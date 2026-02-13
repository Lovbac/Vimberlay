; Track which GUIs are currently shown (to avoid calling Show repeatedly)
; Track which GUIs are currently shown (to avoid calling Show repeatedly)
; VimberlayState.ShownGuis tracks this now

; Helper to show GUI only once, then just move
ShowOrMove(g, x, y, w := unset, h := unset) {
    if (!VimberlayState.ShownGuis.Has(g.Hwnd)) {
        ; First time: Show with position to avoid ghost at wrong location
        showOpts := "NoActivate x" x " y" y
        if (IsSet(w))
            showOpts .= " w" w
        if (IsSet(h))
            showOpts .= " h" h
        g.Show(showOpts)
        VimberlayState.ShownGuis[g.Hwnd] := true
    } else {
        ; Already shown, just move
        g.Move(x, y, IsSet(w) ? w : unset, IsSet(h) ? h : unset)
    }
}

; Helper to hide GUI and clear shown state
HideGui(g) {
    g.Hide()
    if (VimberlayState.ShownGuis.Has(g.Hwnd)) {
        VimberlayState.ShownGuis.Delete(g.Hwnd)
    }
}

; ==============================================================================
; MODE INDICATOR HUD (Existing Logic, slightly cleaned)
; ==============================================================================

ShowIndicator(mode, ownerHwnd, isActive := true) {

    ; Width/Height now in Config
    boxWidth := Config.ModeIndicatorWidth
    boxHeight := Config.ModeIndicatorHeight
    text := ""
    bgColor := ""

    if (mode == VimberlayMode.PASSTHROUGH) {
        bgColor := Config.ModeProperties.Passthrough.BackgroundColor
        text := Config.ModeProperties.Passthrough.Text
    } else if (mode == VimberlayMode.HINTS) {
        bgColor := Config.ModeProperties.Hints.BackgroundColor
        text := Config.ModeProperties.Hints.Text
    } else if (mode == VimberlayMode.INSERT) {
        bgColor := Config.ModeProperties.Insert.BackgroundColor
        text := Config.ModeProperties.Insert.Text
    } else if (mode == VimberlayMode.INSERT_URL) {
        bgColor := Config.ModeProperties.InsertUrl.BackgroundColor
        text := Config.ModeProperties.InsertUrl.Text
    } else if (mode == VimberlayMode.SCROLLMARKS) {
        bgColor := Config.ModeProperties.Scrollmarks.BackgroundColor
        text := Config.ModeProperties.Scrollmarks.Text
    } else if (mode == VimberlayMode.SCROLLMARK_EDITOR) {
        bgColor := Config.ModeProperties.ScrollmarkEditor.BackgroundColor
        text := Config.ModeProperties.ScrollmarkEditor.Text
    } else if (mode == VimberlayMode.NORMAL) {
        bgColor := Config.ModeProperties.Normal.BackgroundColor
        text := Config.ModeProperties.Normal.Text
    }

    FinalColor := isActive ? bgColor : Config.ModeProperties.Inactive.BackgroundColor

    if (IsObject(VimberlayState.ModeIndicatorGui) && WinExist("ahk_id " VimberlayState.ModeIndicatorGui.Hwnd)) {
        VimberlayState.ModeIndicatorGui.BackColor := FinalColor
        VimberlayState.ModeIndicatorGui["ModeLabel"].Value := text
        VimberlayState.ModeIndicatorGui.Show("NoActivate")
    }
    else {
        try {
            VimberlayState.ModeIndicatorGui := Gui("-Caption +ToolWindow +E0x20 +E0x80000 -DPIScale +Owner" ownerHwnd
            )
            VimberlayState.ModeIndicatorGui.BackColor := FinalColor
            VimberlayState.ModeIndicatorGui.SetFont("s11 w700", "Consolas")
            VimberlayState.ModeIndicatorGui.Add("Text", "vModeLabel x0 y0 w" boxWidth " h" boxHeight " Center cBlack 0x200",
                text)
            WinSetTransparent(255, VimberlayState.ModeIndicatorGui.Hwnd)
            WinSetRegion("0-0 w" boxWidth " h" boxHeight " R6-6", VimberlayState.ModeIndicatorGui.Hwnd)
            ; Calculate actual position instead of 0,0 to avoid stale lastX/lastY issues
            try {
                WinGetPos(&vx, &vy, &vw, &vh, "ahk_id " ownerHwnd)
                xPos := vx + vw - boxWidth - Config.IndicatorPadding
                yPos := vy + vh - boxHeight - Config.IndicatorPadding
                VimberlayState.ModeIndicatorGui.Show("NoActivate x" xPos " y" yPos " w" boxWidth " h" boxHeight)
            } catch {
                VimberlayState.ModeIndicatorGui.Show("NoActivate x0 y0 w" boxWidth " h" boxHeight)
            }
        } catch {
            VimberlayState.ModeIndicatorGui := ""
            return
        }
    }

}

; VimberlayState.ModeIndicatorWidth/Height removed - using Config directly

HideIndicator() {
    if (IsObject(VimberlayState.ModeIndicatorGui)) {
        try VimberlayState.ModeIndicatorGui.Destroy()
        VimberlayState.ModeIndicatorGui := ""
    }
    ; Reset position tracking so next Show will move to correct position
    VimberlayState.ModeIndicatorLastX := 0
    VimberlayState.ModeIndicatorLastY := 0
}

UpdatePosition(hwnd) {

    if (!IsObject(VimberlayState.ModeIndicatorGui))
        return
    try {
        WinGetPos(&vx, &vy, &vw, &vh, "ahk_id " hwnd)
        xPos := vx + vw - Config.ModeIndicatorWidth - Config.IndicatorPadding
        yPos := vy + vh - Config.ModeIndicatorHeight - Config.IndicatorPadding

        ; Only call Move if position actually changed
        if (xPos != VimberlayState.ModeIndicatorLastX || yPos != VimberlayState.ModeIndicatorLastY) {
            VimberlayState.ModeIndicatorGui.Move(xPos, yPos)
            VimberlayState.ModeIndicatorLastX := xPos
            VimberlayState.ModeIndicatorLastY := yPos
        }
    } catch {
        HideIndicator()
    }
}
