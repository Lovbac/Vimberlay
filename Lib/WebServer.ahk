; ==============================================================================
; WEB SERVER WITH SSE SUPPORT (Winsock)
; HTTP endpoints + Server-Sent Events for real-time state push
; ==============================================================================

class WebServer {
    static ServerSocket := -1
    static WM_SOCKET := 0x5000
    static Started := false
    static ClientSockets := Map()  ; Regular HTTP clients (closed after response)
    static SSEClients := Map()     ; SSE clients (kept alive for push)

    static Start() {
        if (this.Started)
            return

        wsaData := Buffer(400)
        result := DllCall("Ws2_32\WSAStartup", "UShort", 0x0202, "Ptr", wsaData)
        if (result != 0) {
            ToolTip("WSAStartup failed: " . result)
            return
        }

        this.ServerSocket := DllCall("Ws2_32\socket", "Int", 2, "Int", 1, "Int", 6, "Ptr")
        if (this.ServerSocket == -1) {
            ToolTip("Socket creation failed")
            return
        }

        sockaddr := Buffer(16, 0)
        NumPut("UShort", 2, sockaddr, 0)
        NumPut("UShort", DllCall("Ws2_32\htons", "UShort", Config.Port, "UShort"), sockaddr, 2)
        NumPut("UInt", DllCall("Ws2_32\inet_addr", "AStr", "127.0.0.1", "UInt"), sockaddr, 4)

        if (DllCall("Ws2_32\bind", "Ptr", this.ServerSocket, "Ptr", sockaddr, "Int", 16) != 0) {
            this.Cleanup()
            return
        }

        DllCall("Ws2_32\listen", "Ptr", this.ServerSocket, "Int", 5)
        DllCall("Ws2_32\WSAAsyncSelect", "Ptr", this.ServerSocket, "Ptr", A_ScriptHwnd, "UInt", this.WM_SOCKET, "Int",
            8) ; FD_ACCEPT

        OnMessage(this.WM_SOCKET, this.HandleSocketMessage.Bind(this))

        ; Start SSE heartbeat timer (every 30 seconds)
        SetTimer(ObjBindMethod(this, "SendHeartbeat"), 30000)

        this.Started := true
        ToolTip("Vimberlay WebServer Started on port " . Config.Port . " (SSE enabled)")
        SetTimer(() => ToolTip(), -3000)
    }

    static Stop() {
        if (!this.Started)
            return
        SetTimer(ObjBindMethod(this, "SendHeartbeat"), 0)
        this.Cleanup()
        this.Started := false
    }

    static Cleanup() {
        if (this.ServerSocket != -1) {
            DllCall("Ws2_32\closesocket", "Ptr", this.ServerSocket)
            this.ServerSocket := -1
        }
        for sock, _ in this.ClientSockets
            DllCall("Ws2_32\closesocket", "Ptr", sock)
        for sock, _ in this.SSEClients
            DllCall("Ws2_32\closesocket", "Ptr", sock)
        this.ClientSockets := Map()
        this.SSEClients := Map()
        DllCall("Ws2_32\WSACleanup")
    }

    static HandleSocketMessage(wParam, lParam, msg, hwnd) {
        socket := wParam
        event := lParam & 0xFFFF
        error := lParam >> 16

        if (error != 0) {
            this.CloseClient(socket)
            this.CloseSSEClient(socket)
            return
        }

        if (socket == this.ServerSocket) {
            if (event == 8) ; FD_ACCEPT
                this.AcceptConnection()
        } else {
            if (event == 1) ; FD_READ
                this.HandleRead(socket)
            else if (event == 32) ; FD_CLOSE
            {
                this.CloseClient(socket)
                this.CloseSSEClient(socket)
            }
        }
    }

    static AcceptConnection() {
        clientSock := DllCall("Ws2_32\accept", "Ptr", this.ServerSocket, "Ptr", 0, "Ptr", 0, "Ptr")
        if (clientSock == -1)
            return

        this.ClientSockets[clientSock] := true
        DllCall("Ws2_32\WSAAsyncSelect", "Ptr", clientSock, "Ptr", A_ScriptHwnd, "UInt", this.WM_SOCKET, "Int", 1 | 32) ; FD_READ | FD_CLOSE
    }

