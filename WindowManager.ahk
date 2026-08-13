#NoEnv
#SingleInstance Force
SendMode Input
SetBatchLines, -1  

; =======================================================
; 📂 1. 初始化与配置文件读取 (config.ini)
; =======================================================
global IniFile := A_ScriptDir . "\config.ini"

; 读取配置文件，如果没有则使用默认值
IniRead, TriggerModifier, %IniFile%, Hotkeys, TriggerModifier, !
IniRead, BindModifier, %IniFile%, Hotkeys, BindModifier, ^!
IniRead, UnbindModifier, %IniFile%, Hotkeys, UnbindModifier, ^+
IniRead, PinHotkey, %IniFile%, Hotkeys, PinHotkey, !T
IniRead, SnapshotHotkey, %IniFile%, Hotkeys, SnapshotHotkey, !0
IniRead, PreviewHotkey, %IniFile%, Hotkeys, PreviewHotkey, !vkC0
IniRead, RadialHotkey, %IniFile%, Hotkeys, RadialHotkey, !Space
IniRead, ConfigHotkey, %IniFile%, Hotkeys, ConfigHotkey, ^!vkC0

; 提取按键的物理键，供 KeyWait 使用 (剔除修饰符)
global PreviewPhysicalKey := RegExReplace(PreviewHotkey, "^[\^\!\+\#\<\>\*\$~]+", "")
global RadialPhysicalKey := RegExReplace(RadialHotkey, "^[\^\!\+\#\<\>\*\$~]+", "")

global KeyList := ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
global WindowBindings := {}
global WindowIsOverlaid := {}     
global RestoreData_Active := {}   
global RestoreData_Above := {}    
global RestoreData_MinMax := {}   
global g_TriggerModifier := TriggerModifier 
global g_BindModifier := BindModifier
global g_UnbindModifier := UnbindModifier
global g_RadialOpen := false
global g_RadialCenterX := 0
global g_RadialCenterY := 0
global g_RadialVirtualX := 0
global g_RadialVirtualY := 0
global g_RadialSelected := 0
global g_RadialItems := []
global g_RadialOuterRadius := 220
global g_RadialInnerRadius := 142
global g_RadialPreviewWidth := 260
global g_RadialPreviewHeight := 88
global g_RadialGapDegrees := 2
global g_RadialMenuPadding := 8
global g_RadialDeadZone := g_RadialInnerRadius
global g_RadialHwnd := 0
global g_RadialSectorHwnds := []
global g_RadialCenterControlHwnd := 0

; =======================================================
; 🚀 2. 动态注册所有快捷键
; =======================================================
for index, key in KeyList {
    Hotkey, %g_BindModifier%%key%, BindHandler       
    Hotkey, %g_UnbindModifier%%key%, UnbindHandler     
    Hotkey, $*%g_TriggerModifier%%key%, TriggerHandler 
}

Hotkey, $*%SnapshotHotkey%, SnapshotHandler
Hotkey, $*%PreviewHotkey%, PreviewHandler
Hotkey, $*%RadialHotkey%, RadialHandler
Hotkey, $*%PinHotkey%, PinHandler
Hotkey, %ConfigHotkey%, ShowConfigGUI

; 启动时给出优雅的 OSD 提示，告诉用户如何打开设置
ShowOSD("🚀 启动成功！按 " . FormatHotkey(ConfigHotkey) . " 打开配置", 2500)
return 
; ------------------- 自动执行段结束 -------------------

