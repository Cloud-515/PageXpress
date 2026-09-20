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

; 快捷键默认值集中在这里，有两个用途：
;   1. 作为 IniRead 的兜底（配置文件缺项时用）；
;   2. 作为注册失败时的回退目标（见 RegisterHotkey），所以不能只在 IniRead 里写死。
global DefaultTriggerModifier := "!"
global DefaultBindModifier := "^!"
global DefaultUnbindModifier := "^+"
global DefaultPinHotkey := "!T"
global DefaultSnapshotHotkey := "!0"
global DefaultPreviewHotkey := "!vkC0"
global DefaultRadialHotkey := "!="
global DefaultRadialHotkeyAlt := "!-"
global DefaultWindowMenuHotkey := "!M"
global DefaultCamouflageEditKey := "Shift"
global DefaultConfigHotkey := "^!vkC0"

; 读取配置文件，如果没有则使用默认值
IniRead, TriggerModifier, %IniFile%, Hotkeys, TriggerModifier, %DefaultTriggerModifier%
IniRead, BindModifier, %IniFile%, Hotkeys, BindModifier, %DefaultBindModifier%
IniRead, UnbindModifier, %IniFile%, Hotkeys, UnbindModifier, %DefaultUnbindModifier%
IniRead, PinHotkey, %IniFile%, Hotkeys, PinHotkey, %DefaultPinHotkey%
IniRead, SnapshotHotkey, %IniFile%, Hotkeys, SnapshotHotkey, %DefaultSnapshotHotkey%
IniRead, PreviewHotkey, %IniFile%, Hotkeys, PreviewHotkey, %DefaultPreviewHotkey%
IniRead, RadialHotkey, %IniFile%, Hotkeys, RadialHotkey, %DefaultRadialHotkey%
IniRead, RadialHotkeyAlt, %IniFile%, Hotkeys, RadialHotkeyAlt, %DefaultRadialHotkeyAlt%
IniRead, RadialOffsetX, %IniFile%, RadialMenu, OffsetX, 0
IniRead, RadialOffsetY, %IniFile%, RadialMenu, OffsetY, 0
IniRead, RadialSize, %IniFile%, RadialMenu, Size, 220
IniRead, RadialNormalColor, %IniFile%, RadialMenu, NormalColor, 3A4658
IniRead, RadialSelectedColor, %IniFile%, RadialMenu, SelectedColor, 4FC3F7
IniRead, RadialCenterColor, %IniFile%, RadialMenu, CenterColor, 202833
IniRead, RadialStyle, %IniFile%, RadialMenu, Style, Band
IniRead, BandInnerRatio, %IniFile%, RadialMenu, BandInnerRatio, 0.72
IniRead, BandOuterRatio, %IniFile%, RadialMenu, BandOuterRatio, 0.96
IniRead, ShowIcons, %IniFile%, RadialMenu, ShowIcons, 1
IniRead, ShowKeyBadges, %IniFile%, RadialMenu, ShowKeyBadges, 1
IniRead, LabelMode, %IniFile%, RadialMenu, LabelMode, Always
IniRead, WindowMenuHotkey, %IniFile%, Hotkeys, WindowMenuHotkey, %DefaultWindowMenuHotkey%
IniRead, CamouflageEditKey, %IniFile%, Hotkeys, CamouflageEditKey, %DefaultCamouflageEditKey%
IniRead, ConfigHotkey, %IniFile%, Hotkeys, ConfigHotkey, %DefaultConfigHotkey%
RadialHotkey := NormalizeHotkeySpelling(RadialHotkey)
RadialHotkeyAlt := NormalizeHotkeySpelling(RadialHotkeyAlt)

; 启动告警收集器。必须在下面任何 SanitizeModifier / RegisterHotkey 之前建好，
; 否则第一条告警会因为往空变量上 Push 而抛错。
global g_RegisteredHotkeys := {}
global g_StartupWarnings := []

; 三个修饰键要拼在 1~9 前面成为完整热键，所以先做形状校验：
; 非法值整体回退默认，避免出现"1~8 注册成功、9 失败"这种半截状态，
; 同时把结果写回变量，让配置页下拉框显示的就是真正生效的修饰键。
TriggerModifier := SanitizeModifier(TriggerModifier, DefaultTriggerModifier, "呼出/隐藏修饰键")
BindModifier := SanitizeModifier(BindModifier, DefaultBindModifier, "绑定修饰键")
UnbindModifier := SanitizeModifier(UnbindModifier, DefaultUnbindModifier, "解绑修饰键")
; 抑制键不是热键而是"按住才生效"的键，判定方式不同（见 IsUsableKeyName）
CamouflageEditKey := SanitizeKeyName(CamouflageEditKey, DefaultCamouflageEditKey, "迷彩编辑抑制键")

; 提取按键的物理键，供 KeyWait 使用 (剔除修饰符)
; 注意只保留真正会被读的那个：轮盘用的是 A_ThisHotkey 现算的键，不需要全局副本
global PreviewPhysicalKey := StripHotkeyModifiers(PreviewHotkey)

global KeyList := ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
global WindowBindings := {}
global WindowIsOverlaid := {}     
; 注意：下面几张表用绑定键（"1"~"9"）作下标。AHK v1 里 obj["1"]（字面量）与 obj[变量]
; 即使变量里就是同一个字符串，也可能落到不同条目上（v1.1.37 实测：字面量写得进、
; 变量读不出）。所以这几张表的读写一律用变量下标，别图省事写成字面量。
global RestoreData_Active := {}   
global RestoreData_Above := {}    
global RestoreData_MinMax := {}   
global RestoreData_Topmost := {}  
global g_TriggerModifier := TriggerModifier 
global g_BindModifier := BindModifier
global g_UnbindModifier := UnbindModifier
global g_RadialOpen := false
global g_RadialOriginX := 0
global g_RadialOriginY := 0
global g_RadialCenterX := 0
global g_RadialCenterY := 0
global g_RadialSelected := 0
; 当前被高亮成"选中色"的扇区，用于把重绘限制在变化的那两个扇区上
global g_RadialHighlighted := 0
global g_RadialItems := []
global g_RadialOffsetX := RadialOffsetX + 0
global g_RadialOffsetY := RadialOffsetY + 0
global g_RadialOuterRadius := Max(120, RadialSize + 0)
global g_RadialInnerRadius := Round(g_RadialOuterRadius * 0.645)
; -------------------------------------------------------
; 轮盘外观（阶段 0：薄环带 + 扇区内图标/角标 + 圆形中心舱）
;
; 核心设计决定：**视觉环带与命中区故意解耦**。
;   命中区仍用 g_RadialInnerRadius ~ g_RadialOuterRadius 这一整圈（内径 0.645R），
;   因为视觉变细不等于要用户瞄得更准 —— 鼠标只要落在扇区方向上就该选中。
;   视觉只画 g_RadialBandInner ~ g_RadialBandOuter 这条薄带，看起来轻得多。
; 环带两端做圆头端帽（见 BuildArcBandPoints）：相邻扇区之间就是"设计过的缺口"，
; 而不是切歪的直角。
; -------------------------------------------------------
global g_RadialStyle := (RadialStyle = "Wedge") ? "Wedge" : "Band"
global g_RadialBandInnerRatio := (BandInnerRatio + 0 >= 0.3 && BandInnerRatio + 0 <= 0.95) ? BandInnerRatio + 0 : 0.72
global g_RadialBandOuterRatio := (BandOuterRatio + 0 > g_RadialBandInnerRatio && BandOuterRatio + 0 <= 1.0) ? BandOuterRatio + 0 : 0.96
global g_RadialBandInner := Round(g_RadialOuterRadius * g_RadialBandInnerRatio)
global g_RadialBandOuter := Round(g_RadialOuterRadius * g_RadialBandOuterRatio)
global g_RadialBandMid := Round((g_RadialBandInner + g_RadialBandOuter) / 2)
global g_RadialBandThickness := g_RadialBandOuter - g_RadialBandInner
global g_RadialShowIcons := (ShowIcons + 0) ? true : false
global g_RadialShowBadges := (ShowKeyBadges + 0) ? true : false
global g_RadialLabelMode := (LabelMode = "Never" || LabelMode = "Hover") ? LabelMode : "Always"
; 中心舱：圆形。直径按"屏幕上不超过内径的 88%"反推 —— 环带是物理像素（Region 不缩放），
; 而中心舱是 DPI 缩放的窗口，所以这里要先把物理目标算出来，再折回逻辑尺寸交给 AHK 放大，
; 否则 125% 下这个圆会胀到压住环带。内容排版则按逻辑尺寸设计，整体等比放大。
global g_RadialHubPhysicalDiameter := Round(g_RadialInnerRadius * 2 * 0.88)
global g_RadialHubDiameter := Round(g_RadialHubPhysicalDiameter * 96 / A_ScreenDPI)
global g_RadialNormalColor := NormalizeColor(RadialNormalColor, "3A4658")
global g_RadialSelectedColor := NormalizeColor(RadialSelectedColor, "4FC3F7")
global g_RadialCenterColor := NormalizeColor(RadialCenterColor, "202833")
global g_RadialGapDegrees := 2
global g_RadialMenuPadding := 8
global g_RadialHwnd := 0
global g_RadialSectorHwnds := []
global g_RadialSectorLabelHwnds := []
global g_RadialSectorIconHwnds := []
global g_RadialLabelGuiNames := []
; 标签窗口本身的句柄（g_RadialSectorLabelHwnds 存的是标签里那个 Text 控件，别混用），
; LabelMode=Hover 时要靠它整窗显示/隐藏
global g_RadialLabelWinHwnds := []
; 扇区内部的图标与键位角标控件
global g_RadialBandIconHwnds := []
global g_RadialBandBadgeHwnds := []
global g_RadialAppControlHwnd := 0
global g_RadialCenterControlHwnd := 0
global g_RadialIconControlHwnd := 0
global WindowStateByHwnd := {}
global g_WindowMenuTargetHwnd := 0
global g_WindowMenuOpen := false
global g_WindowMenuHwnd := 0
; 整条的布局尺寸（逻辑像素）。放在全局是因为定位数学有两个调用点：
; 新建整条时定位、目标窗口移动后跟随（见 ComputeWindowMenuPos）。
global g_WindowMenuWidth := 704
global g_WindowMenuHeight := 100
; 上一次看到的窗口左上角，用来判断"窗口动了没有"，避免每 tick 都重算定位
global g_WindowMenuTargetX := 0
global g_WindowMenuTargetY := 0
global g_CamouflageHideDelay := 250
; 控制条与目标窗口之间留的视觉缝隙（物理像素），同时是一条坐标契约：
; 这条缝隙既不在窗口矩形里、也不在整条矩形里，而鼠标从窗口挪向整条必然要穿过它，
; 所以命中测试必须把缝隙当"过道"一起算进保活区，详见 IsPointInMenuHoverArea。
global g_WindowMenuGap := 8
; 命中测试的额外容差：窗口边框和 DPI 取整会让 WinGetPos 的矩形跟视觉边缘差几像素
global g_WindowMenuHoverPad := 6
; 和迷彩同款宽限期：单帧的坐标抖动不该直接把整条收掉
global g_WindowMenuHideDelay := 250
global g_WindowMenuHideAt := 0
global g_CamouflageEditKey := CamouflageEditKey
global g_CamouflageGuiNames := {}
global g_CamouflageGuiHwnds := {}
; 编辑态正在被拖动的那个触发区。区域重叠时，鼠标会同时落在多个触发区里，
; 没有这个归属标记就会一次拖走好几块。
global g_CamouflageDragOwner := 0
; 呼出/隐藏判定里给窗口矩形留的容差（物理像素），与 g_WindowMenuHoverPad 同类
global g_CamouflageWindowPad := 8
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
; 全部走 RegisterHotkey：它把"配置里的值不能用"这件事变成一次降级，而不是一次崩溃。
; 之前直接 Hotkey 的写法有两个致命处（均在 v1.1.37 实测）：
;   1. 非法键名会让 Hotkey 命令抛错并终止脚本 —— 若坏的是 ConfigHotkey，
;      重启后连配置页都打不开，只能手改 config.ini 才能救回来；
;   2. 重复注册同一个键不报错，AHK 会静默把前一个标签顶掉，功能无声消失。
; 现在：非法值回退到该功能的默认键，与已注册键冲突的跳过，两者都会记进 g_StartupWarnings。
; 每个字段都把生效值写回变量：配置页显示的就是实际注册成功的键，不会"看着是 A、实际是 B"。
for index, key in KeyList {
    RegisterHotkey(g_BindModifier . key, "BindHandler", DefaultBindModifier . key, "")
    RegisterHotkey(g_UnbindModifier . key, "UnbindHandler", DefaultUnbindModifier . key, "")
    RegisterHotkey(g_TriggerModifier . key, "TriggerHandler", DefaultTriggerModifier . key)
}
SnapshotHotkey := RegisterHotkey(SnapshotHotkey, "SnapshotHandler", DefaultSnapshotHotkey)
PreviewHotkey := RegisterHotkey(PreviewHotkey, "PreviewHandler", DefaultPreviewHotkey)
RadialHotkey := RegisterHotkey(RadialHotkey, "RadialHandler", DefaultRadialHotkey)
WindowMenuHotkey := RegisterHotkey(WindowMenuHotkey, "WindowMenuHandler", DefaultWindowMenuHotkey)
if (RadialHotkeyAlt != RadialHotkey)
    RadialHotkeyAlt := RegisterHotkey(RadialHotkeyAlt, "RadialHandler", DefaultRadialHotkeyAlt)