    static HandleRead(socket) {
        buf := Buffer(2048)
        received := DllCall("Ws2_32\recv", "Ptr", socket, "Ptr", buf, "Int", 2048, "Int", 0)

        if (received > 0) {
            reqStr := StrGet(buf, received, "UTF-8")

            ; --- CORS Preflight ---
            if (InStr(reqStr, "OPTIONS ")) {
                this.SendCORSPreflight(socket)
                return
            }

            ; --- POST /command (from Vivaldi mod or Extension) ---
            if (InStr(reqStr, "POST /command")) {
                if (RegExMatch(reqStr, "s)\r\n\r\n(.*)", &match)) {
                    this.HandleCommand(match[1])
                }
                this.SendJson(socket, '{ "status": "ok" }')
                return
            }

            ; --- GET /events (SSE endpoint) ---
            if (InStr(reqStr, "GET /events")) {
                this.UpgradeToSSE(socket)
                this.SendSSEEvent(socket, "state", VimberlayState.GetPublicStateAsJson())
                return ; Don't close - SSE client stays connected
            }

            ; --- GET /vivaldimod/config ---
            if (InStr(reqStr, "GET /config")) {
                configJson := ToJson({
                    Key: "constants",
                    Value: ToJson({
                        Key: "vimberlayMode",
                        Value: ToJson(ApplyMap(GetPublicProps(VimberlayMode), (v, k) =>
                            ({ Key: k, Value: v, Type: JsonType.String }))*),
                        Type: JsonType.Raw
                    }),
                    Type: JsonType.Raw
                }, {
                    Key: "config",
                    Value: ToJson({
                        Key: "useVivaldiEnhancements",
                        Value: Config.UseVivaldiEnhancements,
                        Type: JsonType.Bool
                    }, {
                        Key: "debug",
                        Value: Config.Debug,
                        Type: JsonType.Bool
                    }, {
                        Key: "modeProperties",
                        Value: Config.ModeProperties.ToJson(),
                        Type: JsonType.Raw
                    }),
                    Type: JsonType.Raw,
                })

                this.SendJson(socket, configJson)
                return
            }
        }
        this.CloseClient(socket)
    }

    ; === SSE HANDLING ===

    static UpgradeToSSE(socket) {
        ; Move from regular clients to SSE clients
        if (this.ClientSockets.Has(socket))
            this.ClientSockets.Delete(socket)

        this.SSEClients[socket] := true

        ; Send SSE headers
        headers := "HTTP/1.1 200 OK`r`n"
            . "Content-Type: text/event-stream`r`n"
            . "Cache-Control: no-cache`r`n"
            . "Connection: keep-alive`r`n"
            . "Access-Control-Allow-Origin: *`r`n"
            . "`r`n"

        this.SendString(socket, headers)

        this.Log("SSE client connected (total: " . this.SSEClients.Count . ")")
    }

    static SendSSEEvent(socket, eventType, data) {
        ; SSE format: "event: type\ndata: json\n\n"
        msg := "event: " . eventType . "`ndata: " . data . "`n`n"
        result := this.SendString(socket, msg)
        return result
    }

    static SendHeartbeat() {
        ; Send heartbeat to all SSE clients to keep connections alive
        deadClients := []
        for socket, _ in this.SSEClients {
            ; SSE comment line (starts with :) is used as heartbeat
            result := this.SendString(socket, ": heartbeat`n`n")
            if (result == -1)
                deadClients.Push(socket)
        }
        ; Clean up dead clients
        for socket in deadClients
            this.CloseSSEClient(socket)
    }

    static CloseSSEClient(socket) {
        if (this.SSEClients.Has(socket)) {
            DllCall("Ws2_32\closesocket", "Ptr", socket)
            this.SSEClients.Delete(socket)
            this.Log("SSE client disconnected (remaining: " . this.SSEClients.Count . ")")
        }
    }

    ; === PUSH STATE (broadcasts to all SSE clients) ===

    static BroadcastStateIfChanged() {
        static lastStateJson := ""

        stateJson := VimberlayState.GetPublicStateAsJson()
        if (stateJson == lastStateJson)
            return
        lastStateJson := stateJson

        ; Push state to all clients
        deadClients := []
        for socket, _ in this.SSEClients {
            result := this.SendSSEEvent(socket, "state", stateJson)
            if (result == -1)
                deadClients.Push(socket)
        }
        ; Clean up dead clients
        for socket in deadClients
            this.CloseSSEClient(socket)
    }

