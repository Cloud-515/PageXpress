#NoEnv
#SingleInstance Force
SendMode Input
SetBatchLines, -1
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen
CoordMode, ToolTip, Screen

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
IniRead, RadialHotkey, %IniFile%, Hotkeys, RadialHotkey, !=
IniRead, RadialHotkeyAlt, %IniFile%, Hotkeys, RadialHotkeyAlt, !-
IniRead, RadialOffsetX, %IniFile%, RadialMenu, OffsetX, 0
IniRead, RadialOffsetY, %IniFile%, RadialMenu, OffsetY, 0
IniRead, RadialSize, %IniFile%, RadialMenu, Size, 220
IniRead, RadialNormalColor, %IniFile%, RadialMenu, NormalColor, 3A4658
IniRead, RadialSelectedColor, %IniFile%, RadialMenu, SelectedColor, 4FC3F7
IniRead, RadialCenterColor, %IniFile%, RadialMenu, CenterColor, 202833
IniRead, WindowMenuHotkey, %IniFile%, Hotkeys, WindowMenuHotkey, !M
IniRead, ConfigHotkey, %IniFile%, Hotkeys, ConfigHotkey, ^!vkC0
RadialHotkey := NormalizeRadialHotkey(RadialHotkey)
RadialHotkeyAlt := NormalizeRadialHotkey(RadialHotkeyAlt)

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
global g_RadialOriginX := 0
global g_RadialOriginY := 0
global g_RadialCenterX := 0
global g_RadialCenterY := 0
global g_RadialVirtualX := 0
global g_RadialVirtualY := 0
global g_RadialLastMouseX := 0
global g_RadialLastMouseY := 0
global g_RadialSelected := 0
global g_RadialItems := []
global g_RadialOffsetX := RadialOffsetX + 0
global g_RadialOffsetY := RadialOffsetY + 0
global g_RadialOuterRadius := Max(120, RadialSize + 0)
global g_RadialInnerRadius := Round(g_RadialOuterRadius * 0.645)
global g_RadialPreviewWidth := Round(g_RadialOuterRadius * 1.18)
global g_RadialPreviewHeight := Round(g_RadialOuterRadius * 0.4)
global g_RadialNormalColor := NormalizeColor(RadialNormalColor, "3A4658")
global g_RadialSelectedColor := NormalizeColor(RadialSelectedColor, "4FC3F7")
global g_RadialCenterColor := NormalizeColor(RadialCenterColor, "202833")
global g_RadialGapDegrees := 2
global g_RadialMenuPadding := 8
global g_RadialDeadZone := g_RadialInnerRadius
global g_RadialHwnd := 0
global g_RadialSectorHwnds := []
global g_RadialSectorLabelHwnds := []
global g_RadialSectorIconHwnds := []
global g_RadialLabelGuiNames := []
global g_RadialAppControlHwnd := 0
global g_RadialCenterControlHwnd := 0
global g_RadialIconControlHwnd := 0
global g_RadialIgnoreCursorDelta := false
global WindowStateByHwnd := {}
global g_WindowMenuTargetHwnd := 0
global g_WindowMenuOpen := false
global g_CamouflageHideDelay := 250

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
Hotkey, $*%WindowMenuHotkey%, WindowMenuHandler
if (RadialHotkeyAlt != RadialHotkey)
    Hotkey, $*%RadialHotkeyAlt%, RadialHandler
