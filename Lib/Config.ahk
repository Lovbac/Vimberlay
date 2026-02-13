class Config {
    static __Item[name] => this.%name%

    static UseVivaldiEnhancements := true ; Only applies if browser is vivaldi
    static Debug := false
    static Port := 8000
    static BrowserExecutable := ""
    static ModeIndicatorWidth := 293 ; Unused if vivaldi enhancements are applied
    static ModeIndicatorHeight := 32 ; Unused if vivaldi enhancements are applied
    static ScrollLength := 120
    static FocusPageKey := "A"
    static PageScrollRatio := 5
    static MaxScrollLength := 30000
    static VivaldiPath := "C:\Users\abcd-usr-wintuf\scoop\apps\vivaldi"
    static StateMode := 4

    ; --- Visual Constants ---
    static IndicatorPadding := 13
    static TypingIndicatorSize := 32
    static TypingIndicatorFontSize := 14
    static TypingIndicatorOffset := 15

    static MarkSize := 44
    static MarkInnerSize := 36
    static MarkLabelOffset := 6
    static IndicatorSmallSize := 22
    static IndicatorSmallInnerSize := 18

    class ModeProperties {
        static __Item[name] => this.%name%

        class Normal {
            static BackgroundColor := "A6E22E"
            static ForegroundColor := "000000"
            static Text := "Normal"
        }

        class Insert {
            static BackgroundColor := "66D9EF"
            static ForegroundColor := "000000"
            static Text := "Insert"
        }

        class InsertUrl {
            static BackgroundColor := "44B4CA"
            static ForegroundColor := "000000"
            static Text := "Insert URL"
        }

        class Hints {
            static BackgroundColor := "E6DB74"
            static ForegroundColor := "000000"
            static Text := "Hints"
        }

        class Passthrough {
            static BackgroundColor := "AE81FF"
            static ForegroundColor := "000000"
            static Text := "Passthrough"
        }

        class SemiPassthrough {
            static BackgroundColor := "AE81FF"
            static ForegroundColor := "000000"
            static Text := "Semi-Passthrough"
        }

        class Scrollmarks {
            static BackgroundColor := "FD971F"
            static ForegroundColor := "000000"
            static Text := "Scrollmarks"
        }

        class ScrollmarkEditor {
            static BackgroundColor := "FF6900"
            static ForegroundColor := "000000"
            static Text := "Scrollmark Editor"
        }

        class Inactive {
            static BackgroundColor := "BCBCBC"
            static ForegroundColor := "000000"
            static Text := ""
        }

        static ToJson() {
            return ToJson(
                this._GetSerializable("Normal", VimberlayMode.NORMAL),
                this._GetSerializable("Insert", VimberlayMode.INSERT),
                this._GetSerializable("InsertUrl", VimberlayMode.INSERT_URL),
                this._GetSerializable("Hints", VimberlayMode.HINTS),
                this._GetSerializable("Passthrough", VimberlayMode.PASSTHROUGH),
                this._GetSerializable("SemiPassthrough", VimberlayMode.SEMI_PASSTHROUGH),
                this._GetSerializable("Scrollmarks", VimberlayMode.SCROLLMARKS),
                this._GetSerializable("ScrollmarkEditor", VimberlayMode.SCROLLMARK_EDITOR),
                this._GetSerializable("Inactive", VimberlayMode.INACTIVE),
            )
        }

        static _GetSerializable(modePropertyName, vimberlayMode) {
            return {
                Key: vimberlayMode,
                Value: ToJson({
                    Key: "backgroundColor",
                    Value: "#" . this[modePropertyName].BackgroundColor,
                    Type: JsonType.String
                }, {
                    Key: "foregroundColor",
                    Value: "#" . this[modePropertyName].ForegroundColor,
                    Type: JsonType.String
                }, {
                    Key: "text",
                    Value: this[modePropertyName].Text,
                    Type: JsonType.String
                }),
                Type: JsonType.Raw
            }
        }
    }

    class ScrollmarkProperties {
        static ActiveBackgroundColor := "FD971F"
        static ActiveForegroundColor := "000000"
        static ActiveBorderColor := "000000"

        static PreviousBackgroundColor := "BCBCBC"
        static PreviousForegroundColor := "000000"
        static PreviousBorderColor := "000000"

        static InactiveBackgroundColor := "BCBCBC"
        static InactiveForegroundColor := "000000"
        static InactiveBorderColor := "BCBCBC"

        static CrosshairBackgroundColor := "FD971F"
        static CrosshairBorderColor := "000000"
    }

    class BrowserBindings {
        static __Item[name] => this.%name%

        static Reload := ""
        static ForceReload := ""
        static HistoryBack := ""
        static HistoryForward := ""
        static PageUp := ""
        static PageDown := ""
        static GoToTop := ""
        static GoToBottom := ""
        static FocusCurrentInputOrFindInputs := "" ; Surfingkeys action
    }
}