; =======================================================
; ⚙️ 3. 可视化配置中心 GUI (Ctrl+Alt+·)
; =======================================================
ShowConfigGUI:
    Gui, Config:Destroy
    Gui, Config:+AlwaysOnTop -MinimizeBox +ToolWindow
    Gui, Config:Color, White
    Gui, Config:Font, s10, Microsoft YaHei

    Gui, Config:Add, GroupBox, x15 y10 w330 h130, 1. 窗口绑定与触发 (配合数字键 1~9)
    
    Gui, Config:Add, Text, x30 y40, 呼出/隐藏修饰键:
    Gui, Config:Add, DropDownList, x150 y35 w170 vUI_Trigger, % BuildDDL(g_TriggerModifier)

    Gui, Config:Add, Text, x30 y75, 绑定窗口修饰键:
    Gui, Config:Add, DropDownList, x150 y70 w170 vUI_Bind, % BuildDDL(g_BindModifier)

    Gui, Config:Add, Text, x30 y110, 解绑窗口修饰键:
    Gui, Config:Add, DropDownList, x150 y105 w170 vUI_Unbind, % BuildDDL(g_UnbindModifier)

    Gui, Config:Add, GroupBox, x15 y155 w330 h235, 2. 独立功能快捷键 (AHK语法)
    Gui, Config:Add, Text, x30 y180 w300 cGray, 语法：! = Alt，^ = Ctrl，+ = Shift`n特殊：vkC0 = · 键 (Esc下方波浪号)

    Gui, Config:Add, Text, x30 y225, 全局置顶按键:
    Gui, Config:Add, Edit, x150 y220 w170 vUI_Pin, %PinHotkey%

    Gui, Config:Add, Text, x30 y255, 记录层级快照:
    Gui, Config:Add, Edit, x150 y250 w170 vUI_Snapshot, %SnapshotHotkey%

    Gui, Config:Add, Text, x30 y285, 实时预览面板:
    Gui, Config:Add, Edit, x150 y280 w170 vUI_Preview, %PreviewHotkey%

    Gui, Config:Add, Text, x30 y315, 鼠标轮盘按键:
    Gui, Config:Add, Edit, x150 y310 w170 vUI_Radial, %RadialHotkey%

    Gui, Config:Add, Text, x30 y345, 弹出本配置页:
    Gui, Config:Add, Edit, x150 y340 w170 vUI_Config, %ConfigHotkey%

    Gui, Config:Add, Button, x25 y405 w90 h35 gSaveConfig, 保存并重启
    Gui, Config:Add, Button, x135 y405 w90 h35 gCloseConfig, 取消
    Gui, Config:Add, Button, x245 y405 w90 h35 gResetConfig, 恢复默认

    Gui, Config:Show, , ⚙️ 快捷键配置中心
return

SaveConfig:
    Gui, Config:Submit
    ; 提取下拉菜单中真实的符号 (例如把 "! (Alt)" 变回 "!")
    RegExMatch(UI_Trigger, "^[^\s]+", newTrigger)
    RegExMatch(UI_Bind, "^[^\s]+", newBind)
    RegExMatch(UI_Unbind, "^[^\s]+", newUnbind)
    
    IniWrite, %newTrigger%, %IniFile%, Hotkeys, TriggerModifier
    IniWrite, %newBind%, %IniFile%, Hotkeys, BindModifier
    IniWrite, %newUnbind%, %IniFile%, Hotkeys, UnbindModifier
    IniWrite, %UI_Pin%, %IniFile%, Hotkeys, PinHotkey
    IniWrite, %UI_Snapshot%, %IniFile%, Hotkeys, SnapshotHotkey
    IniWrite, %UI_Preview%, %IniFile%, Hotkeys, PreviewHotkey
    IniWrite, %UI_Radial%, %IniFile%, Hotkeys, RadialHotkey
    IniWrite, %UI_Config%, %IniFile%, Hotkeys, ConfigHotkey
    
    ShowOSD("✅ 配置已保存，正在生效...")
    Sleep, 1000
    Reload
return

ResetConfig:
    FileDelete, %IniFile%
    ShowOSD("♻️ 已恢复出厂默认配置...")
    Sleep, 1000
    Reload
return

CloseConfig:
    Gui, Config:Destroy
return

; =======================================================
; 📌 4. 全局置顶/取消置顶
; =======================================================
PinHandler:
    WinGet, currentHwnd, ID, A
    if (!currentHwnd)
        return
    WinGetTitle, title, ahk_id %currentHwnd%
    if (StrLen(title) > 12)
        title := SubStr(title, 1, 11) . "…"
    if (title == "")
        title := "当前窗口"

    WinGet, exStyle, ExStyle, ahk_id %currentHwnd%
    if (exStyle & 0x8) {
        WinSet, AlwaysOnTop, Off, ahk_id %currentHwnd%
        ShowOSD("🔽 已取消置顶: " . title)
    } else {
        WinSet, AlwaysOnTop, On, ahk_id %currentHwnd%
        ShowOSD("📌 窗口已置顶: " . title)
    }
return

; =======================================================
; 📸 5. 重新记录层级快照
; =======================================================
SnapshotHandler:
    WinGet, winList, List
    topmostNormal := 0
    Loop, %winList% {
        cand := winList%A_Index%
        WinGetClass, winClass, ahk_id %cand%
        if (winClass == "AutoHotkeyGUI")
            continue
        WinGet, exStyle, ExStyle, ahk_id %cand%
        if (exStyle & 0x8)
            continue
        isCandOverlaid := false
        for k, h in WindowBindings {
            if (h == cand && WindowIsOverlaid[k]) {
                isCandOverlaid := true
                break
            }
        }
        if (!isCandOverlaid) {
            topmostNormal := cand
            break
        }
    }
    
    lastAnchor := topmostNormal
    updatedCount := 0
    Loop, %winList% {
        cand := winList%A_Index%
        boundKey := ""
        for k, h in WindowBindings {
            if (h == cand && WindowIsOverlaid[k]) {
                boundKey := k
                break
            }
        }
        if (boundKey != "") {
            RestoreData_Above[boundKey] := lastAnchor
            RestoreData_Active[boundKey] := topmostNormal 
            lastAnchor := cand 
            updatedCount++
        }
    }
    
    if (updatedCount > 0)
        ShowOSD("📸 快照成功：隐藏时将沉入当前背景下方 (" updatedCount "个)")
    else
        ShowOSD("⚠️ 当前没有被呼出的窗口，无需记录")
return

; =======================================================
; 🔍 6. 可视化实时预览面板
; =======================================================
PreviewHandler:
    ShowPreview()
    KeyWait, %PreviewPhysicalKey%  
    Gui, Preview:Destroy  
return

ShowPreview() {
    global WindowBindings, KeyList, g_TriggerModifier
    Gui, Preview:Destroy
    Gui, Preview:+AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20
    previewHwnd := WinExist() 
    Gui, Preview:Color, 282C34
    Gui, Preview:Margin, 25, 25
    
    bindCount := 0
    ItemWidth := 170    
    ColSpacing := 15    
    RowSpacing := 25    
    
    for index, key in KeyList {
        hwnd := WindowBindings[key]
        if (hwnd && WinExist("ahk_id " hwnd)) {
            WinGetTitle, title, ahk_id %hwnd%
            if (StrLen(title) > 12)
                title := SubStr(title, 1, 11) . "…"
            if (title == "")
                title := "无标题窗口"
                
            appName := GetAppName(hwnd)
            shortcutStr := "[" GetDisplayName(key) "] " title
            
            c := Mod(bindCount, 4)
            r := Floor(bindCount / 4)
            xPos := 25 + c * (ItemWidth + ColSpacing)
            yPosApp := 25 + r * (60 + RowSpacing)
            yPosTitle := yPosApp + 22
            
            Gui, Preview:Font, s11 c99AAB5 w700, Microsoft YaHei
            Gui, Preview:Add, Text, x%xPos% y%yPosApp% w%ItemWidth% Center, %appName%
            Gui, Preview:Font, s12 cWhite w600, Microsoft YaHei
            Gui, Preview:Add, Text, x%xPos% y%yPosTitle% w%ItemWidth% Center, %shortcutStr%
            
            bindCount++
        }
    }
    
    if (bindCount == 0) {
        Gui, Preview:Font, s13 cWhite w600, Microsoft YaHei
        Gui, Preview:Add, Text, Center, ⚠️ 当前未绑定任何窗口
    }
    
    Gui, Preview:Show, NoActivate y40
    WinGetPos,,, w, h, ahk_id %previewHwnd%
    WinSet, Region, 0-0 w%w% h%h% R15-15, ahk_id %previewHwnd%
    WinSet, Transparent, 240, ahk_id %previewHwnd%
}

GetAppName(hwnd) {
    WinGet, exeName, ProcessName, ahk_id %hwnd%
    StringReplace, cleanName, exeName, .exe,, All
    StringLower, lowerName, cleanName
    if (lowerName == "chrome")
        return "Chrome 浏览器"
    if (lowerName == "msedge")
        return "Edge 浏览器"
    if (lowerName == "code")
        return "VS Code"
    if (lowerName == "notepad")
        return "记事本"
    if (lowerName == "explorer")
        return "文件资源管理器"
    StringUpper, cleanName, cleanName, T
    return cleanName
}

; =======================================================
; 7. 鼠标轮盘窗口切换
; =======================================================
RadialHandler:
    global g_RadialOpen, g_RadialCenterX, g_RadialCenterY, g_RadialSelected
    global g_RadialItems, g_RadialDeadZone, RadialPhysicalKey

    if (g_RadialOpen)
        return

    CollectRadialItems()
    if (g_RadialItems.Length() == 0) {
        ShowOSD("当前没有可用的窗口绑定")
        return
    }

    MouseGetPos, g_RadialCenterX, g_RadialCenterY
    g_RadialVirtualX := 0
    g_RadialVirtualY := 0
    g_RadialSelected := 0
    g_RadialOpen := true
    ShowRadialMenu()
    SetTimer, RadialSelectionTimer, 16
    KeyWait, %RadialPhysicalKey%
    SetTimer, RadialSelectionTimer, Off
    MouseMove, %g_RadialCenterX%, %g_RadialCenterY%, 0
    DestroyRadialMenu()
    g_RadialOpen := false

    if (g_RadialSelected)
        ActivateRadialWindow(g_RadialItems[g_RadialSelected].key)
return

RadialSelectionTimer:
    UpdateRadialSelection()
return

CollectRadialItems() {
    global KeyList, WindowBindings, WindowIsOverlaid, g_RadialItems

    g_RadialItems := []
    for index, key in KeyList {
        hwnd := WindowBindings[key]
        if (!hwnd)
            continue
        if (!WinExist("ahk_id " . hwnd)) {
            WindowBindings[key] := ""
            WindowIsOverlaid[key] := ""
            continue
        }

        WinGetTitle, title, ahk_id %hwnd%
        if (title == "")
            title := "无标题窗口"
        if (StrLen(title) > 14)
            title := SubStr(title, 1, 13) . "..."
        g_RadialItems.Push({key: key, hwnd: hwnd, app: GetAppName(hwnd), title: title})
    }
}

ShowRadialMenu() {
    global g_RadialItems, g_RadialCenterX, g_RadialCenterY, g_RadialOuterRadius
    global g_RadialInnerRadius, g_RadialPreviewWidth, g_RadialPreviewHeight, g_RadialGapDegrees, g_RadialMenuPadding
    global g_RadialHwnd, g_RadialSectorHwnds, g_RadialCenterControlHwnd, RadialCenterControlHwnd

    DestroyRadialMenu()
    g_RadialSectorHwnds := []
    diameter := (g_RadialOuterRadius + g_RadialMenuPadding) * 2
    menuX := g_RadialCenterX - Floor(diameter / 2)
    menuY := g_RadialCenterY - Floor(diameter / 2)
    center := Floor(diameter / 2)
    itemCount := g_RadialItems.Length()
    angleStep := 360 / itemCount

    Loop, %itemCount% {
        sectorIndex := A_Index
        startAngle := -90 + (sectorIndex - 1) * angleStep + g_RadialGapDegrees / 2
        sweepAngle := angleStep - g_RadialGapDegrees
        CreateRadialSector(sectorIndex, menuX, menuY, diameter, center, startAngle, sweepAngle, "3A4658")
    }

    centerX := g_RadialCenterX - Floor(g_RadialPreviewWidth / 2)
    centerY := g_RadialCenterY - Floor(g_RadialPreviewHeight / 2)
    Gui, RadialCenter:Destroy
    Gui, RadialCenter:+AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20
    g_RadialHwnd := WinExist()
    Gui, RadialCenter:Color, 202833
    Gui, RadialCenter:Font, s10 cFFFFFF w700, Microsoft YaHei
    Gui, RadialCenter:Add, Text, x12 y12 w%g_RadialPreviewWidth% h64 Center hwndRadialCenterControlHwnd, 移动鼠标`n选择窗口
    g_RadialCenterControlHwnd := RadialCenterControlHwnd
    Gui, RadialCenter:Show, NoActivate x%centerX% y%centerY% w%g_RadialPreviewWidth% h%g_RadialPreviewHeight%
    WinSet, Region, 0-0 w%g_RadialPreviewWidth% h%g_RadialPreviewHeight% R8-8, ahk_id %g_RadialHwnd%
    WinSet, Transparent, 245, ahk_id %g_RadialHwnd%
}