Hotkey, $*%PinHotkey%, PinHandler
Hotkey, %ConfigHotkey%, ShowConfigGUI
SetTimer, CamouflageTimer, 50

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

    Gui, Config:Add, GroupBox, x15 y155 w330 h565, 2. 独立功能快捷键与轮盘外观
    Gui, Config:Add, Text, x30 y180 w300 cGray, 语法：! = Alt，^ = Ctrl，+ = Shift`n特殊：vkC0 = · 键 (Esc下方波浪号)

    Gui, Config:Add, Text, x30 y225, 全局置顶按键:
    Gui, Config:Add, Edit, x150 y220 w170 vUI_Pin, %PinHotkey%

    Gui, Config:Add, Text, x30 y255, 记录层级快照:
    Gui, Config:Add, Edit, x150 y250 w170 vUI_Snapshot, %SnapshotHotkey%

    Gui, Config:Add, Text, x30 y285, 实时预览面板:
    Gui, Config:Add, Edit, x150 y280 w170 vUI_Preview, %PreviewHotkey%

    Gui, Config:Add, Text, x30 y315, 主轮盘按键:
    Gui, Config:Add, Edit, x150 y310 w170 vUI_Radial, %RadialHotkey%

    Gui, Config:Add, Text, x30 y345, 备用轮盘按键:
    Gui, Config:Add, Edit, x150 y340 w170 vUI_RadialAlt, %RadialHotkeyAlt%
    Gui, Config:Add, Text, x30 y365 w290 cGray, 主键盘：!= 为 Alt+=；!- 为 Alt+-

    Gui, Config:Add, Text, x30 y395, 轮盘水平偏移:
    Gui, Config:Add, Edit, x150 y390 w70 Number vUI_RadialOffsetX, %RadialOffsetX%
    Gui, Config:Add, Text, x230 y395, 像素

    Gui, Config:Add, Text, x30 y425, 轮盘垂直偏移:
    Gui, Config:Add, Edit, x150 y420 w70 Number vUI_RadialOffsetY, %RadialOffsetY%
    Gui, Config:Add, Text, x230 y425, 像素

    Gui, Config:Add, Text, x30 y455, 轮盘外半径:
    Gui, Config:Add, Edit, x150 y450 w70 Number vUI_RadialSize, %RadialSize%
    Gui, Config:Add, Text, x230 y455, 像素

    Gui, Config:Add, Text, x30 y485, 普通扇区颜色:
    Gui, Config:Add, Edit, x150 y480 w100 vUI_RadialNormalColor, %RadialNormalColor%

    Gui, Config:Add, Text, x30 y515, 选中扇区颜色:
    Gui, Config:Add, Edit, x150 y510 w100 vUI_RadialSelectedColor, %RadialSelectedColor%

    Gui, Config:Add, Text, x30 y545, 中心预览颜色:
    Gui, Config:Add, Edit, x150 y540 w100 vUI_RadialCenterColor, %RadialCenterColor%
    Gui, Config:Add, Text, x30 y565 w280 cGray, 填写 6 位十六进制色值，例如 #202833

    Gui, Config:Add, Text, x30 y595, 当前窗口控制条:
    Gui, Config:Add, Edit, x150 y590 w170 vUI_WindowMenu, %WindowMenuHotkey%

    Gui, Config:Add, Text, x30 y625, 弹出本配置页:
    Gui, Config:Add, Edit, x150 y620 w170 vUI_Config, %ConfigHotkey%

    Gui, Config:Add, Button, x25 y685 w90 h35 gSaveConfig, 保存并重启
    Gui, Config:Add, Button, x135 y685 w90 h35 gCloseConfig, 取消
    Gui, Config:Add, Button, x245 y685 w90 h35 gResetConfig, 恢复默认

    Gui, Config:Show, , ⚙️ 快捷键配置中心
return

SaveConfig:
    Gui, Config:Submit
    UI_Radial := NormalizeRadialHotkey(UI_Radial)
    UI_RadialAlt := NormalizeRadialHotkey(UI_RadialAlt)
    UI_RadialNormalColor := NormalizeColor(UI_RadialNormalColor, "3A4658")
    UI_RadialSelectedColor := NormalizeColor(UI_RadialSelectedColor, "4FC3F7")
    UI_RadialCenterColor := NormalizeColor(UI_RadialCenterColor, "202833")
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
    IniWrite, %UI_RadialAlt%, %IniFile%, Hotkeys, RadialHotkeyAlt
    IniWrite, %UI_Config%, %IniFile%, Hotkeys, ConfigHotkey
    IniWrite, %UI_RadialOffsetX%, %IniFile%, RadialMenu, OffsetX
    IniWrite, %UI_RadialOffsetY%, %IniFile%, RadialMenu, OffsetY
    IniWrite, %UI_RadialSize%, %IniFile%, RadialMenu, Size
    IniWrite, %UI_RadialNormalColor%, %IniFile%, RadialMenu, NormalColor
    IniWrite, %UI_RadialSelectedColor%, %IniFile%, RadialMenu, SelectedColor
    IniWrite, %UI_RadialCenterColor%, %IniFile%, RadialMenu, CenterColor
    IniWrite, %UI_WindowMenu%, %IniFile%, Hotkeys, WindowMenuHotkey

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
; 7. 迷彩化与当前窗口控制条
; =======================================================
WindowMenuHandler:
    if (g_RadialOpen)
        return
    WinGet, hwnd, ID, A
    if (!hwnd || IsScriptGui(hwnd)) {
        ShowOSD("请选择一个普通应用窗口")
        return
    }
    g_WindowMenuTargetHwnd := hwnd
    EnsureWindowState(hwnd)
    ShowWindowMenu(hwnd)
return

CamouflageTimer:
    CheckCamouflageWindows()
return

WindowMenuOpacityChanged:
    Gui, WindowMenu:Submit, NoHide
    opacity := Round(UI_WindowOpacity * 2.55)
    SetWindowOpacity(g_WindowMenuTargetHwnd, opacity)
    GuiControl, WindowMenu:, WindowOpacityValue, % UI_WindowOpacity . "%"
return
WindowMenuCamouflage:
    state := EnsureWindowState(g_WindowMenuTargetHwnd)
    SetCamouflage(g_WindowMenuTargetHwnd, !state.camouflageEnabled)
    RefreshWindowMenu()
return
WindowMenuTriggerSmall:
    SetCamouflageSize(g_WindowMenuTargetHwnd, 160, 90)
    RefreshWindowMenu()
return
WindowMenuTriggerMedium:
    SetCamouflageSize(g_WindowMenuTargetHwnd, 240, 135)
    RefreshWindowMenu()
return
WindowMenuTriggerLarge:
    SetCamouflageSize(g_WindowMenuTargetHwnd, 320, 180)
    RefreshWindowMenu()
return
WindowMenuTopmost:
    state := EnsureWindowState(g_WindowMenuTargetHwnd)
    SetWindowTopmost(g_WindowMenuTargetHwnd, !state.alwaysOnTop)
    RefreshWindowMenu()
return
WindowMenuBindChanged:
    Gui, WindowMenu:Submit, NoHide
    if (UI_WindowMenuBind = "无")
        UnbindWindow(g_WindowMenuTargetHwnd)
    else
        BindWindowToKey(g_WindowMenuTargetHwnd, UI_WindowMenuBind)
return

GetWindowBindingKey(hwnd) {
    global KeyList, WindowBindings

    for index, key in KeyList {
        if (WindowBindings[key] = hwnd)
            return key
    }
    return "无"
}

UnbindWindow(hwnd) {
    global KeyList, WindowBindings, WindowIsOverlaid

    for index, key in KeyList {
        if (WindowBindings[key] = hwnd) {
            WindowBindings[key] := ""
            WindowIsOverlaid[key] := false
        }
    }
    ShowOSD("当前窗口已解除绑定")
}

BindWindowToKey(hwnd, bindKey) {
    global KeyList, WindowBindings, WindowIsOverlaid

    if (bindKey < "1" || bindKey > "9" || StrLen(bindKey) != 1) {
        ShowOSD("绑定键必须是 1-9")
        return
    }
    UnbindWindow(hwnd)
    WindowBindings[bindKey] := hwnd
    WindowIsOverlaid[bindKey] := false
    ShowOSD("当前窗口已绑定到: [" . GetDisplayName(bindKey) . "]")
}
WindowMenuClose:
    DestroyWindowMenu()
return

EnsureWindowState(hwnd) {
    global WindowStateByHwnd

    if (!WindowStateByHwnd.HasKey(hwnd))
        WindowStateByHwnd[hwnd] := {opacity: 255, alwaysOnTop: false, camouflageEnabled: false, camouflageHidden: false, triggerWidth: 240, triggerHeight: 135, x: 0, y: 0, width: 0, height: 0, triggerX: 0, triggerY: 0, hoverArmed: true, hideAt: 0}
    return WindowStateByHwnd[hwnd]
}

UpdateCamouflageTrigger(hwnd) {
    global WindowStateByHwnd

    state := EnsureWindowState(hwnd)
    WinGetPos, x, y, width, height, ahk_id %hwnd%
    state.x := x, state.y := y, state.width := width, state.height := height
    state.triggerX := Round(x + (width - state.triggerWidth) / 2)
    state.triggerY := Round(y + (height - state.triggerHeight) / 2)
}

SetCamouflageSize(hwnd, width, height) {
    global WindowStateByHwnd

    state := EnsureWindowState(hwnd)
    state.triggerWidth := width, state.triggerHeight := height
    if (WinExist("ahk_id " . hwnd))
        UpdateCamouflageTrigger(hwnd)
    ShowOSD("迷彩区域: " . width . " × " . height)
}

SetWindowOpacity(hwnd, opacity) {
    global WindowStateByHwnd

    state := EnsureWindowState(hwnd)
    state.opacity := opacity
    WinSet, Transparent, %opacity%, ahk_id %hwnd%
}

SetWindowTopmost(hwnd, enabled) {
    global WindowStateByHwnd

    state := EnsureWindowState(hwnd)
    state.alwaysOnTop := enabled
    setting := enabled ? "On" : "Off"
    WinSet, AlwaysOnTop, %setting%, ahk_id %hwnd%
}

SetCamouflage(hwnd, enabled) {
    global WindowStateByHwnd

    if (!WinExist("ahk_id " . hwnd))
        return
    state := EnsureWindowState(hwnd)
    if (!enabled) {
        state.camouflageEnabled := false
        if (state.camouflageHidden) {
            WinRestore, ahk_id %hwnd%
            state.camouflageHidden := false
        }
        return
    }

    WinGet, minMax, MinMax, ahk_id %hwnd%
    if (minMax = -1) {
        ShowOSD("请先恢复窗口后再启用迷彩化")
        return
    }
    UpdateCamouflageTrigger(hwnd)
    state.camouflageEnabled := true
    state.camouflageHidden := true
    state.hoverArmed := true
    DestroyWindowMenu()
    WinMinimize, ahk_id %hwnd%
    ShowOSD("迷彩化已启用，鼠标进入区域显示，离开后再次隐藏")
}

RevealCamouflageWindow(hwnd, activate := false) {
    global WindowStateByHwnd

    if (!WindowStateByHwnd.HasKey(hwnd))
        return
    state := WindowStateByHwnd[hwnd]
    if (!state.camouflageHidden)
        return
    WinRestore, ahk_id %hwnd%
    opacity := state.opacity
    WinSet, Transparent, %opacity%, ahk_id %hwnd%
    if (state.alwaysOnTop)
        WinSet, AlwaysOnTop, On, ahk_id %hwnd%
    state.camouflageHidden := false
    if (activate)
        WinActivate, ahk_id %hwnd%
}

CheckCamouflageWindows() {
    global WindowStateByHwnd

    GetCursorScreenPos(mouseX, mouseY)
    for hwnd, state in WindowStateByHwnd {
        if (!WinExist("ahk_id " . hwnd)) {
            WindowStateByHwnd.Delete(hwnd)
            continue
        }
        insideTrigger := mouseX >= state.triggerX && mouseX <= state.triggerX + state.triggerWidth && mouseY >= state.triggerY && mouseY <= state.triggerY + state.triggerHeight
        if (state.camouflageEnabled && !state.camouflageHidden)
            UpdateCamouflageTrigger(hwnd)
        if (state.camouflageHidden && insideTrigger) {
            RevealCamouflageWindow(hwnd, true)
            state.hideAt := 0
        } else if (state.camouflageEnabled && !state.camouflageHidden) {
            WinGetPos, wx, wy, ww, wh, ahk_id %hwnd%
            insideWindow := mouseX >= wx - 8 && mouseX <= wx + ww + 8 && mouseY >= wy - 8 && mouseY <= wy + wh + 8
            if (!insideTrigger && !insideWindow) {
                if (!state.hideAt)
                    state.hideAt := A_TickCount + g_CamouflageHideDelay
                else if (A_TickCount >= state.hideAt) {
                    state.camouflageHidden := true
                    state.hideAt := 0
                    WinMinimize, ahk_id %hwnd%
                }
            } else {
                state.hideAt := 0
            }
        }
    }
}

ShowWindowMenu(hwnd) {
    global g_WindowMenuOpen, UI_WindowOpacity, UI_WindowMenuBind, WindowOpacityValue

    DestroyWindowMenu()
    state := EnsureWindowState(hwnd)
    WinGetPos, x, y, width, height, ahk_id %hwnd%
    menuWidth := 590, menuHeight := 76
    opacityPercent := Round(state.opacity / 2.55)
    menuX := x + Round((width - menuWidth) / 2)
    menuY := y - menuHeight - 8

    SysGet, targetMonitor, Monitor, ahk_id %hwnd%
    SysGet, workArea, MonitorWorkArea, %targetMonitor%
    workLeft := workAreaLeft
    workTop := workAreaTop
    workRight := workAreaRight
    workBottom := workAreaBottom
    if (menuY < workTop)
        menuY := y + height + 8
    menuX := Max(workLeft, Min(menuX, workRight - menuWidth))
    menuY := Max(workTop, Min(menuY, workBottom - menuHeight))
    Gui, WindowMenu:+AlwaysOnTop -Caption +ToolWindow +HwndWindowMenuHwnd
    Gui, WindowMenu:Color, 202833
    Gui, WindowMenu:Font, s9 cFFFFFF, Microsoft YaHei
    Gui, WindowMenu:Add, Text, x12 y6 w180 Center, 透明度
    Gui, WindowMenu:Add, Text, x205 y6 w44 Center, 迷彩
    Gui, WindowMenu:Add, Text, x270 y6 w104 Center, 触发区域
    Gui, WindowMenu:Add, Text, x417 y6 w44 Center, 置顶
    Gui, WindowMenu:Add, Text, x478 y6 w92 Center, 绑定
    Gui, WindowMenu:Add, Slider, x16 y29 w140 h28 Range5-100 ToolTip vUI_WindowOpacity gWindowMenuOpacityChanged, %opacityPercent%
    Gui, WindowMenu:Add, Text, x160 y32 w32 vWindowOpacityValue, % opacityPercent . "%"
    camoText := state.camouflageEnabled ? "关" : "开"
    Gui, WindowMenu:Add, Button, x208 y29 w36 h28 gWindowMenuCamouflage, %camoText%
    Gui, WindowMenu:Add, Button, x270 y29 w32 h28 gWindowMenuTriggerSmall, S
    Gui, WindowMenu:Add, Button, x306 y29 w32 h28 gWindowMenuTriggerMedium, M
    Gui, WindowMenu:Add, Button, x342 y29 w32 h28 gWindowMenuTriggerLarge, L
    Gui, WindowMenu:Add, Text, x270 y59 w104 Center cAAB7C4, % state.triggerWidth . " × " . state.triggerHeight
    topText := state.alwaysOnTop ? "关" : "开"
    Gui, WindowMenu:Add, Button, x421 y29 w36 h28 gWindowMenuTopmost, %topText%
    currentBinding := GetWindowBindingKey(hwnd)
    Gui, WindowMenu:Add, DropDownList, x476 y31 w94 vUI_WindowMenuBind gWindowMenuBindChanged, 无|1|2|3|4|5|6|7|8|9
    GuiControl, WindowMenu:ChooseString, UI_WindowMenuBind, %currentBinding%
    Gui, WindowMenu:Add, Button, x562 y3 w22 h18 gWindowMenuClose, ×
    Gui, WindowMenu:Show, NoActivate x%menuX% y%menuY% w%menuWidth% h%menuHeight%
    WinSet, Transparent, 235, ahk_id %WindowMenuHwnd%
    g_WindowMenuOpen := true
}

RefreshWindowMenu() {
    global g_WindowMenuTargetHwnd
    if (g_WindowMenuTargetHwnd && WinExist("ahk_id " . g_WindowMenuTargetHwnd))
        ShowWindowMenu(g_WindowMenuTargetHwnd)
}

DestroyWindowMenu() {
    global g_WindowMenuOpen
    Gui, WindowMenu:Destroy
    g_WindowMenuOpen := false
}

IsScriptGui(hwnd) {
    WinGetClass, className, ahk_id %hwnd%
    return (className = "AutoHotkeyGUI")
}

; =======================================================
; 8. 鼠标轮盘窗口切换
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

    GetCursorScreenPos(g_RadialOriginX, g_RadialOriginY)
    g_RadialCenterX := g_RadialOriginX + g_RadialOffsetX
    g_RadialCenterY := g_RadialOriginY + g_RadialOffsetY
    g_RadialVirtualX := g_RadialCenterX
    g_RadialVirtualY := g_RadialCenterY
    g_RadialLastMouseX := g_RadialOriginX
    g_RadialLastMouseY := g_RadialOriginY
    g_RadialSelected := 0
    g_RadialOpen := true
    ShowRadialMenu()
    SetTimer, RadialSelectionTimer, 16
    radialPhysicalKey := RegExReplace(A_ThisHotkey, "^[\^\!\+\#\<\>\*\$~]+", "")
    KeyWait, %radialPhysicalKey%
    SetTimer, RadialSelectionTimer, Off
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

        WinGetTitle, fullTitle, ahk_id %hwnd%
        if (fullTitle == "")
            fullTitle := "无标题窗口"
        title := fullTitle
        if (StrLen(title) > 14)
            title := SubStr(title, 1, 13) . "..."
        g_RadialItems.Push({key: key, hwnd: hwnd, app: GetAppName(hwnd), title: title, fullTitle: fullTitle})
    }
}

ShowRadialMenu() {
    global g_RadialItems, g_RadialCenterX, g_RadialCenterY, g_RadialOuterRadius
    global g_RadialInnerRadius, g_RadialPreviewWidth, g_RadialPreviewHeight, g_RadialGapDegrees, g_RadialMenuPadding
    global g_RadialNormalColor, g_RadialHwnd, g_RadialSectorHwnds
    global g_RadialSectorLabelHwnds, g_RadialSectorIconHwnds
    global g_RadialAppControlHwnd, g_RadialCenterControlHwnd, g_RadialIconControlHwnd
    global RadialAppControlHwnd, RadialCenterControlHwnd, RadialIconControlHwnd

    DestroyRadialMenu()
    g_RadialSectorHwnds := []
    g_RadialSectorLabelHwnds := []
    g_RadialSectorIconHwnds := []
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
        CreateRadialSector(sectorIndex, menuX, menuY, diameter, center, startAngle, sweepAngle, g_RadialNormalColor)
    }

    centerX := g_RadialCenterX - Floor(g_RadialPreviewWidth / 2)
    centerY := g_RadialCenterY - Floor(g_RadialPreviewHeight / 2)
    Gui, RadialCenter:Destroy
    Gui, RadialCenter:+AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20
    g_RadialHwnd := WinExist()
    iconY := 8
    appTextX := 34
    appTextWidth := g_RadialPreviewWidth - appTextX - 5
    titleY := 39
    titleHeight := g_RadialPreviewHeight - titleY - 5
    titleWidth := g_RadialPreviewWidth - 10
    Gui, RadialCenter:Color, %g_RadialCenterColor%
    Gui, RadialCenter:Add, Picture, x5 y%iconY% w24 h24 hwndRadialIconControlHwnd
    Gui, RadialCenter:Font, s10 cFFFFFF w700, Microsoft YaHei
    Gui, RadialCenter:Add, Text, x%appTextX% y5 w%appTextWidth% h30 Left +0x200 hwndRadialAppControlHwnd, 移动鼠标选择窗口
    Gui, RadialCenter:Font, s9 cD8DEE9, Microsoft YaHei
    Gui, RadialCenter:Add, Text, x5 y%titleY% w%titleWidth% h%titleHeight% Left hwndRadialCenterControlHwnd,
    g_RadialIconControlHwnd := RadialIconControlHwnd
    g_RadialAppControlHwnd := RadialAppControlHwnd
    g_RadialCenterControlHwnd := RadialCenterControlHwnd
    GuiControl, RadialCenter:Hide, %g_RadialIconControlHwnd%
    Gui, RadialCenter:Show, NoActivate x%centerX% y%centerY% w%g_RadialPreviewWidth% h%g_RadialPreviewHeight%
    WinSet, Region, 0-0 w%g_RadialPreviewWidth% h%g_RadialPreviewHeight% R8-8, ahk_id %g_RadialHwnd%
    WinSet, Transparent, 245, ahk_id %g_RadialHwnd%
}

CreateRadialSector(index, menuX, menuY, diameter, center, startAngle, sweepAngle, color) {
    global g_RadialOuterRadius, g_RadialInnerRadius, g_RadialSectorHwnds
    global g_RadialSectorLabelHwnds, g_RadialSectorIconHwnds, g_RadialItems

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
    CreateRadialLabel(index, menuX, menuY, diameter, center, startAngle, sweepAngle)
}

CreateRadialLabel(index, menuX, menuY, diameter, center, startAngle, sweepAngle) {
    global g_RadialItems, g_RadialOuterRadius, g_RadialSectorLabelHwnds, g_RadialSectorIconHwnds, g_RadialLabelGuiNames

    item := g_RadialItems[index]
    itemCount := g_RadialItems.Length()
    labelGui := "RadialLabel" . index
    labelWidth := itemCount <= 4 ? 170 : (itemCount <= 8 ? 130 : 70)
    labelHeight := itemCount <= 4 ? 42 : 24
    labelRadius := g_RadialOuterRadius + 42
    labelAngle := (startAngle + sweepAngle / 2) * 0.017453292519943
    labelCenterX := Round(menuX + center + Cos(labelAngle) * labelRadius)
    labelCenterY := Round(menuY + center + Sin(labelAngle) * labelRadius)
    labelX := Round(labelCenterX - labelWidth / 2)
    labelY := Round(labelCenterY - labelHeight / 2)
    iconSize := itemCount <= 4 ? 20 : 16
    iconY := Floor((labelHeight - iconSize) / 2)

    Gui, %labelGui%:Destroy
    Gui, %labelGui%:+AlwaysOnTop -Caption +ToolWindow +E0x20 +LastFound
    Gui, %labelGui%:Color, 10151D
    Gui, %labelGui%:Font, s8 cD8DEE9 w700, Microsoft YaHei
    Gui, %labelGui%:Add, Picture, x4 y%iconY% w%iconSize% h%iconSize% hwndSectorIconHwnd
    iconSpec := "HICON:*" . GetWindowIcon(item.hwnd)
    GuiControl, %labelGui%:, %SectorIconHwnd%, %iconSpec%
    textX := iconSize + 8
    textWidth := labelWidth - textX - 4
    if (itemCount <= 4)
        labelText := "[" . item.key . "] " . item.app . "`n" . item.title
    else if (itemCount <= 8)
        labelText := "[" . item.key . "] " . item.app
    else
        labelText := "[" . item.key . "]"
    Gui, %labelGui%:Add, Text, x%textX% y0 w%textWidth% h%labelHeight% Left +0x200 hwndSectorLabelHwnd, %labelText%
    Gui, %labelGui%:Show, NoActivate x%labelX% y%labelY% w%labelWidth% h%labelHeight%
    labelHwnd := WinExist()
    WinSet, TransColor, 10151D 0, ahk_id %labelHwnd%
    g_RadialSectorIconHwnds.Push(SectorIconHwnd)
    g_RadialSectorLabelHwnds.Push(SectorLabelHwnd)
    g_RadialLabelGuiNames.Push(labelGui)
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

