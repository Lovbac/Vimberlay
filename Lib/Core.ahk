; ==============================================================================
; CORE LOGIC & STATE MACHINE
; ==============================================================================

Contexts := {
    Always: (*) => WinActive("ahk_exe " . Config.BrowserExecutable),
    Scrollmarks: (*) => WinActive("ahk_exe " . Config.BrowserExecutable)
    && VimberlayState.VimMode == VimberlayMode.SCROLLMARKS,
    ScrollmarkEditor: (*) => WinActive("ahk_exe " . Config.BrowserExecutable)
    && VimberlayState.VimMode == VimberlayMode.SCROLLMARK_EDITOR,
    Global: (*) => WinActive("ahk_exe " . Config.BrowserExecutable)
    && VimberlayState.VimMode != VimberlayMode.PASSTHROUGH
    && VimberlayState.VimMode != VimberlayMode.HINTS
    && VimberlayState.VimMode != VimberlayMode.SCROLLMARKS
    && VimberlayState.VimMode != VimberlayMode.SCROLLMARK_EDITOR
    && VimberlayState.VimMode != VimberlayMode.INSERT
    && VimberlayState.VimMode != VimberlayMode.INSERT_URL,
    InsertUrl: (*) => WinActive("ahk_exe " . Config.BrowserExecutable)
    && VimberlayState.VimMode == VimberlayMode.INSERT_URL,
    Insert: (*) => WinActive("ahk_exe " . Config.BrowserExecutable)
    && VimberlayState.VimMode == VimberlayMode.INSERT,
    Normal: (*) => WinActive("ahk_exe " . Config.BrowserExecutable)
    && VimberlayState.VimMode == VimberlayMode.NORMAL,
    Hints: (*) => WinActive("ahk_exe " . Config.BrowserExecutable)
    && VimberlayState.VimMode == VimberlayMode.HINTS
}

; --- MODE CALCULATION ---
; Extracted from CheckVivaldiState to reduce complexity
CalculateMode(isActive, currentIsTyping) {
    if (!isActive)
        return VimberlayMode.NORMAL

    if (VimberlayState.ManualInsertMode && !currentIsTyping)
        VimberlayState.ManualInsertMode := false

    if (VimberlayState.PassthroughEnabled)
        return VimberlayMode.PASSTHROUGH
    if (ScrollMarker.Mode)
        return ScrollMarker.Moved ? VimberlayMode.SCROLLMARK_EDITOR : VimberlayMode.SCROLLMARKS
    if (VimberlayState.AddressBarMode)
        return VimberlayMode.INSERT_URL
    if (InStr(WinGetTitle("ahk_id " VimberlayState.LastHwnd), WindowTitle.NEOVIM_PREFIX)) {
        Actions.EditInNeovim()
        return VimberlayMode.INSERT
    }
    if (VimberlayState.ManualInsertMode && currentIsTyping)
        return VimberlayMode.INSERT
    if (VimberlayState.HintsActive)
        return VimberlayMode.HINTS
    return VimberlayMode.NORMAL
}

