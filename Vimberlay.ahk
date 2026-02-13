#Requires AutoHotkey v2.0
#SingleInstance Force
ListLines 0
ProcessSetPriority "High"

; --- LOAD MODULES ---
#Include "Lib\Globals.ahk"
#Include "Lib\Config.ahk"
#Include "Lib\Constants.ahk"
#Include "Lib\State.ahk"
#Include "Lib\Visuals.ahk"
#Include "Lib\Utils\Utils.ahk"
#Include "Lib\Lib\Utils.ahk"
#Include "Lib\ScrollMarker.ahk"
#Include "Lib\Core.ahk"
#Include "Lib\Input.ahk"
#Include "Lib\Actions.ahk"
#Include "Lib\WebServer.ahk"
#Include "Lib\VivaldiModPatcher.ahk"

; ==============================================================================
; INITIALIZATION & MAPPINGS
; ==============================================================================

Actions := ActionMapper()

; --- MAPPER SETUP ---
AlwaysMap := Actions.MappingManagers.Always.Map.Bind(Actions.MappingManagers.Always)
GlobalMap := Actions.MappingManagers.Global.Map.Bind(Actions.MappingManagers.Global)
InsertMap := Actions.MappingManagers.Insert.Map.Bind(Actions.MappingManagers.Insert)
NormalMap := Actions.MappingManagers.Normal.Map.Bind(Actions.MappingManagers.Normal)
HintsMap := Actions.MappingManagers.Hints.Map.Bind(Actions.MappingManagers.Hints)
InsertUrlMap := Actions.MappingManagers.InsertUrl.Map.Bind(Actions.MappingManagers.InsertUrl)
; Scrollmark maps initialized later

; --- 1. ALWAYS ACTIVE ---
AlwaysMap("+Esc", Actions.TogglePassthrough)

; --- 2. GLOBAL MAPPINGS ---
GlobalMap("^F11", Actions.ToggleFullscreen)
GlobalMap("^=", Actions.PageZoomIn)
GlobalMap("^-", Actions.PageZoomOut)
GlobalMap("^0", Actions.PageZoomReset)
AlwaysMap("$LButton", Actions.PauseWhileClicking)
GlobalMap("^o", Actions.RefocusPage)

; --- 3. INSERT MODE ---
InsertMap("$Esc", Actions.Insert_Exit)
InsertMap("^e", Actions.EditInNeovim_FromInsert)
InsertMap("$^Enter", Actions.Insert_SendEnterThenExit) ; Might be an actual binding though rare, use passthrough or add e.g. ^!Enter to send this if needed
InsertMap("$^+Enter", Actions.Insert_SendShiftEnterThenExit)

; --- 3.1 INSERT URL MODE ---
InsertUrlMap("Enter", Actions.AddressBar_Enter)
InsertUrlMap("Esc", Actions.AddressBar_Esc)
InsertUrlMap("^e", Actions.EditInNeovim_FromAddressBar)

; --- 4. NORMAL MODE ---
NormalMap("i", Actions.EnterInsertMode)
NormalMap("+i", Actions.EnterInsertModeAtStart)
NormalMap("+a", Actions.EnterInsertModeAtEnd)
NormalMap("f", Actions.OpenLinkHints)
NormalMap("+f", Actions.OpenLinkHintsNewTabBg)
NormalMap("$Esc", Actions.Normal_Esc)
NormalMap("^e", Actions.EditInNeovim_IfTyping)

; Direct Bindings
NormalMap("+^", Actions.SwitchToTab1)
NormalMap("+<^>!4", Actions.SwitchToLastTab)
NormalMap("^¨", Actions.MoveTabsToBeginning)
NormalMap("^<^>!4", Actions.MoveTabsToEnd)

; Scroll
NormalMap("j", Actions.ScrollDown)
NormalMap("k", Actions.ScrollUp)
NormalMap("!j", Actions.ScrollDown_Alt)
NormalMap("!k", Actions.ScrollUp_Alt)

; Tab Navigation
NormalMap("+k", Actions.PreviousTab)
NormalMap("+j", Actions.NextTab)