CreateRadialSector(index, menuX, menuY, diameter, center, startAngle, sweepAngle, color) {
    global g_RadialOuterRadius, g_RadialInnerRadius, g_RadialSectorHwnds

    guiName := "RadialSector" . index
    Gui, %guiName%:Destroy
    Gui, %guiName%:+AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20
    sectorHwnd := WinExist()
    Gui, %guiName%:Color, %color%
    Gui, %guiName%:Show, NoActivate x%menuX% y%menuY% w%diameter% h%diameter%

    points := BuildAnnularSectorPoints(center, g_RadialOuterRadius, g_RadialInnerRadius, startAngle, sweepAngle)
    SetPolygonWindowRegion(sectorHwnd, points)
    g_RadialSectorHwnds.Push(sectorHwnd)
    WinSet, Transparent, 225, ahk_id %sectorHwnd%
}

BuildAnnularSectorPoints(center, outerRadius, innerRadius, startAngle, sweepAngle) {
    pointCount := Max(8, Ceil(sweepAngle / 4))
    points := []
    Loop, % pointCount + 1 {
        angle := startAngle + (A_Index - 1) * sweepAngle / pointCount
        radian := angle * 0.017453292519943
        points.Push({x: Round(center + Cos(radian) * outerRadius), y: Round(center + Sin(radian) * outerRadius)})
    }
    Loop, % pointCount + 1 {
        angle := startAngle + sweepAngle - (A_Index - 1) * sweepAngle / pointCount
        radian := angle * 0.017453292519943
        points.Push({x: Round(center + Cos(radian) * innerRadius), y: Round(center + Sin(radian) * innerRadius)})
    }
    return points
}

