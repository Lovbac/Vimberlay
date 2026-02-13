class VimberlayMode {
    static NORMAL => "NORMAL"
    static INSERT => "INSERT"
    static INSERT_URL => "INSERT_URL"
    static HINTS => "HINTS"
    static PASSTHROUGH => "PASSTHROUGH"
    static SEMI_PASSTHROUGH => "SEMI_PASSTHROUGH"
    static SCROLLMARKS => "SCROLLMARKS"
    static SCROLLMARK_EDITOR => "SCROLLMARK_EDITOR"
    static INACTIVE => "INACTIVE" ; TODO not actually a mode, should be handled just like a state
}

; TODO I think can be removed. Communicating via browser extension now.
class WindowTitle {
    static NEOVIM_PREFIX => "[NEOVIM] "
    static VH_PREFIX => "[VH] "
    static VIVALDI_START_PAGE => "Start Page - Vivaldi"
}

; TODO can do away including the tooltips, I only use tooltips for quick debugging.
class Defaults {
    static TOOLTIP_X => 1550
    static TOOLTIP_Y => 987
    static TOOLTIP_DISPLAY_MS => 2500
}
