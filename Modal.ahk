#Warn Unreachable, Off
#SingleInstance force

; Note: this is all in a single file to make the hotreloading work easier.
; A possible easy enhancement would be to also search for other files in
; this script's directory but for now it's ok.

; Taken and modified from examples floating around the web.
CheckScriptUpdate() {
    global ScriptStartModTime
    static ReloadTryCount := 0
    currentModTime := FileGetTime(A_ScriptFullPath)
    if (currentModTime == ScriptStartModTime) {
        return
    }
    SetTimer(, 0)
    loop {
        ReloadTryCount += 1
        if (ReloadTryCount == 2) {
            Cleanup()
            ExitApp
        }
        Alert("Reloading")
        Reload()
        Sleep(300)  
        Cleanup()
    }
}
ScriptStartModTime := FileGetTime(A_ScriptFullPath) 
SetTimer(CheckScriptUpdate, 100, 0x7FFFFFFF)



; Message popup initialization.
AlertGui := Gui("-caption -Border +alwaysontop +ToolWindow")

AlertGui.MarginX := 10
AlertGui.MarginY := 10
AlertGui_MessageListView := AlertGui.Add("ListView", "w800 h800", ["Message"])
AlertGui_MessageListView.ModifyCol(1, 750)
WinSetTransparent(255, AlertGui.Hwnd)
WinSetExStyle("+0x20", AlertGui.Hwnd)

Alert(message) {
    row := AlertGui_MessageListView.Add(, message)
    AlertGui_MessageListView.Modify(row, "Vis")
    AlertGui.Show()
}

Cleanup() {
    AlertGui.Hide()
}



; Global state for the current mode. Should someday be encapsulated.
Mode_Name := "Launcher"
Mode_Menu := Launcher_Menu
Mode_MakeHotkeysActive := Launcher_MakeHotkeysActive
Mode_Handle := Launcher_Handle



; Fake dynamic late-binding to hotkeys.
Handle(key) {
    Mode_Handle(key)
}

InitHotkeys() {
    ; F1 is special because it's the master starting hotkey.
    Hotkey("F1", "On")
    Hotkey("F2", Handle, "Off")
    Hotkey("F3", Handle, "Off")
    Hotkey("F4", Handle, "Off")
    Hotkey("F5", Handle, "Off")
    Hotkey("F6", Handle, "Off")
    Hotkey("F7", Handle, "Off")
    Hotkey("F8", Handle, "Off")
    Hotkey("F9", Handle, "Off")
    Hotkey("F10", Handle, "Off")
    Hotkey("F11", Handle, "Off")
    Hotkey("F12", Handle, "Off")
    Hotkey("^F11", Handle, "Off")
    Hotkey("^F12", Handle, "Off")
}

Hotkey("F1", _ => Start())
Hotkey("^!F1", _ => Launcher_SwitchTo())
Hotkey("^F1", _ => Start())
Hotkey("!F1", _ => ActuallySendF1())

ActuallySendF1() {
    Hotkey("F1", "Off")
    Send("{F1}")
    Hotkey("F1", "On")
}

Start() {
    if (WinActive(AlertGui.Hwnd)) {
        Cleanup()
        return
    }

    Mode_Menu()
    Mode_MakeHotkeysActive()
}



Alert("Loaded")
InitHotkeys()
LoadCurrentMode()
SetTimer(Cleanup, -500)





 
; Could use inheritence but this was simpler for prototyping.
Base_Menu() {
    Alert(Mode_Name)
    Alert("F1: Cancel")
    Alert("Ctrl-Alt-F1: Exit mode")
}

Base_SwitchTo(name, menuFunc, makeHotkeysActiveFunc, handleFunc) {
    Alert("Switching to " name)
    global Mode_Name := name
    global Mode_Menu := menuFunc
    global Mode_MakeHotkeysActive := makeHotkeysActiveFunc
    global Mode_Handle := handleFunc
    SaveCurrentMode()
    Mode_MakeHotkeysActive()
    Mode_Menu()
}





; Some helpers integrated with the UI system.