SetPolygonWindowRegion(hwnd, points) {
    pointBuffer := ""
    pointSize := 8
    VarSetCapacity(pointBuffer, points.Length() * pointSize, 0)
    for index, point in points {
        NumPut(point.x, pointBuffer, (index - 1) * pointSize, "Int")
        NumPut(point.y, pointBuffer, (index - 1) * pointSize + 4, "Int")
    }
    region := DllCall("CreatePolygonRgn", "Ptr", &pointBuffer, "Int", points.Length(), "Int", 1, "Ptr")
    DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", region, "Int", true)
}

DestroyRadialMenu() {
    global g_RadialItems, g_RadialCenterControlHwnd

    Loop, % g_RadialItems.Length() {
        guiName := "RadialSector" . A_Index
        Gui, %guiName%:Destroy
    }
    Gui, RadialCenter:Destroy
    g_RadialCenterControlHwnd := 0
}

UpdateRadialSelection() {
    global g_RadialCenterX, g_RadialCenterY, g_RadialVirtualX, g_RadialVirtualY
    global g_RadialInnerRadius, g_RadialOuterRadius, g_RadialItems, g_RadialSelected

    MouseGetPos, mouseX, mouseY
    g_RadialVirtualX += mouseX - g_RadialCenterX
    g_RadialVirtualY += mouseY - g_RadialCenterY
    MouseMove, %g_RadialCenterX%, %g_RadialCenterY%, 0

    distance := Sqrt(g_RadialVirtualX * g_RadialVirtualX + g_RadialVirtualY * g_RadialVirtualY)
    maxDistance := g_RadialOuterRadius - 4
    if (distance > maxDistance) {
        scale := maxDistance / distance
        g_RadialVirtualX *= scale
        g_RadialVirtualY *= scale
        distance := maxDistance
    }

    newSelection := 0
    if (distance >= g_RadialInnerRadius) {
        angle := DllCall("msvcrt\atan2", "Double", g_RadialVirtualY, "Double", g_RadialVirtualX, "CDecl Double") * 57.295779513082
        if (angle < 0)
            angle += 360
        angle := Mod(angle + 90, 360)
        angleStep := 360 / g_RadialItems.Length()
        newSelection := Floor((angle + angleStep / 2) / angleStep) + 1
        if (newSelection > g_RadialItems.Length())
            newSelection := 1
    }

    if (newSelection != g_RadialSelected) {
        g_RadialSelected := newSelection
        UpdateRadialHighlight()
    }
}

