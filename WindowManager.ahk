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
IniRead, CamouflageEditKey, %IniFile%, Hotkeys, CamouflageEditKey, Shift
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
global g_WindowMenuHwnd := 0
global g_CamouflageHideDelay := 250
global g_CamouflageEditKey := CamouflageEditKey
global g_CamouflageGuiNames := {}
global g_CamouflageGuiHwnds := {}
global g_RadialPreviewKey := 0
global g_RadialPreviewWasMinimized := false
global g_RadialPreviewHwnd := 0
global g_RadialPreviewMinMax := 0
global g_RadialPreviewWasTopmost := false
global g_RadialPreviewSnapshotIndex := 0
global g_RadialZOrderSnapshot := []

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
SetTimer, CamouflageTimer, 30

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

    Gui, Config:Add, Text, x30 y625, 迷彩编辑抑制键:
    Gui, Config:Add, Edit, x150 y620 w170 vUI_CamouflageEditKey, %CamouflageEditKey%
    Gui, Config:Add, Text, x30 y655, 弹出本配置页:
    Gui, Config:Add, Edit, x150 y650 w170 vUI_Config, %ConfigHotkey%

    Gui, Config:Add, Button, x25 y715 w90 h35 gSaveConfig, 保存并重启
    Gui, Config:Add, Button, x135 y715 w90 h35 gCloseConfig, 取消
    Gui, Config:Add, Button, x245 y715 w90 h35 gResetConfig, 恢复默认

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
    IniWrite, %UI_CamouflageEditKey%, %IniFile%, Hotkeys, CamouflageEditKey

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
    if (g_WindowMenuOpen && g_WindowMenuTargetHwnd = hwnd) {
        DestroyWindowMenu()
        return
    }
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
    if (IsCamouflageEditKeyDown() && GetKeyState("LButton", "P"))
        EditCamouflageRegions()
    else
        ReleaseCamouflageRegions()
return

; -------------------------------------------------------
; 控制条各控件的响应处理器
;
; 统一原则：状态变更一律"增量刷新"，绝不重建整条。
; 重建（Gui,Destroy 后重新 ShowWindowMenu）会带来两个副作用：
;   1. ShowWindowMenu 会重新采样 resizeBaseWidth/Height，已缩放的窗口会把当前尺寸误当成 100% 基准，
;      宽高滑块随之跳回 100；
;   2. 启用迷彩会先把窗口最小化，此时 WinGetPos 拿到的是 -32000，被工作区钳制后整条会跑到屏幕左上角。
; 所以下面各处理器只用 GuiControl 改动受影响的那一两个控件。
; -------------------------------------------------------
WindowMenuOpacityChanged:
    Gui, WindowMenu:Submit, NoHide
    opacity := Round(UI_WindowOpacity * 2.55)
    SetWindowOpacity(g_WindowMenuTargetHwnd, opacity)
    GuiControl, WindowMenu:, WindowOpacityValue, % UI_WindowOpacity . "%"
return
WindowMenuCamouflage:
    Gui, WindowMenu:Submit, NoHide
    SetCamouflage(g_WindowMenuTargetHwnd, UI_WindowCamouflage)
    ; 启用成功时 SetCamouflage 会自行关闭控制条（窗口已最小化，控制条没有依附对象了）；
    ; 启用失败时（窗口本来就是最小化状态）控制条仍在，此时必须把勾选态拨回真实状态，否则显示与实际脱节。
    SyncWindowMenuToggles(g_WindowMenuTargetHwnd)
return
WindowMenuTriggerSmall:
    SetCamouflageSize(g_WindowMenuTargetHwnd, 160, 90)
    UpdateWindowMenuTriggerValue(g_WindowMenuTargetHwnd)
return
WindowMenuTriggerMedium:
    SetCamouflageSize(g_WindowMenuTargetHwnd, 240, 135)
    UpdateWindowMenuTriggerValue(g_WindowMenuTargetHwnd)
return
WindowMenuTriggerLarge:
    SetCamouflageSize(g_WindowMenuTargetHwnd, 320, 180)
    UpdateWindowMenuTriggerValue(g_WindowMenuTargetHwnd)
return
WindowMenuTopmost:
    ; 复选框的勾选状态就是目标状态，直接取值，不必再读旧状态取反
    Gui, WindowMenu:Submit, NoHide
    SetWindowTopmost(g_WindowMenuTargetHwnd, UI_WindowTopmost)
return
WindowMenuBindChanged:
    Gui, WindowMenu:Submit, NoHide
    if (UI_WindowMenuBind = "无")
        UnbindWindow(g_WindowMenuTargetHwnd)
    else
        BindWindowToKey(g_WindowMenuTargetHwnd, UI_WindowMenuBind)
return
WindowMenuResizeByWidth:
    Gui, WindowMenu:Submit, NoHide
    state := EnsureWindowState(g_WindowMenuTargetHwnd)
    requestedWidth := Round(state.resizeBaseWidth * UI_WindowWidthScale / 100)
    ResizeTargetWindow(g_WindowMenuTargetHwnd, requestedWidth, 0, "width", UI_WindowAspectLocked)
    UpdateWindowMenuSizeValues(g_WindowMenuTargetHwnd)
