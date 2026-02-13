class ActionMapperBase {
    MappingManagers := {}

    __New() {
        for ContextName, ConditionFunc in Contexts.OwnProps() {
            this.MappingManagers.%ContextName% := MappingManager(ConditionFunc, this)
        }
    }
}

class MappingManager {
    Tree := Map()
    Timeout := 1000
    HUD := ""
    IsWaiting := false
    ContextCondition := ""
    Owner := ""

    __New(conditionFunc, ownerInstance) {
        this.ContextCondition := conditionFunc
        this.Owner := ownerInstance
    }

    Map(Params*) {
        if (Params.Length < 2)
            throw Error("Bind requires at least 1 key and 1 action.")

        Action := Params.Pop()

        try {
            if !Action.HasProp("DisplayName")
                Action.DisplayName := Action.Name
        }

        if (this.Owner && Action.MinParams > 0) {
            Action := Action.Bind(this.Owner)
        }

        Params.Push(Action)

        SafeCondition := ((Mgr, Condition, *) => Condition() && !Mgr.IsWaiting).Bind(this, this.ContextCondition)

        HotIf SafeCondition
        this.Set(Params*)
        HotIf
    }

    Set(Params*) {
        if (Params.Length < 1) {
            throw Error("Bind requires at least 1 key.")
        }
        Action := Params.Pop()
        FirstKey := Params[1]

        if (Params.Length == 1 && !this.Tree.Has(FirstKey)) {
            this.Tree[FirstKey] := Action
            Hotkey(FirstKey, (_) => Action(), "On")
            return
        }

        Current := this.Tree
        if (Params.Length > 1 && Current.Has(FirstKey) && !(Current[FirstKey] is Map)) {
            OldAction := Current[FirstKey]
            Current[FirstKey] := Map("default", OldAction)
            Hotkey(FirstKey, this.Execute.Bind(this, FirstKey), "On")
        }

        for i, Key in Params {
            if (i == Params.Length) {
                if (Current.Has(Key) && !(Current[Key] is Map)) {
                    throw Error("Duplicate Bind: " . Key . " is already bound.")
                }
                if (Current.Has(Key) && (Current[Key] is Map) && Current[Key].Has("default")) {
                    throw Error("Duplicate Bind: " . Key . " already has a default action.")
                }
                if (!Current.Has(Key)) {
                    Current[Key] := Action
                } else if (Current[Key] is Map) {
                    Current[Key]["default"] := Action
                }
                continue
            }
            if (!Current.Has(Key)) {
                Current[Key] := Map()
            }
            if (!(Current[Key] is Map)) {
                Existing := Current[Key]
                Current[Key] := Map("default", Existing)
            }
            Current := Current[Key]
        }
        if (this.Tree[FirstKey] is Map) {
            Hotkey(FirstKey, this.Execute.Bind(this, FirstKey), "On")
        }
    }

    Unset(Params*) {
        if (Params.Length < 1) {
            return
        }
        FirstKey := Params[1]
        if (!this.Tree.Has(FirstKey)) {
            return
        }
        if (Params.Length == 1) {
            Node := this.Tree[FirstKey]
            if (Node is Map) {
                if (Node.Has("default")) {
                    Node.Delete("default")
                }
            } else {
                Hotkey(FirstKey, "Off")
                this.Tree.Delete(FirstKey)
                return
            }
        } else {
            Path := []
            Current := this.Tree
            for i, Key in Params {
                if (i == Params.Length) {
                    if (Current.Has(Key)) {
                        Target := Current[Key]
                        if (Target is Map) {
                            if (Target.Has("default")) {
                                Target.Delete("default")
                            }
                        } else {
                            Current.Delete(Key)
                        }
                    }
                } else {
                    if (!Current.Has(Key) || !(Current[Key] is Map)) {
                        return
                    }
                    Path.Push({ Obj: Current, Key: Key })
                    Current := Current[Key]
                }
            }
            loop Path.Length {
                i := Path.Length - A_Index + 1
                Item := Path[i]
                ParentMap := Item.Obj
                Key := Item.Key
                Child := ParentMap[Key]
                if (Child is Map && Child.Count == 0) {
                    ParentMap.Delete(Key)
                } else if (Child is Map && Child.Count == 1 && Child.Has("default")) {
                    Action := Child["default"]
                    ParentMap[Key] := Action
                }
            }
        }
        if (this.Tree.Has(FirstKey)) {
            Root := this.Tree[FirstKey]
            if (Root is Map && Root.Count == 0) {
                Hotkey(FirstKey, "Off")
                this.Tree.Delete(FirstKey)
            } else if (Root is Map && Root.Count == 1 && Root.Has("default")) {
                Action := Root["default"]
                this.Tree[FirstKey] := Action
                Hotkey(FirstKey, (_) => Action(), "On")
            } else if (!(Root is Map)) {
                Hotkey(FirstKey, (_) => Root(), "On")
            }
        }
    }

