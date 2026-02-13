class ScrollMarker {
    ; --- State Properties (from Globals.ahk) ---
    static Mode := false
    static CursorX := 0
    static CursorY := 0
    static Moved := false

    static SELECT_MODE_TOOLTIP => "Scrollmarks: [hjkl] Set Mode, [1-9] Jump, [Del] Delete, [Esc] Exit"
    static SET_MODE_TOOLTIP => "Scrollmark Editor: [hjkl] Move, [1-9] Save, [Esc] Cancel"

    ; --- Visual GUI Handles (from Visuals.ahk) ---
    static MarkGuis := Map()
    static CrosshairGuis := ""
    static ActiveCircle := ""
    static NormalIndicator := ""
    static PreviewIndicator := ""
    static LastOwnerHwnd := 0

    ; --- Action Methods (from Actions.ahk) ---

    static CenterCursor() {
        hwnd := VimberlayState.LastHwnd ? VimberlayState.LastHwnd : WinExist("A")
        try {
            WinGetPos(, , &vw, &vh, "ahk_id " hwnd)
            ScrollMarker.CursorX := vw // 2
            ScrollMarker.CursorY := vh // 2
        }
    }

    static EnterSelectMode() {
        ScrollMarker.Mode := true
        ScrollMarker.Moved := false
        ScrollMarker.CenterCursor()
        CheckVivaldiState()
        ToolTip(ScrollMarker.SELECT_MODE_TOOLTIP)
    }

    static EnterSetMode() {
        ScrollMarker.Mode := true
        ScrollMarker.Moved := true
        ScrollMarker.CenterCursor()
        CheckVivaldiState()
        ToolTip(ScrollMarker.SET_MODE_TOOLTIP)
    }

    static ExitMode() {
        ScrollMarker.Mode := false
        CheckVivaldiState()
        ToolTip()
    }

    static SetToSelect() {
        ScrollMarker.Moved := false
        ScrollMarker.CenterCursor()
        CheckVivaldiState()
        ToolTip(ScrollMarker.SELECT_MODE_TOOLTIP)
    }

    static Move(dx, dy) {
        ScrollMarker.CursorX += dx
        ScrollMarker.CursorY += dy
        ScrollMarker.Moved := true
        CheckVivaldiState()
    }

    static AddToHistory(State, Index) {
        if (State.HistoryStack.Length == 0 || State.HistoryStack[State.HistoryStack.Length] != Index) {
            State.HistoryStack.Push(Index)
        }
    }

    static Jump(MarkChar) {
        State := GetActiveState()
        if (State.CoordinateMarks.Has(MarkChar)) {
            if (State.CurrentIndex != MarkChar) {
                ScrollMarker.AddToHistory(State, State.CurrentIndex)
            }
            State.CurrentIndex := MarkChar
            Target := State.CoordinateMarks[MarkChar]
            State.ScrollCoordinates := { x: Target.x, y: Target.y }
            State.ScrollMode := "COORDS"
            SaveActiveState(State)
            ScrollMarker.ExitMode()
            ToolTip("Jumped to Mark " . MarkChar)
            SetTimer(() => ToolTip(), -1000)
        } else {
            ToolTip("Mark " . MarkChar . " is empty")
            SetTimer(() => ToolTip(), -1000)
        }
    }

    static JumpBack() {
        State := GetActiveState()
        TargetIndex := ""
        Found := false
        while (State.HistoryStack.Length > 0) {
            Candidate := State.HistoryStack.Pop()
            if (Candidate == State.CurrentIndex) {
                continue
            }
            if (State.CoordinateMarks.Has(Candidate)) {
                TargetIndex := Candidate
                Found := true
                break
            }
        }
        if (!Found) {
            if (State.CoordinateMarks.Has("0") && State.CurrentIndex != "0") {
                TargetIndex := "0"
                Found := true
            }
        }
        if (Found) {
            ScrollMarker.AddToHistory(State, State.CurrentIndex)
            State.CurrentIndex := TargetIndex
            Target := State.CoordinateMarks[TargetIndex]
            State.ScrollCoordinates := { x: Target.x, y: Target.y }
            State.ScrollMode := "COORDS"
            SaveActiveState(State)
            ScrollMarker.ExitMode()
            ToolTip("Jumped Back to " . TargetIndex)
            SetTimer(() => ToolTip(), -1000)
        } else {
            ScrollMarker.ExitMode()
        }
    }

    static IsAtCenter() {
        if (!VimberlayState.LastHwnd)
            return false
        try {
            WinGetPos(, , &vw, &vh, "ahk_id " VimberlayState.LastHwnd)
            cx := vw // 2
            cy := vh // 2
            return (Abs(ScrollMarker.CursorX - cx) <= 1 && Abs(ScrollMarker.CursorY - cy) <= 1)
        }
        return false
    }

    static DeleteMark(Slot) {
        State := GetActiveState()
        if (!State.CoordinateMarks.Has(Slot)) {
            ToolTip("Mark " . Slot . " is already empty")
            SetTimer(() => ToolTip(), -1000)
            return
        }
        State.CoordinateMarks.Delete(Slot)
        if (State.CurrentIndex == Slot) {
            NewIndex := ScrollMarker.GetJumpBackPreview(State)
            if (NewIndex != "" && State.CoordinateMarks.Has(NewIndex)) {
                State.CurrentIndex := NewIndex
                Target := State.CoordinateMarks[NewIndex]
                State.ScrollCoordinates := { x: Target.x, y: Target.y }
            } else {
                State.CurrentIndex := "0"
                State.ScrollCoordinates := { x: -1, y: -1 }
            }
        }
        SaveActiveState(State)
        CheckVivaldiState()
        ToolTip("Deleted Mark " . Slot)
        SetTimer(() => ToolTip(), -1000)
        hasMarks := false
        for char, _ in State.CoordinateMarks {
            if (char != "0") {
                hasMarks := true
                break
            }
        }
        if (!hasMarks) {
            ScrollMarker.ExitMode()
        }
    }

    static Delete(Slot) {
        ScrollMarker.DeleteMark(Slot)
    }

    static DeleteAll() {
        State := GetActiveState()
        loop 9 {
            idx := String(A_Index)
            if (State.CoordinateMarks.Has(idx)) {
                State.CoordinateMarks.Delete(idx)
            }
        }
        State.CurrentIndex := "0"
        State.ScrollCoordinates := { x: -1, y: -1 }
        SaveActiveState(State)
        CheckVivaldiState()
        ToolTip("Deleted Marks 1-9")
        SetTimer(() => ToolTip(), -1000)
        ScrollMarker.ExitMode()
    }

    static SaveTo(Slot) {
        if (Slot == "0" && !ScrollMarker.IsAtCenter()) {
            if (VimberlayState.LastHwnd) {
                try {
                    WinGetPos(, , &vw, &vh, "ahk_id " VimberlayState.LastHwnd)
                    ScrollMarker.CursorX := vw // 2
                    ScrollMarker.CursorY := vh // 2
                }
            }
            CheckVivaldiState()
            ToolTip("Recentered")
            SetTimer(() => ToolTip(), -1000)
            return
        }
        if (ScrollMarker.IsAtCenter()) {
            ScrollMarker.ExitMode()
            return
        }
        State := GetActiveState()
        for char, pos in State.CoordinateMarks {
            if (char != "0" && char != Slot && pos.x == ScrollMarker.CursorX && pos.y == ScrollMarker.CursorY) {
                State.CoordinateMarks.Delete(char)
                ScrollMarker.DestroyMarkGui(char)
            }
        }
        State.CoordinateMarks[Slot] := { x: ScrollMarker.CursorX, y: ScrollMarker.CursorY }
        if (State.CurrentIndex != Slot) {
            ScrollMarker.AddToHistory(State, State.CurrentIndex)
        }
        State.CurrentIndex := Slot
        State.ScrollCoordinates := { x: ScrollMarker.CursorX, y: ScrollMarker.CursorY }
        State.ScrollMode := "COORDS"
        SaveActiveState(State)
        ScrollMarker.ExitMode()
        ToolTip("Saved & Activated Mark " . Slot)
        SetTimer(() => ToolTip(), -1000)
    }

    ; --- Visual Methods (from Visuals.ahk) ---

    static CreateCircleGui(ownerHwnd, outerSize, innerSize, borderColor, fillColor, labelText := "") {
        gBorder := Gui("-Caption +ToolWindow +E0x20 +E0x80000 -DPIScale +Owner" . ownerHwnd)
        WinSetTransparent(255, gBorder.Hwnd)
        gBorder.BackColor := borderColor
        WinSetRegion("0-0 w" outerSize " h" outerSize " E", gBorder.Hwnd)

        gInner := Gui("-Caption +ToolWindow +E0x20 +E0x80000 -DPIScale +Owner" . ownerHwnd)
        WinSetTransparent(255, gInner.Hwnd)
        gInner.BackColor := fillColor
        if (labelText != "") {
            gInner.SetFont("s11 w700", "Consolas")
            gInner.Add("Text", "vLabel Center cBlack BackgroundTrans w" innerSize " h" innerSize, labelText)
            gInner["Label"].Opt("+Center")
            try gInner["Label"].Move(0, Config.MarkLabelOffset, innerSize, 29)
        }
        WinSetRegion("0-0 w" innerSize " h" innerSize " E", gInner.Hwnd)

        return { border: gBorder, inner: gInner }
    }

    static CreateMarkGui(ownerHwnd, index) {
        result := ScrollMarker.CreateCircleGui(ownerHwnd,
            Config.MarkSize, Config.MarkInnerSize,
            Config.ScrollmarkProperties.ActiveBorderColor,
            Config.ScrollmarkProperties.InactiveBackgroundColor,
            index)
        ScrollMarker.MarkGuis[index] := result
        return result
    }

    static DestroyMarkGui(index) {
        if (ScrollMarker.MarkGuis.Has(index)) {
            try ScrollMarker.MarkGuis[index].border.Destroy()
            try ScrollMarker.MarkGuis[index].inner.Destroy()
            try ScrollMarker.MarkGuis.Delete(index)
        }
    }

    static CreateNormalIndicator(ownerHwnd) {
        ScrollMarker.NormalIndicator := ScrollMarker.CreateCircleGui(ownerHwnd,
            Config.IndicatorSmallSize, Config.IndicatorSmallInnerSize,
            Config.ScrollmarkProperties.ActiveBorderColor,
            Config.ScrollmarkProperties.ActiveBackgroundColor)
        return ScrollMarker.NormalIndicator
    }

    static CreatePreviewIndicator(ownerHwnd) {
        ScrollMarker.PreviewIndicator := ScrollMarker.CreateCircleGui(ownerHwnd,
            Config.IndicatorSmallSize, Config.IndicatorSmallInnerSize,
            Config.ScrollmarkProperties.ActiveBorderColor,
            Config.ScrollmarkProperties.InactiveBackgroundColor)
        return ScrollMarker.PreviewIndicator
    }

    static CreateActiveCircle(ownerHwnd) {
        ScrollMarker.ActiveCircle := ScrollMarker.CreateCircleGui(ownerHwnd,
            Config.MarkSize, Config.MarkInnerSize,
            Config.ScrollmarkProperties.ActiveBorderColor,
            Config.ScrollmarkProperties.ActiveBackgroundColor,
            "")
        return ScrollMarker.ActiveCircle
    }

    static DestroyCrosshair() {
        if (!IsObject(ScrollMarker.CrosshairGuis))
            return
        try ScrollMarker.CrosshairGuis.vTop.border.Destroy()
        try ScrollMarker.CrosshairGuis.vTop.inner.Destroy()
        try ScrollMarker.CrosshairGuis.vBot.border.Destroy()
        try ScrollMarker.CrosshairGuis.vBot.inner.Destroy()
        try ScrollMarker.CrosshairGuis.hLeft.border.Destroy()
        try ScrollMarker.CrosshairGuis.hLeft.inner.Destroy()
        try ScrollMarker.CrosshairGuis.hRight.border.Destroy()
        try ScrollMarker.CrosshairGuis.hRight.inner.Destroy()
        ScrollMarker.CrosshairGuis := ""
    }

    static DestroyAllGuis() {
        VimberlayState.ShownGuis.Clear()
        for index, _ in ScrollMarker.MarkGuis {
            ScrollMarker.DestroyMarkGui(index)
        }
        if (IsObject(ScrollMarker.NormalIndicator)) {
            try ScrollMarker.NormalIndicator.border.Destroy()
            try ScrollMarker.NormalIndicator.inner.Destroy()
            ScrollMarker.NormalIndicator := ""
        }
        if (IsObject(ScrollMarker.PreviewIndicator)) {
            try ScrollMarker.PreviewIndicator.border.Destroy()
            try ScrollMarker.PreviewIndicator.inner.Destroy()
            ScrollMarker.PreviewIndicator := ""
        }
        if (IsObject(ScrollMarker.ActiveCircle)) {
            try ScrollMarker.ActiveCircle.border.Destroy()
            try ScrollMarker.ActiveCircle.inner.Destroy()
            ScrollMarker.ActiveCircle := ""
        }
        ScrollMarker.DestroyCrosshair()
        ScrollMarker.LastOwnerHwnd := 0
    }

    static GetJumpBackPreview(State) {
        TargetIndex := ""
        TempStack := []
        for idx, val in State.HistoryStack {
            TempStack.Push(val)
        }
        while (TempStack.Length > 0) {
            Candidate := TempStack.Pop()
            if (Candidate == State.CurrentIndex) {
                continue
            }
            if (State.CoordinateMarks.Has(Candidate)) {
                TargetIndex := Candidate
                break
            }
        }
        if (TargetIndex == "" && State.CoordinateMarks.Has("0") && State.CurrentIndex != "0") {
            TargetIndex := "0"
        }
        return TargetIndex
    }

    static UpdateVisuals(ownerHwnd, activeX, activeY, showCircle, wx, wy, ww, wh, isActive, marksMap := "", selector :=
        "",
        previewX := 0, previewY := 0, currentIndex := "", previewIndex := "") {
        if (ownerHwnd != ScrollMarker.LastOwnerHwnd) {
            ScrollMarker.DestroyAllGuis()
            ScrollMarker.LastOwnerHwnd := ownerHwnd
        }
        ActiveColor := isActive ? Config.ScrollmarkProperties.ActiveBackgroundColor : Config.ScrollmarkProperties.InactiveBackgroundColor
        isScrollMode := IsObject(selector) || IsObject(marksMap)
        if (IsObject(selector)) {
            thk := 2
            border := 2
            totalThk := thk + (border * 2)
            sx := selector.x
            sy := selector.y
            vTopH := sy - wy
            vBotH := (wy + wh) - sy
            hLeftW := sx - wx
            hRightW := (wx + ww) - sx
            if (!IsObject(ScrollMarker.CrosshairGuis)) {
                ScrollMarker.CrosshairGuis := {
                    vTop: {
                        border: Gui("-Caption +ToolWindow +E0x20 +E0x80000 -DPIScale +Owner" . ownerHwnd),
                        inner: Gui("-Caption +ToolWindow +E0x20 +E0x80000 -DPIScale +Owner" . ownerHwnd)
                    },
                    vBot: {
                        border: Gui("-Caption +ToolWindow +E0x20 +E0x80000 -DPIScale +Owner" . ownerHwnd),
                        inner: Gui("-Caption +ToolWindow +E0x20 +E0x80000 -DPIScale +Owner" . ownerHwnd)
                    },
                    hLeft: {
                        border: Gui("-Caption +ToolWindow +E0x20 +E0x80000 -DPIScale +Owner" . ownerHwnd),
                        inner: Gui("-Caption +ToolWindow +E0x20 +E0x80000 -DPIScale +Owner" . ownerHwnd)
                    },
                    hRight: {
                        border: Gui("-Caption +ToolWindow +E0x20 +E0x80000 -DPIScale +Owner" . ownerHwnd),
                        inner: Gui("-Caption +ToolWindow +E0x20 +E0x80000 -DPIScale +Owner" . ownerHwnd)
                    }
                }
                for dir in ["vTop", "vBot", "hLeft", "hRight"] {
                    WinSetTransparent(255, ScrollMarker.CrosshairGuis.%dir%.border.Hwnd)
                    ScrollMarker.CrosshairGuis.%dir%.border.BackColor := Config.ScrollmarkProperties.CrosshairBorderColor
                    WinSetTransparent(255, ScrollMarker.CrosshairGuis.%dir%.inner.Hwnd)
                    ScrollMarker.CrosshairGuis.%dir%.inner.BackColor := Config.ScrollmarkProperties.CrosshairBackgroundColor
                }
            }
            ShowOrMove(ScrollMarker.CrosshairGuis.vTop.border, sx - (totalThk // 2), wy, totalThk, vTopH)
            ShowOrMove(ScrollMarker.CrosshairGuis.vTop.inner, sx - (thk // 2), wy, thk, vTopH)
            ShowOrMove(ScrollMarker.CrosshairGuis.vBot.border, sx - (totalThk // 2), sy, totalThk, vBotH)
            ShowOrMove(ScrollMarker.CrosshairGuis.vBot.inner, sx - (thk // 2), sy, thk, vBotH)
            ShowOrMove(ScrollMarker.CrosshairGuis.hLeft.border, wx, sy - (totalThk // 2), hLeftW, totalThk)
            ShowOrMove(ScrollMarker.CrosshairGuis.hLeft.inner, wx, sy - (thk // 2), hLeftW, thk)
            ShowOrMove(ScrollMarker.CrosshairGuis.hRight.border, sx, sy - (totalThk // 2), hRightW, totalThk)
            ShowOrMove(ScrollMarker.CrosshairGuis.hRight.inner, sx, sy - (thk // 2), hRightW, thk)
        } else {
            ScrollMarker.DestroyCrosshair()
        }
        if (IsObject(marksMap)) {
            renderedMarks := Map()
            for char, pos in marksMap {
                if (char == "0" || (pos.x == -1 && pos.y == -1)) {
                    continue
                }
                if (!ScrollMarker.MarkGuis.Has(char)) {
                    ScrollMarker.CreateMarkGui(ownerHwnd, char)
                }
                markColor := Config.ScrollmarkProperties.InactiveBackgroundColor
                borderColor := Config.ScrollmarkProperties.InactiveBorderColor
                if (char == currentIndex) {
                    markColor := Config.ScrollmarkProperties.ActiveBackgroundColor
                    borderColor := Config.ScrollmarkProperties.ActiveBorderColor
                } else if (char == previewIndex) {
                    markColor := Config.ScrollmarkProperties.InactiveBackgroundColor
                    borderColor := Config.ScrollmarkProperties.ActiveBorderColor
                }
                tx := wx + pos.x
                ty := wy + pos.y
                ScrollMarker.MarkGuis[char].border.BackColor := borderColor
                ShowOrMove(ScrollMarker.MarkGuis[char].border, tx - (Config.MarkSize // 2), ty - (Config.MarkSize //
                    2), Config.MarkSize, Config.MarkSize)
                ScrollMarker.MarkGuis[char].inner.BackColor := markColor
                ShowOrMove(ScrollMarker.MarkGuis[char].inner, tx - (Config.MarkInnerSize // 2), ty - (Config.MarkInnerSize //
                    2), Config.MarkInnerSize, Config.MarkInnerSize)
                renderedMarks[char] := true
            }
            mark0Color := Config.ScrollmarkProperties.InactiveBackgroundColor
            border0Color := Config.ScrollmarkProperties.InactiveBorderColor
            if ("0" == currentIndex) {
                mark0Color := Config.ScrollmarkProperties.ActiveBackgroundColor
                border0Color := Config.ScrollmarkProperties.ActiveBorderColor
            } else if ("0" == previewIndex) {
                mark0Color := Config.ScrollmarkProperties.InactiveBackgroundColor
                border0Color := Config.ScrollmarkProperties.ActiveBorderColor
            }
            centerX := wx + (ww // 2)
            centerY := wy + (wh // 2)
            if (!ScrollMarker.MarkGuis.Has("0")) {
                ScrollMarker.CreateMarkGui(ownerHwnd, "0")
            }
            ScrollMarker.MarkGuis["0"].border.BackColor := border0Color
            ShowOrMove(ScrollMarker.MarkGuis["0"].border, centerX - (Config.MarkSize // 2), centerY - (Config.MarkSize //
                2), Config.MarkSize, Config.MarkSize)
            ScrollMarker.MarkGuis["0"].inner.BackColor := mark0Color
            ShowOrMove(ScrollMarker.MarkGuis["0"].inner, centerX - (Config.MarkInnerSize // 2), centerY - (Config
                .MarkInnerSize // 2), Config.MarkInnerSize, Config.MarkInnerSize)
            renderedMarks["0"] := true
            toDestroy := []
            for char, _ in ScrollMarker.MarkGuis {
                if (!renderedMarks.Has(char)) {
                    toDestroy.Push(char)
                }
            }
            for _, char in toDestroy {
                ScrollMarker.DestroyMarkGui(char)
            }
        } else {
            toDestroy := []
            for char, _ in ScrollMarker.MarkGuis {
                toDestroy.Push(char)
            }
            for _, char in toDestroy {
                ScrollMarker.DestroyMarkGui(char)
            }
        }
        if (IsObject(ScrollMarker.ActiveCircle)) {
            HideGui(ScrollMarker.ActiveCircle.border)
            HideGui(ScrollMarker.ActiveCircle.inner)
        }
        if (!isScrollMode) {
            if (showCircle && activeX != 0 && activeY != 0) {
                if (!IsObject(ScrollMarker.NormalIndicator)) {
                    ScrollMarker.CreateNormalIndicator(ownerHwnd)
                }
                ShowOrMove(ScrollMarker.NormalIndicator.border, activeX - (Config.IndicatorSmallSize // 2), activeY -
                (Config.IndicatorSmallSize // 2), Config.IndicatorSmallSize, Config.IndicatorSmallSize)
                ScrollMarker.NormalIndicator.inner.BackColor := ActiveColor
                ShowOrMove(ScrollMarker.NormalIndicator.inner, activeX - (Config.IndicatorSmallInnerSize // 2),
                activeY - (Config.IndicatorSmallInnerSize // 2), Config.IndicatorSmallInnerSize, Config.IndicatorSmallInnerSize
                )
            } else if (IsObject(ScrollMarker.NormalIndicator)) {
                HideGui(ScrollMarker.NormalIndicator.border)
                HideGui(ScrollMarker.NormalIndicator.inner)
            }
            if (previewX != 0 && previewY != 0) {
                if (!IsObject(ScrollMarker.PreviewIndicator)) {
                    ScrollMarker.CreatePreviewIndicator(ownerHwnd)
                }
                ShowOrMove(ScrollMarker.PreviewIndicator.border, previewX - (Config.IndicatorSmallSize // 2),
                previewY - (Config.IndicatorSmallSize // 2), Config.IndicatorSmallSize, Config.IndicatorSmallSize
                )
                ShowOrMove(ScrollMarker.PreviewIndicator.inner, previewX - (Config.IndicatorSmallInnerSize // 2),
                previewY - (Config.IndicatorSmallInnerSize // 2), Config.IndicatorSmallInnerSize, Config.IndicatorSmallInnerSize
                )
            } else if (IsObject(ScrollMarker.PreviewIndicator)) {
                HideGui(ScrollMarker.PreviewIndicator.border)
                HideGui(ScrollMarker.PreviewIndicator.inner)
            }
        } else {
            if (IsObject(ScrollMarker.NormalIndicator)) {
                HideGui(ScrollMarker.NormalIndicator.border)
                HideGui(ScrollMarker.NormalIndicator.inner)
            }
            if (IsObject(ScrollMarker.PreviewIndicator)) {
                HideGui(ScrollMarker.PreviewIndicator.border)
                HideGui(ScrollMarker.PreviewIndicator.inner)
            }
        }
    }
}