return
WindowMenuResizeByHeight:
    Gui, WindowMenu:Submit, NoHide
    state := EnsureWindowState(g_WindowMenuTargetHwnd)
    requestedHeight := Round(state.resizeBaseHeight * UI_WindowHeightScale / 100)
    ResizeTargetWindow(g_WindowMenuTargetHwnd, 0, requestedHeight, "height", UI_WindowAspectLocked)
    UpdateWindowMenuSizeValues(g_WindowMenuTargetHwnd)
return
WindowMenuAspectChanged:
    Gui, WindowMenu:Submit, NoHide
    state := EnsureWindowState(g_WindowMenuTargetHwnd)
    state.aspectRatioLocked := UI_WindowAspectLocked
    if (state.aspectRatioLocked)
        CaptureWindowAspectRatio(g_WindowMenuTargetHwnd)
    UpdateWindowMenuSizeValues(g_WindowMenuTargetHwnd)
return

; 增量刷新：把窗口的实际宽高写回读数，并让两个滑块位置与实际尺寸对齐
; （窗口被锁定比例联动、或被外部程序改过大小时，滑块不能停在旧位置）
UpdateWindowMenuSizeValues(hwnd) {
    if (!WinExist("ahk_id " . hwnd))
        return
    state := EnsureWindowState(hwnd)
    WinGetPos,,, width, height, ahk_id %hwnd%
    GuiControl, WindowMenu:, WindowMenuWidthValue, % width . " px"
    GuiControl, WindowMenu:, WindowMenuHeightValue, % height . " px"
    if (state.resizeBaseWidth > 0)
        GuiControl, WindowMenu:, UI_WindowWidthScale, % Max(1, Min(200, Round(width * 100 / state.resizeBaseWidth)))
    if (state.resizeBaseHeight > 0)
        GuiControl, WindowMenu:, UI_WindowHeightScale, % Max(1, Min(200, Round(height * 100 / state.resizeBaseHeight)))
}

; 增量刷新：只改触发区域的尺寸读数（"240 × 135"），不动其他控件
UpdateWindowMenuTriggerValue(hwnd) {
    global g_WindowMenuOpen

    if (!g_WindowMenuOpen)
        return
    state := EnsureWindowState(hwnd)
    GuiControl, WindowMenu:, WindowMenuTriggerValue, % state.triggerWidth . " × " . state.triggerHeight
}

; 增量刷新：把置顶 / 迷彩两个复选框拨回窗口的真实状态。
; 用于操作可能失败的场合——例如窗口已最小化时 SetCamouflage 会直接返回、并不真的启用迷彩，
; 此时复选框已被用户勾上，必须回读 state 纠正，否则显示与实际不一致。
; 注：GuiControl 改变勾选状态不会触发控件自身的 g 标签，不存在递归。
SyncWindowMenuToggles(hwnd) {
    global g_WindowMenuOpen, UI_WindowCamouflage, UI_WindowTopmost

    if (!g_WindowMenuOpen)
        return
    state := EnsureWindowState(hwnd)
    GuiControl, WindowMenu:, UI_WindowCamouflage, % state.camouflageEnabled ? 1 : 0
    GuiControl, WindowMenu:, UI_WindowTopmost, % state.alwaysOnTop ? 1 : 0
}

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

BuildBindingChoices(hwnd, ByRef occupiedKeys) {
    global KeyList, WindowBindings

    choices := "无"
    occupiedKeys := ""
    for index, key in KeyList {
        boundHwnd := WindowBindings[key]
        if (!boundHwnd || boundHwnd = hwnd)
            choices .= "|" . key
        else
            occupiedKeys .= (occupiedKeys = "" ? "" : " ") . key
    }
    return choices
}