    Execute(TriggerKey, *) {
        ; CORRECTION: Check Physical Shift State (Fix 8)
        ; If Shift is physically held (key down) but logically up (because PostScroll neutralized it),
        ; AHK would see 'g' instead of 'G'. We must manually detect this and force the key to be '+g'.
        ; This allows the user to mash 'Shift+g' rapidly without accidental 'g' chords starting.
        if (StrLen(TriggerKey) == 1 && GetKeyState("Shift", "P") && !GetKeyState("Shift")) {
            TriggerKey := "+" . TriggerKey
        }

        if (!this.Tree.Has(TriggerKey))
            return

        Node := this.Tree[TriggerKey]

        if (Node is Map) {
            this.WaitNext(Node, TriggerKey)
        } else {
            Node()
        }
    }

    WaitNext(Node, CurrentPath) {
        this.IsWaiting := true
        try {
            loop {
                HasDefault := Node.Has("default")
                this.ShowHUD(Node, CurrentPath)

                ih := InputHook("L0 " . (HasDefault ? "T" . (this.Timeout / 1000) : ""))
                ih.VisibleNonText := false
                ih.KeyOpt("{All}", "N S") ; Suppress everything

                HeldMods := Map(
                    "Ctrl", GetKeyState("Ctrl", "P"),
                    "Shift", GetKeyState("Shift", "P"),
                    "Alt", GetKeyState("Alt", "P"),
                    "Win", (GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
                )

                MatchedKey := ""
                PassthroughKey := ""
                PassthroughMods := ""

                ih.OnKeyDown := (obj, vk, sc) => (
                    this.OnKeyDown(obj, vk, sc, Node, &MatchedKey, &PassthroughKey, &PassthroughMods, HeldMods)
                )

                ih.OnKeyUp := (obj, vk, sc) => (
                    this.OnKeyUp(obj, vk, sc, HeldMods)
                )

                ih.Start()
                Reason := ih.Wait()

                if (Reason == "Timeout") {
                    ih.Stop()
                    this.HideHUD()
                    if (HasDefault) {
                        this.IsWaiting := false
                        Node["default"]()
                    }
                    return
                }

                if (MatchedKey != "") {
                    Node := Node[MatchedKey]
                    CurrentPath .= MatchedKey

                    if (Node is Map) {
                        continue
                    } else {
                        this.HideHUD()
                        this.IsWaiting := false
                        Node()
                        return
                    }
                }

                this.HideHUD()
                if (HasDefault) {
                    this.IsWaiting := false
                    Node["default"]()
                }

                if (PassthroughKey != "") {
                    SendStr := ""
                    if InStr(PassthroughMods, "^")
                        SendStr .= "^"
                    if InStr(PassthroughMods, "+")
                        SendStr .= "+"
                    if InStr(PassthroughMods, "!")
                        SendStr .= "!"
                    if InStr(PassthroughMods, "#")
                        SendStr .= "#"

                    Send(SendStr . "{" . PassthroughKey . "}")
                }
                return
            }
        } finally {
            this.IsWaiting := false
        }
    }

    OnKeyDown(ih, vk, sc, Node, &MatchedKey, &PassthroughKey, &PassthroughMods, HeldMods) {
        KeyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))

