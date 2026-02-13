; Automatically copies vivaldi mod fiels to Vivaldi's application directory
class VivaldiModPatcher {
    static Apply() {

        if (!Config.VivaldiPath) {
            err := Error("Must configure VIVALDI_PATH in Globals.ahk to use VivaldiMods")
            this.LogError(err.msg)
            throw err
        }

        vivaldiResourcesPath := this.ResolvePath(Config.VivaldiPath)

        if (!DirExist(vivaldiResourcesPath)) {
            err := Error("Could not resolve path: " . Config.VivaldiPath)
            this.LogError(err.msg)
            throw err
        }

        this.PatchVivaldi(vivaldiResourcesPath)

        this.CopyMod(vivaldiResourcesPath)
    }

    ; Patch Vivaldi's window.html
    static PatchVivaldi(vivaldiResourcesPath) {
        try {
            windowHtml := vivaldiResourcesPath . "\window.html"
            content := FileRead(windowHtml)

            ; Inject URL global and module script
            urlGlobal := '<script>window.__VIMBERLAY_URL = "http://127.0.0.1:' . Config.Port . '";</script>'
            modScriptTag := '<script type="module" src="vimberlay_mod/main.js"></script>'
            injectionBlock := urlGlobal . "`n" . modScriptTag

            if (!InStr(content, modScriptTag)) {
                newContent := StrReplace(content, "</body>", injectionBlock . "`n</body>")
                FileSetAttrib("-R", windowHtml) ; Ensure not read-only
                FileOpen(windowHtml, "w", "UTF-8").Write(newContent)
            } else if (!InStr(content, "__VIMBERLAY_URL")) {
                ; Script tag exists but URL global doesn't - insert global before it
                newContent := StrReplace(content, modScriptTag, injectionBlock)
                FileSetAttrib("-R", windowHtml)
                FileOpen(windowHtml, "w", "UTF-8").Write(newContent)
            }
        } catch as e {
            this.LogError(e.Message)
            throw
        }
    }

    ; Copy all mod files to Vivaldi's application directory
    static CopyMod(vivaldiResourcesPath) {
        try {
            destDir := vivaldiResourcesPath . "\vimberlay_mod"
            sourceDir := A_ScriptDir . "\dist\vivaldi"

            loop files, sourceDir . "\*.*", "R" {
                try {
                    destFileDir := destDir . StrReplace(A_LoopFileDir, sourceDir, "")
                    if (!DirExist(destFileDir))
                        DirCreate(destFileDir)
                    destFile := destFileDir . "\" . A_LoopFileName
                    FileCopy(A_LoopFileFullPath, destFile, true)
                } catch as e {
                    this.LogError("Failed to copy " . A_LoopFileName . ": " . e.Message)
                    throw e
                }
            }
        }
        catch as e {
            this.LogError(e.Message)
            throw
        }
    }

    static ResolvePath(base) {
        ; 1. If empty, start with default Local AppData path
        if (base == "") {
            base := EnvGet("LocalAppData") . "\Vivaldi"
        }

        ; 2. Possible 'Application' folder locations (Standard vs Scoop)
        checkPaths := [
            base . "\current\Application", ; Scoop
            base . "\Application",         ; Standard
            base                           ; Already pointing to App or root
        ]

        for p in checkPaths {
            if (!DirExist(p))
                continue

            ; Find latest version subfolder (e.g. 7.7.3851.67)
            latest := ""
            loop files, p . "\*", "D" {
                if (RegExMatch(A_LoopFileName, "^\d")) {
                    if (latest == "" || A_LoopFileName > latest)
                        latest := A_LoopFileName
                }
            }

            if (latest) {
                resPath := p . "\" . latest . "\resources\vivaldi"
                if (DirExist(resPath))
                    return resPath
            }
        }

        ; 3. Final fallback: If user pointed directly to a resources/vivaldi folder
        if (DirExist(base . "\vivaldi")) ; Points to resources/
            return base . "\vivaldi"
        if (InStr(base, "resources\vivaldi") && DirExist(base))
            return base

        return ""
    }

    static LogError(msg) {
        FileAppend(FormatTime() . " - " . msg . "`n", A_ScriptDir . "\error_log.txt")
    }
}