CalibrateRadialLayers(menuX, menuY, diameter) {
    global g_RadialCenterX, g_RadialCenterY, g_RadialSectorHwnds, g_RadialHwnd

    firstSectorHwnd := g_RadialSectorHwnds[1]
    WinGetPos, actualX, actualY, actualW, actualH, ahk_id %firstSectorHwnd%
    actualCenterX := actualX + actualW / 2
    actualCenterY := actualY + actualH / 2
    offsetX := Round(g_RadialCenterX - actualCenterX)
    offsetY := Round(g_RadialCenterY - actualCenterY)

    Loop, % g_RadialSectorHwnds.Length() {
        hwnd := g_RadialSectorHwnds[A_Index]
        WinGetPos, x, y,,, ahk_id %hwnd%
        MoveWindowBy(hwnd, x + offsetX, y + offsetY)
    }

    WinGetPos, centerX, centerY,,, ahk_id %g_RadialHwnd%
    MoveWindowBy(g_RadialHwnd, centerX + offsetX, centerY + offsetY)
}

MoveWindowBy(hwnd, x, y) {
    DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", 0, "Int", 0, "UInt", 0x0015)
}

GetCursorScreenPos(ByRef x, ByRef y) {
    VarSetCapacity(point, 8, 0)
    DllCall("GetCursorPos", "Ptr", &point)
    x := NumGet(point, 0, "Int")
    y := NumGet(point, 4, "Int")
}