        if (KeyName = "Control" || KeyName = "LControl" || KeyName = "RControl") {
            HeldMods["Ctrl"] := true
            return
        }
        if (KeyName = "Shift" || KeyName = "LShift" || KeyName = "RShift") {
            HeldMods["Shift"] := true
            return
        }
        if (KeyName = "Alt" || KeyName = "LAlt" || KeyName = "RAlt") {
            HeldMods["Alt"] := true
            return
        }
        if (KeyName = "LWin" || KeyName = "RWin") {
            HeldMods["Win"] := true
            return
        }

        PassthroughKey := KeyName
        PassthroughMods := ""

        Mods := ""
        if (HeldMods["Ctrl"]) {
            Mods .= "^"
            PassthroughMods .= "^"
        }
        if (HeldMods["Shift"]) {
            Mods .= "+"
            PassthroughMods .= "+"
        }
        if (HeldMods["Alt"]) {
            Mods .= "!"
            PassthroughMods .= "!"
        }
        if (HeldMods["Win"]) {
            Mods .= "#"
            PassthroughMods .= "#"
        }

        Candidate := Mods . KeyName

        if (Node.Has(Candidate)) {
            MatchedKey := Candidate
            ih.Stop()
        } else {
            ih.Stop()
        }
    }

    OnKeyUp(ih, vk, sc, HeldMods) {
        KeyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))

        if (KeyName = "Control" || KeyName = "LControl" || KeyName = "RControl")
            HeldMods["Ctrl"] := false
        else if (KeyName = "Shift" || KeyName = "LShift" || KeyName = "RShift")
            HeldMods["Shift"] := false
        else if (KeyName = "Alt" || KeyName = "LAlt" || KeyName = "RAlt")
            HeldMods["Alt"] := false
        else if (KeyName = "LWin" || KeyName = "RWin")
            HeldMods["Win"] := false
    }

    ShowHUD(Node, ChordStr) {
        this.HideHUD()

        this.HUD := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        this.HUD.BackColor := "101010"
        this.HUD.SetFont("s11 cdfdfdf", "Consolas")
        this.HUD.MarginX := 20
        this.HUD.MarginY := 20

        Header := "chord: " . ChordStr . "`n-----`n"
        Body := this.WalkTree(Node, "")

        this.HUD.Add("Text", "w500", Header . Body)
        this.HUD.Show("NoActivate xCenter yCenter AutoSize")
    }

    HideHUD() {
        if (this.HUD) {
            this.HUD.Destroy()
            this.HUD := ""
        }
    }

    WalkTree(Node, Indent) {
        Out := ""
        if (Node.Has("default")) {
            Out .= Indent . "_: <" . this.GetActionName(Node["default"]) . ">`n"
        }
        Keys := []
        for K in Node {
            if (K != "default")
                Keys.Push(K)
        }
        if (Keys.Length > 0) {
            loop Keys.Length {
                i := A_Index
                loop Keys.Length - i {
                    j := A_Index
                    if (StrCompare(String(Keys[j]), String(Keys[j + 1])) > 0) {
                        Temp := Keys[j]
                        Keys[j] := Keys[j + 1]
                        Keys[j + 1] := Temp
                    }
                }
            }
        }
        for Key in Keys {
            Value := Node[Key]
            if (Value is Map) {
                Out .= Indent . Key . ":`n"
                Out .= this.WalkTree(Value, Indent . "... ")
            } else {
                Out .= Indent . Key . ": <" . this.GetActionName(Value) . ">`n"
            }
        }
        return Out
    }

    GetActionName(Fn) {
        if Fn.HasProp("DisplayName")
            return Fn.DisplayName
        return (Fn.HasProp("Name") && Fn.Name != "") ? Fn.Name : "Action"
    }
}
