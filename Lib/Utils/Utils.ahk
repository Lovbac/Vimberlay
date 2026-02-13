; ==============================================================================
; HELPER FUNCTIONS & ACTIONS
; ==============================================================================

IsTyping() {
    if CaretGetPos(&x, &y)
        return true

    static OBJID_CARET := -8
    static IID_IAccessible := "{618736E0-3C3D-11CF-810C-00AA00389B71}"

    hwnd := WinExist("A")
    if !hwnd
        return false

    try {
        ptr := 0
        guid := Buffer(16)
        DllCall("ole32\CLSIDFromString", "Str", IID_IAccessible, "Ptr", guid)
        ; If we successfully get a caret object, typing is happening
        ; Don't bother checking state - that's what causes crashes
        if (DllCall("oleacc\AccessibleObjectFromWindow", "Ptr", hwnd, "UInt", OBJID_CARET, "Ptr", guid, "Ptr*", &ptr) ==
        0 && ptr != 0) {
            return true
        }
    } catch {
        ; Ignore COM errors
    }
    return false
}

SendVivaldi(key) {
    Send("^+!#{" . key . "}")
}

QueueAction(action, sleepBeforeStateCheck := 0) {
    static ActionQueue := []
    static IsProcessingQueue := false

    ActionQueue.Push(action)

    if (!IsProcessingQueue) {
        IsProcessingQueue := true

        while (ActionQueue.Length > 0) {
            currentAction := ActionQueue.RemoveAt(1)

            VimberlayState.StateCheckPaused := true
            currentAction()
            if (sleepBeforeStateCheck) {
                sleep(sleepBeforeStateCheck)
            }
            VimberlayState.StateCheckPaused := false
            CheckVivaldiState()
        }

        IsProcessingQueue := false
    }
}

QueueSend(keys, sleepBeforeStateCheck := 0) => QueueAction(() => Send(keys), sleepBeforeStateCheck)

PostScroll(delta, useCenter := false, repeatCount := 1) {
    static WM_MOUSEWHEEL := 0x020A

    static WM_MOUSEWHEEL := 0x020A

    hwnd := WinExist("A")
    if !hwnd
        return

    local x, y
    State := GetActiveState()

    CurrentMode := useCenter ? State.ScrollMode : "MOUSE"

    if (CurrentMode == "COORDS") {
        WinGetPos(&vx, &vy, &vw, &vh, "ahk_id " hwnd)

        targetX := State.ScrollCoordinates.x
        targetY := State.ScrollCoordinates.y

        if (targetX == -1) {
            ; Dynamic Center
            x := vx + (vw // 2)
        } else {
            ; Relative -> Screen
            x := vx + targetX
        }

        if (targetY == -1) {
            y := vy + (vh // 2)
        } else {
            y := vy + targetY
        }
    }
    else { ; MOUSE
        buf := Buffer(8)
        DllCall("GetCursorPos", "ptr", buf)
        x := NumGet(buf, 0, "Int")
        y := NumGet(buf, 4, "Int")
    }

    lParam := (y << 16) | (x & 0xFFFF)
    wParam := (delta << 16)

    VimberlayState.GlobalScrollId++
    currentScrollId := VimberlayState.GlobalScrollId

    ; NEUTRALIZE MODIFIERS (Prevents Zooming/History Nav)
    ctrl := GetKeyState("Ctrl", "P")
    shift := GetKeyState("Shift", "P")
    alt := GetKeyState("Alt", "P")

    if (ctrl)
        SendInput "{Blind}{Ctrl Up}"
    if (shift)
        SendInput "{Blind}{Shift Up}"
    if (alt)
        SendInput "{Blind}{Alt Up}"

    Sleep(Duration.Mini)

    loop repeatCount {
        if (VimberlayState.GlobalScrollId != currentScrollId) {
            break
        }
        DllCall("SendMessage", "ptr", hwnd, "uint", WM_MOUSEWHEEL, "ptr", wParam, "ptr", lParam)
        Sleep(Duration.Yield)
    }

    if (ctrl && GetKeyState("Ctrl", "P"))
        SendInput "{Blind}{Ctrl Down}"
    if (shift && GetKeyState("Shift", "P"))
        SendInput "{Blind}{Shift Down}"
    if (alt && GetKeyState("Alt", "P"))
        SendInput "{Blind}{Alt Down}"
}

Duration := {
    Yield: 1, ; Yield to let the OS process other things
    Mini: 15, ; Give a little breathing room for things to be processed, sometimes unclear if needed
    Short: 25, ; Give a little breathing room for things to be processed, usually clear it's needed
    Medium: 125,
    Long: 375,
}