RunWithCmd(command) {
    fullCommand := A_ComSpec " /c `"" command "`""
    Alert(fullCommand)
    Run(fullCommand)
}

StrJoin(arrayOfStrings, joiner := "", surrounder := "") {
    result := ""
    for string in arrayOfStrings {
        result := result joiner surrounder string surrounder
    }
    return result
}

EnsureBrowserOpenWithTabs(titleOfFirstTab, tabs) {
    SetTitleMatchMode(2)
    Alert("Looking for: " titleOfFirstTab)
    possibleExistingWindowHwnd := WinExist(titleOfFirstTab)
    Alert("Found possible existing window: " possibleExistingWindowHwnd)
    if (possibleExistingWindowHwnd != 0) {
        WinClose(possibleExistingWindowHwnd)
        WinWaitClose(titleOfFirstTab)
    }

    ; According to FF docs, FF always opens in a new window as long as there are two or more incoming URLs.
    ; Add an about:newtab to force this behavior no matter what.
    ffPath := EverythingPath("-w -n 1 " "firefox.exe")
    path := ffPath " " StrJoin(tabs, " ", "`"") " `"about:newtab`""
    Alert(path)
    Run(path)
    WinWaitActive(titleOfFirstTab)
}

GetLocalUserDir() {
    path := ""
    SplitPath(A_Desktop,, &path)
    return path
}

GetTempFilePath(name) {
    return A_Temp "\" name
}

; Use included es.exe interface to a running instance of Everything Search to make device-universal hotkeys possible.
EverythingPath(search) {
    result := ""
    results_path := GetTempFilePath("es_out.txt")
    everythingBinDirectory := ""
    SplitPath(A_ScriptFullPath, , &everythingBinDirectory)
    command := A_ComSpec ' /c ""' everythingBinDirectory '\es.exe" ' search ' > ' results_path '"'
    Alert(command)
    runResult := RunWait(command)
    if (runResult != 0) {
        ; todo error handling
    }
    results_raw := FileRead(results_path)
    Loop Parse, results_raw, "`n", "`r"
    {
        result := A_LoopField 
        Break
    }
    return result
}





; Persist selected mode between hotreloads.
SaveCurrentMode() {
    path := GetTempFilePath("mode.txt")
    file := FileOpen(path, "w")
    file.Write(Mode_Name)
}

LoadCurrentMode() {
    path := GetTempFilePath("mode.txt")
    try {
        file := FileOpen(path, "r")
        result := file.ReadLine()
        SwitchToByString(result)
    } catch {
        SaveCurrentMode()
        file := FileOpen(path, "r")
        result := file.ReadLine()
        SwitchToByString(result)
    }
}

SwitchToByString(modeName) {
    switch modeName {
        case "Launcher":
            Launcher_SwitchTo()
        case "Ignore":
            Ignore_SwitchTo()
        default:
            Alert("Tried to load " modeName " but that isn't a mode I know about")
            Launcher_SwitchTo()
            SaveCurrentMode()
            return
            
    }
}



Launch(exeName) {
    Alert("Launching " exeName)
    path := EverythingPath("-w -n 1 " exeName)
    Run(path)
}

LaunchOrSwitchTo(exeName, windowName) {
    hwnd := WinExist(windowName)
    if (hwnd == 0) {
        Alert("Launching " windowName)
        path := EverythingPath("-w -n 1 " exeName)
        Run(path)
    } else {
        Alert("Found " windowName " already running")
        WinActivate(hwnd)
    }
}

SwitchTo(windowName) {
    hwnd := WinExist(windowName)
    Alert("Found " windowName)
    WinActivate(hwnd)  
}






Launcher_Menu() {
    Base_Menu()
    Alert("F2: Browsing")
    Alert("F3: Coding")
    Alert("F11: Ignore")
}

Launcher_MakeHotkeysActive() {
    InitHotkeys()
    Hotkey("F2", "On")
    Hotkey("F3", "On")
    Hotkey("F11", "On")
}

Launcher_Handle(key) {
    switch key {
        case "F2":
            Browsing_SwitchTo()
        case "F3":
            Coding_SwitchTo()
        case "F11":
            Ignore_SwitchTo()
        default:
            Launcher_SwitchTo()
    }
}

Launcher_SwitchTo() {
    Base_SwitchTo("Launcher", Launcher_Menu, Launcher_MakeHotkeysActive, Launcher_Handle)
    Cleanup()
}






Browsing_Menu() {
    Base_Menu()
}

Browsing_MakeHotkeysActive() {
    InitHotkeys()
    Hotkey("F1", "Off")
}

Browsing_Handle(key) {
    switch key {
        ; todo put useful macros/hotkeys for web browsing here
        default:
            return
    }
}

Browsing_SwitchTo() {
    Base_SwitchTo("Browsing", Browsing_Menu, Browsing_MakeHotkeysActive, Browsing_Handle)
    tabs := [
        "https://news.ycombinator.com/",
        "https://www.google.com/",
    ]
    EnsureBrowserOpenWithTabs("Hacker", tabs)
    Cleanup()
}




Coding_Menu() {
    Base_Menu()
}

Coding_MakeHotkeysActive() {
    InitHotkeys()
    Hotkey("F1", "Off")
}

Coding_Handle(key) {
    switch key {
        ; todo put useful macros/hotkeys for coding here
        default:
            return
    }
}

Coding_SwitchTo() {
    Base_SwitchTo("Coding", Coding_Menu, Coding_MakeHotkeysActive, Coding_Handle)
    RunWithCmd('code ' A_ScriptDir)
    Cleanup()
}





Ignore_Menu() {
    Base_Menu()
}

Ignore_MakeHotkeysActive() {
    InitHotkeys()
}

Ignore_Handle(key) {
}

Ignore_SwitchTo() {
    Base_SwitchTo("Ignore", Ignore_Menu, Ignore_MakeHotkeysActive, Ignore_Handle)
    Cleanup()
}