UpdateRadialHighlight() {
    global g_RadialItems, g_RadialSelected, g_RadialSectorHwnds, g_RadialCenterControlHwnd

    Loop, % g_RadialItems.Length() {
        guiName := "RadialSector" . A_Index
        color := (A_Index == g_RadialSelected) ? "4FC3F7" : "3A4658"
        Gui, %guiName%:Color, %color%
        sectorHwnd := g_RadialSectorHwnds[A_Index]
        opacity := (A_Index == g_RadialSelected) ? 250 : 225
        WinSet, Transparent, %opacity%, ahk_id %sectorHwnd%
    }

    if (g_RadialSelected) {
        item := g_RadialItems[g_RadialSelected]
        centerText := "[" . item.key . "] " . item.app . "`n" . item.title
    } else {
        centerText := "移动鼠标`n选择窗口"
    }
    GuiControl, RadialCenter:, %g_RadialCenterControlHwnd%, %centerText%
}

ActivateRadialWindow(key) {
    global WindowBindings, WindowIsOverlaid

    hwnd := WindowBindings[key]
    if (!hwnd || !WinExist("ahk_id " . hwnd)) {
        WindowBindings[key] := ""
        WindowIsOverlaid[key] := ""
        ShowOSD("目标窗口已关闭，绑定已清理")
        return
    }

    WinGet, minMaxState, MinMax, ahk_id %hwnd%
    if (minMaxState == -1)
        WinRestore, ahk_id %hwnd%
    WinSet, AlwaysOnTop, Off, ahk_id %hwnd%
    WinActivate, ahk_id %hwnd%
    ShowOSD("窗口已激活: [" . GetDisplayName(key) . "]")
}

