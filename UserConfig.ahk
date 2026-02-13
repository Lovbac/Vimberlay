; ==============================================================================
; Mandatory Config
; ==============================================================================

; --- Browser Executable ---
; Set the executable name of the browser you want to use Vimberlay for.
; Common browsers:
;   "vivaldi.exe", "chrome.exe", "firefox.exe", "msedge.exe", "brave.exe"
Config.BrowserExecutable := "vivaldi.exe"

; --- Browser Bindings ---
; Define the keybindings you have setup in your browser for these browser actions.
; If you are using the provided vivaldi configurations, you do not have to touch this section.
; Vimberlay actions that rely on these browser actions will be disabled if they are not bound.
; Note that this section does not define user bindings (see the "Key Mappings" section for that).
Config.BrowserBindings.Reload := "^+!#2"
Config.BrowserBindings.ForceReload := "^+!#{F10}"
Config.BrowserBindings.HistoryBack := "^+!#1"
Config.BrowserBindings.HistoryForward := "^+!#6"
Config.BrowserBindings.PageUp := "^+!#{F11}"
Config.BrowserBindings.PageDown := "^+!#3"
Config.BrowserBindings.GoToTop := "^+!#M"
Config.BrowserBindings.GoToBottom := "^+!#Q"
Config.BrowserBindings.FocusCurrentInputOrFindInputs := "^2"

; ==============================================================================
; Optional Config
; ==============================================================================

; --- Config Overrides ---
; See <insert documentation link> for default and available options.
; Example: Set the scroll length to 180
; Config.ScrollLength := 180
; Example: Enable debug logging for the extension and VivaldiMod
; Config.Debug := true
; Example: Change the web server port (default 8000)
; Config.Port := 9000

; --- Key Mappings ---
; See <insert documentation link> for default mappings and available mapping functions and actions.
; Modifier keys:
;   ^ = Ctrl
;   + = Shift
;   ! = Alt
;   # = Win
; Example: Map "t" to New Tab in normal mode
;   NormalMap("t", Actions.NewTab)
; Example: Map the chord "gT" (g then Shift+t) to Previous Tab in normal mode
;   NormalMap("g", "+t", Actions.PreviousTab)
