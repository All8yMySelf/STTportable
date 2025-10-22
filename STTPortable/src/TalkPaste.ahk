#Requires AutoHotkey v2.0
#SingleInstance Force

; ====== Globals ======

appParent := DirExist(A_ScriptDir "\..")
APPDIR := appParent ? RTrim(appParent, "\/") : A_ScriptDir
BINDIR := APPDIR "\\bin"
MODELDIR := APPDIR "\\models"
CFGDIR := APPDIR "\\config"
LOGDIR := APPDIR "\\logs"
CONFIG_FILE := CFGDIR "\config.ini"
LOG_FILE := LOGDIR "\sttportable.log"

DirCreate(CFGDIR)
DirCreate(LOGDIR)

DefaultConfig := {
    hotkeys: {
        toggle: "#^t",
        settings: "#^,",
        cancel: "#^x",
        mode_toggle: "#^y"
    },
    stt: {
        model: "models\\ggml-medium.en.gguf",
        sample_rate: "16000",
        mic_device: "audio=Default"
    },
    insert: {
        mode: "paste"
    }
}

Config := LoadConfig()

ffmpegPath := BINDIR "\ffmpeg.exe"
whisperPath := BINDIR "\whisper.exe"

isRecording := false
ffmpegPid := 0
currentTempBase := ""
currentWavPath := ""
currentToggleHotkey := ""
settingsGui := 0

BindStaticHotkeys()
BindToggleHotkey(Config.hotkeys.toggle)

if !currentToggleHotkey {
    fallback := DefaultConfig.hotkeys.toggle
    if fallback && fallback != Config.hotkeys.toggle && BindToggleHotkey(fallback) {
        Config.hotkeys.toggle := fallback
        LogMessage("Reverted toggle hotkey to default: " fallback)
        SaveConfig(Config)
    }
}

CreateTrayMenu()

OnExit(HandleExit)

return

; ====== Hotkey Handlers ======
ToggleRecord(*) {
    global isRecording
    if !isRecording {
        StartRecording()
    } else {
        StopRecording(true)
    }
}

CancelRecording(*) {
    StopRecording(false)
}

OpenSettings(*) {
    ShowSettingsGui()
}

ToggleInsertModeHotkey(*) {
    global Config
    Config.insert.mode := (Config.insert.mode = "paste") ? "type" : "paste"
    SaveConfig(Config)
    TrayTip("STTPortable", "Insert mode set to " Config.insert.mode, 2, 17)
    UpdateSettingsGuiMode()
}

; ====== Recording Logic ======
StartRecording() {
    global isRecording, ffmpegPid, ffmpegPath, Config, currentTempBase, currentWavPath

    if !FileExist(ffmpegPath) {
        ReportError("ffmpeg.exe not found in bin folder.")
        return
    }

    device := Config.stt.mic_device
    if !device
        device := "audio=Default"
    sampleRate := Config.stt.sample_rate
    if !sampleRate
        sampleRate := "16000"

    tempBase := A_Temp "\stt_" A_TickCount
    wavPath := tempBase ".wav"

    cmd := Format('"{1}" -y -hide_banner -loglevel error -f dshow -i "{2}" -ac 1 -ar {3} "{4}"', ffmpegPath, device, sampleRate, wavPath)

    try {
        ffmpegPid := Run(cmd, , "Hide")
        isRecording := true
        currentTempBase := tempBase
        currentWavPath := wavPath
    } catch as err {
        ReportError("Failed to start ffmpeg: " err.Message)
    }
}

StopRecording(transcribe) {
    global isRecording, ffmpegPid, currentWavPath

    if !isRecording
        return

    isRecording := false
    if ffmpegPid {
        try {
            ProcessClose(ffmpegPid)
            ProcessWaitClose(ffmpegPid, 1)
        } catch {
        }
    }
    ffmpegPid := 0

    Sleep(200)

    if !FileExist(currentWavPath) {
        if transcribe
            ReportError("Recording file was not created.")
        CleanupTemp()
        return
    }

    if transcribe {
        text := TranscribeWhisper(currentWavPath)
        if text != "" {
            Sleep(120)
            InsertTextAtCursor(text)
        }
    }

    CleanupTemp()
}

CleanupTemp() {
    global currentTempBase, currentWavPath
    if currentWavPath && FileExist(currentWavPath) {
        try FileDelete(currentWavPath)
    }
    txtPath := currentTempBase ".txt"
    if FileExist(txtPath) {
        try FileDelete(txtPath)
    }
    currentTempBase := ""
    currentWavPath := ""
}