; =======================================================
; 8. 绑定、解绑与核心触发路由
; =======================================================
BindHandler:
    KeyName := RegExReplace(A_ThisHotkey, "^[\^\!\+\*\$]+", "")
    WinGet, currentHwnd, ID, A
    WindowBindings[KeyName] := currentHwnd
    WindowIsOverlaid[KeyName] := false  
    
    WinSet, Transparent, 255, ahk_id %currentHwnd% 
    WinSet, AlwaysOnTop, Off, ahk_id %currentHwnd%
    ShowOSD("✅ 成功绑定当前窗口至: [" . GetDisplayName(KeyName) . "] ")
return

UnbindHandler:
    KeyName := RegExReplace(A_ThisHotkey, "^[\^\!\+\*\$]+", "")
    WindowBindings[KeyName] := ""   
    WindowIsOverlaid[KeyName] := ""
    ShowOSD("❌ 已解除绑定: [" . GetDisplayName(KeyName) . "] ")
return

TriggerHandler:
    KeyName := RegExReplace(A_ThisHotkey, "^[\^\!\+\*\$]+", "")
    targetHwnd := WindowBindings[KeyName]
    
    if (!targetHwnd) {
        Send, {Blind}{%KeyName%}
        return
    }
    IfWinNotExist, ahk_id %targetHwnd%
    {
        WindowBindings[KeyName] := ""
        WindowIsOverlaid[KeyName] := ""
        ShowOSD("⚠️ 目标窗口已关闭，自动清理绑定 ")
        Send, {Blind}{%KeyName%}
        return
    }

    WinGet, currentActiveHwnd, ID, A
    isOverlaid := WindowIsOverlaid[KeyName]

    if (!isOverlaid) {
        RestoreData_Active[KeyName] := currentActiveHwnd
        WinGet, minMaxState, MinMax, ahk_id %targetHwnd%
        RestoreData_MinMax[KeyName] := minMaxState
        RestoreData_Above[KeyName] := GetRealNativeAnchor(targetHwnd)
        WindowIsOverlaid[KeyName] := true
        
        WinSet, AlwaysOnTop, Off, ahk_id %targetHwnd%
        WinActivate, ahk_id %targetHwnd%
        ShowOSD("👀 窗口已呼出: [" . GetDisplayName(KeyName) . "] ")
        
        KeyWait, %KeyName%, T0.3
        if (ErrorLevel) {
            KeyWait, %KeyName% 
            RestoreWindow(KeyName)
        }
    } else {
        if (currentActiveHwnd == targetHwnd) {
            RestoreWindow(KeyName)
            KeyWait, %KeyName% 
        } else {
            WinSet, AlwaysOnTop, Off, ahk_id %targetHwnd%
            WinActivate, ahk_id %targetHwnd%
            ShowOSD("👀 再次呼出: [" . GetDisplayName(KeyName) . "] ")
            KeyWait, %KeyName%, T0.3
            if (ErrorLevel) {
                KeyWait, %KeyName% 
                RestoreWindow(KeyName)
            }
        }
    }
return