; Commands
NormalMap("+x", Actions.CloseTab)
NormalMap("!x", Actions.ShowQuickCommands)
NormalMap("^k", Actions.MoveActiveTabBackward)
NormalMap("^j", Actions.MoveActiveTabForward)
NormalMap("+u", Actions.ReopenClosedTab)
NormalMap("b", Actions.FocusAddressBar)

; Input Triggers
NormalMap("o", Actions.OpenURL)
NormalMap("+o", Actions.NewTab)
NormalMap("!o", Actions.EditURL)

NormalMap("r", Actions.ReloadPage)
NormalMap("+r", Actions.ForceReloadPage)
NormalMap("+h", Actions.HistoryBack)
NormalMap("+l", Actions.HistoryForward)
NormalMap("n", Actions.OpenDevTools)
NormalMap("^u", Actions.PageUp)
NormalMap("^d", Actions.PageDown)

; Chords
NormalMap("g", "g", Actions.ScrollToTop)
NormalMap("g", "i", Actions.FocusFirstInput)
NormalMap("+g", Actions.ScrollToBottom)

; --- SCROLL MARKER BINDINGS ---

; 1. Enter ScrollSelect Mode: s
NormalMap("s", (*) => ScrollMarker.EnterSelectMode())
NormalMap("+s", (*) => ScrollMarker.EnterSetMode())

; 2A. SCROLL SELECT MODE (Navigation & Management)
ScrollmarksMap := Actions.MappingManagers.Scrollmarks.Map.Bind(Actions.MappingManagers.Scrollmarks)
ScrollmarksMap("Esc", (*) => ScrollMarker.ExitMode())
ScrollmarksMap("s", (*) => ScrollMarker.JumpBack())

; Jump to Marks (1-9, 0) — Shift+N consumed to prevent fallthrough to editor delete
ScrollmarksMap("0", ObjBindMethod(ScrollMarker, "Jump", "0"))
loop 9 {
    Num := String(A_Index)
    ScrollmarksMap(Num, ObjBindMethod(ScrollMarker, "Jump", Num))
    ScrollmarksMap("+" . Num, (*) => "")
}
ScrollmarksMap("+0", (*) => "")

; 2B. SCROLLMARK EDITOR MODE (Crosshair Visible - Placement)
ScrollmarkEditorMap := Actions.MappingManagers.ScrollmarkEditor.Map.Bind(Actions.MappingManagers.ScrollmarkEditor)
ScrollmarkEditorMap("Esc", (*) => ScrollMarker.ExitMode())

; Movement
ScrollmarkEditorMap("h", ObjBindMethod(ScrollMarker, "Move", -200, 0))
ScrollmarkEditorMap("j", ObjBindMethod(ScrollMarker, "Move", 0, 200))
ScrollmarkEditorMap("k", ObjBindMethod(ScrollMarker, "Move", 0, -200))
ScrollmarkEditorMap("l", ObjBindMethod(ScrollMarker, "Move", 200, 0))

; Save to Marks (1-9)
loop 9 {
    Num := String(A_Index)
    ScrollmarkEditorMap(Num, ObjBindMethod(ScrollMarker, "SaveTo", Num))
    ScrollmarkEditorMap("+" . Num, ObjBindMethod(ScrollMarker, "Delete", Num))
}
ScrollmarkEditorMap("+0", (*) => ScrollMarker.DeleteAll())

; Mark 0 is reserved for dynamic center, cannot save to it manually except maybe clear? Use del.

; Mark 0 reserved for dynamic center; Shift+0 consumed above

; --- 5. HINTS MODE ---
HintsMap("Esc", Actions.Hints_Esc)
HintsMap("+k", Actions.Hints_PreviousTab)
HintsMap("+j", Actions.Hints_NextTab)

#Include "*i UserConfig.ahk"

if (Config.BrowserExecutable == "") {
    MsgBox(
        "You must set Config.BrowserExecutable in UserConfig.ahk`n`nExample:`nConfig.BrowserExecutable := `"vivaldi.exe`"",
        "VimBrowserOverlay Configuration Needed", "Icon!")
    ExitApp
}

if (Config.BrowserExecutable == "vivaldi.exe" && Config.UseVivaldiEnhancements)
    VivaldiModPatcher.Apply()

WebServer.Start()
OnExit((*) => WebServer.Stop())

SetTimer(CheckVivaldiState, 20)