BindWindowToKey(hwnd, bindKey) {
    global WindowBindings, WindowIsOverlaid

    if (bindKey < "1" || bindKey > "9" || StrLen(bindKey) != 1) {
        ShowOSD("绑定键必须是 1-9")
        return
    }
    if (WindowBindings[bindKey] && WindowBindings[bindKey] != hwnd) {
        ShowOSD("该绑定键已被其他窗口占用")
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
        WindowStateByHwnd[hwnd] := {opacity: 255, alwaysOnTop: false, camouflageEnabled: false, camouflageHidden: false, triggerWidth: 240, triggerHeight: 135, x: 0, y: 0, width: 0, height: 0, triggerX: 0, triggerY: 0, hoverArmed: true, hideAt: 0, editX: 0, editY: 0, editWidth: 0, editHeight: 0, aspectRatio: 0, aspectRatioLocked: true, resizeBaseWidth: 0, resizeBaseHeight: 0, preserveSize: false, preserveWidth: 0, preserveHeight: 0, preserveLastX: 0, preserveLastY: 0, preserveHasPosition: false, preservePending: false, dragMode: "", dragStartX: 0, dragStartY: 0, dragStartLeft: 0, dragStartTop: 0, dragStartWidth: 0, dragStartHeight: 0}
    return WindowStateByHwnd[hwnd]
}

CaptureWindowAspectRatio(hwnd) {
    state := EnsureWindowState(hwnd)
    if (!WinExist("ahk_id " . hwnd))
        return false
    WinGetPos,,, width, height, ahk_id %hwnd%
    if (width < 1 || height < 1)
        return false
    state.aspectRatio := width / height
    return true
}

ResizeTargetWindow(hwnd, requestedWidth, requestedHeight, resizeBy, keepAspectRatio) {
    if (!WinExist("ahk_id " . hwnd)) {
        ShowOSD("目标窗口已关闭")
        return false
    }

    state := EnsureWindowState(hwnd)
    WinGetPos, x, y, currentWidth, currentHeight, ahk_id %hwnd%
    if (currentWidth < 1 || currentHeight < 1) {
        ShowOSD("无法读取窗口尺寸")
        return false
    }
    if (!state.aspectRatio || !state.aspectRatioLocked)
        state.aspectRatio := currentWidth / currentHeight
    state.aspectRatioLocked := keepAspectRatio

    if (resizeBy = "width") {
        newWidth := Max(1, Round(requestedWidth))
        newHeight := keepAspectRatio ? Max(1, Round(newWidth / state.aspectRatio)) : currentHeight
    } else {
        newHeight := Max(1, Round(requestedHeight))
        newWidth := keepAspectRatio ? Max(1, Round(newHeight * state.aspectRatio)) : currentWidth
    }

    resizeSucceeded := ForceResizeTargetWindow(hwnd, x, y, newWidth, newHeight)
    WinGetPos, newX, newY, actualWidth, actualHeight, ahk_id %hwnd%
    state.x := newX, state.y := newY, state.width := actualWidth, state.height := actualHeight
    if (keepAspectRatio && actualHeight)
        state.aspectRatio := actualWidth / actualHeight
    if (state.camouflageEnabled)
        UpdateCamouflageTrigger(hwnd)
    if (!resizeSucceeded) {
        ShowOSD("目标程序拒绝该窗口尺寸: " . actualWidth . " x " . actualHeight)
        return false
    }
    if (actualWidth < 1 || actualHeight < 1)
        return false
    state.preserveSize := true
    state.preserveWidth := actualWidth
    state.preserveHeight := actualHeight
    state.preserveLastX := newX
    state.preserveLastY := newY
    state.preserveHasPosition := true
    state.preservePending := false
    return true
}

ForceResizeTargetWindow(hwnd, x, y, width, height) {
    flags := 0x0414
    Loop, 3 {
        if (!DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", width, "Int", height, "UInt", flags))
            break
        Sleep, 1
        WinGetPos,,, actualWidth, actualHeight, ahk_id %hwnd%
        if (actualWidth = width && actualHeight = height)
            return true
    }
    return false
}

PreserveTargetWindowSize(hwnd) {
    state := EnsureWindowState(hwnd)
    if (!state.preserveSize || !WinExist("ahk_id " . hwnd) || state.camouflageHidden)
        return

    WinGet, minMax, MinMax, ahk_id %hwnd%
    if (minMax = -1)
        return

    WinGetPos, currentX, currentY, currentWidth, currentHeight, ahk_id %hwnd%
    if (currentWidth < 1 || currentHeight < 1)
        return

    if (!state.preserveHasPosition) {
        state.preserveLastX := currentX
        state.preserveLastY := currentY
        state.preserveHasPosition := true
        return
    }

    if (currentX != state.preserveLastX || currentY != state.preserveLastY) {
        state.preserveLastX := currentX
        state.preserveLastY := currentY
        state.preservePending := true
    }

    if (currentWidth != state.preserveWidth || currentHeight != state.preserveHeight)
        state.preservePending := true

    if (GetKeyState("LButton", "P") || !state.preservePending)
        return

    state.preservePending := false
    if (currentWidth != state.preserveWidth || currentHeight != state.preserveHeight)
        ForceResizeTargetWindow(hwnd, currentX, currentY, state.preserveWidth, state.preserveHeight)

    WinGetPos, actualX, actualY, actualWidth, actualHeight, ahk_id %hwnd%
    state.x := actualX, state.y := actualY, state.width := actualWidth, state.height := actualHeight
    state.preserveLastX := actualX
    state.preserveLastY := actualY
    state.preserveHasPosition := true
    if (state.camouflageEnabled && !state.camouflageHidden)
        UpdateCamouflageTrigger(hwnd)
}

UpdateCamouflageTrigger(hwnd) {
    global WindowStateByHwnd

    state := EnsureWindowState(hwnd)
    WinGetPos, x, y, width, height, ahk_id %hwnd%
    state.x := x, state.y := y, state.width := width, state.height := height
    if (!state.editWidth) {
        state.editX := Round(x + (width - state.triggerWidth) / 2)
        state.editY := Round(y + (height - state.triggerHeight) / 2)
        state.editWidth := state.triggerWidth
        state.editHeight := state.triggerHeight
    }
    state.triggerX := state.editX
    state.triggerY := state.editY
    state.triggerWidth := state.editWidth
    state.triggerHeight := state.editHeight
    UpdateCamouflageRegion(hwnd)
}

SetCamouflageSize(hwnd, width, height) {
    global WindowStateByHwnd

    state := EnsureWindowState(hwnd)
    state.editWidth := width, state.editHeight := height
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
    global WindowStateByHwnd, g_CamouflageEditKey

    if (!WinExist("ahk_id " . hwnd))
        return
    state := EnsureWindowState(hwnd)
    if (!enabled) {
        state.camouflageEnabled := false
        state.camouflageHidden := false
        DestroyCamouflageRegion(hwnd)
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
    CreateCamouflageRegion(hwnd)
    HideCamouflageWindow(hwnd)
    DestroyWindowMenu()
    ShowOSD("迷彩区域已启用，按住 " . g_CamouflageEditKey . " 可编辑")
}

HideCamouflageWindow(hwnd) {
    global WindowStateByHwnd
    state := EnsureWindowState(hwnd)
    WinGetPos, x, y, w, h, ahk_id %hwnd%
    state.originalX := x, state.originalY := y, state.originalWidth := w, state.originalHeight := h
    WinMinimize, ahk_id %hwnd%
    state.camouflageHidden := true
}

CreateCamouflageRegion(hwnd) {
    global WindowStateByHwnd, g_CamouflageGuiNames, g_CamouflageGuiHwnds
    state := EnsureWindowState(hwnd)
    guiName := "Camouflage" . hwnd
    g_CamouflageGuiNames[hwnd] := guiName
    Gui, %guiName%:Destroy
    Gui, %guiName%:+AlwaysOnTop -Caption +ToolWindow +E0x20 +HwndregionHwnd
    Gui, %guiName%:Color, 4FC3F7
    regionOptions := "NoActivate x" . state.triggerX . " y" . state.triggerY . " w" . state.triggerWidth . " h" . state.triggerHeight
    Gui, %guiName%:Show, %regionOptions%
    g_CamouflageGuiHwnds[hwnd] := regionHwnd
    WinSet, Transparent, 13, ahk_id %regionHwnd%
    regionSpec := "0-0 w" . state.triggerWidth . " h" . state.triggerHeight . " R8-8"
    WinSet, Region, %regionSpec%, ahk_id %regionHwnd%
}

DestroyCamouflageRegion(hwnd) {
    global g_CamouflageGuiNames, g_CamouflageGuiHwnds
    guiName := g_CamouflageGuiNames[hwnd]
    if (guiName != "")
        Gui, %guiName%:Destroy
    g_CamouflageGuiNames.Delete(hwnd)
    g_CamouflageGuiHwnds.Delete(hwnd)
}

UpdateCamouflageRegion(hwnd) {
    global WindowStateByHwnd, g_CamouflageGuiHwnds
    state := EnsureWindowState(hwnd)
    regionHwnd := g_CamouflageGuiHwnds[hwnd]
    if (!regionHwnd)
        return
    regionX := state.triggerX, regionY := state.triggerY
    regionWidth := state.triggerWidth, regionHeight := state.triggerHeight
    WinMove, ahk_id %regionHwnd%,, %regionX%, %regionY%, %regionWidth%, %regionHeight%
    regionSpec := "0-0 w" . regionWidth . " h" . regionHeight . " R8-8"
    WinSet, Region, %regionSpec%, ahk_id %regionHwnd%
}

IsCamouflageEditKeyDown() {
    global g_CamouflageEditKey
    return GetKeyState(g_CamouflageEditKey, "P")
}

CamouflageRegionMouseDown(hwnd, mouseX, mouseY) {
    global WindowStateByHwnd
    state := EnsureWindowState(hwnd)
    if (!IsCamouflageEditKeyDown())
        return
    edge := 8
    onLeft := mouseX <= state.triggerX + edge
    onRight := mouseX >= state.triggerX + state.triggerWidth - edge
    onTop := mouseY <= state.triggerY + edge
    onBottom := mouseY >= state.triggerY + state.triggerHeight - edge
    state.dragMode := (onLeft ? "l" : "") . (onRight ? "r" : "") . (onTop ? "t" : "") . (onBottom ? "b" : "")
    if (state.dragMode = "")
        state.dragMode := "move"
    state.dragStartX := mouseX, state.dragStartY := mouseY
    state.dragStartLeft := state.triggerX, state.dragStartTop := state.triggerY
    state.dragStartWidth := state.triggerWidth, state.dragStartHeight := state.triggerHeight
}

EditCamouflageRegions() {
    global WindowStateByHwnd
    GetCursorScreenPos(mouseX, mouseY)
    for hwnd, state in WindowStateByHwnd {
        if (!state.camouflageEnabled)
            continue
        if (!state.dragMode)
            continue
        dx := mouseX - state.dragStartX, dy := mouseY - state.dragStartY
        if (state.dragMode = "move")
            state.editX := state.triggerX := state.dragStartLeft + dx, state.editY := state.triggerY := state.dragStartTop + dy
        else {
            newLeft := state.dragStartLeft
            newTop := state.dragStartTop
            newWidth := state.dragStartWidth
            newHeight := state.dragStartHeight
            if (InStr(state.dragMode, "l")) {
                newLeft := state.dragStartLeft + dx
                newWidth := state.dragStartWidth - dx
            }
            if (InStr(state.dragMode, "r"))
                newWidth := state.dragStartWidth + dx
            if (InStr(state.dragMode, "t")) {
                newTop := state.dragStartTop + dy
                newHeight := state.dragStartHeight - dy
            }
            if (InStr(state.dragMode, "b"))
                newHeight := state.dragStartHeight + dy
            if (newWidth < 40) {
                if (InStr(state.dragMode, "l"))
                    newLeft := state.dragStartLeft + state.dragStartWidth - 40
                newWidth := 40
            }
            if (newHeight < 30) {
                if (InStr(state.dragMode, "t"))
                    newTop := state.dragStartTop + state.dragStartHeight - 30
                newHeight := 30
            }
            state.editX := state.triggerX := newLeft
            state.editY := state.triggerY := newTop
            state.editWidth := state.triggerWidth := newWidth
            state.editHeight := state.triggerHeight := newHeight
        }
        UpdateCamouflageRegion(hwnd)
    }
}

ReleaseCamouflageRegions() {
    global WindowStateByHwnd
    for hwnd, state in WindowStateByHwnd
        state.dragMode := ""
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
    if (state.preserveSize)
        state.preservePending := true
    if (activate)
        WinActivate, ahk_id %hwnd%
}

CheckCamouflageWindows() {
    global WindowStateByHwnd, g_CamouflageGuiHwnds, g_RadialPreviewHwnd

    GetCursorScreenPos(mouseX, mouseY)
    for hwnd, state in WindowStateByHwnd {
        if (!WinExist("ahk_id " . hwnd)) {
            WindowStateByHwnd.Delete(hwnd)
            continue
        }
        if (hwnd = g_RadialPreviewHwnd) {
            state.hideAt := 0
            continue
        }
        PreserveTargetWindowSize(hwnd)
        insideTrigger := mouseX >= state.triggerX && mouseX <= state.triggerX + state.triggerWidth && mouseY >= state.triggerY && mouseY <= state.triggerY + state.triggerHeight
        if (state.camouflageEnabled && !state.camouflageHidden)
            UpdateCamouflageTrigger(hwnd)
        if (state.camouflageEnabled && IsCamouflageEditKeyDown()) {
            regionHwnd := g_CamouflageGuiHwnds[hwnd]
            if (regionHwnd)
                WinSet, ExStyle, -0x20, ahk_id %regionHwnd%
            if (!state.dragMode && GetKeyState("LButton", "P") && insideTrigger)
                CamouflageRegionMouseDown(hwnd, mouseX, mouseY)
            continue
        }
        regionHwnd := g_CamouflageGuiHwnds[hwnd]
        if (regionHwnd)
            WinSet, ExStyle, +0x20, ahk_id %regionHwnd%
        if (state.camouflageHidden && insideTrigger) {
            RevealCamouflageWindow(hwnd, true)
            state.hideAt := 0
        } else if (state.camouflageEnabled && !state.camouflageHidden) {
            WinGetPos, wx, wy, ww, wh, ahk_id %hwnd%
            insideWindow := mouseX >= wx - 8 && mouseX <= wx + ww + 8 && mouseY >= wy - 8 && mouseY <= wy + wh + 8
            insideMenu := IsWindowMenuUnderCursor(hwnd, mouseX, mouseY)
            if (!insideTrigger && !insideWindow && !insideMenu) {
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
    global g_WindowMenuOpen, g_WindowMenuTargetHwnd
    if (g_WindowMenuOpen && g_WindowMenuTargetHwnd) {
        menuTarget := g_WindowMenuTargetHwnd
        WinGetPos, targetX, targetY, targetW, targetH, ahk_id %menuTarget%
        overTarget := mouseX >= targetX && mouseX <= targetX + targetW && mouseY >= targetY && mouseY <= targetY + targetH
        if (!overTarget && !IsWindowMenuUnderCursor(menuTarget, mouseX, mouseY))
            DestroyWindowMenu()
    }
}

IsWindowMenuUnderCursor(hwnd, mouseX, mouseY) {
    global g_WindowMenuOpen, g_WindowMenuTargetHwnd, g_WindowMenuHwnd
    if (!g_WindowMenuOpen || g_WindowMenuTargetHwnd != hwnd || !g_WindowMenuHwnd)
        return false
    WinGetPos, menuX, menuY, menuWidth, menuHeight, ahk_id %g_WindowMenuHwnd%
    return mouseX >= menuX && mouseX <= menuX + menuWidth && mouseY >= menuY && mouseY <= menuY + menuHeight
}

; -------------------------------------------------------
; 控制条布局规范（坐标契约，改动前请先读）
;
;   外边距 14 ┊ 列间距 20（间距正中一条 1px 分隔线）┊ 整条 704 × 100
;
;   ┌──────────────────────┬─────────────┬──────────┬─────────────────────┬──┐
;   │ 透明度               │ 触发区域    │ 绑定     │ 窗口大小  ☑锁定比例 │ ×│  ← 标题行 y8
;   │ ▬▬▬▬●▬▬ 100%         │ [S][M][L]   │ [无   ▾] │ 宽 ▬▬●▬ 1920 px     │  │  ← B 行 y28
;   │ ☐置顶  ☐迷彩         │  240 × 135  │ 已占用 3 │ 高 ▬▬●▬ 1080 px     │  │  ← C 行 y60
;   └──────────────────────┴─────────────┴──────────┴─────────────────────┴──┘
;    x14         x196   x216       x338 x358   x462 x482            x688
;
; 三条硬规则：
;   1. 控件顶边只允许取 y28 或 y60，行高统一 26，否则同一行会出现视觉错位。
;   2. 列的左边界只允许取 x14 / x216 / x358 / x482；分隔线固定在 x206 / x348 / x472
;      （即相邻两列边界的正中）。挪动列宽时必须同步挪分隔线。
;   3. 字体分三级依次落笔：标题 s8 暗 → 控件 s9 白 → 次要读数 s8 更暗。
;      AHK v1 的 Gui,Font 是"当前状态"，后续 Add 全部继承，所以顺序不能打乱。
;
; 注：坐标是逻辑像素，AHK v1 默认按系统 DPI 缩放（125% 下整条实际 880 物理像素宽）。
; -------------------------------------------------------
ShowWindowMenu(hwnd) {
    global g_WindowMenuOpen, g_WindowMenuHwnd, UI_WindowOpacity, UI_WindowMenuBind, UI_WindowWidthScale, UI_WindowHeightScale, UI_WindowAspectLocked, UI_WindowTopmost, UI_WindowCamouflage, WindowOpacityValue, WindowMenuWidthValue, WindowMenuHeightValue, WindowMenuTriggerValue, WindowMenuBindHint

    DestroyWindowMenu()
    state := EnsureWindowState(hwnd)
    WinGetPos, x, y, width, height, ahk_id %hwnd%
    ; 以当前尺寸作为宽高滑块 100% 的基准。只在整条新建时采样一次：
    ; 状态变更若走重建，这里会被反复重新采样，导致已缩放的窗口把当前尺寸误当成新基准。
    state.resizeBaseWidth := width
    state.resizeBaseHeight := height
    if (state.aspectRatioLocked)
        state.aspectRatio := width / height
    menuWidth := 704, menuHeight := 100
    opacityPercent := Round(state.opacity / 2.55)
    ; 默认贴在目标窗口正上方居中
    menuX := x + Round((width - menuWidth) / 2)
    menuY := y - menuHeight - 8

    ; 顶部空间不够时翻到窗口下方，再整体收进工作区，避免整条被屏幕边缘截断
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
    g_WindowMenuHwnd := WindowMenuHwnd
    Gui, WindowMenu:Color, 202833

    ; 分组分隔线：1px 宽的 Progress 只露出 Background 颜色，是 AHK v1 画彩色细线的常规做法
    for index, sepX in [206, 348, 472]
        Gui, WindowMenu:Add, Progress, x%sepX% y16 w1 h68 Background303B4A

    ; ---- 第一级：列标题。小一号 + 降对比度，避免和数值抢注意力 ----
    Gui, WindowMenu:Font, s8 c8A94A6, Microsoft YaHei
    Gui, WindowMenu:Add, Text, x14 y8 w140 Center, 透明度
    Gui, WindowMenu:Add, Text, x216 y8 w122 Center, 触发区域
    Gui, WindowMenu:Add, Text, x358 y8 w104 Center, 绑定
    Gui, WindowMenu:Add, Text, x482 y8 w70, 窗口大小

    ; ---- 第二级：交互控件 ----
    Gui, WindowMenu:Font, s9 cFFFFFF, Microsoft YaHei
    ; 第 1 列：透明度滑块 +（下一行）两个状态开关。
    ; 开关用 Checkbox 而非"开/关"按钮：勾选状态直接等于功能状态，不会出现"显示开、其实是关"的歧义。
    Gui, WindowMenu:Add, Slider, x14 y28 w140 h26 Range5-100 ToolTip vUI_WindowOpacity gWindowMenuOpacityChanged, %opacityPercent%
    Gui, WindowMenu:Add, Text, x160 y33 w36 vWindowOpacityValue, % opacityPercent . "%"
    ; 选项串必须先拼进变量：Gui,Add 的 Options 参数中间不认 "% 表达式"，只有参数开头的 "% " 才是强制表达式
    topOptions := state.alwaysOnTop ? "Checked" : ""
    camoOptions := state.camouflageEnabled ? "Checked" : ""
    Gui, WindowMenu:Add, Checkbox, x14 y61 w80 h22 vUI_WindowTopmost gWindowMenuTopmost %topOptions%, 置顶
    Gui, WindowMenu:Add, Checkbox, x100 y61 w80 h22 vUI_WindowCamouflage gWindowMenuCamouflage %camoOptions%, 迷彩

    ; 第 2 列：迷彩触发区域的三档预设尺寸
    Gui, WindowMenu:Add, Button, x216 y28 w38 h26 gWindowMenuTriggerSmall, S
    Gui, WindowMenu:Add, Button, x258 y28 w38 h26 gWindowMenuTriggerMedium, M
    Gui, WindowMenu:Add, Button, x300 y28 w38 h26 gWindowMenuTriggerLarge, L

    ; 第 3 列：绑定键。DropDownList 的高度由字体决定而非 h 选项，
    ; 所以不写 h，改用 y30 让它在 y28 起的 26px 行内视觉居中。
    currentBinding := GetWindowBindingKey(hwnd)
    bindChoices := BuildBindingChoices(hwnd, occupiedKeys)
    Gui, WindowMenu:Add, DropDownList, x358 y30 w104 vUI_WindowMenuBind gWindowMenuBindChanged, %bindChoices%
    GuiControl, WindowMenu:ChooseString, UI_WindowMenuBind, %currentBinding%

    ; 第 4 列：宽 / 高各占一行。"锁定比例"是本组的修饰项而非第三个参数，
    ; 放标题行右侧，省掉一个只为它存在的第三行（整条因此从 140 降到 100 高）。
    aspectOptions := state.aspectRatioLocked ? "Checked" : ""
    Gui, WindowMenu:Add, Checkbox, x560 y6 w86 h20 vUI_WindowAspectLocked gWindowMenuAspectChanged %aspectOptions%, 锁定比例
    Gui, WindowMenu:Add, Text, x482 y33 w20, 宽
    Gui, WindowMenu:Add, Slider, x506 y28 w124 h26 Range1-200 ToolTip vUI_WindowWidthScale gWindowMenuResizeByWidth, 100
    Gui, WindowMenu:Add, Text, x636 y33 w52 vWindowMenuWidthValue, % width . " px"
    Gui, WindowMenu:Add, Text, x482 y65 w20, 高
    Gui, WindowMenu:Add, Slider, x506 y60 w124 h26 Range1-200 ToolTip vUI_WindowHeightScale gWindowMenuResizeByHeight, 100
    Gui, WindowMenu:Add, Text, x636 y65 w52 vWindowMenuHeightValue, % height . " px"

    Gui, WindowMenu:Add, Button, x674 y6 w20 h20 gWindowMenuClose, ×

    ; ---- 第三级：次要读数，比数值再弱一级 ----
    ; 两个读数都无条件创建（哪怕内容为空），这样有无内容都不会让布局跳动，也才能用 GuiControl 增量刷新。
    Gui, WindowMenu:Font, s8 c7A8494, Microsoft YaHei
    Gui, WindowMenu:Add, Text, x216 y64 w122 Center vWindowMenuTriggerValue, % state.triggerWidth . " × " . state.triggerHeight
    Gui, WindowMenu:Add, Text, x358 y64 w104 Center vWindowMenuBindHint, % occupiedKeys != "" ? "已占用 " . occupiedKeys : ""

    Gui, WindowMenu:Show, NoActivate x%menuX% y%menuY% w%menuWidth% h%menuHeight%
    WinSet, Transparent, 235, ahk_id %WindowMenuHwnd%
    g_WindowMenuOpen := true
}

RefreshWindowMenu() {
    global g_WindowMenuTargetHwnd, g_WindowMenuOpen
    ; 仅在需要重新定位整条时使用；日常状态变更请用 UpdateWindowMenu* 系列做增量刷新，
    ; 因为重建会重新采样 resizeBaseWidth/Height，导致宽高滑块基准被打断。
    if (g_WindowMenuOpen && g_WindowMenuTargetHwnd && WinExist("ahk_id " . g_WindowMenuTargetHwnd))
        ShowWindowMenu(g_WindowMenuTargetHwnd)
}

DestroyWindowMenu() {
    global g_WindowMenuOpen, g_WindowMenuHwnd
    Gui, WindowMenu:Destroy
    g_WindowMenuOpen := false
    g_WindowMenuHwnd := 0
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

    CaptureRadialZOrderSnapshot()
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
    if (!g_RadialSelected)
        UpdateRadialPreview(0)
    DestroyRadialMenu()
    g_RadialOpen := false

    if (g_RadialSelected) {
        CommitRadialPreview()
        ActivateRadialWindow(g_RadialItems[g_RadialSelected].key)
    }
return

RadialSelectionTimer:
    UpdateRadialSelection()
return

CaptureRadialZOrderSnapshot() {
    global g_RadialZOrderSnapshot
    g_RadialZOrderSnapshot := []
    WinGet, winList, List
    Loop, %winList% {
        hwnd := winList%A_Index%
        if (!hwnd || !DllCall("IsWindowVisible", "Ptr", hwnd))
            continue
        WinGetClass, className, ahk_id %hwnd%
        if (className = "AutoHotkeyGUI")
            continue
        WinGet, exStyle, ExStyle, ahk_id %hwnd%
        if (exStyle & 0x8)
            continue
        g_RadialZOrderSnapshot.Push(hwnd)
    }
}

GetRadialSnapshotIndex(hwnd) {
    global g_RadialZOrderSnapshot
    for index, snapshotHwnd in g_RadialZOrderSnapshot {
        if (snapshotHwnd = hwnd)
            return index
    }
    return 0
}

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
        snapshotIndex := GetRadialSnapshotIndex(hwnd)
        g_RadialItems.Push({key: key, hwnd: hwnd, app: GetAppName(hwnd), title: title, fullTitle: fullTitle, snapshotIndex: snapshotIndex})
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
    g_RadialLabelGuiNames := []
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

    Loop, %itemCount% {
        sectorIndex := A_Index
        startAngle := -90 + (sectorIndex - 1) * angleStep + g_RadialGapDegrees / 2
        sweepAngle := angleStep - g_RadialGapDegrees
        CreateRadialLabel(sectorIndex, menuX, menuY, diameter, center, startAngle, sweepAngle)
    }
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
    Gui, %labelGui%:Font, s8 cFFFFFF w700, Microsoft YaHei
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
    WinSet, Transparent, 235, ahk_id %labelHwnd%
    WinSet, AlwaysOnTop, On, ahk_id %labelHwnd%
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

KeepRadialMenuOnTop() {
    global g_RadialHwnd, g_RadialSectorHwnds, g_RadialLabelGuiNames
    flags := 0x213 | 0x0040
    if (g_RadialHwnd)
        DllCall("SetWindowPos", "Ptr", g_RadialHwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", flags)
    for _, hwnd in g_RadialSectorHwnds
        DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", flags)
    for _, guiName in g_RadialLabelGuiNames {
        Gui, %guiName%:+LastFound
        labelGuiHwnd := WinExist()
        if (labelGuiHwnd)
            DllCall("SetWindowPos", "Ptr", labelGuiHwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", flags)
    }
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
        UpdateRadialPreview(newSelection)
    }
}

UpdateRadialPreview(selection) {
    global g_RadialItems, g_RadialPreviewKey, g_RadialPreviewHwnd
    global g_RadialPreviewSnapshotIndex, g_RadialPreviewMinMax, g_RadialPreviewWasMinimized, g_RadialPreviewWasTopmost
    if (g_RadialPreviewKey && (selection = 0 || g_RadialItems[selection].key != g_RadialPreviewKey))
        RestoreRadialPreview()
    if (!selection || g_RadialPreviewKey)
        return

    item := g_RadialItems[selection]
    itemHwnd := item.hwnd
    WinGet, minMax, MinMax, ahk_id %itemHwnd%
    state := EnsureWindowState(itemHwnd)
    g_RadialPreviewKey := item.key
    g_RadialPreviewHwnd := itemHwnd
    g_RadialPreviewSnapshotIndex := item.snapshotIndex
    g_RadialPreviewMinMax := minMax
    g_RadialPreviewWasMinimized := (minMax = -1 || state.camouflageHidden)
    WinGet, previewExStyle, ExStyle, ahk_id %itemHwnd%
    g_RadialPreviewWasTopmost := !!(previewExStyle & 0x8)

    if (minMax = -1 || state.camouflageHidden) {
        WinRestore, ahk_id %itemHwnd%
        state.camouflageHidden := false
    }
    ; 轮盘本身是置顶 GUI，预览必须临时位于其上方，但不激活窗口。
    DllCall("SetWindowPos", "Ptr", itemHwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x213 | 0x0040)
    KeepRadialMenuOnTop()
}

CommitRadialPreview() {
    global g_RadialPreviewKey, g_RadialPreviewHwnd, g_RadialPreviewSnapshotIndex
    global g_RadialPreviewMinMax, g_RadialPreviewWasMinimized, g_RadialPreviewWasTopmost
    g_RadialPreviewKey := 0
    g_RadialPreviewHwnd := 0
    g_RadialPreviewSnapshotIndex := 0
    g_RadialPreviewMinMax := 0
    g_RadialPreviewWasMinimized := false
    g_RadialPreviewWasTopmost := false
}

RestoreRadialSnapshotPosition(snapshotIndex, targetHwnd) {
    global g_RadialZOrderSnapshot
    flags := 0x213

    index := snapshotIndex - 1
    while (index >= 1) {
        candidate := g_RadialZOrderSnapshot[index]
        if (candidate != targetHwnd && DllCall("IsWindow", "Ptr", candidate)) {
            DllCall("SetWindowPos", "Ptr", targetHwnd, "Ptr", candidate, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", flags)
            return
        }
        index--
    }

    index := snapshotIndex + 1
    snapshotCount := g_RadialZOrderSnapshot.Length()
    while (index <= snapshotCount) {
        candidate := g_RadialZOrderSnapshot[index]
        if (candidate != targetHwnd && DllCall("IsWindow", "Ptr", candidate)) {
            currentAbove := DllCall("GetWindow", "Ptr", candidate, "UInt", 3, "Ptr")
            if (currentAbove = targetHwnd)
                return
            DllCall("SetWindowPos", "Ptr", targetHwnd, "Ptr", currentAbove, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", flags)
            return
        }
        index++
    }

    DllCall("SetWindowPos", "Ptr", targetHwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", flags)
}

RestoreRadialPreview() {
    global g_RadialPreviewKey, g_RadialPreviewHwnd, g_RadialPreviewSnapshotIndex
    global g_RadialPreviewMinMax, g_RadialPreviewWasMinimized, g_RadialPreviewWasTopmost, WindowStateByHwnd
    hwnd := g_RadialPreviewHwnd
    if (hwnd && WinExist("ahk_id " . hwnd)) {
        if (g_RadialPreviewWasMinimized) {
            if (WindowStateByHwnd.HasKey(hwnd) && WindowStateByHwnd[hwnd].camouflageEnabled)
                WindowStateByHwnd[hwnd].camouflageHidden := true
            WinMinimize, ahk_id %hwnd%
        } else if (!g_RadialPreviewWasTopmost) {
            DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", -2, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x213 | 0x0040)
            RestoreRadialSnapshotPosition(g_RadialPreviewSnapshotIndex, hwnd)
        }
    }
    g_RadialPreviewKey := 0
    g_RadialPreviewHwnd := 0
    g_RadialPreviewSnapshotIndex := 0
    g_RadialPreviewMinMax := 0
    g_RadialPreviewWasMinimized := false
    g_RadialPreviewWasTopmost := false
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