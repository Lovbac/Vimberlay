; ==============================================================================
; CONFIGURATION & GLOBALS
; ==============================================================================

class VimberlayState {
    static VimMode := VimberlayMode.NORMAL
    static AddressBarMode := false

    ; --- Mutable State ---
    static PassthroughEnabled := false
    static ManualInsertMode := false
    static HintsActive := false
    static CurrentSID := ""
    static StateCheckPaused := false
    static WaitingForBlur := false
    static LastHwnd := 0
    static ChordTimestamps := Map()
    static GlobalScrollId := 0

    ; --- Visual State ---
    static ModeIndicatorGui := ""
    ; Width/Height moved to Constants
    static ModeIndicatorLastX := 0
    static ModeIndicatorLastY := 0
    static TypingIndicatorGui := ""
    static ShownGuis := Map()

    static GetPublicStateAsJson() {
        return ToJson({
            Key: "mode",
            Value: this.VimMode,
            Type: JsonType.String
        })
    }
}

; --- VISUAL CONFIGURATION ---
VisualConfig := {
    ; 1. MarkSet Mode (Setting a mark)
    MarkSet_ShowCircle: true,
    ; 2. Active Mark Mode (After jumping to a position)
    Active_ShowCircle: true
}

; --- MARKSET & VISUAL STATE ---
; --- SCROLLMARK STATE ---

CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"