TranscribeWhisper(wavPath) {
    global Config, whisperPath, currentTempBase

    if !FileExist(whisperPath) {
        ReportError("whisper.exe not found in bin folder.")
        return ""
    }

    modelPath := ResolvePath(Config.stt.model)
    if !FileExist(modelPath) {
        ReportError("Model file not found: " modelPath)
        return ""
    }

    tempBase := currentTempBase ? currentTempBase : wavPath
    txtPath := tempBase ".txt"

    cmd := Format('"{1}" -m "{2}" -f "{3}" -otxt -l en -of "{4}"', whisperPath, modelPath, wavPath, tempBase)

    try {
        exitCode := RunWait(cmd, , "Hide")
        if exitCode != 0 {
            ReportError("whisper.exe returned exit code " exitCode)
            return ""
        }
    } catch as err {
        ReportError("Failed to run whisper.exe: " err.Message)
        return ""
    }

    if !FileExist(txtPath) {
        ReportError("Transcription output not found.")
        return ""
    }

    try {
        text := FileRead(txtPath, "UTF-8")
    } catch as err {
        ReportError("Failed to read transcription: " err.Message)
        return ""
    } finally {
        try FileDelete(txtPath)
    }

    return text
}

InsertTextAtCursor(text) {
    global Config

    if !text
        return

    text := NormalizeNewlines(text)

    if Config.insert.mode = "paste" {
        backup := ""
        try backup := ClipboardAll()
        try {
            A_Clipboard := text
            if !ClipWait(1) {
                throw Error("Clipboard did not update in time.")
            }
            Send("^v")
        } catch as err {
            LogMessage("Failed to paste via clipboard: " err.Message)
            SendText(text)
        } finally {
            Sleep(50)
            try A_Clipboard := backup
        }
    } else {
        SendText(text)
    }
}

NormalizeNewlines(text) {
    text := StrReplace(text, "`r`n", "`n")
    text := StrReplace(text, "`r", "`n")
    return StrReplace(text, "`n", "`r`n")
}

; ====== Config Management ======
LoadConfig() {
    global DefaultConfig, CONFIG_FILE
    cfg := CloneObject(DefaultConfig)
    if !FileExist(CONFIG_FILE)
        return cfg

    try {
        cfg.hotkeys.toggle := IniRead(CONFIG_FILE, "hotkeys", "toggle", cfg.hotkeys.toggle)
        cfg.hotkeys.settings := IniRead(CONFIG_FILE, "hotkeys", "settings", cfg.hotkeys.settings)
        cfg.hotkeys.cancel := IniRead(CONFIG_FILE, "hotkeys", "cancel", cfg.hotkeys.cancel)
        cfg.hotkeys.mode_toggle := IniRead(CONFIG_FILE, "hotkeys", "mode_toggle", cfg.hotkeys.mode_toggle)

        cfg.stt.model := IniRead(CONFIG_FILE, "stt", "model", cfg.stt.model)
        cfg.stt.sample_rate := IniRead(CONFIG_FILE, "stt", "sample_rate", cfg.stt.sample_rate)
        cfg.stt.mic_device := IniRead(CONFIG_FILE, "stt", "mic_device", cfg.stt.mic_device)

        cfg.insert.mode := IniRead(CONFIG_FILE, "insert", "mode", cfg.insert.mode)
    } catch as err {
        ReportError("Failed to read config: " err.Message)
    }
    return cfg
}

SaveConfig(cfg) {
    global CONFIG_FILE
    SplitPathCreate(CONFIG_FILE)
    try {
        IniWrite(cfg.hotkeys.toggle, CONFIG_FILE, "hotkeys", "toggle")
        IniWrite(cfg.hotkeys.settings, CONFIG_FILE, "hotkeys", "settings")
        IniWrite(cfg.hotkeys.cancel, CONFIG_FILE, "hotkeys", "cancel")
        IniWrite(cfg.hotkeys.mode_toggle, CONFIG_FILE, "hotkeys", "mode_toggle")

        IniWrite(cfg.stt.model, CONFIG_FILE, "stt", "model")
        IniWrite(cfg.stt.sample_rate, CONFIG_FILE, "stt", "sample_rate")
        IniWrite(cfg.stt.mic_device, CONFIG_FILE, "stt", "mic_device")

        IniWrite(cfg.insert.mode, CONFIG_FILE, "insert", "mode")
    } catch as err {
        ReportError("Failed to write config: " err.Message)
    }
}

CloneObject(obj) {
    if Type(obj) != "Object"
        return obj
    copy := {}
    for key, value in obj.OwnProps() {
        copy.%key% := CloneObject(value)
    }
    return copy
}

SplitPathCreate(path) {
    SplitPath path, , &dir
    if dir && !DirExist(dir)
        DirCreate(dir)
    return dir
}

ResolvePath(path) {
    global APPDIR
    if !path
        return ""
    if InStr(path, ":") || RegExMatch(path, "^[\\/]")
        return path
    return APPDIR "\\" path
}

NormalizeModelPath(path) {
    global APPDIR
    if !path
        return ""
    full := ResolvePath(path)
    if InStr(full, APPDIR) = 1 {
        relStart := StrLen(APPDIR) + 1
        if SubStr(full, relStart, 1) = "\\" || SubStr(full, relStart, 1) = "/"
            relStart += 1
        rel := SubStr(full, relStart)
        if rel
            return rel
    }
    return path
}