CheckVivaldiState() {
    global VisualConfig

    if (VimberlayState.StateCheckPaused)
        return

    static PreviousMode := ""
    static PreviousActive := -1
    static PreviousIsTyping := false
    static IsVisible := false

    ; --- DRAG DETECTION via position change ---
    static LastWinX := 0, LastWinY := 0
    static DragFrameCount := 0

    currentIsTyping := IsTyping()

    currentHwnd := WinActive("ahk_exe " . Config.BrowserExecutable)

    if (currentHwnd) {
        VimberlayState.LastHwnd := currentHwnd
    }

    if (!VimberlayState.LastHwnd || !WinExist("ahk_id " VimberlayState.LastHwnd)) {
        if (IsVisible) {
            HideIndicator()
            IsVisible := false
        }
        VimberlayState.LastHwnd := 0
        return
    }

    if (WinGetMinMax("ahk_id " VimberlayState.LastHwnd) == -1) {
        if (IsVisible) {
            HideIndicator()
            IsVisible := false
        }
        return
    }

    ; --- DRAG DETECTION: Skip updates while window is being dragged ---
    try {
        WinGetPos(&curX, &curY, , , "ahk_id " VimberlayState.LastHwnd)
        if (curX != LastWinX || curY != LastWinY) {
            ; Position changed - increment drag frame counter
            DragFrameCount++
            LastWinX := curX
            LastWinY := curY
            ; If position changed for 2+ consecutive frames, likely dragging
            if (DragFrameCount >= 2)
                return
        } else {
            ; Position stable - reset counter
            DragFrameCount := 0
        }
    }

    isActive := (WinActive("ahk_id " VimberlayState.LastHwnd) != 0)

    ; --- BLUR RESET ---
    ; If we lost focus (Active -> Inactive), reset strict modes
    if (!isActive && PreviousActive) {
        if (!VimberlayState.PassthroughEnabled) {
            VimberlayState.ManualInsertMode := false
            VimberlayState.AddressBarMode := false
        }
    }

    ; --- MODE CALCULATION ---
    currentMode := CalculateMode(isActive, currentIsTyping)
    if (!isActive)
        currentIsTyping := false

    if (currentMode != PreviousMode || isActive != PreviousActive || currentIsTyping != PreviousIsTyping || !IsVisible) {
        VimberlayState.VimMode := currentMode

        if (!(Config.BrowserExecutable == "vivaldi.exe" && Config.UseVivaldiEnhancements))
            ShowIndicator(currentMode, VimberlayState.LastHwnd, isActive)

        PreviousMode := currentMode
        PreviousActive := isActive
        PreviousIsTyping := currentIsTyping
        IsVisible := true
    }

    WebServer.BroadcastStateIfChanged()
    UpdatePosition(VimberlayState.LastHwnd)

    ; --- VISUAL INDICATOR LOGIC (CONFIGURED) ---
    targetX := 0
    targetY := 0
    showCircle := false
    previewX := 0
    previewY := 0

    ; Get Window Position for Relative -> Screen calculation
    WinGetPos(&vx, &vy, &vw, &vh, "ahk_id " VimberlayState.LastHwnd)

    selector := ""
    if (VimberlayState.VimMode == VimberlayMode.SCROLLMARKS || VimberlayState.VimMode == VimberlayMode.SCROLLMARK_EDITOR
    ) {
        ; 1. Selector (Moving Crosshair) - Only if in SCROLLSET mode
        if (VimberlayState.VimMode == VimberlayMode.SCROLLMARK_EDITOR) {
            selector := { x: vx + ScrollMarker.CursorX, y: vy + ScrollMarker.CursorY }
        }

        ; 2. Current Scroll Position (Axis Indicators ONLY, No Circle)
        State := GetActiveState()

        ; If in Select Mode (Crosshair Hidden), visualize active mark based on stored or dynamic coords
        if (VimberlayState.VimMode == VimberlayMode.SCROLLMARKS) {
            if (State.ScrollMode == "COORDS" && State.ScrollCoordinates.x != -1) {
                targetX := vx + State.ScrollCoordinates.x
                targetY := vy + State.ScrollCoordinates.y
            } else if (State.CurrentIndex == "0") {
                ; Special case: Mark 0 active and at center
                targetX := vx + (vw // 2)
                targetY := vy + (vh // 2)
            }
        }
        else {
            ; Crosshair Visible (SCROLLSET): show active circle at its LAST KNOWN location
            ; Or stick to cursor? Logic says we only show crosshair in SCRSET.
            ; The user prompt implies crosshair visible mode SCROLLSET sets marks.
            ; We probably don't show the orange circle of "Active" mark following cursor,
            ; or maybe we do? Old logic: "show active circle at its LAST KNOWN location?"
            ; Actually original code: targetX := ScrollMarkCursorX (but logic was messy)

            ; Let's behave: SCROLLSET shows CROSSHAIR (selector).
            ; Active mark visualization is less important or should stay at last active?
            ; Let's keep it consistent: We show active mark at its location.
            if (State.ScrollMode == "COORDS" && State.ScrollCoordinates.x != -1) {
                targetX := vx + State.ScrollCoordinates.x
                targetY := vy + State.ScrollCoordinates.y
            }
        }

    }
    else {
        State := GetActiveState()

        ; Only show if explicitly set (NOT -1) OR if CurrentIndex is "0" (dynamic center)
        ; BUT: Don't show mark 0 if it's the only mark (no saved marks 1-9)
        hasOtherMarks := false
        for idx, pos in State.CoordinateMarks {
            if (idx != "0" && pos.x != -1) {
                hasOtherMarks := true
                break
            }
        }

        if (State.CurrentIndex == "0" && hasOtherMarks) {
            ; Mark 0 is the dynamic center
            targetX := vx + (vw // 2)
            targetY := vy + (vh // 2)
            showCircle := VisualConfig.Active_ShowCircle
        } else if (State.ScrollMode == "COORDS" && State.ScrollCoordinates.x != -1) {
            ; State coordinates are Relative
            targetX := vx + State.ScrollCoordinates.x
            targetY := vy + State.ScrollCoordinates.y
            showCircle := VisualConfig.Active_ShowCircle
        }
        else if (State.ScrollMode == "COORDS" && State.ScrollCoordinates.x == -1) {
            showCircle := false
        }

        ; === CALCULATE PREVIEW POSITION (NORMAL & INSERT MODE) ===
        if (VimberlayState.VimMode == VimberlayMode.NORMAL || VimberlayState.VimMode == VimberlayMode.INSERT ||
            VimberlayState.VimMode == VimberlayMode.INSERT_URL) {
            PreviewIndex := ScrollMarker.GetJumpBackPreview(State)

            ; "unless it is both (logically mark 0 && mark 0 is active)"
            ; Don't render if preview is "0" and current is "0"
            if (PreviewIndex != "" && !(PreviewIndex == "0" && State.CurrentIndex == "0")) {
                if (PreviewIndex == "0") {
                    ; Mark 0 is the dynamic center, calculate it
                    previewX := vx + (vw // 2)
                    previewY := vy + (vh // 2)
                } else if (State.CoordinateMarks.Has(PreviewIndex)) {
                    PreviewPos := State.CoordinateMarks[PreviewIndex]
                    previewX := vx + PreviewPos.x
                    previewY := vy + PreviewPos.y
                }
            }
        }
    }

    ; --- FETCH ALL MARKS FOR VISUALIZATION ---
    marksMap := ""
    currentIndex := ""
    previewIndex := ""

    if (VimberlayState.VimMode == VimberlayMode.SCROLLMARKS || VimberlayState.VimMode == VimberlayMode.SCROLLMARK_EDITOR
    ) {
        State := GetActiveState()
        if (State.CoordinateMarks.Count > 0) {
            marksMap := State.CoordinateMarks
        }
        ; Pass current and preview indices for color coding
        currentIndex := State.CurrentIndex
        previewIndex := ScrollMarker.GetJumpBackPreview(State)
    }

    ScrollMarker.UpdateVisuals(VimberlayState.LastHwnd, targetX, targetY, showCircle, vx, vy, vw, vh, isActive,
        marksMap,
        selector,
        previewX,
        previewY, currentIndex, previewIndex)
}

ResetToNormalMode() {
    ScrollMarker.Mode := false
    VimberlayState.HintsActive := false
    VimberlayState.ManualInsertMode := false
    VimberlayState.AddressBarMode := false
    CheckVivaldiState()
}