PinHotkey := RegisterHotkey(PinHotkey, "PinHandler", DefaultPinHotkey)
ConfigHotkey := RegisterHotkey(ConfigHotkey, "ShowConfigGUI", DefaultConfigHotkey, "")

; 物理键要在注册之后重新提取：上面可能刚刚把非法值换成了默认值
PreviewPhysicalKey := StripHotkeyModifiers(PreviewHotkey)

SetTimer, CamouflageTimer, 30

; 有快捷键没生效时优先报这个：它比"怎么打开配置"更需要用户知道
if (g_StartupWarnings.Length())
    ShowOSD("⚠️ " . JoinText(g_StartupWarnings, "；"), 5000)
else
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
    UI_Radial := NormalizeHotkeySpelling(UI_Radial)
    UI_RadialAlt := NormalizeHotkeySpelling(UI_RadialAlt)
    UI_RadialNormalColor := NormalizeColor(UI_RadialNormalColor, "3A4658")
    UI_RadialSelectedColor := NormalizeColor(UI_RadialSelectedColor, "4FC3F7")
    UI_RadialCenterColor := NormalizeColor(UI_RadialCenterColor, "202833")
    ; 提取下拉菜单中真实的符号 (例如把 "! (Alt)" 变回 "!")
    RegExMatch(UI_Trigger, "^[^\s]+", newTrigger)
    RegExMatch(UI_Bind, "^[^\s]+", newBind)
    RegExMatch(UI_Unbind, "^[^\s]+", newUnbind)

    ; 写盘前先校验：坏值一旦落进 config.ini，下次启动就靠"回退默认值"去救，
    ; 用户看到的将是"我明明设了却没生效"。能在这里拦住就别留给启动时兜底。
    errorMessage := ""
    if (!ValidateHotkeyInput(UI_Pin, "全局置顶按键", errorMessage)
        || !ValidateHotkeyInput(UI_Snapshot, "记录层级快照按键", errorMessage)
        || !ValidateHotkeyInput(UI_Preview, "实时预览面板按键", errorMessage)
        || !ValidateHotkeyInput(UI_Radial, "主轮盘按键", errorMessage)
        || !ValidateHotkeyInput(UI_RadialAlt, "备用轮盘按键", errorMessage)
        || !ValidateHotkeyInput(UI_WindowMenu, "当前窗口控制条按键", errorMessage)
        || !ValidateHotkeyInput(UI_Config, "配置页按键", errorMessage)) {
        ShowOSD("⚠️ " . errorMessage . "，未保存", 3000)
        return
    }
    conflictMessage := FindHotkeyConflict(newTrigger, newBind, newUnbind, UI_Pin, UI_Snapshot, UI_Preview, UI_Radial, UI_RadialAlt, UI_WindowMenu, UI_Config)
    if (conflictMessage != "") {
        ShowOSD("⚠️ " . conflictMessage . "，未保存", 3000)
        return
    }
    ; 抑制键单独校验：它允许是裸修饰键（默认就是 Shift），所以不能套用热键那套规则
    if (!IsUsableKeyName(UI_CamouflageEditKey)) {
        ShowOSD("⚠️ 迷彩编辑抑制键「" . Trim(UI_CamouflageEditKey) . "」不是可用键名，未保存", 3000)
        return
    }
    
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
; 置顶状态有三个"副本"：窗口真实的 WS_EX_TOPMOST、state.alwaysOnTop、控制条复选框。
; 这里一律以 ExStyle 为准来翻转，再通过 SetWindowTopmost 写回 state，
; 保证控制条上看到的就是真的（此前只 WinSet 不写 state，勾选态会和实际相反）。
PinHandler:
    WinGet, currentHwnd, ID, A
    if (!currentHwnd)
        return
    if (IsScriptGui(currentHwnd)) {
        ShowOSD("请选择一个普通应用窗口")
        return
    }
    WinGetTitle, title, ahk_id %currentHwnd%
    if (StrLen(title) > 12)
        title := SubStr(title, 1, 11) . "…"
    if (title == "")
        title := "当前窗口"

    WinGet, exStyle, ExStyle, ahk_id %currentHwnd%
    if (exStyle & 0x8) {
        SetWindowTopmost(currentHwnd, false)
        ShowOSD("🔽 已取消置顶: " . title)
    } else {
        SetWindowTopmost(currentHwnd, true)
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
    ; 带超时：万一 up 事件丢了（外部工具顶掉键盘钩子等），没有超时就会永久卡在这里，
    ; 预览面板会一直挂在屏幕上
    KeyWait, %PreviewPhysicalKey%, T60
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
    ; 绑定关系变了，"已占用"提示跟着变（放开一个键后它就不再被占用），
    ; 不刷新的话下方提示会一直停在上一次的内容上
    UpdateWindowMenuBindHint(g_WindowMenuTargetHwnd)
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

; 增量刷新：只改"已占用"提示那一行
UpdateWindowMenuBindHint(hwnd) {
    global g_WindowMenuOpen

    if (!g_WindowMenuOpen)
        return
    bindChoices := BuildBindingChoices(hwnd, occupiedKeys)
    GuiControl, WindowMenu:, WindowMenuBindHint, % occupiedKeys != "" ? "已占用 " . occupiedKeys : ""
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
    ; 置顶以窗口真实状态为准（用户可能在这期间按过 Alt+T），不能只信 state
    state.alwaysOnTop := IsWindowTopmost(hwnd)
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

; silent：被 BindWindowToKey 调用时不要弹"已解除绑定"——
; 那条 OSD 会立刻被后面的"已绑定到…"顶掉，屏幕上只剩一次闪烁
UnbindWindow(hwnd, silent := false) {
    global KeyList, WindowBindings, WindowIsOverlaid

    for index, key in KeyList {
        if (WindowBindings[key] = hwnd) {
            WindowBindings[key] := ""
            WindowIsOverlaid[key] := false
        }
    }
    if (!silent)
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
    UnbindWindow(hwnd, true)
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
        WindowStateByHwnd[hwnd] := {opacity: 255, alwaysOnTop: false, camouflageEnabled: false, camouflageHidden: false, triggerWidth: 240, triggerHeight: 135, triggerX: 0, triggerY: 0, hideAt: 0, editX: 0, editY: 0, editWidth: 0, editHeight: 0, aspectRatio: 0, aspectRatioLocked: true, resizeBaseWidth: 0, resizeBaseHeight: 0, preserveSize: false, preserveWidth: 0, preserveHeight: 0, preserveLastX: 0, preserveLastY: 0, preserveHasPosition: false, preservePending: false, dragMode: "", dragStartX: 0, dragStartY: 0, dragStartLeft: 0, dragStartTop: 0, dragStartWidth: 0, dragStartHeight: 0, revealTick: 0, hideTick: 0, appliedX: -99999, appliedY: -99999, appliedWidth: 0, appliedHeight: 0, regionClickThrough: -1, regionVisible: -1, pinned: false}
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

; 把窗口钉在控制条里刚调好的尺寸上。
;
; 这套机制的适用范围必须严格限定，否则会变成"这个窗口再也改不了大小"：
;   · 只在控制条正对着这个窗口开着的时候生效 —— 那才是"我正在调它的尺寸"的时段。
;     控制条一关，DestroyWindowMenu 就会把 preserveSize 清掉，窗口重新自由。
;   · 最小化和最大化都直接跳过：WinGetPos 对最小化窗口返回 -32000 与垃圾尺寸，
;     而最大化/全屏本来就是"尺寸被外部改变"的正常情况，拉回去会把 F11 全屏顶掉。
PreserveTargetWindowSize(hwnd) {
    global g_WindowMenuOpen, g_WindowMenuTargetHwnd

    state := EnsureWindowState(hwnd)
    if (!state.preserveSize || !WinExist("ahk_id " . hwnd) || state.camouflageHidden)
        return
    if (!g_WindowMenuOpen || g_WindowMenuTargetHwnd != hwnd)
        return

    WinGet, minMax, MinMax, ahk_id %hwnd%
    if (minMax != 0)
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
    ; 换大尺寸预设时区域可能伸出屏幕（比如原位置贴右下角），同样要收回来
    newX := state.editX, newY := state.editY
    ClampCamouflageRegion(newX, newY, width, height)
    state.editX := state.triggerX := newX
    state.editY := state.triggerY := newY
    if (WinExist("ahk_id " . hwnd))
        UpdateCamouflageTrigger(hwnd)
    ShowOSD("迷彩区域: " . width . " × " . height)
}

SetWindowOpacity(hwnd, opacity) {
    global WindowStateByHwnd

    state := EnsureWindowState(hwnd)
    state.opacity := opacity
    ; 同 RevealCamouflageWindow：滑到 100% 就把层摘掉，而不是留一个"透明度 255"的 layered 窗口
    if (opacity >= 255)
        WinSet, Transparent, Off, ahk_id %hwnd%
    else
        WinSet, Transparent, %opacity%, ahk_id %hwnd%
}

; 置顶的唯一写入口：先写 state 再落到窗口，这样 state 始终是"用户意图"的权威记录。
; 所有直接 WinSet, AlwaysOnTop 的地方都应改走这里，否则 state 会和实际脱节
; （控制条勾选态、呼出后是否恢复置顶都依赖它）。
SetWindowTopmost(hwnd, enabled) {
    global WindowStateByHwnd

    state := EnsureWindowState(hwnd)
    state.alwaysOnTop := enabled
    setting := enabled ? "On" : "Off"
    WinSet, AlwaysOnTop, %setting%, ahk_id %hwnd%
}

; 读窗口真实的置顶状态。
; 不能拿 state.alwaysOnTop 当"现状"用：用户可能刚用 Alt+T 改过、
; 或窗口被别的程序改过，只有 ExStyle 说的是实话。
IsWindowTopmost(hwnd) {
    if (!WinExist("ahk_id " . hwnd))
        return false
    WinGet, exStyle, ExStyle, ahk_id %hwnd%
    return (exStyle & 0x8) ? true : false
}

; 把 state 里记的置顶状态同步成窗口的真实状态（开控制条时调用，让复选框说实话）
SyncWindowTopmostState(hwnd) {
    state := EnsureWindowState(hwnd)
    state.alwaysOnTop := IsWindowTopmost(hwnd)
    return state.alwaysOnTop
}

SetCamouflage(hwnd, enabled) {
    global WindowStateByHwnd, g_CamouflageEditKey

    if (!WinExist("ahk_id " . hwnd))
        return
    state := EnsureWindowState(hwnd)
    if (!enabled) {
        ; 取消勾选时若窗口正处于隐藏（最小化）态，必须先把它捞回来再销毁区域：
        ; 区域一没，唯一的呼出入口也没了，窗口会以最小化状态被永久遗忘在任务栏里。
        if (state.camouflageHidden)
            RevealCamouflageWindow(hwnd, false)
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
    CreateCamouflageRegion(hwnd)
    HideCamouflageWindow(hwnd)
    DestroyWindowMenu()
    ShowOSD("迷彩区域已启用，按住 " . g_CamouflageEditKey . " 可编辑")
}

HideCamouflageWindow(hwnd) {
    global WindowStateByHwnd
    state := EnsureWindowState(hwnd)
    ; 不记录"原始位置/尺寸"：WinMinimize + WinRestore 由系统还原到收起前的几何，
    ; 这里再存一份只会在窗口被外部移动后变成过期数据（此前那几个 original* 字段从没被读过）
    WinMinimize, ahk_id %hwnd%
    state.camouflageHidden := true
    state.hideAt := 0
    state.pinned := false
    ; 记一个时间戳：隐藏/呼出都是异步生效的，SyncCamouflageHiddenState 靠它区分
    ; "窗口真的被用户动了" 和 "我们自己刚下的命令还没落地"
    state.hideTick := A_TickCount
}

CreateCamouflageRegion(hwnd) {
    global WindowStateByHwnd, g_CamouflageGuiNames, g_CamouflageGuiHwnds
    state := EnsureWindowState(hwnd)
    guiName := "Camouflage" . hwnd
    g_CamouflageGuiNames[hwnd] := guiName
    Gui, %guiName%:Destroy
    ; -DPIScale：触发区的坐标全程来自 WinGetPos / GetCursorPos，都是物理像素。
    ;   实测（本机 A_ScreenDPI=120，即 125%）Gui,Show 只缩放 w/h 而不缩放 x/y：
    ;   请求 240×135 实际会建出 300×169 的窗口，靠 WinSet,Region 的物理 240×135 裁回去才看不出来。
    ;   于是编辑态摘掉点击穿透后，右/下各有 60/34px 的隐形区域照样吃点击。
    ; +E0x08000000（WS_EX_NOACTIVATE）：编辑态会临时摘掉点击穿透，
    ;   没有这一位的话点中区域会把焦点从当前应用抢走。
    Gui, %guiName%:+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000 -DPIScale +HwndregionHwnd
    Gui, %guiName%:Color, 4FC3F7
    regionOptions := "NoActivate x" . state.triggerX . " y" . state.triggerY . " w" . state.triggerWidth . " h" . state.triggerHeight
    Gui, %guiName%:Show, %regionOptions%
    g_CamouflageGuiHwnds[hwnd] := regionHwnd
    WinSet, Transparent, 13, ahk_id %regionHwnd%
    regionSpec := "0-0 w" . state.triggerWidth . " h" . state.triggerHeight . " R8-8"
    WinSet, Region, %regionSpec%, ahk_id %regionHwnd%
    ; 记下刚刚落地的几何与样式，作为脏检查的基线
    state.appliedX := state.triggerX, state.appliedY := state.triggerY
    state.appliedWidth := state.triggerWidth, state.appliedHeight := state.triggerHeight
    state.regionClickThrough := 1
    state.regionVisible := 1
}

DestroyCamouflageRegion(hwnd) {
    global g_CamouflageGuiNames, g_CamouflageGuiHwnds, WindowStateByHwnd
    guiName := g_CamouflageGuiNames[hwnd]
    if (guiName != "")
        Gui, %guiName%:Destroy
    g_CamouflageGuiNames.Delete(hwnd)
    g_CamouflageGuiHwnds.Delete(hwnd)
    ; 作废脏检查基线，否则下次重建区域时会被误判为"几何没变、不必下发"
    if (WindowStateByHwnd.HasKey(hwnd)) {
        state := WindowStateByHwnd[hwnd]
        state.appliedX := -99999, state.appliedY := -99999
        state.appliedWidth := 0, state.appliedHeight := 0
        state.regionClickThrough := -1
        state.regionVisible := -1
    }
}

UpdateCamouflageRegion(hwnd) {
    global WindowStateByHwnd, g_CamouflageGuiHwnds
    state := EnsureWindowState(hwnd)
    regionHwnd := g_CamouflageGuiHwnds[hwnd]
    if (!regionHwnd)
        return
    ; 藏起来的这段时间一律不下发几何：DetectHiddenWindows 默认 Off，
    ; WinMove / WinSet 根本找不到隐藏窗口，会静默失败——却照样把 applied* 基线刷成新值，
    ; 于是区域再露脸时脏检查认为"已经是新几何"，人却永远停在旧位置上。
    ; 什么都不做则 applied* 仍如实记录窗口的真实几何，重新显示时那次脏检查自然会补上。
    if (state.regionVisible = 0)
        return
    ; 脏检查：轮询每秒会把这里叫上 33 次。位置没变就不必 WinMove；
    ; 尺寸没变则绝不重设 Region——SetWindowRgn 是这条链路上最贵的一次调用，也是边缘闪烁的来源。
    moved := (state.appliedX != state.triggerX || state.appliedY != state.triggerY)
    resized := (state.appliedWidth != state.triggerWidth || state.appliedHeight != state.triggerHeight)
    if (!moved && !resized)
        return
    regionX := state.triggerX, regionY := state.triggerY
    regionWidth := state.triggerWidth, regionHeight := state.triggerHeight
    WinMove, ahk_id %regionHwnd%,, %regionX%, %regionY%, %regionWidth%, %regionHeight%
    if (resized) {
        regionSpec := "0-0 w" . regionWidth . " h" . regionHeight . " R8-8"
        WinSet, Region, %regionSpec%, ahk_id %regionHwnd%
    }
    state.appliedX := regionX, state.appliedY := regionY
    state.appliedWidth := regionWidth, state.appliedHeight := regionHeight
}

; 点击穿透（WS_EX_TRANSPARENT）只在状态翻转时写一次。
; 此前是每 tick 无条件 WinSet 一次 ExStyle，纯属白烧。
SetCamouflageRegionClickThrough(hwnd, state, enabled) {
    global g_CamouflageGuiHwnds
    if (state.regionClickThrough = enabled)
        return
    regionHwnd := g_CamouflageGuiHwnds[hwnd]
    if (!regionHwnd)
        return
    if (enabled)
        WinSet, ExStyle, +0x20, ahk_id %regionHwnd%
    else
        WinSet, ExStyle, -0x20, ahk_id %regionHwnd%
    state.regionClickThrough := enabled
}

; 触发区只在窗口收起时才该露脸。窗口呼出后区域仍浮在最上层的话，
; 它那块半透明蓝色会直接糊在画面上——窗口自身透明度调低时尤其明显。
; 同样做状态缓存，避免每 tick 白烧一次 ShowWindow。
SetCamouflageRegionVisible(hwnd, state, visible) {
    global g_CamouflageGuiHwnds
    if (state.regionVisible = visible)
        return
    regionHwnd := g_CamouflageGuiHwnds[hwnd]
    if (!regionHwnd)
        return
    ; SW_SHOWNOACTIVATE(4) / SW_HIDE(0)：Gui,Show 会抢激活，这里必须用 ShowWindow
    DllCall("ShowWindow", "Ptr", regionHwnd, "Int", visible ? 4 : 0)
    state.regionVisible := visible
    ; 先记状态再补几何：UpdateCamouflageRegion 在隐藏期是空转的，
    ; 藏着时被改过的尺寸（控制条换预设）要靠这一次补发才能按新几何露出来。
    if (visible)
        UpdateCamouflageRegion(hwnd)
}

; 控制条开着时该窗口正在被调参——三档尺寸预设需要看得见区域才有反馈，
; 所以这段时间即使窗口是亮着的也不藏。
; 独立成函数只是为了让调用点读起来是"这件事成不成立"，
; 而不是在 CheckCamouflageWindows 里再塞两个全局进去（global 声明与位置无关，
; 在同一个函数里再声明一次并不算错，只是没必要）。
IsCamouflageRegionTweaking(hwnd) {
    global g_WindowMenuOpen, g_WindowMenuTargetHwnd
    return (g_WindowMenuOpen && g_WindowMenuTargetHwnd = hwnd)
}

; 把 camouflageHidden 拨回窗口的真实最小化状态。
; 用户自己点最小化按钮、或从任务栏把窗口捞回来时，标志会和现实脱节：
; 标志说"显示中"而窗口其实已最小化时，呼出分支进不去、隐藏分支又不超时，这个触发区就彻底失灵。
; 200ms 宽限期留给 WinMinimize / WinRestore 的动画，免得和我们自己刚下的命令抢状态。
SyncCamouflageHiddenState(hwnd, state) {
    WinGet, minMax, MinMax, ahk_id %hwnd%
    if (minMax = -1) {
        if (!state.camouflageHidden && A_TickCount - state.revealTick > 200) {
            state.camouflageHidden := true
            state.hideAt := 0
        }
    } else if (state.camouflageHidden && A_TickCount - state.hideTick > 200) {
        state.camouflageHidden := false
    }
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

; 把迷彩触发区钳制在虚拟屏幕范围内。
;
; 触发区是窗口的呼出入口：没有绑定快捷键的窗口，鼠标进入触发区是把它叫回来的唯一手段。
; 一旦被拖到屏幕外（或换成大尺寸预设后伸出屏幕），就再也点不到它了。
; 多显示器用虚拟屏幕的并集包围盒，不追求逐屏判断——只要保证整块矩形落在"看得见"的范围内。
ClampCamouflageRegion(ByRef x, ByRef y, width, height) {
    SysGet, vsLeft, 76
    SysGet, vsTop, 77
    SysGet, vsWidth, 78
    SysGet, vsHeight, 79
    if (vsWidth < 1 || vsHeight < 1)
        return
    ; +0：把空值/非数值先归一成 0。Min/Max 遇到非数值会一路把空串传出去，
    ; 那样 WinMove 会收到一个空坐标（AHK 视作"不改这一维"），区域就静默不动了
    x := Max(vsLeft, Min(x + 0, vsLeft + vsWidth - width))
    y := Max(vsTop, Min(y + 0, vsTop + vsHeight - height))
}

EditCamouflageRegions() {
    global WindowStateByHwnd, g_CamouflageDragOwner
    GetCursorScreenPos(mouseX, mouseY)
    for hwnd, state in WindowStateByHwnd {
        if (!state.camouflageEnabled)
            continue
        if (!state.dragMode)
            continue
        ; 只让按下时认定的那一个区域跟手：区域重叠时，遍历到的每个 state 都满足
        ; "鼠标在触发区内"，不设owner 就会两个区域一起被拖走
        if (g_CamouflageDragOwner && g_CamouflageDragOwner != hwnd)
            continue
        dx := mouseX - state.dragStartX, dy := mouseY - state.dragStartY
        if (state.dragMode = "move") {
            newLeft := state.dragStartLeft + dx
            newTop := state.dragStartTop + dy
            ClampCamouflageRegion(newLeft, newTop, state.triggerWidth, state.triggerHeight)
            state.editX := state.triggerX := newLeft
            state.editY := state.triggerY := newTop
        } else {
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
            ClampCamouflageRegion(newLeft, newTop, newWidth, newHeight)
            state.editX := state.triggerX := newLeft
            state.editY := state.triggerY := newTop
            state.editWidth := state.triggerWidth := newWidth
            state.editHeight := state.triggerHeight := newHeight
        }
        UpdateCamouflageRegion(hwnd)
    }
}

ReleaseCamouflageRegions() {
    global WindowStateByHwnd, g_CamouflageDragOwner
    for hwnd, state in WindowStateByHwnd
        state.dragMode := ""
    g_CamouflageDragOwner := 0
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
    ; 全不透明时用 Off 彻底摘掉 WS_EX_LAYERED：留着层会让 Chromium 系窗口掉帧
    if (opacity >= 255)
        WinSet, Transparent, Off, ahk_id %hwnd%
    else
        WinSet, Transparent, %opacity%, ahk_id %hwnd%
    ; 置顶不在这里补：最小化/还原不会丢 WS_EX_TOPMOST，系统自己会保持。
    ; 按 state 补反而有害——state 一旦过期，就会把用户已经取消的置顶又钉回去。
    state.camouflageHidden := false
    state.hideAt := 0
    state.revealTick := A_TickCount
    ; 每次呼出都从"未钉住"开始：是否留下由用户接下来有没有真交互决定
    state.pinned := false
    if (state.preserveSize)
        state.preservePending := true
    if (activate)
        WinActivate, ahk_id %hwnd%
}

CheckCamouflageWindows() {
    global WindowStateByHwnd, g_CamouflageGuiHwnds, g_RadialPreviewHwnd
    global g_CamouflageDragOwner, g_CamouflageWindowPad

    GetCursorScreenPos(mouseX, mouseY)
    foregroundHwnd := DllCall("GetForegroundWindow", "Ptr")
    ; 遍历中不能直接删键：先收集，循环结束后统一清理
    staleHwnds := []
    for hwnd, state in WindowStateByHwnd {
        if (!WinExist("ahk_id " . hwnd)) {
            staleHwnds.Push(hwnd)
            continue
        }
        if (hwnd = g_RadialPreviewHwnd) {
            state.hideAt := 0
            ; 轮盘预览会绕过 RevealCamouflageWindow 直接把窗口 WinRestore 出来，
            ; 这条分支又提前 continue、走不到下面的可见性判定：不在这里单独收一次，
            ; 预览画面上就会留着那块蓝斑。（未启用迷彩的窗口没有区域，此调用自然空转）
            SetCamouflageRegionVisible(hwnd, state, false)
            continue
        }
        PreserveTargetWindowSize(hwnd)
        ; 没启用迷彩的窗口（只是开过控制条）到此为止：
        ; 它的 triggerX/Y 还是 0，再往下算命中测试纯属浪费
        if (!state.camouflageEnabled) {
            state.hideAt := 0
            continue
        }
        SyncCamouflageHiddenState(hwnd, state)
        insideTrigger := mouseX >= state.triggerX && mouseX <= state.triggerX + state.triggerWidth && mouseY >= state.triggerY && mouseY <= state.triggerY + state.triggerHeight
        if (!state.camouflageHidden)
            UpdateCamouflageTrigger(hwnd)
        if (IsCamouflageEditKeyDown()) {
            ; 编辑态例外：窗口开着也得看得见区域才好挪，否则只能凭记忆拖一块隐形矩形。
            ; 顺序不能反——WinSet,ExStyle 同样找不到隐藏窗口，得先让它露出来再摘点击穿透。
            SetCamouflageRegionVisible(hwnd, state, true)
            SetCamouflageRegionClickThrough(hwnd, state, false)
            ; 归属标记决定这一轮拖动由谁负责：先按下的那个区域独占，别的一律不跟手
            if (!g_CamouflageDragOwner && !state.dragMode && GetKeyState("LButton", "P") && insideTrigger) {
                g_CamouflageDragOwner := hwnd
                CamouflageRegionMouseDown(hwnd, mouseX, mouseY)
            }
            continue
        }
        ; 同理：先在还看得见的时候把点击穿透补回去，再决定要不要藏
        SetCamouflageRegionClickThrough(hwnd, state, true)
        ; 窗口已呼出时藏起触发区：留着它会在画面上盖一层蓝斑
        SetCamouflageRegionVisible(hwnd, state, state.camouflageHidden || IsCamouflageRegionTweaking(hwnd))
        if (state.camouflageHidden && insideTrigger) {
            RevealCamouflageWindow(hwnd, true)
        } else if (!state.camouflageHidden) {
            WinGetPos, wx, wy, ww, wh, ahk_id %hwnd%
            insideWindow := mouseX >= wx - g_CamouflageWindowPad && mouseX <= wx + ww + g_CamouflageWindowPad && mouseY >= wy - g_CamouflageWindowPad && mouseY <= wy + wh + g_CamouflageWindowPad
            insideMenu := IsWindowMenuHoverArea(hwnd, mouseX, mouseY)
            hasFocus := (foregroundHwnd = hwnd)
            ; 呼出时我们会顺手 WinActivate，所以"是前台"并不等于"用户在用它"：
            ; 若前台就无条件保活，悬停扫一眼的窗口移开鼠标后会永远赖在屏幕上。
            ; 只有真正交互过才钉住——在窗口里点过，或正往里打字。
            ; （A_TimeIdleKeyboard 是纯键盘空闲、不被鼠标移动污染，前提是键盘钩子已装；
            ;   本脚本的 $ 前缀热键强制装了钩子，见文件顶部 Hotkey 注册段。）
            if (hasFocus && ((insideWindow && GetKeyState("LButton", "P")) || A_TimeIdleKeyboard < 1000))
                state.pinned := true
            ; 钉住之后按"失去焦点 + 鼠标离开"才隐藏——手离开鼠标、把光标甩到别的屏都不该让窗口溜走
            keepAlive := insideTrigger || insideWindow || insideMenu || (state.pinned && hasFocus)
            if (!keepAlive) {
                if (!state.hideAt)
                    state.hideAt := A_TickCount + g_CamouflageHideDelay
                else if (A_TickCount >= state.hideAt)
                    HideCamouflageWindow(hwnd)
            } else {
                state.hideAt := 0
            }
        }
    }
    ; 目标窗口已关闭：区域 GUI 必须跟着销毁。只删 state 的话，屏幕上会留下一块
    ; 谁都点不动、也再没人负责回收的半透明矩形（认领它的那条 state 已经没了）
    for index, staleHwnd in staleHwnds {
        DestroyCamouflageRegion(staleHwnd)
        WindowStateByHwnd.Delete(staleHwnd)
    }
    global g_WindowMenuOpen, g_WindowMenuTargetHwnd, g_WindowMenuHideAt, g_WindowMenuHideDelay
    if (g_WindowMenuOpen && g_WindowMenuTargetHwnd) {
        menuTarget := g_WindowMenuTargetHwnd
        if (!WinExist("ahk_id " . menuTarget)) {
            ; 目标窗口没了就没什么可控的了，不必等宽限期
            DestroyWindowMenu()
        } else {
            WinGetPos, targetX, targetY, targetW, targetH, ahk_id %menuTarget%
            overTarget := mouseX >= targetX && mouseX <= targetX + targetW && mouseY >= targetY && mouseY <= targetY + targetH
            ; 目标窗口被拖走后整条要跟上，否则它会留在原地、连过道都对不上
            FollowWindowMenuTarget(mouseX, mouseY)
            if (overTarget || IsWindowMenuHoverArea(menuTarget, mouseX, mouseY)) {
                g_WindowMenuHideAt := 0
            } else if (!g_WindowMenuHideAt) {
                ; 过道之外还会有别的空档：整条比窗口窄时窗口顶边两侧、被钳制到别处时的斜向路径，
                ; 以及 30ms 轮询本身会漏采样的快速移动。先记截止时间，别在第一帧就收掉。
                g_WindowMenuHideAt := A_TickCount + g_WindowMenuHideDelay
            } else if (A_TickCount >= g_WindowMenuHideAt) {
                DestroyWindowMenu()
            }
        }
    }
}

; 鼠标是否停在"控制条本体，或窗口通往控制条的那条过道"上。
;
; 为什么要有过道：ShowWindowMenu 故意让整条和目标窗口之间留 g_WindowMenuGap 的缝隙。
; 这条缝隙不属于任何一个矩形，只测两个矩形的话，鼠标从窗口移向整条的途中必然有几帧
; 落在缝隙上，于是被判成"离开窗口"，整条（连带迷彩窗口）在半路就被收掉。
;
; 过道的竖直范围由两个矩形的实际位置算出，而不是照抄 g_WindowMenuGap——
; 整条被工作区钳制（见 ShowWindowMenu 末尾的 Max/Min）之后真实间距未必还是 8。
; 横向放宽到两者的并集包围盒：过道只有缝隙那么高（常态 8px），横向放宽不会让整条误留，
; 而整条比窗口宽时（704 逻辑像素，125% 下 880），斜着走进两侧凸出部分只能靠它接住。
;
; 纯几何、不碰全局，因此这份源码在 AHK v1 / v2 下都能直接跑，便于单独验证。
IsPointInMenuHoverArea(px, py, tx, ty, tw, th, mx, my, mw, mh, pad) {
    if (px >= mx - pad && px <= mx + mw + pad && py >= my - pad && py <= my + mh + pad)
        return true
    if (px < Min(tx, mx) - pad || px > Max(tx + tw, mx + mw) + pad)
        return false
    ; 两个矩形竖直方向有重叠时 corridorTop > corridorBottom，这个区间自然为空
    corridorTop := Min(ty + th, my + mh)
    corridorBottom := Max(ty, my)
    return py >= corridorTop && py <= corridorBottom
}

IsWindowMenuHoverArea(hwnd, mouseX, mouseY) {
    global g_WindowMenuOpen, g_WindowMenuTargetHwnd, g_WindowMenuHwnd, g_WindowMenuHoverPad
    if (!g_WindowMenuOpen || g_WindowMenuTargetHwnd != hwnd || !g_WindowMenuHwnd)
        return false
    if (!WinExist("ahk_id " . hwnd))
        return false
    WinGetPos, targetX, targetY, targetW, targetH, ahk_id %hwnd%
    WinGetPos, menuX, menuY, menuWidth, menuHeight, ahk_id %g_WindowMenuHwnd%
    return IsPointInMenuHoverArea(mouseX, mouseY, targetX, targetY, targetW, targetH, menuX, menuY, menuWidth, menuHeight, g_WindowMenuHoverPad)
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
;   1. 交互控件（滑块、按钮、下拉框、复选框）顶边只允许取 y28 或 y60，行高统一 26，
;      否则同一行会出现视觉错位。例外只有两处，都写在明面上：
;        · 「锁定比例」和右上角「×」在标题行 y6（它们属于标题行，不是控件行）；
;        · 下拉框用 y30 —— 它的高度由字体决定，h 选项无效，只能靠 y 让它视觉居中。
;   2. 列的左边界只允许取 x14 / x216 / x358 / x482；分隔线固定在 x206 / x348 / x472
;      （即相邻两列边界的正中）。挪动列宽时必须同步挪分隔线。
;   3. 字体分三级依次落笔：标题 s8 暗 → 控件 s9 白 → 次要读数 s8 更暗。
;      AHK v1 的 Gui,Font 是"当前状态"，后续 Add 全部继承，所以顺序不能打乱。
;      次要读数（"100%""1920 px""240 × 135"）贴着控件底边取 y33 / y64，不属于上面第 1 条。
;
; 整条与目标窗口之间的缝隙统一走 g_WindowMenuGap，不要在这里写字面量：
; 缝隙同时被鼠标保活的命中测试消费（过道，见 IsPointInMenuHoverArea），
; 两边各写一个数字的话，缝隙一变宽就又会出现"移向整条的半路整条自己消失"。
;
; 注：布局坐标是逻辑像素。AHK v1 的 Gui,Show 只把 w/h 按系统 DPI 缩放，**不**缩放 x/y
;     （实测 125%：请求 x1000 y500 w704 h100，实际得到 1000,500 880×125）。
;     所以 w/h 继续给逻辑值交给 AHK 缩放，而一切定位数学（居中、翻转、工作区钳制）
;     必须用 menuPhysicalWidth/Height 这对物理尺寸来算——它们和 WinGetPos/SysGet 同一坐标系。
; -------------------------------------------------------

; 算整条该落在哪：默认贴目标窗口正上方居中，顶部空间不够就翻到下方，
; 最后整体收进目标窗口所在显示器的工作区，避免被屏幕边缘截断。
;
; 抽成函数是因为它有两个调用点：新建整条时的初始定位，以及目标窗口移动后的跟随。
; 跟随绝不能靠重建整条来做——重建会重新采样 resizeBaseWidth/Height，
; 把已经缩放过的窗口的当前尺寸当成新的 100% 基准，滑块就会跳回 100。
ComputeWindowMenuPos(hwnd, ByRef menuX, ByRef menuY, ByRef menuPhysicalWidth, ByRef menuPhysicalHeight) {
    global g_WindowMenuWidth, g_WindowMenuHeight, g_WindowMenuGap

    menuPhysicalWidth := Round(g_WindowMenuWidth * A_ScreenDPI / 96)
    menuPhysicalHeight := Round(g_WindowMenuHeight * A_ScreenDPI / 96)

    WinGetPos, x, y, width, height, ahk_id %hwnd%
    SysGet, targetMonitor, Monitor, ahk_id %hwnd%
    SysGet, workArea, MonitorWorkArea, %targetMonitor%

    menuX := x + Round((width - menuPhysicalWidth) / 2)
    menuY := y - menuPhysicalHeight - g_WindowMenuGap
    if (menuY < workAreaTop)
        menuY := y + height + g_WindowMenuGap
    menuX := Max(workAreaLeft, Min(menuX, workAreaRight - menuPhysicalWidth))
    menuY := Max(workAreaTop, Min(menuY, workAreaBottom - menuPhysicalHeight))
}

; 目标窗口被移动/缩放后让整条跟上，而不是把整条留在原地。
; 只在窗口左上角真的变了才动，且鼠标正停在整条上时不动 —— 那多半是在拖滑块。
FollowWindowMenuTarget(mouseX, mouseY) {
    global g_WindowMenuOpen, g_WindowMenuTargetHwnd, g_WindowMenuHwnd
    global g_WindowMenuTargetX, g_WindowMenuTargetY, g_WindowMenuHoverPad

    if (!g_WindowMenuOpen || !g_WindowMenuTargetHwnd || !g_WindowMenuHwnd)
        return
    if (!WinExist("ahk_id " . g_WindowMenuTargetHwnd) || !WinExist("ahk_id " . g_WindowMenuHwnd))
        return

    WinGetPos, x, y,,, ahk_id %g_WindowMenuTargetHwnd%
    if (x = g_WindowMenuTargetX && y = g_WindowMenuTargetY)
        return
    g_WindowMenuTargetX := x, g_WindowMenuTargetY := y

    WinGetPos, menuX, menuY, menuWidth, menuHeight, ahk_id %g_WindowMenuHwnd%
    if (mouseX >= menuX - g_WindowMenuHoverPad && mouseX <= menuX + menuWidth + g_WindowMenuHoverPad
        && mouseY >= menuY - g_WindowMenuHoverPad && mouseY <= menuY + menuHeight + g_WindowMenuHoverPad)
        return

    newX := 0, newY := 0, physicalWidth := 0, physicalHeight := 0
    ComputeWindowMenuPos(g_WindowMenuTargetHwnd, newX, newY, physicalWidth, physicalHeight)
    WinMove, ahk_id %g_WindowMenuHwnd%,, %newX%, %newY%
}

ShowWindowMenu(hwnd) {
    global g_WindowMenuOpen, g_WindowMenuHwnd, g_WindowMenuTargetX, g_WindowMenuTargetY, UI_WindowOpacity, UI_WindowMenuBind, UI_WindowWidthScale, UI_WindowHeightScale, UI_WindowAspectLocked, UI_WindowTopmost, UI_WindowCamouflage, WindowOpacityValue, WindowMenuWidthValue, WindowMenuHeightValue, WindowMenuTriggerValue, WindowMenuBindHint

    DestroyWindowMenu()
    state := EnsureWindowState(hwnd)
    ; 新开的控制条从"没有尺寸锁"开始：尺寸锁只在用户真的拖了宽高滑块之后才建立。
    ; 不重置的话，上一次遗留的 preserveWidth/Height 会在开条瞬间把窗口拽回旧尺寸。
    state.preserveSize := false
    state.preservePending := false
    ; 复选框要显示窗口的真实状态，不能拿 state 当现状：
    ; 用户可能刚用 Alt+T 置顶过，那时 state.alwaysOnTop 还没被更新
    SyncWindowTopmostState(hwnd)
    WinGetPos, x, y, width, height, ahk_id %hwnd%
    ; 以当前尺寸作为宽高滑块 100% 的基准。只在整条新建时采样一次：
    ; 状态变更若走重建，这里会被反复重新采样，导致已缩放的窗口把当前尺寸误当成新基准。
    state.resizeBaseWidth := width
    state.resizeBaseHeight := height
    if (state.aspectRatioLocked)
        state.aspectRatio := width / height
    opacityPercent := Round(state.opacity / 2.55)
    ; ByRef 的输出变量先给出初值再传：AHK v1 里传一个尚未存在的变量时，
    ; 函数内的赋值不保证回写（实测过"传进去、读出来还是空"），显式初始化最稳
    menuX := 0, menuY := 0, menuPhysicalWidth := 0, menuPhysicalHeight := 0
    ComputeWindowMenuPos(hwnd, menuX, menuY, menuPhysicalWidth, menuPhysicalHeight)
    g_WindowMenuTargetX := x, g_WindowMenuTargetY := y
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

    Gui, WindowMenu:Show, NoActivate x%menuX% y%menuY% w%g_WindowMenuWidth% h%g_WindowMenuHeight%
    WinSet, Transparent, 235, ahk_id %WindowMenuHwnd%
    g_WindowMenuOpen := true
}

DestroyWindowMenu() {
    global g_WindowMenuOpen, g_WindowMenuHwnd, g_WindowMenuHideAt, g_WindowMenuTargetHwnd
    global WindowStateByHwnd

    Gui, WindowMenu:Destroy
    g_WindowMenuOpen := false
    g_WindowMenuHwnd := 0
    ; 清掉待收计时，否则下次呼出会继承上一次的截止时间，刚弹出就被收掉
    g_WindowMenuHideAt := 0
    ; 关掉控制条就解除"尺寸保持"：那套机制只服务于"正在调参"的这段时间，
    ; 留着它会让窗口此后永远无法被手动缩放、也进不了全屏（见 PreserveTargetWindowSize）
    if (g_WindowMenuTargetHwnd && WindowStateByHwnd.HasKey(g_WindowMenuTargetHwnd)) {
        WindowStateByHwnd[g_WindowMenuTargetHwnd].preserveSize := false
        WindowStateByHwnd[g_WindowMenuTargetHwnd].preservePending := false
    }
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
    global g_RadialItems

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
    g_RadialSelected := 0
    g_RadialOpen := true
    ShowRadialMenu()
    SetTimer, RadialSelectionTimer, 16
    radialPhysicalKey := RegExReplace(A_ThisHotkey, "^[\^\!\+\#\<\>\*\$~]+", "")
    ; 超时只是保险：万一 up 事件丢了，菜单不该永远挂在屏幕上（g_RadialOpen 会一直为真）
    KeyWait, %radialPhysicalKey%, T60
    SetTimer, RadialSelectionTimer, Off
    if (!g_RadialSelected)
        UpdateRadialPreview(0)
    DestroyRadialMenu()
    g_RadialOpen := false

    if (g_RadialSelected) {
        ; 预览为了浮在轮盘之上，把窗口临时推成了 TOPMOST（SetWindowPos 会真的设置 WS_EX_TOPMOST）。
        ; 提交时要按预览前记下的真实状态收尾：本来不是置顶的才摘掉，
        ; 本来就是用户钉住的就保持不动 —— 否则从轮盘切过去会把置顶弄丢。
        commitWasTopmost := g_RadialPreviewWasTopmost
        CommitRadialPreview()
        ActivateRadialWindow(g_RadialItems[g_RadialSelected].key, commitWasTopmost)
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
    global g_RadialInnerRadius, g_RadialHubDiameter, g_RadialHubPhysicalDiameter, g_RadialGapDegrees, g_RadialMenuPadding
    global g_RadialNormalColor, g_RadialHwnd, g_RadialSectorHwnds
    global g_RadialSectorLabelHwnds, g_RadialSectorIconHwnds
    global g_RadialAppControlHwnd, g_RadialCenterControlHwnd, g_RadialIconControlHwnd
    global RadialAppControlHwnd, RadialCenterControlHwnd, RadialIconControlHwnd
    global g_RadialHighlighted, g_RadialLabelMode
    global g_RadialLabelWinHwnds, g_RadialBandIconHwnds, g_RadialBandBadgeHwnds

    DestroyRadialMenu()
    g_RadialSectorHwnds := []
    g_RadialSectorLabelHwnds := []
    g_RadialSectorIconHwnds := []
    g_RadialLabelGuiNames := []
    g_RadialLabelWinHwnds := []
    g_RadialBandIconHwnds := []
    g_RadialBandBadgeHwnds := []
    ; 扇区全部以普通色新建，所以此刻没有任何扇区处于高亮态
    g_RadialHighlighted := 0
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

    ; ---- 中心舱：圆形，物理直径不超过内径的 88%（保证不压到环带）----
    ; 定位按物理尺寸算：AHK 只把 w/h 按 DPI 放大，x/y 原样传下去
    hubPhysicalSize := g_RadialHubPhysicalDiameter
    centerX := g_RadialCenterX - Floor(hubPhysicalSize / 2)
    centerY := g_RadialCenterY - Floor(hubPhysicalSize / 2)
    Gui, RadialCenter:Destroy
    Gui, RadialCenter:+AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20
    g_RadialHwnd := WinExist()
    ; 圆舱内的排版按逻辑坐标设计（AHK 会把控件一起缩放，所以整体等比）：
    ; 直径 g_RadialHubDiameter 的圆，圆心在正中；下面每个控件的 y 都留了圆形的收边余量，
    ; 越靠下可用宽度越窄，所以标题止步于 y126+44 处
    hubTextX := Round(g_RadialHubDiameter * 0.07)
    hubTextWidth := g_RadialHubDiameter - hubTextX * 2
    hubIconSize := Round(g_RadialHubDiameter * 0.115)
    hubIconX := Round(g_RadialHubDiameter / 2 - hubIconSize / 2)
    hubIconY := Round(g_RadialHubDiameter * 0.22)
    hubAppY := Round(g_RadialHubDiameter * 0.36)
    hubTitleY := Round(g_RadialHubDiameter * 0.45)
    hubTitleHeight := Round(g_RadialHubDiameter * 0.16)
    Gui, RadialCenter:Color, %g_RadialCenterColor%
    Gui, RadialCenter:Add, Picture, x%hubIconX% y%hubIconY% w%hubIconSize% h%hubIconSize% hwndRadialIconControlHwnd
    Gui, RadialCenter:Font, s11 cFFFFFF w700, Microsoft YaHei
    Gui, RadialCenter:Add, Text, x%hubTextX% y%hubAppY% w%hubTextWidth% Center +0x200 hwndRadialAppControlHwnd, 移动鼠标选择窗口
    Gui, RadialCenter:Font, s9 cD8DEE9, Microsoft YaHei
    Gui, RadialCenter:Add, Text, x%hubTextX% y%hubTitleY% w%hubTextWidth% h%hubTitleHeight% Center hwndRadialCenterControlHwnd,
    g_RadialIconControlHwnd := RadialIconControlHwnd
    g_RadialAppControlHwnd := RadialAppControlHwnd
    g_RadialCenterControlHwnd := RadialCenterControlHwnd
    GuiControl, RadialCenter:Hide, %g_RadialIconControlHwnd%
    Gui, RadialCenter:Show, NoActivate x%centerX% y%centerY% w%g_RadialHubDiameter% h%g_RadialHubDiameter%
    ; E = 椭圆：中心舱是圆的，和环形轮盘才是一套视觉语言
    WinSet, Region, 0-0 w%hubPhysicalSize% h%hubPhysicalSize% E, ahk_id %g_RadialHwnd%
    WinSet, Transparent, 245, ahk_id %g_RadialHwnd%

    if (g_RadialLabelMode = "Never")
        return
    Loop, %itemCount% {
        sectorIndex := A_Index
        startAngle := -90 + (sectorIndex - 1) * angleStep + g_RadialGapDegrees / 2
        sweepAngle := angleStep - g_RadialGapDegrees
        CreateRadialLabel(sectorIndex, menuX, menuY, diameter, center, startAngle, sweepAngle)
    }
}

CreateRadialSector(index, menuX, menuY, diameter, center, startAngle, sweepAngle, color) {
    global g_RadialOuterRadius, g_RadialInnerRadius, g_RadialSectorHwnds
    global g_RadialItems, g_RadialStyle, g_RadialBandInner, g_RadialBandOuter
    global g_RadialBandMid, g_RadialBandThickness, g_RadialShowIcons, g_RadialShowBadges
    global g_RadialBandIconHwnds, g_RadialBandBadgeHwnds

    guiName := "RadialSector" . index
    Gui, %guiName%:Destroy
    ; -DPIScale 是必须的，理由和迷彩触发区一样、但这里更要紧：
    ;   Region 用的是物理像素（SetWindowRgn 不做 DPI 换算），而 AHK 默认会把控件的
    ;   坐标/尺寸按 DPI 放大。两者混在一起，125% 下扇区里的图标会被推到环带外面、再被
    ;   Region 裁掉。关掉缩放后窗口、Region、子控件全在同一坐标系（物理像素）里。
    ;   环带本身的视觉大小不变：Region 一直是物理的，原来那个 1.25 倍的窗口只是多余的外壳。
    Gui, %guiName%:+AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20 -DPIScale
    sectorHwnd := WinExist()
    Gui, %guiName%:Color, %color%
    Gui, %guiName%:Show, NoActivate x%menuX% y%menuY% w%diameter% h%diameter%

    if (g_RadialStyle = "Wedge")
        points := BuildAnnularSectorPoints(center, g_RadialOuterRadius, g_RadialInnerRadius, startAngle, sweepAngle)
    else
        points := BuildArcBandPoints(center, g_RadialBandInner, g_RadialBandOuter, startAngle, sweepAngle)
    SetPolygonWindowRegion(sectorHwnd, points)
    g_RadialSectorHwnds.Push(sectorHwnd)
    WinSet, Transparent, 225, ahk_id %sectorHwnd%

    ; 扇区内的图标与键位角标。
    ; 控件必须落在环带内：子控件同样受父窗口 Region 裁剪（当年把标签挪到环外就是这个原因），
    ; 所以尺寸和半径都按环带厚度算，改 BandInnerRatio/BandOuterRatio 也不会被裁掉。
    item := g_RadialItems[index]
    midAngle := (startAngle + sweepAngle / 2) * 0.017453292519943
    iconHwnd := 0, badgeHwnd := 0
    if (g_RadialShowIcons) {
        iconSize := Min(22, Max(12, Round(g_RadialBandThickness * 0.38)))
        iconRadius := g_RadialBandMid + Round(g_RadialBandThickness * 0.19)
        iconX := Round(center + Cos(midAngle) * iconRadius - iconSize / 2)
        iconY := Round(center + Sin(midAngle) * iconRadius - iconSize / 2)
        Gui, %guiName%:Add, Picture, x%iconX% y%iconY% w%iconSize% h%iconSize% +BackgroundTrans hwndIconHwnd
        GuiControl, %guiName%:, %iconHwnd%, % "HICON:*" . GetWindowIcon(item.hwnd)
    }
    if (g_RadialShowBadges) {
        badgeHeight := Min(16, Max(10, Round(g_RadialBandThickness * 0.26)))
        badgeWidth := badgeHeight + 2
        badgeRadius := g_RadialBandMid - Round(g_RadialBandThickness * 0.26)
        badgeX := Round(center + Cos(midAngle) * badgeRadius - badgeWidth / 2)
        badgeY := Round(center + Sin(midAngle) * badgeRadius - badgeHeight / 2)
        Gui, %guiName%:Font, s8 cA8B8C8 w700, Microsoft YaHei
        ; +BackgroundTrans 是必须的：扇区高亮时会整窗换色（Gui, Color），
        ; 控件若不透明就会留下一块旧色补丁
        Gui, %guiName%:Add, Text, x%badgeX% y%badgeY% w%badgeWidth% h%badgeHeight% Center +BackgroundTrans +0x200 hwndBadgeHwnd, % item.key
    }
    g_RadialBandIconHwnds.Push(iconHwnd)
    g_RadialBandBadgeHwnds.Push(badgeHwnd)
}

CreateRadialLabel(index, menuX, menuY, diameter, center, startAngle, sweepAngle) {
    global g_RadialItems, g_RadialOuterRadius, g_RadialSectorLabelHwnds, g_RadialSectorIconHwnds
    global g_RadialLabelGuiNames, g_RadialLabelWinHwnds, g_RadialLabelMode

    item := g_RadialItems[index]
    itemCount := g_RadialItems.Length()
    labelGui := "RadialLabel" . index
    labelWidth := itemCount <= 4 ? 170 : (itemCount <= 8 ? 130 : 70)
    labelHeight := itemCount <= 4 ? 42 : 24
    labelRadius := g_RadialOuterRadius + 42
    labelAngle := (startAngle + sweepAngle / 2) * 0.017453292519943
    labelCenterX := Round(menuX + center + Cos(labelAngle) * labelRadius)
    labelCenterY := Round(menuY + center + Sin(labelAngle) * labelRadius)
    ; 标签框要"以 labelCenter 为中心"，就得按放大后的物理尺寸反推左上角：
    ; 请求的 w/h 会被 AHK 按 DPI 放大，而 x/y 不会，照逻辑尺寸算会让标签整体右下偏移
    physicalLabelWidth := Round(labelWidth * A_ScreenDPI / 96)
    physicalLabelHeight := Round(labelHeight * A_ScreenDPI / 96)
    labelX := Round(labelCenterX - physicalLabelWidth / 2)
    labelY := Round(labelCenterY - physicalLabelHeight / 2)
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
    ; LabelMode=Hover 时开局全部藏起来，等选中了再显示（UpdateRadialHighlight 负责）
    if (g_RadialLabelMode = "Hover")
        DllCall("ShowWindow", "Ptr", labelHwnd, "Int", 0)
    g_RadialSectorIconHwnds.Push(SectorIconHwnd)
    g_RadialSectorLabelHwnds.Push(SectorLabelHwnd)
    g_RadialLabelGuiNames.Push(labelGui)
    g_RadialLabelWinHwnds.Push(labelHwnd)
}

; 生成"薄环带 + 两端圆头端帽"的闭合多边形，用于 SetWindowRgn。
;
; 为什么要有圆头：直角端看起来像"切歪了"，圆头（capsule）让相邻扇区之间那道
; g_RadialGapDegrees 的缺口变成设计的一部分。
;
; 几何上的关键点：端帽是以**中径**为圆心、带厚一半为半径的半圆。
; 于是外弧端点恰好落在端帽圆上（距离 = bandOuter - bandMid = capRadius），
; 内弧端点同理，两段弧与端帽自然接上，不需要额外补偿。
; 附带一个很好用的不变量：**所有顶点到圆心的距离都在 [bandInner, bandOuter] 内**
; （端帽最外侧到圆心的距离是 sqrt(bandMid² + capRadius²) < bandOuter），
; 测试台直接断言它就能守住形状，不必逐点比对坐标。
BuildArcBandPoints(center, bandInner, bandOuter, startAngle, sweepAngle) {
    bandMid := (bandInner + bandOuter) / 2
    capRadius := (bandOuter - bandInner) / 2
    arcPoints := Max(6, Ceil(sweepAngle / 4))
    capPoints := 6
    points := []

    ; 外弧：起角 → 止角
    Loop, % arcPoints + 1 {
        radian := (startAngle + (A_Index - 1) * sweepAngle / arcPoints) * 0.017453292519943
        points.Push({x: Round(center + Cos(radian) * bandOuter), y: Round(center + Sin(radian) * bandOuter)})
    }

    endAngle := startAngle + sweepAngle
    endRadian := endAngle * 0.017453292519943
    capCenterX := center + Cos(endRadian) * bandMid
    capCenterY := center + Sin(endRadian) * bandMid
    ; 止端半圆：从外弧端点绕端帽外侧 180° 转到内弧端点
    Loop, % capPoints + 1 {
        radian := (endAngle + (A_Index - 1) * 180 / capPoints) * 0.017453292519943
        points.Push({x: Round(capCenterX + Cos(radian) * capRadius), y: Round(capCenterY + Sin(radian) * capRadius)})
    }

    ; 内弧：止角 → 起角（反向走，保证多边形不自交）
    Loop, % arcPoints + 1 {
        radian := (endAngle - (A_Index - 1) * sweepAngle / arcPoints) * 0.017453292519943
        points.Push({x: Round(center + Cos(radian) * bandInner), y: Round(center + Sin(radian) * bandInner)})
    }

    startRadian := startAngle * 0.017453292519943
    capCenterX := center + Cos(startRadian) * bandMid
    capCenterY := center + Sin(startRadian) * bandMid
    ; 起端半圆：从内弧端点绕端帽外侧 180° 转回外弧起点
    Loop, % capPoints + 1 {
        radian := (startAngle + 180 + (A_Index - 1) * 180 / capPoints) * 0.017453292519943
        points.Push({x: Round(capCenterX + Cos(radian) * capRadius), y: Round(capCenterY + Sin(radian) * capRadius)})
    }
    return points
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

MoveWindowBy(hwnd, x, y) {
    DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", 0, "Int", 0, "UInt", 0x0015)
}

GetCursorScreenPos(ByRef x, ByRef y) {
    VarSetCapacity(point, 8, 0)
    DllCall("GetCursorPos", "Ptr", &point)
    x := NumGet(point, 0, "Int")
    y := NumGet(point, 4, "Int")
}

; 说明：这里删掉了两个从未被调用的函数——
;   CalibrateRadialLayers()：想按实测窗口矩形修正轮盘各层与光标的偏移。实测不需要：
;     -Caption +ToolWindow 窗口的客户区原点与窗口原点重合（frameOffset = 0,0），
;     而 Region 用的正是窗口坐标，所以 menuX + center 恰好落在 g_RadialCenterX 上，
;     环本身就自洽。删掉是为了不留"以为有校准"的错觉。
;   SetCursorScreenPos()：只有 GetCursorScreenPos 有实际调用方。

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
    global g_RadialLabelWinHwnds, g_RadialBandIconHwnds, g_RadialBandBadgeHwnds

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
    g_RadialLabelWinHwnds := []
    g_RadialBandIconHwnds := []
    g_RadialBandBadgeHwnds := []
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

; 只重绘"上一次高亮"和"这一次高亮"两个扇区。
; 之前每换一次选择就把 N 个扇区窗口全部 Gui,Color + WinSet,Transparent 一遍，
; 9 个窗口各重绘一次纯属白烧——真正变色的只有离开的那个和进入的那个。
UpdateRadialHighlight() {
    global g_RadialItems, g_RadialSelected, g_RadialHighlighted, g_RadialSectorHwnds
    global g_RadialSectorLabelHwnds, g_RadialSectorIconHwnds, g_RadialLabelGuiNames
    global g_RadialAppControlHwnd, g_RadialCenterControlHwnd, g_RadialIconControlHwnd
    global g_RadialNormalColor, g_RadialSelectedColor
    global g_RadialBandBadgeHwnds, g_RadialLabelWinHwnds, g_RadialLabelMode

    Loop, % g_RadialItems.Length() {
        if (A_Index != g_RadialSelected && A_Index != g_RadialHighlighted)
            continue
        guiName := "RadialSector" . A_Index
        color := (A_Index == g_RadialSelected) ? g_RadialSelectedColor : g_RadialNormalColor
        Gui, %guiName%:Color, %color%
        sectorHwnd := g_RadialSectorHwnds[A_Index]
        ; 薄环带本身就比原来的实心扇区轻，所以未选中项再压一点透明度，对比更明确
        opacity := (A_Index == g_RadialSelected) ? 252 : 205
        WinSet, Transparent, %opacity%, ahk_id %sectorHwnd%
        ; LabelMode=Never 时这些数组是空的，必须跳过：
        ; 空 Gui 名会让 GuiControl 落到"默认 Gui"上，改错窗口的控件
        labelGui := g_RadialLabelGuiNames[A_Index]
        if (labelGui != "") {
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
        ; 键位角标跟着一起变：它是"这一格对应 Alt+几"的唯一提示
        badgeHwnd := g_RadialBandBadgeHwnds[A_Index]
        if (badgeHwnd) {
            if (A_Index == g_RadialSelected)
                GuiControl, %guiName%: +cFFFFFF, %badgeHwnd%
            else
                GuiControl, %guiName%: +cA8B8C8, %badgeHwnd%
        }
    }
    g_RadialHighlighted := g_RadialSelected

    ; LabelMode=Hover：只留选中项的标签，其余整窗藏起来（比重建便宜，也不动层级）
    if (g_RadialLabelMode = "Hover") {
        Loop, % g_RadialItems.Length() {
            labelWin := g_RadialLabelWinHwnds[A_Index]
            if (!labelWin)
                continue
            if (A_Index = g_RadialSelected)
                DllCall("ShowWindow", "Ptr", labelWin, "Int", 4)   ; SW_SHOWNOACTIVATE
            else
                DllCall("ShowWindow", "Ptr", labelWin, "Int", 0)   ; SW_HIDE
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
        ; 死区：明确告诉用户"松开就等于取消"，比只写"移动鼠标"少一次试错
        GuiControl, RadialCenter:Hide, %g_RadialIconControlHwnd%
        GuiControl, RadialCenter:, %g_RadialAppControlHwnd%, 移动鼠标选择窗口
        GuiControl, RadialCenter:, %g_RadialCenterControlHwnd%, 松开即取消
    }
}

ActivateRadialWindow(key, previewWasTopmost := false) {
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
    ; 只收掉"预览期间临时加的"置顶；用户自己钉住的窗口保持钉住
    if (!previewWasTopmost)
        SetWindowTopmost(hwnd, false)
    WinActivate, ahk_id %hwnd%
    ShowOSD("窗口已激活: [" . GetDisplayName(key) . "]")
}

; =======================================================
; 8. 绑定、解绑与核心触发路由
; =======================================================
; 三个处理器都要挡掉脚本自己的 GUI：控制条是可激活的普通 ToolWindow，
; 点一下滑块它就成了前台窗口，这时按绑定键会把控制条自己绑成"窗口"。
; 只挡 Bind/Trigger 不够 —— 置顶同样会把控制条钉在最上层。
BindHandler:
    KeyName := RegExReplace(A_ThisHotkey, "^[\^\!\+\*\$]+", "")
    WinGet, currentHwnd, ID, A
    if (!currentHwnd || IsScriptGui(currentHwnd)) {
        ShowOSD("请选择一个普通应用窗口再绑定")
        return
    }
    WindowBindings[KeyName] := currentHwnd
    WindowIsOverlaid[KeyName] := false  
    
    ; 走统一的 setter，而不是直接 WinSet：
    ; Transparent 255 会留下 WS_EX_LAYERED（Chromium 系窗口掉帧），且不更新 state.opacity，
    ; 于是下次开控制条滑块显示的百分比会与实际不符
    SetWindowOpacity(currentHwnd, 255)
    SetWindowTopmost(currentHwnd, false)
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
        ; 置顶状态也要先记下来：下面为了让"沉到锚点下方"生效必须摘掉置顶，
        ; 但摘掉之后如果没人负责还原，用户用 Alt+T 钉住的窗口会在这里永久失去置顶
        RestoreData_Topmost[KeyName] := SyncWindowTopmostState(targetHwnd)
        WindowIsOverlaid[KeyName] := true
        
        SetWindowTopmost(targetHwnd, false)
        WinActivate, ahk_id %targetHwnd%
        ShowOSD("👀 窗口已呼出: [" . GetDisplayName(KeyName) . "] ")
        
        KeyWait, %KeyName%, T0.3
        if (ErrorLevel) {
            ; 加超时：万一 up 事件丢了（钩子被外部工具顶掉等），
            ; 没有超时就会永远卡在这里，窗口留在"已呼出"状态再也回不去
            KeyWait, %KeyName%, T60
            RestoreWindow(KeyName)
        }
    } else {
        if (currentActiveHwnd == targetHwnd) {
            RestoreWindow(KeyName)
            KeyWait, %KeyName%, T60
        } else {
            SetWindowTopmost(targetHwnd, false)
            WinActivate, ahk_id %targetHwnd%
            ShowOSD("👀 再次呼出: [" . GetDisplayName(KeyName) . "] ")
            KeyWait, %KeyName%, T0.3
            if (ErrorLevel) {
                KeyWait, %KeyName%, T60
                RestoreWindow(KeyName)
            }
        }
    }
return

; =======================================================
; 8. 恢复与原生隔离算法
; =======================================================
RestoreWindow(KeyName) {
    global RestoreData_Topmost

    targetHwnd := WindowBindings[KeyName]
    prevActive := RestoreData_Active[KeyName]
    hwndAbove := RestoreData_Above[KeyName]
    minMaxState := RestoreData_MinMax[KeyName]
    wasTopmost := RestoreData_Topmost[KeyName]
    
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
    ; 呼出时为了能沉到锚点下方而摘掉了置顶，这里按呼出前记下的状态还原，
    ; 否则"Alt+T 钉住的窗口"会被呼出/隐藏一轮后永久失去置顶
    SetWindowTopmost(targetHwnd, wasTopmost ? true : false)
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
; 当前值若不在候选表里（例如手改 config.ini 写成 # 即 Win 修饰键），
; 就把它作为额外一项追加进去。否则下拉框会静默显示成第一项，
; 用户一按"保存并重启"就把自己原来的设置改掉了。
BuildDDL(currentVal) {
    options := ["! (Alt)", "^ (Ctrl)", "+ (Shift)", "^! (Ctrl+Alt)", "^+ (Ctrl+Shift)"]
    currentVal := Trim(currentVal)

    hasCurrent := false
    for k, v in options {
        if (RegExReplace(v, "\s.*", "") == currentVal)
            hasCurrent := true
    }
    if (currentVal != "" && !hasCurrent)
        options.Push(currentVal . " (当前值)")

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
; 复用 FormatHotkey，于是 Win 修饰键、< > 左右键指定也能正确显示，
; 不再只认那 5 种写死的组合
GetDisplayName(KeyName) {
    global g_TriggerModifier
    return FormatHotkey(g_TriggerModifier . KeyName)
}

; -------------------------------------------------------
; 快捷键串的归一化、校验与注册
; -------------------------------------------------------

; v1 没有 StrLower() 函数（那是 v2 才有的），只有 StringLower 命令，包一层好在表达式里用
LowerCase(text) {
    StringLower, text, text
    return text
}

; 把用户可能写的 "Alt+="、"Ctrl+Shift+T" 这类写法翻译成 AHK 的修饰符前缀写法。
;
; 用 "+" 分词，而不是 StrReplace 替换链：分词之后"哪个是键、哪些是修饰符"是明确的，
; 不受书写顺序影响；替换链则要靠 "Alt+" 恰好排在 "Ctrl+" 前面这种巧合才对。
; 翻译不了的写法原样返回，交给 RegisterHotkey 去判断和回退 —— 这里只做翻译，不做取舍。
NormalizeHotkeySpelling(hotkey) {
    static modifierSymbols := {"alt": "!", "ctrl": "^", "shift": "+", "win": "#"}

    hotkey := Trim(hotkey)
    if (!InStr(hotkey, "+"))
        return hotkey
    parts := StrSplit(hotkey, "+")
    if (parts.Length() < 2)
        return hotkey

    symbols := ""
    for index, part in parts {
        if (index = parts.Length())
            break
        name := LowerCase(Trim(part))
        if (!modifierSymbols.HasKey(name))
            return hotkey
        symbols .= modifierSymbols[name]
    }
    keyPart := Trim(parts[parts.Length()])
    if (keyPart = "")
        return hotkey
    return symbols . keyPart
}

; 剥掉前导的修饰符与注册前缀符号，取出键名部分
StripHotkeyModifiers(hotkey) {
    return RegExReplace(Trim(hotkey), "^[\#\^\!\+\<\>\*\$~]+")
}

; 键名部分是否为空、或只是一个裸修饰符。
; AHK 允许注册 "!" 这种裸修饰符热键（v1.1.37 实测注册成功），但本脚本要用 KeyWait
; 等它抬起，PreviewPhysicalKey 会因此变成空串 —— 于是热键按下的那一刻才炸。
; 所以这类值必须在这里就判为非法，而不是让它注册成功后死在运行期。
IsBareModifierHotkey(hotkey) {
    static bareNames := " alt ctrl shift lalt ralt lctrl rctrl lshift rshift lwin rwin win "

    keyPart := LowerCase(StripHotkeyModifiers(hotkey))
    if (keyPart = "")
        return true
    return InStr(bareNames, " " . keyPart . " ") ? true : false
}

; 修饰键只允许由 # ^ ! + 组成（可带 < > 指定左右键）。
; 它是要拼在 1~9 前面成为完整热键的，混进别的字符会拼出意料之外的全局热键。
IsModifierOnly(str) {
    str := Trim(str)
    if (str = "")
        return false
    return RegExMatch(str, "^[\#\^\!\+\<\>]+$") ? true : false
}

; 判断一个键名能不能交给 GetKeyState / KeyWait 用。
;
; 实测（v1.1.37）：GetKeyState 对合法键名返回 0/1，对非法名字既不抛错也不报错，
; 只是返回空串。于是"迷彩编辑抑制键"填错时的症状是"按住键毫无反应"，
; 没有任何提示可查 —— 所以这里用返回值是否为空来判定，把错误挡在写盘之前。
; 注意这与 Hotkey 的判定方式不同：Hotkey 对非法键名会抛可捕获异常。
IsUsableKeyName(name) {
    name := Trim(name)
    if (name = "")
        return false
    return (GetKeyState(name, "P") = "") ? false : true
}

SanitizeKeyName(value, fallback, displayName) {
    if (IsUsableKeyName(value))
        return value
    AddStartupWarning(displayName . "「" . (Trim(value) = "" ? "空" : Trim(value)) . "」不是可用键名，已改用 " . fallback)
    return fallback
}

SanitizeModifier(value, fallback, displayName) {
    if (IsModifierOnly(value))
        return value
    AddStartupWarning(displayName . "「" . (Trim(value) = "" ? "空" : Trim(value)) . "」不是合法修饰键，已改用 " . fallback)
    return fallback
}

; 注册一个全局热键，并保证"配置里的值不能用"只导致降级、不导致崩溃。
; 返回真正生效的热键串，调用方应当把它写回变量，让配置页显示的就是实际生效的键。
;
; 三种结果都要说话，不能只有彻底失败才吭声：
;   配置值可用        → 静默注册；
;   配置值不可用、默认值可用 → 注册默认值 + 告警（否则用户会以为自己的设置生效了）；
;   两个都不可用      → 告警说明该功能本次未启用。
RegisterHotkey(hotkey, label, fallback := "", prefix := "$*") {
    configured := NormalizeHotkeySpelling(hotkey)
    displayValue := (Trim(hotkey) = "" ? "空" : Trim(hotkey))

    effective := TryRegisterHotkey(configured, label, prefix)
    if (effective = "" && fallback != "")
        effective := TryRegisterHotkey(fallback, label, prefix)

    if (effective = "")
        AddStartupWarning(GetHotkeyLabelName(label) . "的快捷键「" . displayValue . "」无法使用，本次未启用")
    else if (effective != configured)
        AddStartupWarning(GetHotkeyLabelName(label) . "的快捷键「" . displayValue . "」无效，已改用 " . effective)
    return effective
}

TryRegisterHotkey(hotkey, label, prefix) {
    global g_RegisteredHotkeys

    hotkey := NormalizeHotkeySpelling(hotkey)
    if (hotkey = "" || IsBareModifierHotkey(hotkey))
        return ""

    ; 重复注册不会报错，AHK 只会把先注册的标签顶掉，功能就无声消失了 —— 所以自己查重
    key := LowerCase(hotkey)
    if (g_RegisteredHotkeys.HasKey(key)) {
        AddStartupWarning(hotkey . " 与" . GetHotkeyLabelName(g_RegisteredHotkeys[key]) . "重复，已跳过" . GetHotkeyLabelName(label))
        return ""
    }

    ; 非法键名会让 Hotkey 命令抛错并终止整个脚本，必须在这里兜住（v1.1.37 实测可捕获）
    try {
        Hotkey, % prefix . hotkey, %label%
    } catch {
        return ""
    }
    g_RegisteredHotkeys[key] := label
    return hotkey
}

; 告警里要用用户看得懂的功能名，而不是 BindHandler 这样的标签名
GetHotkeyLabelName(label) {
    static names := {"BindHandler": "绑定", "UnbindHandler": "解绑", "TriggerHandler": "呼出/隐藏"
        , "SnapshotHandler": "记录快照", "PreviewHandler": "实时预览", "RadialHandler": "窗口轮盘"
        , "WindowMenuHandler": "控制条", "PinHandler": "全局置顶", "ShowConfigGUI": "配置页"}
    return names.HasKey(label) ? names[label] : label
}

AddStartupWarning(message) {
    global g_StartupWarnings
    g_StartupWarnings.Push(message)
}

JoinText(items, separator) {
    result := ""
    for index, item in items
        result .= (result = "" ? "" : separator) . item
    return result
}

; 配置页保存前的形状校验：把"空值 / 裸修饰符"这类明显不能用的写法拦在写盘之前，
; 免得坏值先进 config.ini，再靠启动时的回退去救。
; 只做结构判断，不查白名单 —— 白名单会误伤 AHK 支持的冷门键名（如 Media_Play_Pause）。
ValidateHotkeyInput(value, displayName, ByRef errorMessage) {
    value := Trim(value)
    if (value = "") {
        errorMessage := displayName . "不能为空"
        return false
    }
    if (IsBareModifierHotkey(value)) {
        errorMessage := displayName . "「" . value . "」只有修饰键、没有主键，无法注册"
        return false
    }
    return true
}

; 找出配置里互相冲突的快捷键，返回一句人话（无冲突返回空串）。
;
; 必须自己查：AHK 对重复注册不报错，只会让后注册的把前一个标签顶掉，
; 功能就无声消失了（v1.1.37 实测重复注册后 ErrorLevel 仍是 0）。
; 三组数字键要展开成完整热键再比 —— 冲突的是"修饰键+数字"，不是修饰键本身。
FindHotkeyConflict(triggerMod, bindMod, unbindMod, pin, snapshot, preview, radial, radialAlt, windowMenu, config) {
    keys := []
    for index, digit in ["1", "2", "3", "4", "5", "6", "7", "8", "9"] {
        keys.Push({hotkey: triggerMod . digit, name: "呼出/隐藏 " . digit})
        keys.Push({hotkey: bindMod . digit, name: "绑定 " . digit})
        keys.Push({hotkey: unbindMod . digit, name: "解绑 " . digit})
    }
    keys.Push({hotkey: pin, name: "全局置顶"})
    keys.Push({hotkey: snapshot, name: "记录层级快照"})
    keys.Push({hotkey: preview, name: "实时预览"})
    keys.Push({hotkey: radial, name: "主轮盘"})
    keys.Push({hotkey: radialAlt, name: "备用轮盘"})
    keys.Push({hotkey: windowMenu, name: "控制条"})
    keys.Push({hotkey: config, name: "配置页"})

    seen := {}
    for index, item in keys {
        hotkey := NormalizeHotkeySpelling(item.hotkey)
        if (hotkey = "")
            continue
        key := LowerCase(hotkey)
        if (seen.HasKey(key)) {
            ; 备用轮盘与主轮盘相同是合法配置：脚本对相同值会跳过备用轮盘的注册
            if (item.name = "备用轮盘" && seen[key] = "主轮盘")
                continue
            return hotkey . " 同时被「" . seen[key] . "」和「" . item.name . "」占用"
        }
        seen[key] := item.name
    }
    return ""
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

; 把底层特殊键格式化成能看懂的人话。
;
; 必须按前导修饰符逐字符解析，不能写成 StrReplace 链：先把 "^" 换成 "Ctrl+"、
; 再把 "+" 换成 "Shift+"，第二步会把第一步刚生成的那个 "+" 一起换掉，
; 于是 "^!vkC0" 会变成 "CtrlShift+AltShift+·(波浪号)"。
FormatHotkey(hk) {
    static modifierNames := {"#": "Win+", "^": "Ctrl+", "!": "Alt+", "+": "Shift+"}
    static prefixSymbols := "$*~<>"

    hk := Trim(hk)
    text := ""
    keyStart := StrLen(hk) + 1
    Loop, % StrLen(hk) {
        char := SubStr(hk, A_Index, 1)
        if (InStr(prefixSymbols, char))
            continue
        if (modifierNames.HasKey(char)) {
            text .= modifierNames[char]
            continue
        }
        keyStart := A_Index
        break
    }
    return text . RegExReplace(SubStr(hk, keyStart), "i)^vkC0$", "·(波浪号)")
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