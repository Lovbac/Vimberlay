class ActionMapper extends ActionMapperBase {

    ; --- Generic Bindings ---

    TogglePassthrough() {
        VimberlayState.PassthroughEnabled := !VimberlayState.PassthroughEnabled
        CheckVivaldiState()
    }

    ToggleFullscreen() => SendVivaldi("9")
    PageZoomIn() => SendVivaldi("0")
    PageZoomOut() => SendVivaldi("8")
    PageZoomReset() => SendVivaldi("=")

    PassClick() {
        if (VimberlayState.VimMode == VimberlayMode.HINTS) {
            ; Allow click
        }
        if (VimberlayState.VimMode == VimberlayMode.INSERT) {
            WebServer.BroadcastAction("blur")
            this.WaitBlur()
        }
        Action := (*) => (
            Send("{Blind}{LButton Down}")
            KeyWait("LButton")
            Send("{Blind}{LButton Up}")
        )
        this.ActivateNormalMode(Action)
    }

    ; Universal left button handler - pauses GUI updates during mouse hold
    ; Used in ALL modes for consistent drag behavior
    PauseWhileClicking() {
        VimberlayState.StateCheckPaused := true
        Send("{Blind}{LButton Down}")
        KeyWait("LButton")
        Send("{Blind}{LButton Up}")
        VimberlayState.StateCheckPaused := false
        CheckVivaldiState()
    }

    RefocusPage() {
        QueueAction(
            () => (
                SendVivaldi("F9"),
                Sleep(100),
                Send(" "),
                Sleep(Duration.Short),
                Send("{Esc}{Esc}{Esc}"),
                SendVivaldi(Config.FocusPageKey)
            )
        )
    }

    Insert_SendEnterThenExit() {
        this.ActivateNormalMode(() => (
            Send("{Enter}")
        ))
    }

    Insert_SendShiftEnterThenExit() {
        this.ActivateNormalMode(() => (
            Send("+{Enter}")
        ))
    }

    Insert_Exit() {
        this.ActivateNormalMode(() => (
            this.CloseIfEmptyNTP() || SendVivaldi(Config.FocusPageKey)
        ))
    }

    Insert_PageDown() => Send("{PgDn}")
    Insert_PageUp() => Send("{PgUp}")

    EnterInsertMode() => this.FocusCurrentInputOrFindInputs()

    OpenLinkHints() {
        Send("^+f")
        CheckVivaldiState()
    }

    EnterInsertModeAtStart() {
        this.EnterInsertMode()
        Sleep(Duration.Mini)
        Send("{Home}")
    }

    EnterInsertModeAtEnd() {
        this.EnterInsertMode()
        Sleep(Duration.Mini)
        Send("{End}")
    }

    OpenLinkHintsNewTabBg() {
        Send("+!g")
        CheckVivaldiState()
    }

    EditInNeovim() {
        ; TODO Maybe do something via Surfingkeys to check integrity before auto-paste
        ; TODO: Move COPY to browser extension (window.getSelection().toString()) for 100% clean copy.
        ;       PASTE should stay as SendText() because browser extensions cannot easily write to inputs without heavy permissions/focus hacks.

        savedClipboard := ClipboardAll()

        A_Clipboard := ""  ; Must clear in case there is nothing to copy, or we would operate on the existing clipboard.
        Send("^a")
        Sleep(Duration.Mini)
        Send("^c")
        Sleep(Duration.Mini)

        ; Create temp dir if not exists
        TempDir := A_Temp . "\Vimberlay"
        DirCreate(TempDir)

        ; Create temp file
        uuid := GenerateUUID()
        TempFile := TempDir . "\external_edit." . uuid . ".txt"
        FileAppend(A_Clipboard, TempFile, "UTF-8")

        A_Clipboard := savedClipboard ; Restore user clipboard before lauching external editor

        ; Launch Neovim with custom mappings/abbreviations:
        ; - :we            -> Submit (Paste + Enter, Exit Code 5)
        ; - :wq, :x, ZZ, :q-> Update (Paste, Exit Code 0)
        ; - :q!, ZQ, :cq   -> Cancel (Do Nothing, Exit Code 1+)
        ExitCode := 0
        try {
            Args := '-c "cnoreabbrev we w <bar> cquit 100" '
                . '-c "cnoreabbrev wE w <bar> cquit 101" '
                . '-c "cnoreabbrev q! cquit" '
                . '-c "nnoremap ZQ :cquit<CR>" '

            ExitCode := RunWait('nvim.exe ' . Args . '"' . TempFile . '"')
        } catch Error as e {
            MsgBox("Error when running external editor:\n\n" . e.Message, "Vimberlay - Error", "4096 IconX")
            return { ExitCode: -1, FinalAction: () => 0 }
        }

        local finalAction
        if (ExitCode == 0 || ExitCode == 100 || ExitCode == 101) {
            if (FileExist(TempFile)) {
                FileContent := RTrim(FileRead(TempFile, "UTF-8"), " `r`n`t")

                ; 5. Focus Browser & Paste
                if (VimberlayState.LastHwnd && WinExist("ahk_id " VimberlayState.LastHwnd)) {
                    WinActivate("ahk_id " VimberlayState.LastHwnd)
                    WinWaitActive("ahk_id " VimberlayState.LastHwnd, , 2)

                    finalAction := () => (
                        SendText(FileContent),
                        (ExitCode == 100)
                            ? Send("{Enter}")
                            : (ExitCode == 101)
                                ? Send("+{Enter}")
                                : 0
                    )
                }
            }
        } else {
            ; Cancelled or error: Focus browser and deselect (^a was used before)
            if (VimberlayState.LastHwnd && WinExist("ahk_id " . VimberlayState.LastHwnd)) {
                WinActivate("ahk_id " . VimberlayState.LastHwnd)
                WinWaitActive("ahk_id " . VimberlayState.LastHwnd, , 2)
                finalAction := () => (
                    Send("{Right}")
                )
            }
        }

        return { ExitCode: ExitCode, FinalAction: finalAction }
    }

    EditInNeovim_FromInsert() {
        result := this.EditInNeovim()
        exitCode := result.ExitCode
        finalAction := result.FinalAction

        if (exitCode == 0) {
            this.ActivateInsertMode() ; If we are in normal, which we always should be since focus has shifted.
        }
        finalAction()
    }

    EditInNeovim_FromAddressBar() {
        result := this.EditInNeovim()
        finalAction := result.FinalAction
        this.ActivateAddressBarMode(finalAction)
    }

    EditInNeovim_IfTyping() {
        if (IsTyping()) {
            result := this.EditInNeovim()
            finalAction := result.FinalAction
            finalAction()
        }
    }

    Normal_Esc() {
        if (VimberlayState.LastHwnd) {
            try {
                if (WinGetTitle("ahk_id " VimberlayState.LastHwnd) == WindowTitle.VIVALDI_START_PAGE) {
                    SendVivaldi("F6")
                    Sleep(Duration.Short)
                    SendVivaldi("F2")
                    return
                }
            }
        }
        Send("{Esc}")
        WebServer.BroadcastAction("blur")
    }

    SwitchToTab1() => this.ActivateNormalMode(() => SendVivaldi("Z"))
    SwitchToLastTab() => this.ActivateNormalMode(() => Send("^+!H"))
    MoveTabsToBeginning() => QueueAction(() => SendVivaldi("G"))

    MoveTabsToEnd() {
        QueueAction(
            () => (
                SendInput("^+!F"),
                (GetKeyState("LCtrl", "P") ? Send("{LCtrl Down}") : "")
            )
        )
    }

    ScrollDown() => PostScroll(-Config.ScrollLength, true)
    ScrollUp() => PostScroll(Config.ScrollLength, true)
    ScrollDown_Alt() => PostScroll(-Config.ScrollLength)
    ScrollUp_Alt() => PostScroll(Config.ScrollLength)

    PreviousTab() {
        this.ActivateNormalMode(() => SendVivaldi("F5"))
    }
    NextTab() {
        this.ActivateNormalMode(() => SendVivaldi("F3"))
    }

    CloseTab() {
        Action() {
            SendVivaldi("F2")
        }
        QueueAction(Action)
    }

    CloseTab_Alt() => QueueAction(() => SendVivaldi("F2"))

    ShowQuickCommands() => QueueAction(() => SendVivaldi("."))
    MoveActiveTabBackward() => QueueAction(() => SendVivaldi("F6"))
    MoveActiveTabForward() => QueueAction(() => SendVivaldi("F4"))
    ReopenClosedTab() => QueueAction(() => SendVivaldi("F7"))
    FocusAddressBar() => this.ActivateAddressBarMode(() => SendVivaldi("7"))

    OpenURL() => this.ActivateAddressBarMode(() => SendVivaldi("F9"))
    NewTab() => this.ActivateAddressBarMode(() => SendVivaldi("F1"))
    EditURL() {
        this.ActivateAddressBarMode(
            () => (
                SendVivaldi("F9"),
                Sleep(100),
                Send("{Right}")
            )
        )
    }

    ReloadPage() => QueueSend(Config.BrowserBindings.Reload)
    ForceReloadPage() => QueueSend(Config.BrowserBindings.ForceReload)
    HistoryBack() => QueueSend(Config.BrowserBindings.HistoryBack)
    HistoryForward() => QueueSend(Config.BrowserBindings.HistoryForward)
    OpenDevTools() => QueueAction(() => SendVivaldi("F12"))
    PageUp() => PostScroll(Config.ScrollLength * Config.PageScrollRatio, true)
    PageDown() => PostScroll(-Config.ScrollLength * Config.PageScrollRatio, true)

    ScrollToTop() => PostScroll(Config.MaxScrollLength, true, 25)
    ScrollToBottom() => PostScroll(-Config.MaxScrollLength, true, 25)

    FocusFirstInput() => this.FindInputs()

    AddressBar_Enter() {
        Send("{Enter}")
        this.ActivateNormalMode(() => {})
    }

    AddressBar_Esc() {
        this.ActivateNormalMode(() => (
            this.CloseIfEmptyNTP() || SendVivaldi(Config.FocusPageKey)
        ))
    }

    Hints_Esc() => QueueSend("{Esc}")

    Hints_PreviousTab() {
        QueueSend("{Esc}", 25)
        if (!QueueAction(() => (VimberlayState.VimMode == VimberlayMode.HINTS))) {
            this.ActivateNormalMode(() => SendVivaldi("F5"))
        }
    }

    Hints_NextTab() {
        QueueSend("{Esc}", 25)
        if (!QueueAction(() => (VimberlayState.VimMode == VimberlayMode.HINTS))) {
            this.ActivateNormalMode(() => SendVivaldi("F3"))
        }
    }

    FindInputs() {
        this.ActivateInsertMode(
            () => (
                WebServer.BroadcastAction("blur"),
                this.WaitBlur(),
                Send(Config.BrowserBindings.FocusCurrentInputOrFindInputs),
                Sleep(Duration.Short)
            ))

        if (VimberlayState.VimMode != VimberlayMode.INSERT) {
            ToolTip("No focusable input", Defaults.TOOLTIP_X, Defaults.TOOLTIP_Y)
            SetTimer(() => ToolTip(), Defaults.TOOLTIP_DISPLAY_MS)
        }
    }

    FocusCurrentInputOrFindInputs() {
        this.ActivateInsertMode(
            () => (
                Send(Config.BrowserBindings.FocusCurrentInputOrFindInputs),
                Sleep(Duration.Short)
            ))

        if (VimberlayState.VimMode != VimberlayMode.INSERT) {
            ToolTip("No focusable input", Defaults.TOOLTIP_X, Defaults.TOOLTIP_Y)
            SetTimer(() => ToolTip(), Defaults.TOOLTIP_DISPLAY_MS)
        }
    }

    WaitBlur(timeout := 1000) {

        if (!VimberlayState.WaitingForBlur)
            return true

        this_start := A_TickCount
        while (VimberlayState.WaitingForBlur && A_TickCount - this_start < timeout) {
            Sleep(Duration.Yield)
        }

        return !VimberlayState.WaitingForBlur
    }

    AbortsHintsIfActive() {
        if (VimberlayState.VimMode == VimberlayMode.HINTS) {
            Send("!3")
            Sleep(50)
        }
    }

    CloseIfEmptyNTP() {
        static running := false
        if (running) {
            return
        }
        try {
            running := true
            if (!VimberlayState.LastHwnd) {
                return
            }

            title := WinGetTitle("ahk_id " VimberlayState.LastHwnd)
            if (title == WindowTitle.VIVALDI_START_PAGE) {
                currentClipboard := ClipboardAll()
                try {
                    empty_clipboard_placeholder := GenerateUUID()
                    A_Clipboard := empty_clipboard_placeholder
                    Send("^c")
                    Sleep(Duration.Mini)
                    if (A_Clipboard == empty_clipboard_placeholder) {
                        SendVivaldi("F6")
                        Sleep(Duration.Short)
                        SendVivaldi("F2")
                        return true
                    }
                }
                A_Clipboard := currentClipboard ; Restore clipboard
            }

            return false
        } finally {
            running := false
        }
    }

    ; --- Mode Wrappers (Relocated & Renamed) ---

    _ActivateMode(manualInsert, addressBar, actionFunc := "") {
        VimberlayState.StateCheckPaused := true
        VimberlayState.ManualInsertMode := manualInsert
        VimberlayState.AddressBarMode := addressBar
        if (actionFunc != "")
            actionFunc()
        VimberlayState.StateCheckPaused := false
        CheckVivaldiState()
    }

    ActivateNormalMode(actionFunc := "") {
        this._ActivateMode(false, false, actionFunc)
    }

    ActivateInsertMode(actionFunc := "") {
        this._ActivateMode(true, false, actionFunc)
    }

    ActivateAddressBarMode(actionFunc := "") {
        this._ActivateMode(true, true, actionFunc)
    }
}
