; ==============================================================================
; STATE MANAGEMENT (TABS & SIZES)
; ==============================================================================

; Structure: TabStates[TabID] -> SizeMap[WxH] -> TabStateModel
TabStates := Map()

class TabStateModel {
    ScrollMode := "COORDS"
    ScrollCoordinates := { x: -1, y: -1 }
    CurrentIndex := "0"
    HistoryStack := ["0"]
    CoordinateMarks := Map("0", { x: -1, y: -1 })
}

GetActiveState() {
    global TabStates

    stateKey := ""

    ; --- 1. RESOLVE TAB IDENTITY (SID) ---
    if (Config.StateMode == 4) {
        if (VimberlayState.CurrentSID != "") {
            stateKey := VimberlayState.CurrentSID
        } else {
            ; Fallback while waiting for WebSocket SID
            rawTitle := WinGetTitle("ahk_id " VimberlayState.LastHwnd)
            clean := StrReplace(rawTitle, WindowTitle.VH_PREFIX, "")
            clean := StrReplace(clean, WindowTitle.NEOVIM_PREFIX, "")
            clean := RegExReplace(clean, "\s\[SID:.*?\]", "")
            stateKey := "TEMP_" . clean
        }
    } else {
        ; Legacy Modes
        rawTitle := WinGetTitle("ahk_id " VimberlayState.LastHwnd)
        stateKey := StrReplace(rawTitle, WindowTitle.VH_PREFIX, "")
    }

    ; --- 2. RESOLVE WINDOW DIMENSIONS ---
    ; To make scroll positions specific to window size, we create sub-buckets.

    minMax := WinGetMinMax("ahk_id " VimberlayState.LastHwnd)
    sizeKey := ""

    if (minMax == 1) {
        sizeKey := "MAXIMIZED"
    } else {
        WinGetPos(, , &w, &h, "ahk_id " VimberlayState.LastHwnd)
        ; Round to nearest 50px to handle small border fluctuations
        w := Round(w / 50) * 50
        h := Round(h / 50) * 50
        sizeKey := w . "x" . h
    }

    ; --- 3. RETRIEVE NESTED STATE ---

    ; Level 1: Tab Identity
    if (!TabStates.Has(stateKey)) {
        TabStates[stateKey] := Map()
    }
    SizeMap := TabStates[stateKey]

    ; Level 2: Window Size
    if (!SizeMap.Has(sizeKey)) {
        SizeMap[sizeKey] := TabStateModel()
    }

    return SizeMap[sizeKey]
}

SaveActiveState(State) {
    ; Mode 4 saves automatically to memory map by reference
}