SetCursorScreenPos(x, y) {
    DllCall("SetCursorPos", "Int", x, "Int", y)
}

DestroyRadialMenu() {
    global g_RadialItems, g_RadialSectorLabelHwnds, g_RadialSectorIconHwnds, g_RadialLabelGuiNames
    global g_RadialAppControlHwnd, g_RadialCenterControlHwnd, g_RadialIconControlHwnd

    Loop, % g_RadialItems.Length() {
        guiName := "RadialSector" . A_Index
        Gui, %guiName%:Destroy
        labelGui := "RadialLabel" . A_Index
        Gui, %labelGui%:Destroy
    }
    Gui, RadialCenter:Destroy
    g_RadialSectorLabelHwnds := []
    g_RadialSectorIconHwnds := []
    g_RadialLabelGuiNames := []
    g_RadialAppControlHwnd := 0
    g_RadialCenterControlHwnd := 0
    g_RadialIconControlHwnd := 0
}

UpdateRadialSelection() {
    global g_RadialCenterX, g_RadialCenterY, g_RadialInnerRadius, g_RadialOuterRadius
    global g_RadialGapDegrees, g_RadialItems, g_RadialSelected

    GetCursorScreenPos(mouseX, mouseY)
    relativeX := mouseX - g_RadialCenterX
    relativeY := mouseY - g_RadialCenterY
    distance := Sqrt(relativeX * relativeX + relativeY * relativeY)
    newSelection := 0

    if (distance >= g_RadialInnerRadius && distance <= g_RadialOuterRadius) {
        angle := DllCall("msvcrt\atan2", "Double", relativeY, "Double", relativeX, "CDecl Double") * 57.295779513082
        angle := Mod(angle + 90 + 360, 360)
        angleStep := 360 / g_RadialItems.Length()
        sectorIndex := Floor(angle / angleStep) + 1
        sectorStart := (sectorIndex - 1) * angleStep
        localAngle := angle - sectorStart

        if (localAngle >= g_RadialGapDegrees / 2 && localAngle <= angleStep - g_RadialGapDegrees / 2)
            newSelection := sectorIndex
    }

    if (newSelection != g_RadialSelected) {
        g_RadialSelected := newSelection
        UpdateRadialHighlight()
    }
}