; =======================================================
; 8. 恢复与原生隔离算法
; =======================================================
RestoreWindow(KeyName) {
    targetHwnd := WindowBindings[KeyName]
    prevActive := RestoreData_Active[KeyName]
    hwndAbove := RestoreData_Above[KeyName]
    minMaxState := RestoreData_MinMax[KeyName]
    
    WindowIsOverlaid[KeyName] := false
    ShowOSD("⬇️ 完美隐藏，已退回底层: [" . GetDisplayName(KeyName) . "] ")
    
    if (minMaxState == -1) {
        WinMinimize, ahk_id %targetHwnd%
    } else {
        if (hwndAbove != 0) {
            if (hwndAbove == "" || !WinExist("ahk_id " . hwndAbove))
                hwndAbove := 1 
            DllCall("SetWindowPos", "Ptr", targetHwnd, "Ptr", hwndAbove, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
        }
    }
    WinSet, AlwaysOnTop, Off, ahk_id %targetHwnd%
    if (prevActive && prevActive != targetHwnd && WinExist("ahk_id " prevActive)) {
        WinActivate, ahk_id %prevActive%
    }
}

GetRealNativeAnchor(targetHwnd) {
    global WindowBindings, WindowIsOverlaid
    WinGet, winList, List
    targetIndex := 0
    Loop, %winList% {
        if (winList%A_Index% == targetHwnd) {
            targetIndex := A_Index
            break
        }
    }
    if (targetIndex <= 1)
        return 0
    loopIndex := targetIndex - 1
    while (loopIndex >= 1) {
        candidateHwnd := winList%loopIndex%
        WinGetClass, winClass, ahk_id %candidateHwnd%
        if (winClass == "AutoHotkeyGUI") {
            loopIndex--
            continue
        }
        WinGet, exStyle, ExStyle, ahk_id %candidateHwnd%
        if (exStyle & 0x8) {
            loopIndex--
            continue
        }
        isCandidateOverlaid := false
        for key, hwnd in WindowBindings {
            if (hwnd == candidateHwnd && WindowIsOverlaid[key]) {
                isCandidateOverlaid := true
                break
            }
        }
        if (!isCandidateOverlaid)
            return candidateHwnd
        loopIndex--
    }
    return 0 
}

; =======================================================
; 9. 界面工具函数与 OSD 引擎
; =======================================================
; 构建配置界面的下拉菜单项，并自动选中当前配置
BuildDDL(currentVal) {
    options := ["! (Alt)", "^ (Ctrl)", "+ (Shift)", "^! (Ctrl+Alt)", "^+ (Ctrl+Shift)"]
    str := ""
    for k, v in options {
        prefix := RegExReplace(v, "\s.*", "")
        if (prefix == currentVal)
            str .= v . "||"
        else
            str .= v . "|"
    }
    return str
}

; 将冰冷的 AHK 代码转化为好看的文本 (如 !1 变成 Alt+1)
GetDisplayName(KeyName) {
    global g_TriggerModifier
    prefix := g_TriggerModifier
    if (prefix == "!")
        prefix := "Alt+"
    else if (prefix == "^")
        prefix := "Ctrl+"
    else if (prefix == "+")
        prefix := "Shift+"
    else if (prefix == "^!")
        prefix := "Ctrl+Alt+"
    else if (prefix == "^+")
        prefix := "Ctrl+Shift+"
    return prefix . KeyName
}

; 把底层特殊键格式化成能看懂的人话
FormatHotkey(hk) {
    hk := StrReplace(hk, "vkC0", "·(波浪号)")
    hk := StrReplace(hk, "^", "Ctrl+")
    hk := StrReplace(hk, "!", "Alt+")
    hk := StrReplace(hk, "+", "Shift+")
    return hk
}

ShowOSD(Message, Duration := 1500) {
    Gui, OSD:Destroy
    Gui, OSD:+AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20
    osdHwnd := WinExist()
    Gui, OSD:Color, 282C34
    Gui, OSD:Font, s14 cWhite w700, Microsoft YaHei
    Gui, OSD:Margin, 30, 15
    Gui, OSD:Add, Text, Center, %Message%
    Gui, OSD:Show, NoActivate y40
    WinGetPos,,, w, h, ahk_id %osdHwnd%
    WinSet, Region, 0-0 w%w% h%h% R15-15, ahk_id %osdHwnd%
    WinSet, Transparent, 230, ahk_id %osdHwnd%
    SetTimer, HideOSD, -%Duration%
}

HideOSD:
    Gui, OSD:Destroy
return