    static BroadcastAction(action, dataJson := "") {
        payloadJson := ToJson({
            Key: "action", Value: action, Type: JsonType.String
        }, !dataJson ? "" : {
            Key: "data", Value: dataJson, Type: JsonType.Raw
        })

        ; Note: Generalize waiting mechanism if use-cases grow
        if (action == "blur") {
            VimberlayState.WaitingForBlur := true
        }

        this.Log("Pushing action: " . action)

        ; Push action to all clients
        deadClients := []
        for socket, _ in this.SSEClients {
            result := this.SendSSEEvent(socket, "action", payloadJson)
            if (result == -1)
                deadClients.Push(socket)
        }
        ; Clean up dead clients
        for socket in deadClients
            this.CloseSSEClient(socket)
    }

    ; === COMMAND HANDLING ===

    static HandleCommand(jsonStr) {
        try {
            cleanJson := StrReplace(jsonStr, " ", "")
            if (InStr(cleanJson, '"command":"reset_to_normal"')) {
                ResetToNormalMode()
                this.Log("Command: reset_to_normal")
            } else if (InStr(cleanJson, '"command":"linkhints"')) {
                if (InStr(cleanJson, '"active":true')) {
                    VimberlayState.HintsActive := true
                } else {
                    VimberlayState.HintsActive := false
                }
                CheckVivaldiState()
                this.Log("Command: linkhints " . (VimberlayState.HintsActive ? "ON" : "OFF"))
            } else if (InStr(cleanJson, '"command":"sid"')) {
                if (RegExMatch(jsonStr, '"value"\s*:\s*"([A-F0-9]+)"', &match)) {
                    VimberlayState.CurrentSID := match[1]
                    this.Log("Command: sid = " . VimberlayState.CurrentSID)
                }
            } else if (InStr(cleanJson, '"command":"blur_complete"')) {
                VimberlayState.WaitingForBlur := false
                this.Log("Command: blur_complete")
            } else if (InStr(cleanJson, '"command":"input_clicked"')) {
                if (IsTyping()) {
                    VimberlayState.ManualInsertMode := true
                    CheckVivaldiState()
                    this.Log("Command: input_clicked -> INSERT")
                }
            } else if (InStr(cleanJson, '"command":"input_blurred"')) {
                ResetToNormalMode()
                this.Log("Command: input_blurred -> NORMAL")
            } else {
                this.Log("Command (unknown): " . jsonStr)
            }
        }
    }

    static Log(msg) {
        FileAppend(FormatTime() . " - " . msg . "`n", A_ScriptDir . "\web_log.txt")
    }

    ; === HTTP RESPONSES ===

    static SendCORSPreflight(socket) {
        response := "HTTP/1.1 204 No Content`r`n"
            . "Access-Control-Allow-Origin: *`r`n"
            . "Access-Control-Allow-Methods: GET, POST, OPTIONS`r`n"
            . "Access-Control-Allow-Headers: Content-Type`r`n"
            . "Access-Control-Max-Age: 86400`r`n"
            . "Connection: close`r`n`r`n"
        this.SendString(socket, response)
        this.CloseClient(socket)
    }

    static SendJson(socket, json) {
        response := "HTTP/1.1 200 OK`r`n"
            . "Content-Type: application/json`r`n"
            . "Access-Control-Allow-Origin: *`r`n"
            . "Connection: close`r`n"
            . "Content-Length: " . StrLen(json) . "`r`n"
            . "`r`n"
            . json
        this.SendString(socket, response)
        this.CloseClient(socket)
    }

    static CloseClient(socket) {
        if (this.ClientSockets.Has(socket)) {
            DllCall("Ws2_32\closesocket", "Ptr", socket)
            this.ClientSockets.Delete(socket)
        }
    }

    static Send404(socket) {
        body := "Not Found"
        response := "HTTP/1.1 404 Not Found`r`n"
            . "Content-Length: " . StrLen(body) . "`r`n"
            . "Connection: close`r`n`r`n"
            . body

        this.SendString(socket, response)
    }

    static SendString(sock, str) {
        buf := Buffer(StrPut(str, "UTF-8"))
        len := StrPut(str, buf, "UTF-8")
        result := DllCall("Ws2_32\send", "Ptr", sock, "Ptr", buf, "Int", len - 1, "Int", 0)
        return result
    }
}