UpdateRadialHighlight() {
    global g_RadialItems, g_RadialSelected, g_RadialSectorHwnds
    global g_RadialSectorLabelHwnds, g_RadialSectorIconHwnds, g_RadialLabelGuiNames
    global g_RadialAppControlHwnd, g_RadialCenterControlHwnd, g_RadialIconControlHwnd
    global g_RadialNormalColor, g_RadialSelectedColor

    Loop, % g_RadialItems.Length() {
        guiName := "RadialSector" . A_Index
        color := (A_Index == g_RadialSelected) ? g_RadialSelectedColor : g_RadialNormalColor
        Gui, %guiName%:Color, %color%
        sectorHwnd := g_RadialSectorHwnds[A_Index]
        opacity := (A_Index == g_RadialSelected) ? 250 : 225
        WinSet, Transparent, %opacity%, ahk_id %sectorHwnd%
        labelGui := g_RadialLabelGuiNames[A_Index]
        labelHwnd := g_RadialSectorLabelHwnds[A_Index]
        iconHwnd := g_RadialSectorIconHwnds[A_Index]
        if (A_Index == g_RadialSelected) {
            GuiControl, %labelGui%: +cFFFFFF, %labelHwnd%
            GuiControl, %labelGui%: +cFFFFFF, %iconHwnd%
        } else {
            GuiControl, %labelGui%: +cD8DEE9, %labelHwnd%
            GuiControl, %labelGui%: +cD8DEE9, %iconHwnd%
        }
    }

    if (g_RadialSelected) {
        item := g_RadialItems[g_RadialSelected]
        iconSpec := "HICON:*" . GetWindowIcon(item.hwnd)
        GuiControl, RadialCenter:, %g_RadialIconControlHwnd%, %iconSpec%
        GuiControl, RadialCenter:Show, %g_RadialIconControlHwnd%
        GuiControl, RadialCenter:, %g_RadialAppControlHwnd%, % item.app
        GuiControl, RadialCenter:, %g_RadialCenterControlHwnd%, % item.fullTitle
    } else {
        GuiControl, RadialCenter:Hide, %g_RadialIconControlHwnd%
        GuiControl, RadialCenter:, %g_RadialAppControlHwnd%, 移动鼠标选择窗口
        GuiControl, RadialCenter:, %g_RadialCenterControlHwnd%,
    }
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

    RevealCamouflageWindow(hwnd, false)
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
    RevealCamouflageWindow(targetHwnd, false)
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

NormalizeRadialHotkey(hotkey) {
    hotkey := Trim(hotkey)
    hotkey := StrReplace(hotkey, "Alt+", "!")
    hotkey := StrReplace(hotkey, "Ctrl+", "^")
    hotkey := StrReplace(hotkey, "Shift+", "+")
    hotkey := StrReplace(hotkey, "Numpad=", "NumpadAdd")
    hotkey := StrReplace(hotkey, "Numpad-", "NumpadSub")

    if (hotkey = "!+")
        return "!="
    if (hotkey = "")
        return "!="
    return hotkey
}

NormalizeColor(color, fallback) {
    color := Trim(StrReplace(color, "#", ""))
    if (!RegExMatch(color, "i)^[0-9a-f]{6}$"))
        return fallback
    StringUpper, color, color
    return color
}

GetWindowIcon(hwnd) {
    static WM_GETICON := 0x7F
    static ICON_SMALL2 := 2
    static ICON_SMALL := 0
    static GCLP_HICONSM := -34
    static GCLP_HICON := -14
    static IDI_APPLICATION := 32512

    icon := DllCall("SendMessage", "Ptr", hwnd, "UInt", WM_GETICON, "Ptr", ICON_SMALL2, "Ptr", 0, "Ptr")
    if (!icon)
        icon := DllCall("SendMessage", "Ptr", hwnd, "UInt", WM_GETICON, "Ptr", ICON_SMALL, "Ptr", 0, "Ptr")
    classLong := A_PtrSize ? "GetClassLongPtr" : "GetClassLong"
    if (!icon)
        icon := DllCall(classLong, "Ptr", hwnd, "Int", GCLP_HICONSM, "Ptr")
    if (!icon)
        icon := DllCall(classLong, "Ptr", hwnd, "Int", GCLP_HICON, "Ptr")
    if (!icon)
        icon := DllCall("LoadIcon", "Ptr", 0, "Ptr", IDI_APPLICATION, "Ptr")
    return icon
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