; ====== Hotkey Binding ======
BindStaticHotkeys() {
    global Config
    TryBindHotkey(Config.hotkeys.settings, OpenSettings)
    TryBindHotkey(Config.hotkeys.cancel, CancelRecording)
    TryBindHotkey(Config.hotkeys.mode_toggle, ToggleInsertModeHotkey)
}

BindToggleHotkey(hk) {
    global currentToggleHotkey
    if currentToggleHotkey {
        try Hotkey(currentToggleHotkey, ToggleRecord, "Off")
    }

    try {
        Hotkey(hk, ToggleRecord)
    } catch as err {
        msg := "Failed to bind toggle hotkey (" hk "): " err.Message
        MsgBox(msg, "STTPortable", 48)
        LogMessage(msg)
        if currentToggleHotkey {
            try Hotkey(currentToggleHotkey, ToggleRecord)
        }
        return false
    }

    currentToggleHotkey := hk
    return true
}

TryBindHotkey(hk, callback) {
    if !hk
        return false
    try {
        Hotkey(hk, callback)
        return true
    } catch as err {
        msg := "Failed to bind hotkey (" hk "): " err.Message
        MsgBox(msg, "STTPortable", 48)
        LogMessage(msg)
        return false
    }
}

; ====== Tray Menu ======
CreateTrayMenu() {
    A_IconTip := "STTPortable"
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Settings...", OpenSettings)
    A_TrayMenu.Add("Open log folder", OpenLogFolder)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Exit", (*) => ExitApp())
}

OpenLogFolder(*) {
    global LOGDIR
    Run('explorer.exe "' LOGDIR '"')
}

; ====== Settings GUI ======
ShowSettingsGui() {
    global settingsGui, Config
    if !settingsGui {
        settingsGui := Gui(, "STTPortable Settings")
        settingsGui.SetFont("s10", "Segoe UI")
        settingsGui.Add("Text", , "Toggle hotkey:")
        settingsGui.Add("Hotkey", "w200 vToggleHotkey", Config.hotkeys.toggle)
        settingsGui.Add("Text", "ym+10", "Model file:")
        settingsGui.Add("Edit", "w320 vModelPath", Config.stt.model)
        settingsGui.Add("Button", "x+m vBrowseBtn", "Browse...").OnEvent("Click", BrowseModel)
        settingsGui.Add("Text", "xm", "Insert mode:")
        ddl := settingsGui.Add("DropDownList", "w120 vInsertMode", ["paste", "type"])
        ddl.Value := Config.insert.mode
        settingsGui.Add("Button", "xm w80 vSaveBtn", "Save").OnEvent("Click", SaveSettings)
        settingsGui.Add("Button", "x+10 w80", "Cancel").OnEvent("Click", (*) => settingsGui.Hide())
    } else {
        settingsGui["ToggleHotkey"].Value := Config.hotkeys.toggle
        settingsGui["ModelPath"].Value := Config.stt.model
        settingsGui["InsertMode"].Value := Config.insert.mode
    }
    settingsGui.Show()
}

BrowseModel(ctrl, info) {
    global settingsGui, MODELDIR
    startPath := settingsGui["ModelPath"].Value
    if !startPath
        startPath := MODELDIR
    else
        startPath := ResolvePath(startPath)
    file := FileSelect("S", startPath, "Select Whisper model", "GGUF (*.gguf)")
    if file
        settingsGui["ModelPath"].Value := file
}

SaveSettings(ctrl, info) {
    global settingsGui, Config
    toggle := Trim(settingsGui["ToggleHotkey"].Value)
    model := Trim(settingsGui["ModelPath"].Value)
    mode := settingsGui["InsertMode"].Value
    if !toggle || toggle = "0" {
        MsgBox("Toggle hotkey cannot be empty or 0.", "STTPortable", 48)
        return
    }
    if !mode
        mode := "paste"
    normalizedModel := NormalizeModelPath(model)

    if !BindToggleHotkey(toggle) {
        settingsGui["ToggleHotkey"].Value := Config.hotkeys.toggle
        return
    }

    Config.hotkeys.toggle := toggle
    Config.stt.model := normalizedModel
    Config.insert.mode := mode
    SaveConfig(Config)
    TrayTip("STTPortable", "Settings saved.", 2, 17)
    settingsGui.Hide()
}

UpdateSettingsGuiMode() {
    global settingsGui, Config
    if settingsGui
        settingsGui["InsertMode"].Value := Config.insert.mode
}

; ====== Logging and Errors ======
ReportError(message) {
    MsgBox(message, "STTPortable", 48)
    LogMessage(message)
}

LogMessage(message) {
    global LOG_FILE
    time := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    line := Format("[{1}] {2}`r`n", time, message)
    try FileAppend(line, LOG_FILE, "UTF-8")
}

HandleExit(*) {
    StopRecording(false)
}
