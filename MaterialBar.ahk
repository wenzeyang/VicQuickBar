#Requires AutoHotkey v2.0
#SingleInstance Force

;@Ahk2Exe-SetMainIcon assets\app.ico
;@Ahk2Exe-SetVersion 1.0.1.0
;@Ahk2Exe-SetName Vic Quick Bar

#Include modules\MaterialBarDrag.ahk

DllCall("ole32\OleInitialize", "ptr", 0)
MBDrag_Init()

global MaterialBar := MaterialBarApp()
OnExit(MaterialBarExit)
MaterialBar.Show()
if A_Args.Length && A_Args[1] = "--smoke-test"
    SetTimer(MaterialBarSmokeTest, -100)

MaterialBarExit(*) {
    global MaterialBar
    try MaterialBar.Shutdown()
    DllCall("ole32\OleUninitialize")
}

MaterialBarSmokeTest() {
    global MaterialBar
    originalSource := MaterialBar.CurrentSourceIndex
    originalView := MaterialBar.ViewMode
    originalTop := MaterialBar.AlwaysOnTop
    originalWindowWidth := MaterialBar.WindowWidth
    originalWindowHeight := MaterialBar.WindowHeight
    originalPreviewWidth := MaterialBar.PreviewWidth
    originalPreviewHeight := MaterialBar.PreviewHeight
    try {
        MaterialBar.Window.GetClientPos(, , &startupWidth, &startupHeight)
        if startupWidth < MaterialBar.MinWindowWidth - 2
            throw Error("启动宽度异常：" startupWidth)
        if MaterialBar.Expanded
            throw Error("应用启动时不应自动展开")
        for button in MaterialBar.SourceButtons
            if button.Value
                throw Error("收起状态不应保留标签高亮")
        lastTab := MaterialBar.SourceButtons[
            MaterialBar.SourceButtons.Length]
        lastTab.GetPos(&lastTabX, , &lastTabWidth)
        if !lastTab.Visible
            || lastTabX + lastTabWidth > startupWidth - 32
            throw Error("启动时素材标签被挤出窗口")
        MaterialBar.SetExpanded(true)
        if MaterialBar.Window.Hwnd = MaterialBar.ContentWindow.Hwnd
            throw Error("素材栏与展示区没有拆分为独立窗口")
        if !DllCall("user32\IsWindowVisible",
            "ptr", MaterialBar.ContentWindow.Hwnd, "int")
            throw Error("展开后展示窗口未显示")
        barRect := MaterialBar.GetWindowRectangle(MaterialBar.Window.Hwnd)
        contentRect := MaterialBar.GetWindowRectangle(
            MaterialBar.ContentWindow.Hwnd)
        if !IsObject(barRect) || !IsObject(contentRect)
            || Abs(contentRect.Bottom + MaterialBar.PanelGap
                - barRect.Top) > 3
            throw Error("素材栏与展示窗口没有正确对齐")
        if Abs(contentRect.Width - barRect.Width) > 3
            throw Error("素材栏与展示窗口宽度不一致")
        MaterialBar.Status.GetPos(&statusX, &statusY,
            &statusWidth, &statusHeight)
        MaterialBar.RefreshButton.GetPos(&refreshX, &refreshY,
            &refreshWidth, &refreshHeight)
        if statusX + statusWidth > refreshX
            || Abs(statusY - refreshY) > 3
            || statusHeight > MaterialBar.BarHeight
            throw Error("状态提示没有以单行放在刷新按钮左侧")
        if MaterialBar.SourceButtons[MaterialBar.CurrentSourceIndex].Value != 1
            throw Error("当前素材标签没有保持选中高亮")
        ; Regression: opening or switching a tab must keep the bar anchored on
        ; every monitor. This catches delayed WM_SIZE reverse-sync drift on
        ; secondary displays with a different DPI or desktop origin.
        testOriginRect := MaterialBar.GetWindowRectangle(
            MaterialBar.Window.Hwnd)
        MaterialBar.SetExpanded(false)
        Loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index, &workLeft, &workTop,
                &workRight, &workBottom)
            testWidth := testOriginRect.Width
            testHeight := testOriginRect.Height
            testX := workLeft + Max(0,
                Floor((workRight - workLeft - testWidth) / 2))
            testY := workBottom - testHeight - 24
            MaterialBar.SetOuterWindowPosition(MaterialBar.Window.Hwnd,
                testX, testY, testWidth, testHeight)
            Sleep(50)
            anchoredRect := MaterialBar.GetWindowRectangle(
                MaterialBar.Window.Hwnd)
            nextSource := Mod(MaterialBar.CurrentSourceIndex,
                MaterialBar.Sources.Length) + 1
            MaterialBar.ActivateSourceTab(nextSource)
            Sleep(120)
            switchedRect := MaterialBar.GetWindowRectangle(
                MaterialBar.Window.Hwnd)
            if Abs(switchedRect.Left - anchoredRect.Left) > 2
                || Abs(switchedRect.Top - anchoredRect.Top) > 2
                throw Error("扩展屏切换标签后素材栏发生坐标漂移")
            pairedRect := MaterialBar.GetWindowRectangle(
                MaterialBar.ContentWindow.Hwnd)
            if Abs(pairedRect.Bottom + MaterialBar.PanelGap
                    - switchedRect.Top) > 3
                throw Error("扩展屏上的展示窗口没有与素材栏对齐")
            MaterialBar.SetExpanded(false)
        }
        MaterialBar.SetOuterWindowPosition(MaterialBar.Window.Hwnd,
            testOriginRect.Left, testOriginRect.Top,
            testOriginRect.Width, testOriginRect.Height)
        MaterialBar.SetExpanded(true)
        try {
            for size in [[512, 512], [768, 768],
                    [512, 768], [768, 512]] {
                MaterialBar.SetPreviewSize(size[1], size[2])
                if MaterialBar.PreviewWidth != size[1]
                    || MaterialBar.PreviewHeight != size[2]
                    throw Error("预览尺寸切换失败")
            }
        } finally {
            MaterialBar.SetPreviewSize(
                originalPreviewWidth, originalPreviewHeight)
        }
        MaterialBar.SelectSource(MaterialBar.Sources.Length - 1)
        if MaterialBar.Items.Has(1)
            MaterialBar.ShowItemPreview(MaterialBar.Items[1])
        MaterialBar.ShowEmptyPreview()
        smokeTextItems := []
        for color in ["yellow", "pink", "green", "blue"] {
            smokeItem := MaterialBar.BuildTextItem(
                "测试文字卡片 " color, false, "", color)
            MaterialBar.MemoryTextItems.InsertAt(1, smokeItem)
            smokeTextItems.Push(smokeItem)
        }
        MaterialBar.SelectSource(MaterialBar.Sources.Length)
        for mode in ["ExtraLarge", "Large", "Medium", "Small", "List"]
            MaterialBar.SetViewMode(mode)
        MaterialBar.SelectSource(1)
        for mode in ["List", "Small", "Medium", "Large", "ExtraLarge"]
            MaterialBar.SetViewMode(mode)
        MaterialBar.SetViewMode("Large")
        largeIconSize := MaterialBar.ImageWidth
        MaterialBar.SetViewMode("ExtraLarge")
        if MaterialBar.ImageWidth != largeIconSize * 2
            throw Error("超大图标不是大图标的两倍")
        if !MaterialBar.AddExtensionBadgeToList("pptx")
            throw Error("扩展名徽标图标生成失败")
        if MaterialBar.LastExtensionBadgeOpaquePixels < 1
            || MaterialBar.LastExtensionBadgeTransparentPixels < 1
            throw Error("扩展名徽标透明通道生成失败")
        if !MaterialBar.LastExtensionBadgeRenderedColor
            throw Error("扩展名徽标实际绘制后仍为黑色")
        MaterialBar.OnMouseMove(0, 50 | (50 << 16),
            0x0200, MaterialBar.List.Hwnd)
        MaterialBar.OnMouseLeave(0, 0, 0x02A3, MaterialBar.List.Hwnd)
        for smokeItem in smokeTextItems
            MaterialBar.RemoveTextItemFromArray(
                MaterialBar.MemoryTextItems, smokeItem)
        favoriteProbe := MaterialBar.BuildTextItem(
            "收藏持久化测试", false, "", "pink")
        originalFavorites := MaterialBar.FavoriteTextItems
        probePath := ""
        try {
            MaterialBar.WriteFavoriteText(favoriteProbe)
            probePath := favoriteProbe.Path
            if !FileExist(probePath)
                throw Error("收藏文字未写入本地")
            savedFavorite := FileRead(probePath, "UTF-8")
            if !InStr(savedFavorite, "COLOR=pink")
                || !InStr(savedFavorite, "收藏持久化测试")
                throw Error("收藏文字内容校验失败")
            MaterialBar.LoadFavoriteTextItems()
            loadedProbe := false
            for loadedItem in MaterialBar.FavoriteTextItems
                if loadedItem.Path = probePath
                    && loadedItem.Color = "pink"
                    && loadedItem.Content = "收藏持久化测试" {
                    loadedProbe := true
                    break
                }
            if !loadedProbe
                throw Error("收藏文字重新载入校验失败")
            probeArray := [favoriteProbe]
            if !MaterialBar.RemoveTextItemFromArray(
                probeArray, favoriteProbe) || probeArray.Length
                throw Error("文字项移除校验失败")
        } finally {
            MaterialBar.FavoriteTextItems := originalFavorites
            if probePath != "" && FileExist(probePath)
                FileDelete(probePath)
        }
        MaterialBar.SelectSource(originalSource)
        MaterialBar.SetViewMode(originalView)
        MaterialBar.ToggleAlwaysOnTop()
        MaterialBar.ToggleAlwaysOnTop()
        if MaterialBar.AlwaysOnTop != originalTop
            MaterialBar.ToggleAlwaysOnTop()
        MaterialBar.SetExpanded(false)
        for button in MaterialBar.SourceButtons
            if button.Value
                throw Error("关闭展示窗口后仍保留标签高亮")
        MaterialBar.WindowWidth := originalWindowWidth
        MaterialBar.WindowHeight := originalWindowHeight
        IniWrite(originalWindowWidth, MaterialBar.ConfigPath,
            "General", "WindowWidth")
        IniWrite(originalWindowHeight, MaterialBar.ConfigPath,
            "General", "WindowHeight")
        ExitApp(0)
    } catch as error {
        MaterialBar.WindowWidth := originalWindowWidth
        MaterialBar.WindowHeight := originalWindowHeight
        IniWrite(originalWindowWidth, MaterialBar.ConfigPath,
            "General", "WindowWidth")
        IniWrite(originalWindowHeight, MaterialBar.ConfigPath,
            "General", "WindowHeight")
        FileAppend("SMOKE_TEST_FAILED: " error.Message "`n"
            error.Stack, "**", "UTF-8")
        ExitApp(2)
    }
}

class MaterialBarApp {
    __New() {
        this.ConfigPath := A_ScriptDir "\material-bar.ini"
        this.ConfigExamplePath := A_ScriptDir "\material-bar.example.ini"
        this.StatePath := A_ScriptDir "\data\material-bar-state.ini"
        this.AssetDir := A_ScriptDir "\assets"
        this.Items := Map()
        this.Sources := []
        this.SourceButtons := []
        this.ContentControls := []
        this.CurrentSourceIndex := 1
        this.CurrentPath := ""
        this.RootPath := ""
        this.Expanded := false
        this.BarHeight := 52
        this.ImageList := 0
        this.ImageListType := 0
        this.TextCardMode := false
        this.AppIconHandles := []
        this.PreviewBitmap := 0
        this.PreviewImagePath := ""
        this.MemoryTextItems := []
        this.FavoriteTextItems := []
        this.TextEditors := []
        this.TextCaptureEnabled := true
        this.FavoriteTextDir := A_ScriptDir "\data\favorite-texts"
        this.TextColorKeys := ["yellow", "pink", "green", "blue"]
        this.TextColorLabels := Map(
            "yellow", "浅黄色", "pink", "浅粉色",
            "green", "浅绿色", "blue", "浅蓝色")
        this.TextFillColors := Map(
            "yellow", 0xFFF7CC, "pink", 0xFCE7F3,
            "green", 0xDCFCE7, "blue", 0xDBEAFE)
        this.TextBorderColors := Map(
            "yellow", 0xE8C85A, "pink", 0xF0A6C0,
            "green", 0x86C99A, "blue", 0x8DB8E8)
        this.ClipboardImageItems := []
        this.LastClipboardImageSequence := 0
        this.SessionImageDir := A_Temp "\AI-Material-Bar-"
            . DllCall("kernel32\GetCurrentProcessId", "uint")
        this.PreviewHasImage := false
        this.HoverRow := 0
        this.MouseLeaveArmed := false
        this.LastHistoryFingerprint := ""
        this.IgnoreNextClipboardText := false
        this.ReturnWindow := 0
        this.DragArmed := false
        this.DragStarted := false
        this.DragRow := 0
        this.DragStartX := 0
        this.DragStartY := 0
        this.IgnoreSizePersistence := false
        this.IgnorePreviewSizePersistence := false
        this.HasShownWindow := false
        this.SmokeTestMode := A_Args.Length
            && A_Args[1] = "--smoke-test"
        this.UserSizingBar := false
        this.UserSizingContent := false
        this.PanelGap := 8
        this.SyncingWindows := false
        this.WindowPairTimer := ObjBindMethod(this, "SyncContentToBar")
        this.PreviewSaveTimer := ObjBindMethod(this, "PersistPreviewSize")
        this.PreviewHideTimer := ObjBindMethod(this,
            "HidePreviewIfPointerOutside")

        this.EnsureConfig()
        this.LoadConfig()
        this.LoadHistoryState()
        this.LoadFavoriteTextItems()
        this.BuildMenus()
        this.BuildWindow()
        this.InstallInteractions()
        this.SelectSource(this.CurrentSourceIndex)
        this.ConfigureTray()
    }

    EnsureConfig() {
        if FileExist(this.ConfigPath)
            return
        if FileExist(this.ConfigExamplePath) {
            ; Windows' INI APIs detect Unicode reliably only when a BOM is
            ; present. Convert the UTF-8 repository template to UTF-16 so
            ; Chinese tab names survive IniRead/IniWrite on every locale.
            template := FileRead(this.ConfigExamplePath, "UTF-8")
            FileAppend(template, this.ConfigPath, "UTF-16")
            return
        }
        throw Error("缺少配置模板：" this.ConfigExamplePath)
    }

    LoadConfig() {
        this.HotkeyName := Trim(IniRead(this.ConfigPath,
            "General", "Hotkey", "F3"))
        this.AlwaysOnTop := IniRead(this.ConfigPath,
            "General", "AlwaysOnTop", "1") != "0"
        this.BarTitle := Trim(IniRead(this.ConfigPath,
            "General", "BarTitle", "Vic快捷栏"))
        if this.BarTitle = "" || this.BarTitle = "AI 素材栏" {
            this.BarTitle := "Vic快捷栏"
            IniWrite(this.BarTitle, this.ConfigPath,
                "General", "BarTitle")
        }
        this.TitleWidth := Max(112,
            Min(200, 40 + StrLen(this.BarTitle) * 14))
        this.UIFontName := Trim(IniRead(this.ConfigPath,
            "General", "UIFontName", "Microsoft YaHei UI"))
        if this.UIFontName = ""
            this.UIFontName := "Microsoft YaHei UI"
        this.UIFontSize := this.ReadInteger("General", "UIFontSize",
            9, 8, 14)
        this.WindowWidth := this.ReadInteger("General", "WindowWidth",
            1080, 760, 2400)
        this.WindowHeight := this.ReadInteger("General", "WindowHeight",
            680, 420, 1600)
        this.HistoryLimit := this.ReadInteger("General", "HistoryLimit",
            30, 5, 200)
        this.PreviewWidth := this.ReadInteger("General", "PreviewWidth",
            300, 240, 1000)
        this.PreviewHeight := this.ReadInteger("General", "PreviewHeight",
            520, 360, 1000)
        configuredView := StrLower(Trim(IniRead(this.ConfigPath,
            "General", "ViewMode", "Medium")))
        this.ViewMode := Map("extralarge", "ExtraLarge",
            "extra-large", "ExtraLarge", "large", "Large",
            "medium", "Medium", "small", "Small",
            "list", "List").Get(configuredView, "Medium")
        sourceCount := this.ReadInteger("Sources", "Count", 4, 1, 10)
        this.Sources := []
        Loop sourceCount {
            section := "Source" A_Index
            name := Trim(IniRead(this.ConfigPath, section, "Name",
                "文件夹" A_Index))
            path := this.ResolvePath(IniRead(this.ConfigPath, section,
                "Path", "%USERPROFILE%\Desktop"))
            this.Sources.Push({Kind: "folder", Name: name, Path: path,
                Section: section})
        }
        screenshotName := Trim(IniRead(this.ConfigPath,
            "Screenshots", "Name", "历史截图"))
        if screenshotName = "图片截图" {
            screenshotName := "历史截图"
            IniWrite(screenshotName, this.ConfigPath,
                "Screenshots", "Name")
        }
        screenshotPath := this.ResolvePath(IniRead(this.ConfigPath,
            "Screenshots", "Path", "%USERPROFILE%\Pictures\Screenshots"))
        this.Sources.Push({Kind: "screenshots", Name: screenshotName,
            Path: screenshotPath, Section: "Screenshots"})

        textName := Trim(IniRead(this.ConfigPath,
            "Text", "Name", "历史文本"))
        if textName = "文本粘贴" {
            textName := "历史文本"
            IniWrite(textName, this.ConfigPath, "Text", "Name")
        }
        textPath := this.ResolvePath(IniRead(this.ConfigPath,
            "Text", "Path", "%A_ScriptDir%\data\text-blocks"))
        this.Sources.Push({Kind: "text", Name: textName,
            Path: textPath, Section: "Text"})
        this.MinWindowWidth := Max(760,
            this.TitleWidth + 42 + this.Sources.Length * 96)
        this.WindowWidth := Max(this.WindowWidth, this.MinWindowWidth)
        this.CurrentSourceIndex := this.ReadInteger("General",
            "LastSource", 1, 1, this.Sources.Length)
    }

    ReadInteger(section, key, fallback, minimum, maximum) {
        try value := Integer(IniRead(this.ConfigPath, section, key,
            String(fallback)))
        catch
            value := fallback
        return Max(minimum, Min(maximum, value))
    }

    ResolvePath(rawPath) {
        path := Trim(rawPath, " `t`r`n`"")
        path := StrReplace(path, "%A_ScriptDir%", A_ScriptDir)
        path := StrReplace(path, "%A_Desktop%", A_Desktop)
        path := StrReplace(path, "%A_MyDocuments%", A_MyDocuments)
        expansionBuffer := Buffer(32768 * 2, 0)
        expanded := DllCall("kernel32\ExpandEnvironmentStringsW",
            "wstr", path, "ptr", expansionBuffer.Ptr, "uint", 32768, "uint")
        if expanded && expanded <= 32768
            path := StrGet(expansionBuffer.Ptr, "UTF-16")
        if !RegExMatch(path, "i)^(?:[A-Z]:\\|\\\\)")
            path := A_ScriptDir "\" path
        return this.TrimPath(path)
    }

    TrimPath(path) {
        normalized := StrReplace(path, "/", "\")
        if RegExMatch(normalized, "i)^[A-Z]:\\$")
            return normalized
        return RTrim(normalized, "\")
    }

    LoadHistoryState() {
        this.Favorites := Map(
            "screenshots", Map(),
            "text", Map())
        this.HistoryOrders := Map(
            "screenshots", [],
            "text", [])
        for kind in ["screenshots", "text"] {
            title := kind = "screenshots" ? "Screenshots" : "Text"
            for path in this.LoadStatePaths("Favorite" title)
                this.Favorites[kind][StrLower(path)] := path
            this.HistoryOrders[kind] := this.LoadStatePaths("Order" title)
        }
    }

    LoadFavoriteTextItems() {
        this.FavoriteTextItems := []
        if !DirExist(this.FavoriteTextDir)
            return
        Loop Files, this.FavoriteTextDir "\*.clip", "F" {
            try {
                raw := LTrim(FileRead(A_LoopFileFullPath, "UTF-8"),
                    Chr(0xFEFF))
                color := "yellow"
                content := raw
                if RegExMatch(raw,
                    "s)^COLOR=([a-z]+)\R\R(.*)$", &match) {
                    color := this.NormalizeTextColor(match[1])
                    content := match[2]
                }
                if Trim(content) = ""
                    continue
                modified := ""
                try modified := FileGetTime(A_LoopFileFullPath, "M")
                item := this.BuildTextItem(content, true,
                    A_LoopFileFullPath, color, modified)
                this.FavoriteTextItems.Push(item)
            }
        }
        this.SortFavoriteTextItems()
    }

    SortFavoriteTextItems() {
        Loop this.FavoriteTextItems.Length - 1 {
            index := A_Index + 1
            candidate := this.FavoriteTextItems[index]
            cursor := index - 1
            while cursor >= 1
                && StrCompare(this.FavoriteTextItems[cursor].Modified,
                    candidate.Modified) < 0 {
                this.FavoriteTextItems[cursor + 1] :=
                    this.FavoriteTextItems[cursor]
                cursor -= 1
            }
            this.FavoriteTextItems[cursor + 1] := candidate
        }
    }

    LoadStatePaths(section) {
        paths := []
        if !FileExist(this.StatePath)
            return paths
        count := 0
        try count := Integer(IniRead(this.StatePath, section, "Count", "0"))
        Loop Max(0, Min(count, 1000)) {
            path := Trim(IniRead(this.StatePath, section,
                "Item" A_Index, ""))
            if path != ""
                paths.Push(path)
        }
        return paths
    }

    SaveHistoryState(kind) {
        try DirCreate(A_ScriptDir "\data")
        if !FileExist(this.StatePath)
            FileAppend("; Vic Quick Bar state`r`n",
                this.StatePath, "UTF-16")
        title := kind = "screenshots" ? "Screenshots" : "Text"
        favoritePaths := []
        for _, path in this.Favorites[kind]
            favoritePaths.Push(path)
        this.SaveStatePaths("Favorite" title, favoritePaths)
        this.SaveStatePaths("Order" title, this.HistoryOrders[kind])
    }

    SaveStatePaths(section, paths) {
        try IniDelete(this.StatePath, section)
        IniWrite(paths.Length, this.StatePath, section, "Count")
        for index, path in paths
            IniWrite(path, this.StatePath, section, "Item" index)
    }

    BuildMenus() {
        this.ViewMenu := Menu()
        this.ViewLabels := Map("ExtraLarge", "超大图标",
            "Large", "大图标", "Medium", "中图标",
            "Small", "小图标", "List", "列表")
        for mode, label in this.ViewLabels
            this.ViewMenu.Add(label,
                ObjBindMethod(this, "SetViewMode", mode))
        this.ViewMenu.Check(this.ViewLabels[this.ViewMode])

        this.PreviewSizeMenu := Menu()
        this.PreviewSizeMenu.Add("小（260 × 420）",
            ObjBindMethod(this, "SetPreviewSize", 260, 420))
        this.PreviewSizeMenu.Add("中（320 × 520）",
            ObjBindMethod(this, "SetPreviewSize", 320, 520))
        this.PreviewSizeMenu.Add("大（400 × 650）",
            ObjBindMethod(this, "SetPreviewSize", 400, 650))
        this.PreviewSizeMenu.Add()
        this.PreviewSizeMenu.Add("正方形（512 × 512）",
            ObjBindMethod(this, "SetPreviewSize", 512, 512))
        this.PreviewSizeMenu.Add("正方形（768 × 768）",
            ObjBindMethod(this, "SetPreviewSize", 768, 768))
        this.PreviewSizeMenu.Add("竖版（512 × 768）",
            ObjBindMethod(this, "SetPreviewSize", 512, 768))
        this.PreviewSizeMenu.Add("横版（768 × 512）",
            ObjBindMethod(this, "SetPreviewSize", 768, 512))

        this.SettingsMenu := Menu()
        this.SettingsMenu.Add("更换当前标签目录…",
            ObjBindMethod(this, "ChangeCurrentDirectory"))
        this.SettingsMenu.Add("重命名当前标签…",
            ObjBindMethod(this, "RenameCurrentSource"))
        this.SettingsMenu.Add("打开当前目录",
            ObjBindMethod(this, "OpenCurrentDirectory"))
        screenshotLabel := this.Sources[this.Sources.Length - 1].Name
        this.SettingsMenu.Add("导入图片到“" screenshotLabel "”…",
            ObjBindMethod(this, "ImportImagesFromDialog"))
        this.SettingsMenu.Add("预览窗口大小", this.PreviewSizeMenu)
        this.SettingsMenu.Add()
        this.SettingsMenu.Add("修改素材栏名称…",
            ObjBindMethod(this, "ConfigureBarTitle"))
        this.SettingsMenu.Add("界面字体…",
            ObjBindMethod(this, "ConfigureUIFont"))
        this.SettingsMenu.Add("普通素材标签数量…",
            ObjBindMethod(this, "ConfigureSourceCount"))
        this.SettingsMenu.Add()
        this.SettingsMenu.Add("编辑配置文件",
            ObjBindMethod(this, "OpenConfig"))
        this.SettingsMenu.Add("重新载入应用", (*) => Reload())
        this.SettingsMenu.Add()
        this.SettingsMenu.Add("退出", (*) => ExitApp())
    }

    BuildWindow() {
        options := "+Resize +MinSize" this.MinWindowWidth
            . "x52 +MaxSize2400x52 -Caption +Border +E0x40000"
        if this.AlwaysOnTop
            options .= " +AlwaysOnTop"
        this.Window := Gui(options, this.BarTitle)
        this.Window.BackColor := "F7F8FA"
        this.Window.SetFont("s" this.UIFontSize, this.UIFontName)
        this.Window.MarginX := 0
        this.Window.MarginY := 0

        contentOptions := "+Resize +MinSize" this.MinWindowWidth
            . "x320 -Caption +Border +ToolWindow"
        if this.AlwaysOnTop
            contentOptions .= " +AlwaysOnTop"
        this.ContentWindow := Gui(contentOptions,
            this.BarTitle " · 素材展示")
        this.ContentWindow.BackColor := "F7F8FA"
        this.ContentWindow.SetFont("s" this.UIFontSize, this.UIFontName)
        this.ContentWindow.MarginX := 0
        this.ContentWindow.MarginY := 0

        this.List := this.ContentWindow.AddListView(
            "x10 y10 w1060 h535 Icon Multi -Border -E0x200 BackgroundFFFFFF",
            ["名称", "类型 / 摘要", "修改时间", "路径"])
        this.List.ModifyCol(1, 220)
        this.List.ModifyCol(2, 220)
        this.List.ModifyCol(3, 130)
        this.List.ModifyCol(4, 340)
        DllCall("user32\SendMessageW", "ptr", this.List.Hwnd,
            "uint", 0x1036, "ptr", 0x10000, "ptr", 0x10000)

        this.BackButton := this.ContentWindow.AddButton(
            "x10 y554 w32 h28", "←")
        this.PathText := this.ContentWindow.AddText(
            "x48 y554 w570 h28 BackgroundTrans c64748B +0x200", "")
        this.Status := this.ContentWindow.AddText(
            "x620 y526 w300 h22 Center BackgroundTrans c64748B +0x200",
            "准备就绪")
        this.TextCaptureButton := this.ContentWindow.AddButton(
            "x878 y554 w84 h28 Hidden", "收集：开")
        this.RefreshButton := this.ContentWindow.AddButton(
            "x968 y556 w36 h24", Chr(0xE72C))
        this.ViewButton := this.ContentWindow.AddButton(
            "x1008 y556 w36 h24", Chr(0xE80A))
        for button in [this.RefreshButton, this.ViewButton]
            button.SetFont("s9", "Segoe MDL2 Assets")

        this.Title := this.Window.AddText(
            "x0 y0 w" this.TitleWidth
                . " h52 Center BackgroundTrans c182230 +0x200",
            this.BarTitle)
        this.Title.SetFont("s" (this.UIFontSize + 1) " Bold",
            this.UIFontName)

        for index, source in this.Sources {
            button := this.Window.AddCheckbox("x" (this.TitleWidth + 6)
                . " y6 w110 h40 +0x1000 Center", source.Name)
            button.OnEvent("Click",
                ObjBindMethod(this, "ActivateSourceTab", index))
            this.SourceButtons.Push(button)
        }

        ; Compact action rail requested for the far-right edge of the bar.
        this.PinButton := this.Window.AddButton("x1034 y1 w36 h24", "")
        this.MenuButton := this.Window.AddButton("x1034 y27 w36 h24",
            Chr(0xE713))
        this.PinButton.SetFont("s9", "Segoe MDL2 Assets")
        this.MenuButton.SetFont("s9", "Segoe MDL2 Assets")

        this.ContentControls := [this.BackButton, this.PathText,
            this.TextCaptureButton, this.RefreshButton, this.ViewButton,
            this.List, this.Status]

        this.BackButton.OnEvent("Click", ObjBindMethod(this, "GoBack"))
        this.RefreshButton.OnEvent("Click", ObjBindMethod(this, "Refresh"))
        this.TextCaptureButton.OnEvent("Click",
            ObjBindMethod(this, "ToggleTextCapture"))
        this.PinButton.OnEvent("Click", ObjBindMethod(this, "ToggleAlwaysOnTop"))
        this.ViewButton.OnEvent("Click", (*) => this.ViewMenu.Show())
        this.MenuButton.OnEvent("Click", (*) => this.SettingsMenu.Show())
        this.List.OnEvent("DoubleClick", ObjBindMethod(this, "OnDoubleClick"))
        this.List.OnEvent("Click", ObjBindMethod(this, "OnListClick"))
        this.List.OnEvent("ContextMenu", ObjBindMethod(this, "OnContextMenu"))
        this.Window.OnEvent("ContextMenu",
            ObjBindMethod(this, "OnWindowContextMenu"))
        this.Window.OnEvent("Size", ObjBindMethod(this, "OnSize"))
        this.Window.OnEvent("Close", ObjBindMethod(this, "OnClose"))
        this.Window.OnEvent("Escape", ObjBindMethod(this, "OnEscape"))
        this.ContentWindow.OnEvent("DropFiles",
            ObjBindMethod(this, "OnDropFiles"))
        this.ContentWindow.OnEvent("Size", ObjBindMethod(this, "OnSize"))
        this.ContentWindow.OnEvent("Close",
            (*) => this.SetExpanded(false))
        this.ContentWindow.OnEvent("Escape",
            (*) => this.SetExpanded(false))
        this.BuildPreviewWindow()
        this.SetWindowIcon()
        this.ApplyRoundedCorners(this.Window)
        this.ApplyRoundedCorners(this.ContentWindow)
        this.UpdatePinButton()
    }

    SetWindowIcon() {
        for size in [32, 16] {
            try {
                icon := LoadPicture(this.AssetDir "\app.ico",
                    "Icon1 w" size " h" size, &imageType)
                if icon {
                    this.AppIconHandles.Push(icon)
                    DllCall("user32\SendMessageW", "ptr", this.Window.Hwnd,
                        "uint", 0x0080, "ptr", size = 32 ? 1 : 0,
                        "ptr", icon)
                }
            }
        }
    }

    BuildPreviewWindow() {
        options := "+Owner" this.ContentWindow.Hwnd
        options .= " -Caption +ToolWindow +Resize +MinSize240x360"
        options .= " +E0x08000000 +AlwaysOnTop"
        this.PreviewWindow := Gui(options, "素材预览")
        this.PreviewWindow.BackColor := "F7F8FA"
        this.PreviewWindow.SetFont("s" this.UIFontSize, this.UIFontName)
        this.PreviewWindow.MarginX := 0
        this.PreviewWindow.MarginY := 0
        this.PreviewTitle := this.PreviewWindow.AddText(
            "x14 y10 w242 h26 c172033 +0x200", "")
        this.PreviewTitle.SetFont("s10 Bold")
        this.PreviewImage := this.PreviewWindow.AddPicture(
            "x14 y44 w242 h260 +Border Hidden", "")
        this.PreviewText := this.PreviewWindow.AddEdit(
            "x14 y44 w242 h260 ReadOnly Multi WantReturn -Wrap +VScroll c334155",
            "")
        this.PreviewMetaLabel := this.PreviewWindow.AddText(
            "x14 y312 w242 h24 c475569 +0x200", "属性信息")
        this.PreviewMetaLabel.SetFont("Bold")
        this.PreviewMeta := this.PreviewWindow.AddEdit(
            "x14 y338 w242 h104 ReadOnly Multi WantReturn -Wrap +VScroll c64748B",
            "")
        this.PreviewWindow.OnEvent("Size",
            ObjBindMethod(this, "OnPreviewSize"))
        this.ApplyRoundedCorners(this.PreviewWindow)
    }

    InstallInteractions() {
        this.HotkeyCallback := ObjBindMethod(this, "Toggle")
        try Hotkey(this.HotkeyName, this.HotkeyCallback)
        catch as error {
            this.HotkeyName := "F3"
            Hotkey(this.HotkeyName, this.HotkeyCallback)
            MsgBox("配置的快捷键无效，已改用 F3。`n`n" error.Message,
                "Vic快捷栏", "Icon!")
        }
        this.MouseDownCallback := ObjBindMethod(this, "OnMouseDown")
        this.MouseMoveCallback := ObjBindMethod(this, "OnMouseMove")
        this.MouseUpCallback := ObjBindMethod(this, "OnMouseUp")
        this.MouseLeaveCallback := ObjBindMethod(this, "OnMouseLeave")
        this.NotifyCallback := ObjBindMethod(this, "OnNotify")
        this.SizeMoveCallback := ObjBindMethod(this, "OnSizeMoveMessage")
        OnMessage(0x0201, this.MouseDownCallback)
        OnMessage(0x0200, this.MouseMoveCallback)
        OnMessage(0x0202, this.MouseUpCallback)
        OnMessage(0x02A3, this.MouseLeaveCallback)
        OnMessage(0x004E, this.NotifyCallback)
        OnMessage(0x0231, this.SizeMoveCallback) ; WM_ENTERSIZEMOVE
        OnMessage(0x0232, this.SizeMoveCallback) ; WM_EXITSIZEMOVE

        this.ForegroundTimer := ObjBindMethod(this, "TrackForeground")
        SetTimer(this.ForegroundTimer, 250)
        this.HistoryRefreshTimer := ObjBindMethod(this, "AutoRefreshHistory")
        SetTimer(this.HistoryRefreshTimer, 1500)
        this.ClipboardCallback := ObjBindMethod(this, "HandleClipboardChange")
        OnClipboardChange(this.ClipboardCallback)
        SetTimer(ObjBindMethod(this, "CaptureClipboardText"), -180)
        SetTimer(ObjBindMethod(this, "CaptureClipboardImage"), -240)
    }

    ConfigureTray() {
        try TraySetIcon(this.AssetDir "\tray.ico")
        A_IconTip := this.BarTitle
        A_TrayMenu.Delete()
        A_TrayMenu.Add("显示 / 隐藏（" this.HotkeyName "）",
            ObjBindMethod(this, "Toggle"))
        A_TrayMenu.Add("置顶窗口", ObjBindMethod(this, "ToggleAlwaysOnTop"))
        A_TrayMenu.Add("打开配置", ObjBindMethod(this, "OpenConfig"))
        A_TrayMenu.Add()
        A_TrayMenu.Add("退出", (*) => ExitApp())
        A_TrayMenu.Default := "显示 / 隐藏（" this.HotkeyName "）"
    }

    Show(*) {
        targetWidth := Max(this.WindowWidth, this.MinWindowWidth)
        this.WindowWidth := targetWidth
        this.BeginProgrammaticSize()
        this.Window.Show("w" targetWidth " h" this.BarHeight)
        this.HasShownWindow := true
        if this.Expanded {
            this.ShowContentWindow()
            SetTimer(this.WindowPairTimer, 30)
        }
        WinActivate("ahk_id " this.Window.Hwnd)
    }

    BeginProgrammaticSize() {
        this.IgnoreSizePersistence := true
        SetTimer(ObjBindMethod(this, "EndProgrammaticSize"), -150)
    }

    EndProgrammaticSize(*) {
        this.IgnoreSizePersistence := false
    }

    Hide(*) {
        this.SaveWindowState()
        SetTimer(this.WindowPairTimer, 0)
        try this.PreviewWindow.Hide()
        try this.ContentWindow.Hide()
        this.Window.Hide()
    }

    Toggle(*) {
        if DllCall("user32\IsWindowVisible", "ptr", this.Window.Hwnd, "int")
            this.Hide()
        else
            this.Show()
    }

    OnClose(*) {
        this.Hide()
        return true
    }

    OnEscape(*) {
        if this.Expanded
            this.SetExpanded(false)
        else
            this.Hide()
    }

    TrackForeground(*) {
        hwnd := WinExist("A")
        if hwnd && hwnd != this.Window.Hwnd
            && hwnd != this.ContentWindow.Hwnd
            && hwnd != this.PreviewWindow.Hwnd
            this.ReturnWindow := hwnd
    }

    SelectSource(index, *) {
        if index < 1 || index > this.Sources.Length
            return
        this.CurrentSourceIndex := index
        source := this.Sources[index]
        displayPath := source.Kind = "text"
            ? "剪贴板文字（未收藏内容关闭程序后清空）" : source.Path
        this.RootPath := displayPath
        this.CurrentPath := displayPath
        IniWrite(index, this.ConfigPath, "General", "LastSource")
        this.UpdateSourceButtons()
        this.UpdateTextCaptureButton()
        this.Refresh()
    }

    ActivateSourceTab(index, *) {
        if this.Expanded && index = this.CurrentSourceIndex {
            this.SetExpanded(false)
            return
        }
        this.SelectSource(index)
        this.SetExpanded(true)
    }

    SetExpanded(expanded) {
        if expanded = this.Expanded
            return
        this.Expanded := expanded
        this.UpdateSourceButtons()
        if expanded {
            this.ShowContentWindow()
            SetTimer(this.WindowPairTimer, 30)
            this.Refresh()
        } else {
            SetTimer(this.WindowPairTimer, 0)
            this.HoverRow := 0
            this.ShowEmptyPreview()
            this.PreviewWindow.Hide()
            this.ContentWindow.Hide()
        }
    }

    ShowContentWindow() {
        barRect := this.GetWindowRectangle(this.Window.Hwnd)
        if !IsObject(barRect)
            return
        desiredHeight := Max(320,
            this.WindowHeight - this.BarHeight - this.PanelGap)
        workArea := this.GetMonitorWorkAreaForWindow(this.Window.Hwnd)
        workTop := IsObject(workArea) ? workArea.Top : 0
        availableHeight := barRect.Top - workTop - this.PanelGap
        contentHeight := availableHeight >= 320
            ? Min(desiredHeight, availableHeight) : 320
        contentY := Max(workTop,
            barRect.Top - this.PanelGap - contentHeight)
        this.SyncingWindows := true
        this.BeginProgrammaticSize()
        try {
            this.ContentWindow.Show("NA x" barRect.Left
                . " y" contentY " w" barRect.Width
                . " h" contentHeight)
            this.SetOuterWindowPosition(this.ContentWindow.Hwnd,
                barRect.Left, contentY, barRect.Width, contentHeight)
        } finally {
            this.SyncingWindows := false
        }
        this.LayoutContentWindow()
        this.UpdateTextCaptureButton()
    }

    SyncContentToBar(*) {
        if !this.Expanded || this.SyncingWindows
            || !DllCall("user32\IsWindowVisible",
                "ptr", this.ContentWindow.Hwnd, "int")
            return
        barRect := this.GetWindowRectangle(this.Window.Hwnd)
        contentRect := this.GetWindowRectangle(this.ContentWindow.Hwnd)
        if !IsObject(barRect) || !IsObject(contentRect)
            return
        targetY := barRect.Top - this.PanelGap - contentRect.Height
        if contentRect.Left = barRect.Left
            && contentRect.Top = targetY
            && contentRect.Width = barRect.Width
            return
        this.SyncingWindows := true
        try this.SetOuterWindowPosition(this.ContentWindow.Hwnd,
            barRect.Left, targetY, barRect.Width, contentRect.Height)
        finally this.SyncingWindows := false
    }

    SyncBarToContent() {
        if !this.Expanded || this.SyncingWindows
            return
        contentRect := this.GetWindowRectangle(this.ContentWindow.Hwnd)
        barRect := this.GetWindowRectangle(this.Window.Hwnd)
        if !IsObject(contentRect) || !IsObject(barRect)
            return
        this.SyncingWindows := true
        try this.SetOuterWindowPosition(this.Window.Hwnd,
            contentRect.Left, contentRect.Bottom + this.PanelGap,
            contentRect.Width, barRect.Height)
        finally this.SyncingWindows := false
    }

    GetWindowRectangle(hwnd) {
        rect := Buffer(16, 0)
        if !DllCall("user32\GetWindowRect", "ptr", hwnd,
            "ptr", rect.Ptr, "int")
            return 0
        left := NumGet(rect, 0, "int")
        top := NumGet(rect, 4, "int")
        right := NumGet(rect, 8, "int")
        bottom := NumGet(rect, 12, "int")
        return {Left: left, Top: top, Right: right, Bottom: bottom,
            Width: right - left, Height: bottom - top}
    }

    GetMonitorWorkAreaForWindow(hwnd) {
        monitor := DllCall("user32\MonitorFromWindow", "ptr", hwnd,
            "uint", 2, "ptr") ; MONITOR_DEFAULTTONEAREST
        if !monitor
            return 0
        info := Buffer(40, 0)
        NumPut("uint", 40, info, 0)
        if !DllCall("user32\GetMonitorInfoW", "ptr", monitor,
            "ptr", info.Ptr, "int")
            return 0
        left := NumGet(info, 20, "int")
        top := NumGet(info, 24, "int")
        right := NumGet(info, 28, "int")
        bottom := NumGet(info, 32, "int")
        return {Left: left, Top: top, Right: right, Bottom: bottom,
            Width: right - left, Height: bottom - top}
    }

    SetOuterWindowPosition(hwnd, x, y, width, height) {
        return DllCall("user32\SetWindowPos", "ptr", hwnd, "ptr", 0,
            "int", x, "int", y, "int", width, "int", height,
            "uint", 0x14, "int")
    }

    UpdateTextCaptureButton() {
        if !HasProp(this, "TextCaptureButton")
            return
        isTextSource := this.Sources[this.CurrentSourceIndex].Kind = "text"
        this.TextCaptureButton.Visible := isTextSource
        this.TextCaptureButton.Text := this.TextCaptureEnabled
            ? "收集：开" : "收集：关"
    }

    ToggleTextCapture(*) {
        this.TextCaptureEnabled := !this.TextCaptureEnabled
        this.UpdateTextCaptureButton()
        this.Status.Text := this.TextCaptureEnabled
            ? "已开启文字收集（仅本次运行）"
            : "已暂停文字收集；复制密码等敏感内容时更安全"
    }

    UpdateSourceButtons() {
        for index, button in this.SourceButtons {
            selected := index = this.CurrentSourceIndex
            button.Text := this.Sources[index].Name
            button.Value := selected && this.Expanded ? 1 : 0
            button.SetFont(selected && this.Expanded ? "Bold" : "Norm")
        }
    }

    Refresh(*) {
        source := this.Sources[this.CurrentSourceIndex]
        this.HoverRow := 0
        if this.Expanded
            this.ShowEmptyPreview("将鼠标移到素材上",
                "鼠标悬停即可预览；双击文件夹可进入。")
        this.List.Opt("-Redraw")
        this.List.Delete()
        this.Items := Map()
        this.RebuildImageList()
        try {
            if source.Kind = "text"
                items := this.GetMemoryTextItems()
            else if source.Kind = "screenshots"
                items := this.ScanScreenshotItems(source.Path)
            else
                items := this.ScanDirectory(this.CurrentPath)
            for item in items
                this.AddItem(item)
            this.PathText.Text := this.CurrentPath
            this.BackButton.Enabled := source.Kind != "text"
                && StrLower(this.CurrentPath) != StrLower(this.RootPath)
            if source.Kind = "screenshots" || source.Kind = "text"
                this.Status.Text := items.Length
                    ? (source.Kind = "text"
                        ? "共 " items.Length " 条 · 单击即可复制"
                        : "共 " items.Length " 项 · 可拖动 / 右键管理")
                    : (source.Kind = "text"
                        ? (this.TextCaptureEnabled
                            ? "复制文字后会自动出现；敏感内容请及时删除"
                            : "文字收集已暂停；点击“收集：关”重新开启")
                        : "等待截图目录中出现新图片")
            else
                this.Status.Text := items.Length
                    ? "共 " items.Length " 项 · 拖动素材可直接上传"
                    : "这里还没有素材 · 可从“设置”更换目录"
            this.Window.Title := this.BarTitle " · " source.Name
            this.ContentWindow.Title := this.BarTitle " · " source.Name
            if source.Kind = "screenshots"
                this.LastHistoryFingerprint := this.ComputeHistoryFingerprint(
                    source.Kind)
        } catch as error {
            this.PathText.Text := this.CurrentPath
            this.Status.Text := "无法读取目录：" error.Message
            this.ShowEmptyPreview("目录不可用", this.CurrentPath
                "`r`n`r`n请从“设置 → 更换当前标签目录”重新选择。")
        } finally {
            this.List.Opt("+Redraw")
        }
    }

    ScanDirectory(path) {
        if !DirExist(path)
            throw Error("目录不存在")
        items := []
        Loop Files, path "\*", "FD" {
            if InStr(A_LoopFileAttrib, "H") || InStr(A_LoopFileAttrib, "S")
                continue
            isDirectory := InStr(A_LoopFileAttrib, "D") != 0
            modified := ""
            try modified := FileGetTime(A_LoopFileFullPath, "M")
            extension := ""
            if !isDirectory
                SplitPath(A_LoopFileName, , , &extension)
            items.Push({Kind: isDirectory ? "folder" : "file",
                Name: A_LoopFileName, Path: A_LoopFileFullPath,
                Extension: StrLower(extension), Modified: modified,
                IsDir: isDirectory})
            if items.Length >= 1000
                break
        }
        this.SortItems(items)
        return items
    }

    ScanScreenshotItems(path) {
        if !DirExist(path)
            throw Error("截图目录不存在")
        items := []
        Loop Files, path "\*", "F" {
            if !this.IsImage(A_LoopFileFullPath)
                continue
            SplitPath(A_LoopFileName, , , &extension)
            modified := ""
            try modified := FileGetTime(A_LoopFileFullPath, "M")
            items.Push({Kind: "file", Name: A_LoopFileName,
                Path: A_LoopFileFullPath, Extension: StrLower(extension),
                Modified: modified, IsDir: false})
        }
        for item in this.ClipboardImageItems
            if FileExist(item.Path)
                items.Push(item)
        return this.PrepareHistoryItems(items, "screenshots")
    }

    GetMemoryTextItems() {
        items := []
        for item in this.FavoriteTextItems
            items.Push(item)
        for item in this.MemoryTextItems
            items.Push(item)
        return items
    }

    BuildTextItem(content, persistent := false, path := "",
            color := "", modified := "") {
        excerpt := RegExReplace(Trim(content), "\s+", " ")
        if StrLen(excerpt) > 20
            excerpt := SubStr(excerpt, 1, 19) "…"
        if color = ""
            color := this.TextColorKeys[
                Mod(this.MemoryTextItems.Length
                    + this.FavoriteTextItems.Length,
                    this.TextColorKeys.Length) + 1]
        if modified = ""
            modified := FormatTime(, "yyyyMMddHHmmss")
        return {Kind: "text", Name: excerpt, Path: path,
            Extension: "", Modified: modified, IsDir: false,
            Excerpt: excerpt, Content: content,
            Favorite: persistent, Persistent: persistent,
            Color: this.NormalizeTextColor(color)}
    }

    NormalizeTextColor(color) {
        color := StrLower(Trim(color))
        return this.TextFillColors.Has(color) ? color : "yellow"
    }

    WriteFavoriteText(item) {
        DirCreate(this.FavoriteTextDir)
        if !HasProp(item, "Path") || item.Path = "" {
            base := this.FavoriteTextDir "\favorite-"
                . FormatTime(, "yyyyMMdd-HHmmss") "-" A_MSec
            path := base ".clip"
            suffix := 1
            while FileExist(path) {
                path := base "-" suffix ".clip"
                suffix += 1
            }
            item.Path := path
        }
        file := FileOpen(item.Path, "w", "UTF-8")
        if !IsObject(file)
            throw Error("无法保存收藏文字")
        file.Write("COLOR=" this.NormalizeTextColor(item.Color)
            . "`r`n`r`n" item.Content)
        file.Close()
        item.Modified := FormatTime(, "yyyyMMddHHmmss")
        item.Persistent := true
        item.Favorite := true
    }

    ToggleTextFavorite(item, *) {
        try {
            if HasProp(item, "Persistent") && item.Persistent {
                this.RemoveTextItemFromArray(this.FavoriteTextItems, item)
                if item.Path != "" && FileExist(item.Path)
                    FileDelete(item.Path)
                item.Path := ""
                item.Persistent := false
                item.Favorite := false
                this.MemoryTextItems.InsertAt(1, item)
                message := "已取消收藏；这条文字将在关闭程序后清空"
            } else {
                this.RemoveTextItemFromArray(this.MemoryTextItems, item)
                this.WriteFavoriteText(item)
                this.FavoriteTextItems.InsertAt(1, item)
                message := "已收藏到本地，可在下次启动继续使用"
            }
            this.Refresh()
            this.Status.Text := message
        } catch as error {
            this.Status.Text := "收藏操作失败：" error.Message
        }
    }

    SetTextColor(item, color, *) {
        item.Color := this.NormalizeTextColor(color)
        try {
            if HasProp(item, "Persistent") && item.Persistent
                this.WriteFavoriteText(item)
            this.Refresh()
            this.Status.Text := "便签颜色已改为“"
                . this.TextColorLabels[item.Color] "”"
        } catch as error {
            this.Status.Text := "颜色保存失败：" error.Message
        }
    }

    RemoveTextItemFromArray(items, target) {
        Loop items.Length {
            if ObjPtr(items[A_Index]) = ObjPtr(target) {
                items.RemoveAt(A_Index)
                return true
            }
        }
        return false
    }

    DeleteTextItems(items, *) {
        textItems := []
        for item in items
            if item.Kind = "text"
                textItems.Push(item)
        if !textItems.Length
            return
        answer := MsgBox("确定删除选中的 " textItems.Length
            . " 条文字吗？收藏文字会从本地移除。",
            "删除文字", "YesNo Icon!")
        if answer != "Yes"
            return
        failed := 0
        for item in textItems {
            this.RemoveTextItemFromArray(this.MemoryTextItems, item)
            this.RemoveTextItemFromArray(this.FavoriteTextItems, item)
            if HasProp(item, "Persistent") && item.Persistent
                && item.Path != "" && FileExist(item.Path) {
                try FileRecycle(item.Path)
                catch
                    failed += 1
            }
        }
        this.ShowEmptyPreview()
        this.Refresh()
        this.Status.Text := failed
            ? "文字已移除；有 " failed " 个收藏文件未能删除"
            : "已删除 " textItems.Length " 条文字"
    }

    OpenTextEditor(item, *) {
        editor := Gui("+Owner" this.ContentWindow.Hwnd,
            "编辑文字块")
        editor.BackColor := "F7F8FA"
        editor.SetFont("s" this.UIFontSize, this.UIFontName)
        editor.MarginX := 14
        editor.MarginY := 14
        editor.AddText("w500 c475569", "编辑完整内容：")
        edit := editor.AddEdit("xm y+8 w500 h260 Multi WantReturn",
            this.ReadItemText(item))
        editor.AddText("xm y+8 w360 cB45309",
            "请勿长期收藏密码、验证码或其他敏感信息。")
        save := editor.AddButton("xm+336 y+10 w78 h32 Default", "保存")
        cancel := editor.AddButton("x+8 yp w78 h32", "取消")
        save.OnEvent("Click", ObjBindMethod(this,
            "SaveTextEdit", editor, edit, item))
        cancel.OnEvent("Click", (*) => editor.Destroy())
        editor.OnEvent("Escape", (*) => editor.Destroy())
        editor.OnEvent("Close", (*) => editor.Destroy())
        this.TextEditors.Push(editor)
        this.ApplyRoundedCorners(editor)
        editor.Show("AutoSize")
        edit.Focus()
    }

    SaveTextEdit(editor, edit, item, *) {
        content := edit.Value
        if Trim(content) = "" {
            MsgBox("文字内容不能为空。", "编辑文字块", "Icon!")
            return
        }
        excerpt := RegExReplace(Trim(content), "\s+", " ")
        if StrLen(excerpt) > 20
            excerpt := SubStr(excerpt, 1, 19) "…"
        item.Content := content
        item.Excerpt := excerpt
        item.Name := excerpt
        item.Modified := FormatTime(, "yyyyMMddHHmmss")
        try {
            if HasProp(item, "Persistent") && item.Persistent
                this.WriteFavoriteText(item)
            editor.Destroy()
            this.Refresh()
            this.Status.Text := "文字块已更新"
        } catch as error {
            MsgBox("保存失败：`n`n" error.Message,
                "编辑文字块", "Icon!")
        }
    }

    PrepareHistoryItems(items, kind) {
        favorites := this.Favorites[kind]
        orderMap := Map()
        for index, path in this.HistoryOrders[kind]
            orderMap[StrLower(path)] := index
        favoriteCount := 0
        for item in items {
            key := StrLower(item.Path)
            item.Favorite := favorites.Has(key)
            if item.Favorite
                favoriteCount += 1
            item.OrderIndex := orderMap.Has(key) ? orderMap[key] : 0
        }
        this.SortHistoryItems(items)
        result := []
        visibleLimit := Max(this.HistoryLimit, favoriteCount)
        for item in items {
            if result.Length >= visibleLimit
                break
            result.Push(item)
        }
        return result
    }

    SortHistoryItems(items) {
        Loop items.Length - 1 {
            index := A_Index + 1
            candidate := items[index]
            cursor := index - 1
            while cursor >= 1
                && this.HistoryItemComesAfter(items[cursor], candidate) {
                items[cursor + 1] := items[cursor]
                cursor -= 1
            }
            items[cursor + 1] := candidate
        }
    }

    HistoryItemComesAfter(left, right) {
        if left.Favorite != right.Favorite
            return !left.Favorite && right.Favorite
        if left.OrderIndex && right.OrderIndex
            return left.OrderIndex > right.OrderIndex
        if left.OrderIndex != right.OrderIndex
            return left.OrderIndex && !right.OrderIndex
        if left.Modified != right.Modified {
            if left.Modified = ""
                return true
            if right.Modified = ""
                return false
            return StrCompare(left.Modified, right.Modified) < 0
        }
        return StrCompare(left.Name, right.Name, false) > 0
    }

    SortItems(items) {
        ; Small, stable insertion sort keeps folders before files and avoids
        ; depending on external libraries for this compact first version.
        Loop items.Length - 1 {
            index := A_Index + 1
            candidate := items[index]
            cursor := index - 1
            while cursor >= 1 && this.ItemComesAfter(items[cursor], candidate) {
                items[cursor + 1] := items[cursor]
                cursor -= 1
            }
            items[cursor + 1] := candidate
        }
    }

    ItemComesAfter(left, right) {
        leftRank := left.IsDir ? 0 : 1
        rightRank := right.IsDir ? 0 : 1
        if leftRank != rightRank
            return leftRank > rightRank
        return StrCompare(left.Name, right.Name, false) > 0
    }

    AddItem(item) {
        icon := this.AddItemIcon(item)
        if item.Kind = "text"
            displayName := (HasProp(item, "Favorite") && item.Favorite
                ? "★ " : "") item.Excerpt
        else {
            displayName := item.Name
            if this.ViewMode = "ExtraLarge"
                || this.ViewMode = "Large" || this.ViewMode = "Medium"
                displayName := this.CompactIconName(displayName)
            if HasProp(item, "Favorite") && item.Favorite
                displayName := "★ " displayName
        }
        typeText := item.Kind = "folder" ? "文件夹"
            : item.Kind = "text" ? item.Excerpt
            : (item.Extension != "" ? StrUpper(item.Extension) " 文件" : "文件")
        modifiedText := item.Modified != ""
            ? FormatTime(item.Modified, "yyyy-MM-dd HH:mm") : ""
        options := icon ? "Icon" icon : ""
        row := this.List.Add(options, displayName, typeText,
            modifiedText, item.Path)
        this.Items[row] := item
    }

    RebuildImageList() {
        if this.ImageList {
            this.List.SetImageList(0, 0)
            this.List.SetImageList(0, 1)
            DllCall("comctl32\ImageList_Destroy", "ptr", this.ImageList)
            this.ImageList := 0
        }

        ; Thumbnails are 30% larger than the first layout while keeping the
        ; source aspect ratio through the native image-list loader.
        size := Map("ExtraLarge", 250, "Large", 125,
            "Medium", 83, "Small", 42, "List", 29)[this.ViewMode]
        this.ImageWidth := size
        this.ImageHeight := size
        source := this.Sources[this.CurrentSourceIndex]
        this.TextCardMode := source.Kind = "text"
        if this.TextCardMode {
            this.TextCardWidth := 360
            this.ImageWidth := 1
            this.ImageHeight := 1
        }
        this.ExtensionIconCache := Map()
        this.ImageList := DllCall("comctl32\ImageList_Create",
            "int", this.ImageWidth, "int", this.ImageHeight, "uint", 0x21,
            "int", 32, "int", 24, "ptr")
        this.ImageListType := !this.TextCardMode
            && (this.ViewMode = "Small" || this.ViewMode = "List") ? 1 : 0
        this.List.SetImageList(this.ImageList, this.ImageListType)
        this.ApplyListViewMode()
    }

    ApplyListViewMode() {
        if this.TextCardMode {
            this.List.Opt("+Icon")
            this.List.SetFont("s" (this.UIFontSize + 1),
                this.UIFontName)
            this.UpdateTextCardSpacing()
        } else if this.ViewMode = "ExtraLarge"
            || this.ViewMode = "Large" || this.ViewMode = "Medium" {
            this.List.Opt("+Icon")
            this.List.SetFont("s" Max(6, this.UIFontSize - 3),
                this.UIFontName)
            spacingWidth := this.ImageWidth + 20
            spacingHeight := this.ImageHeight + 36
            spacing := (spacingHeight << 16) | (spacingWidth & 0xFFFF)
            DllCall("user32\SendMessageW", "ptr", this.List.Hwnd,
                "uint", 0x1035, "ptr", 0, "ptr", spacing)
        } else if this.ViewMode = "Small" {
            this.List.Opt("+IconSmall")
            this.List.SetFont("s" Max(7, this.UIFontSize - 2),
                this.UIFontName)
        } else {
            this.List.Opt("+Report")
            this.List.SetFont("s" Max(8, this.UIFontSize - 1),
                this.UIFontName)
        }
    }

    UpdateTextCardSpacing(*) {
        if !this.TextCardMode
            return
        client := Buffer(16, 0)
        if !DllCall("user32\GetClientRect", "ptr", this.List.Hwnd,
            "ptr", client.Ptr, "int")
            return
        clientWidth := NumGet(client, 8, "int")
        if clientWidth < 480
            return
        scale := A_ScreenDPI / 96
        this.TextCardGap := Max(8, Round(10 * scale))
        this.TextCardHeight := Max(42, Round(44 * scale))
        this.TextCardSpacingHeight := this.TextCardHeight
            + this.TextCardGap
        this.TextCardWidth := Floor(clientWidth / 2)
        spacing := (this.TextCardSpacingHeight << 16)
            | (this.TextCardWidth & 0xFFFF)
        DllCall("user32\SendMessageW", "ptr", this.List.Hwnd,
            "uint", 0x1035, "ptr", 0, "ptr", spacing)
        DllCall("user32\InvalidateRect", "ptr", this.List.Hwnd,
            "ptr", 0, "int", true)
    }

    AddItemIcon(item) {
        if !this.ImageList
            return 0
        imagePath := ""
        if item.Kind = "text"
            return 0
        if item.IsDir
            imagePath := this.AssetDir "\empty-folder.ico"
        else if item.Kind = "file" && this.IsImage(item.Path) {
            icon := this.AddAspectImageToList(item.Path)
            if icon
                return icon
            imagePath := item.Path
        }
        else {
            icon := this.AddExtensionBadgeToList(item.Extension)
            if icon
                return icon
            imagePath := this.AssetDir "\app.ico"
        }
        try icon := IL_Add(this.ImageList, imagePath)
        catch
            icon := 0
        if !icon && imagePath != this.AssetDir "\app.ico"
            try icon := IL_Add(this.ImageList, this.AssetDir "\app.ico")
        return icon
    }

    AddExtensionBadgeToList(extension) {
        key := StrLower(Trim(extension, " .`t`r`n"))
        if key = ""
            key := "file"
        if this.ExtensionIconCache.Has(key)
            return this.ExtensionIconCache[key]
        label := StrUpper(SubStr(key, 1, 5))
        width := this.ImageWidth
        height := this.ImageHeight
        screenDC := DllCall("user32\GetDC", "ptr", 0, "ptr")
        if !screenDC
            return 0
        memoryDC := DllCall("gdi32\CreateCompatibleDC",
            "ptr", screenDC, "ptr")
        bitmapInfo := Buffer(40, 0)
        NumPut("uint", 40, bitmapInfo, 0)
        NumPut("int", width, bitmapInfo, 4)
        NumPut("int", -height, bitmapInfo, 8)
        NumPut("ushort", 1, bitmapInfo, 12)
        NumPut("ushort", 32, bitmapInfo, 14)
        bitmapBits := 0
        bitmap := memoryDC ? DllCall("gdi32\CreateDIBSection",
            "ptr", screenDC, "ptr", bitmapInfo.Ptr, "uint", 0,
            "ptr*", &bitmapBits, "ptr", 0, "uint", 0, "ptr") : 0
        if !memoryDC || !bitmap {
            if memoryDC
                DllCall("gdi32\DeleteDC", "ptr", memoryDC)
            DllCall("user32\ReleaseDC", "ptr", 0, "ptr", screenDC)
            return 0
        }
        oldBitmap := DllCall("gdi32\SelectObject",
            "ptr", memoryDC, "ptr", bitmap, "ptr")
        whiteBrush := DllCall("gdi32\CreateSolidBrush",
            "uint", this.ToColorRef(0xFFFFFF), "ptr")
        bodyBrush := DllCall("gdi32\CreateSolidBrush",
            "uint", this.ToColorRef(0xE2E8F0), "ptr")
        pen := DllCall("gdi32\CreatePen", "int", 0,
            "int", Max(1, Round(width / 80)),
            "uint", this.ToColorRef(0x94A3B8), "ptr")
        fontHeight := Max(7, Round(height
            * (StrLen(label) > 4 ? 0.15 : 0.19)))
        font := DllCall("gdi32\CreateFontW",
            "int", -fontHeight, "int", 0, "int", 0, "int", 0,
            "int", 700, "uint", 0, "uint", 0, "uint", 0,
            "uint", 1, "uint", 0, "uint", 0, "uint", 5,
            "uint", 0, "wstr", this.UIFontName, "ptr")
        oldPen := 0
        oldBrush := 0
        oldFont := 0
        maskBitmap := 0
        iconHandle := 0
        try {
            fullRect := Buffer(16, 0)
            NumPut("int", width, fullRect, 8)
            NumPut("int", height, fullRect, 12)
            DllCall("user32\FillRect", "ptr", memoryDC,
                "ptr", fullRect.Ptr, "ptr", whiteBrush)
            left := Max(2, Round(width * 0.12))
            top := Max(1, Round(height * 0.05))
            right := width - left
            bottom := height - top
            oldPen := DllCall("gdi32\SelectObject",
                "ptr", memoryDC, "ptr", pen, "ptr")
            oldBrush := DllCall("gdi32\SelectObject",
                "ptr", memoryDC, "ptr", bodyBrush, "ptr")
            DllCall("gdi32\RoundRect", "ptr", memoryDC,
                "int", left, "int", top, "int", right, "int", bottom,
                "int", Max(4, Round(width * 0.08)),
                "int", Max(4, Round(height * 0.08)))
            oldFont := DllCall("gdi32\SelectObject",
                "ptr", memoryDC, "ptr", font, "ptr")
            DllCall("gdi32\SetBkMode", "ptr", memoryDC, "int", 1)
            DllCall("gdi32\SetTextColor", "ptr", memoryDC,
                "uint", this.ToColorRef(0x334155))
            textRect := Buffer(16, 0)
            NumPut("int", left + 2, textRect, 0)
            NumPut("int", top + 2, textRect, 4)
            NumPut("int", right - 2, textRect, 8)
            NumPut("int", bottom - 2, textRect, 12)
            DllCall("user32\DrawTextW", "ptr", memoryDC,
                "str", label, "int", -1, "ptr", textRect.Ptr,
                "uint", 0x825)
            ; GDI draws RGB into the DIB but leaves its alpha channel at 0.
            ; Explicit alpha avoids the solid black rectangles produced by
            ; 32-bit image lists when a compatible bitmap has no alpha data.
            opaquePixels := 0
            transparentPixels := 0
            Loop width * height {
                offset := (A_Index - 1) * 4
                pixel := NumGet(bitmapBits + offset, 0, "uint")
                rgb := pixel & 0xFFFFFF
                alpha := rgb = 0xFFFFFF ? 0 : 0xFF000000
                if alpha
                    opaquePixels += 1
                else
                    transparentPixels += 1
                ; Fully transparent pixels must also have zeroed RGB for
                ; Windows' premultiplied-alpha icon pipeline.
                NumPut("uint", alpha ? rgb | alpha : 0,
                    bitmapBits + offset, 0)
            }
            this.LastExtensionBadgeOpaquePixels := opaquePixels
            this.LastExtensionBadgeTransparentPixels := transparentPixels
            maskBitmap := DllCall("gdi32\CreateBitmap",
                "int", width, "int", height, "uint", 1,
                "uint", 1, "ptr", 0, "ptr")
            maskOffset := A_PtrSize = 8 ? 16 : 12
            colorOffset := maskOffset + A_PtrSize
            iconInfo := Buffer(colorOffset + A_PtrSize, 0)
            NumPut("int", 1, iconInfo, 0)
            NumPut("ptr", maskBitmap, iconInfo, maskOffset)
            NumPut("ptr", bitmap, iconInfo, colorOffset)
            iconHandle := DllCall("user32\CreateIconIndirect",
                "ptr", iconInfo.Ptr, "ptr")
            imageIndex := iconHandle
                ? DllCall("comctl32\ImageList_ReplaceIcon",
                    "ptr", this.ImageList, "int", -1,
                    "ptr", iconHandle, "int") : -1
            icon := imageIndex >= 0 ? imageIndex + 1 : 0
            this.LastExtensionBadgeRenderedColor := icon
                ? this.MeasureImageListIconColor(icon) : 0
            this.ExtensionIconCache[key] := icon
            return icon
        } finally {
            if iconHandle
                DllCall("user32\DestroyIcon", "ptr", iconHandle)
            if oldFont
                DllCall("gdi32\SelectObject", "ptr", memoryDC,
                    "ptr", oldFont)
            if oldBrush
                DllCall("gdi32\SelectObject", "ptr", memoryDC,
                    "ptr", oldBrush)
            if oldPen
                DllCall("gdi32\SelectObject", "ptr", memoryDC,
                    "ptr", oldPen)
            if oldBitmap
                DllCall("gdi32\SelectObject", "ptr", memoryDC,
                    "ptr", oldBitmap)
            for objectHandle in [font, pen, bodyBrush, whiteBrush,
                    maskBitmap, bitmap]
                if objectHandle
                    DllCall("gdi32\DeleteObject", "ptr", objectHandle)
            DllCall("gdi32\DeleteDC", "ptr", memoryDC)
            DllCall("user32\ReleaseDC", "ptr", 0, "ptr", screenDC)
        }
    }

    MeasureImageListIconColor(icon) {
        screenDC := DllCall("user32\GetDC", "ptr", 0, "ptr")
        memoryDC := screenDC ? DllCall("gdi32\CreateCompatibleDC",
            "ptr", screenDC, "ptr") : 0
        bitmap := memoryDC ? DllCall("gdi32\CreateCompatibleBitmap",
            "ptr", screenDC, "int", this.ImageWidth,
            "int", this.ImageHeight, "ptr") : 0
        if !screenDC || !memoryDC || !bitmap {
            if bitmap
                DllCall("gdi32\DeleteObject", "ptr", bitmap)
            if memoryDC
                DllCall("gdi32\DeleteDC", "ptr", memoryDC)
            if screenDC
                DllCall("user32\ReleaseDC", "ptr", 0, "ptr", screenDC)
            return 0
        }
        oldBitmap := DllCall("gdi32\SelectObject",
            "ptr", memoryDC, "ptr", bitmap, "ptr")
        whiteBrush := DllCall("gdi32\CreateSolidBrush",
            "uint", this.ToColorRef(0xFFFFFF), "ptr")
        rect := Buffer(16, 0)
        NumPut("int", this.ImageWidth, rect, 8)
        NumPut("int", this.ImageHeight, rect, 12)
        result := 0
        try {
            DllCall("user32\FillRect", "ptr", memoryDC,
                "ptr", rect.Ptr, "ptr", whiteBrush)
            DllCall("comctl32\ImageList_Draw", "ptr", this.ImageList,
                "int", icon - 1, "ptr", memoryDC,
                "int", 0, "int", 0, "uint", 0)
            sampleX := Max(3, Round(this.ImageWidth * 0.2))
            sampleY := Max(3, Round(this.ImageHeight * 0.2))
            color := DllCall("gdi32\GetPixel", "ptr", memoryDC,
                "int", sampleX, "int", sampleY, "uint")
            if color != 0 && color != 0xFFFFFFFF
                result := color
        } finally {
            if oldBitmap
                DllCall("gdi32\SelectObject", "ptr", memoryDC,
                    "ptr", oldBitmap)
            if whiteBrush
                DllCall("gdi32\DeleteObject", "ptr", whiteBrush)
            DllCall("gdi32\DeleteObject", "ptr", bitmap)
            DllCall("gdi32\DeleteDC", "ptr", memoryDC)
            DllCall("user32\ReleaseDC", "ptr", 0, "ptr", screenDC)
        }
        return result
    }

    CompactIconName(name) {
        limit := this.ViewMode = "ExtraLarge" ? 28
            : this.ViewMode = "Large" ? 22 : 18
        return StrLen(name) > limit ? SubStr(name, 1, limit - 1) "…" : name
    }

    AddAspectImageToList(path) {
        try {
            ; AutoHotkey delegates this load to the Windows image-list
            ; loader, which scales the source down without cropping it and
            ; handles PNG/BMP alpha reliably.
            return IL_Add(this.ImageList, path)
        } catch
            return 0
    }

    SetViewMode(mode, *) {
        if mode = this.ViewMode
            return
        this.ViewMenu.Uncheck(this.ViewLabels[this.ViewMode])
        this.ViewMode := mode
        this.ViewMenu.Check(this.ViewLabels[this.ViewMode])
        IniWrite(mode, this.ConfigPath, "General", "ViewMode")
        this.Refresh()
    }

    OnDoubleClick(list, row) {
        if row && this.Items.Has(row)
            this.ActivateItem(this.Items[row])
    }

    OnListClick(list, row) {
        source := this.Sources[this.CurrentSourceIndex]
        if source.Kind != "text" || !row || !this.Items.Has(row)
            return
        this.CopyTextItems([this.Items[row]])
    }

    ActivateItem(item) {
        if item.Kind = "folder" {
            this.CurrentPath := this.TrimPath(item.Path)
            this.Refresh()
            return
        }
        if item.Kind = "text" {
            this.CopyTextItems([item])
            return
        }
        try Run(item.Path)
        catch as error
            MsgBox("无法打开此文件。`n`n" error.Message,
                "Vic快捷栏", "Icon!")
    }

    GoBack(*) {
        source := this.Sources[this.CurrentSourceIndex]
        if source.Kind = "text"
            return
        if StrLower(this.CurrentPath) = StrLower(this.RootPath)
            return
        SplitPath(this.CurrentPath, , &parent)
        rootLower := StrLower(this.RootPath)
        parentLower := StrLower(parent)
        if parentLower = rootLower || InStr(parentLower "\", rootLower "\") = 1
            this.CurrentPath := this.TrimPath(parent)
        else
            this.CurrentPath := this.RootPath
        this.Refresh()
    }

    ShowItemPreview(item) {
        this.PreviewTitle.Text := item.Name
        this.UpdatePreviewGeometry()
        if item.Kind = "text" {
            this.PreviewHasImage := false
            this.ClearPreviewBitmap()
            this.PreviewImage.Visible := false
            this.PreviewText.Visible := true
            this.PreviewText.Value := this.ReadItemText(item)
            this.PreviewMeta.Value := this.BuildFileInfo(item)
        } else if item.Kind = "file" && this.IsImage(item.Path) {
            this.PreviewHasImage := true
            this.PreviewText.Visible := false
            try {
                if !this.SetPreviewImage(item.Path)
                    throw Error("无法载入图片")
                this.PreviewImage.Visible := true
            } catch {
                this.PreviewHasImage := false
                this.PreviewImage.Visible := false
                this.PreviewText.Visible := true
                this.PreviewText.Value := "无法生成图片预览。"
            }
            this.PreviewMeta.Value := this.BuildFileInfo(item)
        } else if item.Kind = "folder" {
            this.PreviewHasImage := false
            this.ClearPreviewBitmap()
            this.PreviewImage.Visible := false
            this.PreviewText.Visible := true
            this.PreviewText.Value := this.BuildFolderInfo(item.Path)
            this.PreviewMeta.Value := "文件夹`r`n" item.Path
        } else {
            this.PreviewHasImage := false
            this.ClearPreviewBitmap()
            this.PreviewImage.Visible := false
            this.PreviewText.Visible := true
            this.PreviewText.Value := "双击打开，或直接拖到浏览器和上传区域。"
            this.PreviewMeta.Value := this.BuildFileInfo(item)
        }
        this.ShowFloatingPreview()
    }

    ShowEmptyPreview(*) {
        this.PreviewHasImage := false
        this.ClearPreviewBitmap()
        try this.PreviewWindow.Hide()
    }

    SetPreviewImage(path) {
        this.ClearPreviewBitmap()
        original := 0
        try {
            original := LoadPicture(path, "", &imageType)
            if !original || imageType != 0
                return false
            bitmapInfo := Buffer(A_PtrSize = 8 ? 32 : 24, 0)
            if !DllCall("gdi32\GetObjectW", "ptr", original,
                "int", bitmapInfo.Size, "ptr", bitmapInfo.Ptr, "int")
                return false
            sourceWidth := Abs(NumGet(bitmapInfo, 4, "int"))
            sourceHeight := Abs(NumGet(bitmapInfo, 8, "int"))
            if !sourceWidth || !sourceHeight
                return false
            areaWidth := this.PreviewImageAreaWidth
            areaHeight := this.PreviewImageAreaHeight
            scale := Min(areaWidth / sourceWidth, areaHeight / sourceHeight)
            imageWidth := Max(1, Round(sourceWidth * scale))
            imageHeight := Max(1, Round(sourceHeight * scale))
            imageX := this.PreviewImageAreaX
                + Floor((areaWidth - imageWidth) / 2)
            imageY := this.PreviewImageAreaY
                + Floor((areaHeight - imageHeight) / 2)
            this.PreviewImage.Value := path
            this.PreviewImage.Move(imageX, imageY,
                imageWidth, imageHeight)
            this.PreviewImagePath := path
            return true
        } finally {
            if original
                DllCall("gdi32\DeleteObject", "ptr", original)
        }
    }

    ClearPreviewBitmap() {
        try this.PreviewImage.Value := ""
        this.PreviewBitmap := 0
        this.PreviewImagePath := ""
    }

    BuildFolderInfo(path) {
        lines := ["文件夹", path, "", "包含内容："]
        count := 0
        try {
            Loop Files, path "\*", "FD" {
                if InStr(A_LoopFileAttrib, "H")
                    continue
                count += 1
                if count <= 14
                    lines.Push((InStr(A_LoopFileAttrib, "D") ? "▸ " : "• ")
                        A_LoopFileName)
            }
        }
        if !count
            lines.Push("（空文件夹）")
        else if count > 14
            lines.Push("…另有 " (count - 14) " 项")
        return this.Join(lines, "`r`n")
    }

    BuildFileInfo(item) {
        if item.Kind = "text" && HasProp(item, "Content") {
            persistent := HasProp(item, "Persistent") && item.Persistent
            return (persistent ? "本地收藏文字" : "临时剪贴板文字")
                . "`r`n" (persistent
                    ? "已持久化保存；右键可取消收藏或删除"
                    : "仅保存在本次运行的内存中")
                . "`r`n长度：" StrLen(item.Content) " 字"
                . "`r`n颜色：" this.TextColorLabels[
                    this.NormalizeTextColor(item.Color)]
                . "`r`n`r`n提示：密码、验证码等敏感内容请及时删除。"
        }
        if HasProp(item, "SessionClipboard") && item.SessionClipboard
            return "剪贴板截图`r`n仅保存在本次运行的临时缓存中"
                . "`r`n可直接拖到上传区域"
        lines := [item.Kind = "text" ? "文本" : "文件", item.Path]
        try lines.Push("大小：" this.FormatBytes(FileGetSize(item.Path)))
        try lines.Push("修改：" FormatTime(FileGetTime(item.Path, "M"),
            "yyyy-MM-dd HH:mm:ss"))
        if item.Extension != ""
            lines.Push("类型：" StrUpper(item.Extension))
        return this.Join(lines, "`r`n")
    }

    FormatBytes(bytes) {
        if bytes < 1024
            return bytes " B"
        if bytes < 1048576
            return Format("{:.1f} KB", bytes / 1024)
        if bytes < 1073741824
            return Format("{:.1f} MB", bytes / 1048576)
        return Format("{:.2f} GB", bytes / 1073741824)
    }

    ReadText(path) {
        try {
            file := FileOpen(path, "r", "UTF-8")
            if !IsObject(file)
                return ""
            text := file.Read(524288)
            truncated := !file.AtEOF
            file.Close()
            text := LTrim(text, Chr(0xFEFF))
            return text (truncated ? "`r`n`r`n[内容过长，预览已截断]" : "")
        } catch as error {
            return "无法读取文本：" error.Message
        }
    }

    ReadItemText(item) {
        return HasProp(item, "Content") ? item.Content
            : this.ReadText(item.Path)
    }

    IsImage(path) {
        SplitPath(path, , , &extension)
        return RegExMatch(extension,
            "i)^(?:png|jpe?g|webp|gif|bmp|tif|tiff)$") != 0
    }

    GetSelectedItems(clickedRow := 0) {
        if clickedRow && !this.IsRowSelected(clickedRow) {
            this.List.Modify(0, "-Select")
            this.List.Modify(clickedRow, "Select Focus Vis")
        }
        result := []
        row := 0
        while row := this.List.GetNext(row) {
            if this.Items.Has(row)
                result.Push(this.Items[row])
        }
        if !result.Length && clickedRow && this.Items.Has(clickedRow)
            result.Push(this.Items[clickedRow])
        return result
    }

    CopySelected(*) {
        items := this.GetSelectedItems()
        if !items.Length {
            this.Status.Text := "请先选择素材"
            return
        }
        allText := true
        for item in items
            if item.Kind != "text" {
                allText := false
                break
            }
        if allText
            this.CopyTextItems(items)
        else {
            paths := []
            for item in items
                paths.Push(item.Path)
            this.IgnoreNextClipboardText := true
            A_Clipboard := this.Join(paths, "`r`n")
            this.Status.Text := "已复制 " items.Length " 个素材路径"
        }
    }

    CopyTextItems(items) {
        blocks := []
        for item in items
            blocks.Push(this.ReadItemText(item))
        this.IgnoreNextClipboardText := true
        A_Clipboard := this.Join(blocks, "`r`n`r`n")
        this.Status.Text := "已复制 " items.Length " 条文本"
    }

    DeleteSelected(*) {
        items := this.GetSelectedItems()
        if !items.Length {
            this.Status.Text := "请先选择要删除的素材"
            return
        }
        label := items.Length = 1 ? "“" items[1].Name "”"
            : items.Length " 个素材"
        answer := MsgBox("确定将 " label " 移到回收站吗？",
            "删除素材", "YesNo Icon!")
        if answer != "Yes"
            return

        recycled := 0
        failed := []
        for item in items {
            try {
                FileRecycle(item.Path)
                recycled += 1
                this.RemoveHistoryState(item)
            } catch {
                failed.Push(item.Name)
            }
        }
        this.HoverRow := 0
        this.ShowEmptyPreview()
        this.Refresh()
        if failed.Length {
            this.Status.Text := "已移到回收站 " recycled
            this.Status.Text .= " 项，失败 " failed.Length " 项"
        } else
            this.Status.Text := "已移到回收站 " recycled " 项"
    }

    RemoveHistoryState(item) {
        source := this.Sources[this.CurrentSourceIndex]
        if source.Kind != "screenshots" && source.Kind != "text"
            return
        kind := source.Kind
        key := StrLower(item.Path)
        if this.Favorites[kind].Has(key)
            this.Favorites[kind].Delete(key)
        filtered := []
        for path in this.HistoryOrders[kind]
            if StrLower(path) != key
                filtered.Push(path)
        this.HistoryOrders[kind] := filtered
        this.SaveHistoryState(kind)
    }

    PasteSelected(*) {
        items := this.GetSelectedItems()
        textItems := []
        for item in items
            if item.Kind = "text"
                textItems.Push(item)
        if !textItems.Length {
            this.Status.Text := "请先选择一条文本素材"
            return
        }
        blocks := []
        for item in textItems
            blocks.Push(this.ReadItemText(item))
        text := this.Join(blocks, "`r`n`r`n")
        this.IgnoreNextClipboardText := true
        A_Clipboard := text
        target := this.ReturnWindow
        if !target || !WinExist("ahk_id " target) {
            this.Status.Text := "文字已复制；未找到上一个窗口"
            return
        }
        this.Hide()
        try {
            WinActivate("ahk_id " target)
            WinWaitActive("ahk_id " target, , 1.5)
            Send("^v")
        } catch {
            ; Clipboard still contains the text, so the user can paste manually.
        }
    }

    OnContextMenu(list, row, isRightClick, x, y) {
        if !row || !this.Items.Has(row) {
            context := Menu()
            context.Add("刷新", ObjBindMethod(this, "Refresh"))
            context.Show(x, y)
            return
        }
        items := this.GetSelectedItems(row)
        item := this.Items[row]
        context := Menu()
        if item.Kind = "text" {
            context.Add("编辑文字…",
                ObjBindMethod(this, "OpenTextEditor", item))
            context.Add("复制文字", (*) => this.CopyTextItems(items))
            context.Add("粘贴到上一个窗口",
                ObjBindMethod(this, "PasteSelected"))
            context.Add()
            isFavorite := HasProp(item, "Persistent") && item.Persistent
            context.Add(isFavorite ? "取消收藏" : "收藏到本地",
                ObjBindMethod(this, "ToggleTextFavorite", item))
            colorMenu := Menu()
            for colorKey in this.TextColorKeys {
                label := this.TextColorLabels[colorKey]
                colorMenu.Add(label,
                    ObjBindMethod(this, "SetTextColor", item, colorKey))
                if this.NormalizeTextColor(item.Color) = colorKey
                    colorMenu.Check(label)
            }
            context.Add("便签颜色", colorMenu)
            context.Add()
            context.Add("删除文字",
                ObjBindMethod(this, "DeleteTextItems", items))
        } else {
            context.Add(item.Kind = "folder" ? "进入文件夹" : "打开",
                (*) => this.ActivateItem(item))
            context.Add("在资源管理器中显示",
                (*) => this.RevealInExplorer(item.Path))
            context.Add("复制路径", ObjBindMethod(this, "CopySelected"))
        }
        source := this.Sources[this.CurrentSourceIndex]
        if source.Kind = "screenshots" {
            context.Add()
            isFavorite := HasProp(item, "Favorite") && item.Favorite
            context.Add(isFavorite ? "取消收藏" : "收藏",
                ObjBindMethod(this, "ToggleHistoryFavorite",
                    source.Kind, item))
            context.Add("向前移动",
                ObjBindMethod(this, "MoveHistoryItem", source.Kind, item, -1))
            context.Add("向后移动",
                ObjBindMethod(this, "MoveHistoryItem", source.Kind, item, 1))
        }
        if item.Kind != "text" {
            context.Add()
            context.Add("移到回收站", ObjBindMethod(this, "DeleteSelected"))
        }
        context.Show(x, y)
    }

    ToggleHistoryFavorite(kind, item, *) {
        key := StrLower(item.Path)
        if this.Favorites[kind].Has(key)
            this.Favorites[kind].Delete(key)
        else
            this.Favorites[kind][key] := item.Path
        this.SaveHistoryState(kind)
        this.Refresh()
    }

    MoveHistoryItem(kind, item, direction, *) {
        paths := []
        row := 1
        while this.Items.Has(row) {
            paths.Push(this.Items[row].Path)
            row += 1
        }
        current := 0
        for index, path in paths
            if StrLower(path) = StrLower(item.Path) {
                current := index
                break
            }
        target := current + direction
        if !current || target < 1 || target > paths.Length
            return
        swap := paths[target]
        paths[target] := paths[current]
        paths[current] := swap
        this.HistoryOrders[kind] := paths
        this.SaveHistoryState(kind)
        this.Refresh()
    }

    RevealInExplorer(path) {
        try {
            if DirExist(path)
                Run("explorer.exe `"" path "`"")
            else
                Run("explorer.exe /select,`"" path "`"")
        }
    }

    ToggleAlwaysOnTop(*) {
        this.AlwaysOnTop := !this.AlwaysOnTop
        this.Window.Opt(this.AlwaysOnTop ? "+AlwaysOnTop" : "-AlwaysOnTop")
        this.ContentWindow.Opt(this.AlwaysOnTop
            ? "+AlwaysOnTop" : "-AlwaysOnTop")
        IniWrite(this.AlwaysOnTop ? "1" : "0",
            this.ConfigPath, "General", "AlwaysOnTop")
        this.UpdatePinButton()
    }

    UpdatePinButton() {
        this.PinButton.Text := Chr(this.AlwaysOnTop ? 0xE77A : 0xE718)
    }

    OnWindowContextMenu(guiObj, guiCtrl, item, isRightClick, x, y) {
        if !IsObject(guiCtrl)
            return
        sourceIndex := 0
        for index, button in this.SourceButtons
            if guiCtrl.Hwnd = button.Hwnd {
                sourceIndex := index
                break
            }
        if !sourceIndex
            return
        source := this.Sources[sourceIndex]
        context := Menu()
        context.Add("重命名标签…",
            ObjBindMethod(this, "RenameSource", sourceIndex))
        context.Add()
        if source.Kind = "text" {
            label := "未收藏文字使用内存；收藏文字保存在本地"
            context.Add(label, (*) => 0)
            context.Disable(label)
        } else {
            context.Add("更换指向的文件夹…",
                ObjBindMethod(this, "ChangeSourceDirectory", sourceIndex))
            context.Add("打开指向的文件夹",
                (*) => Run("explorer.exe `"" source.Path "`""))
        }
        context.Show(x, y)
    }

    ChangeCurrentDirectory(*) {
        this.ChangeSourceDirectory(this.CurrentSourceIndex)
    }

    ChangeSourceDirectory(index, *) {
        if index < 1 || index > this.Sources.Length
            return
        source := this.Sources[index]
        if source.Kind = "text" {
            this.Status.Text := "历史文本仅使用内存，无需设置目录"
            return
        }
        ; Prefixing the initial path with * selects it without making it the
        ; dialog root, so the user can navigate to parent and sibling folders.
        selected := DirSelect("*" source.Path, 0,
            "选择“" source.Name "”的素材目录")
        if selected = ""
            return
        source.Path := this.TrimPath(selected)
        this.Sources[index] := source
        IniWrite(source.Path, this.ConfigPath, source.Section, "Path")
        if index = this.CurrentSourceIndex {
            this.RootPath := source.Path
            this.CurrentPath := source.Path
            this.Refresh()
        } else
            this.Status.Text := "已更新“" source.Name "”指向的文件夹"
    }

    RenameCurrentSource(*) {
        this.RenameSource(this.CurrentSourceIndex)
    }

    RenameSource(index, *) {
        if index < 1 || index > this.Sources.Length
            return
        source := this.Sources[index]
        result := InputBox("输入标签名称：", "重命名素材标签",
            "w360 h140", source.Name)
        if result.Result != "OK" || Trim(result.Value) = ""
            return
        source.Name := SubStr(Trim(result.Value), 1, 24)
        this.Sources[index] := source
        IniWrite(source.Name, this.ConfigPath, source.Section, "Name")
        this.UpdateSourceButtons()
        if index = this.CurrentSourceIndex {
            this.Window.Title := this.BarTitle " · " source.Name
            this.ContentWindow.Title := this.Window.Title
        }
    }

    ConfigureBarTitle(*) {
        result := InputBox("输入素材栏左侧显示的名称：",
            "修改素材栏名称", "w400 h150", this.BarTitle)
        title := Trim(result.Value)
        if result.Result != "OK" || title = ""
            return
        this.BarTitle := SubStr(title, 1, 20)
        this.TitleWidth := Max(112,
            Min(200, 40 + StrLen(this.BarTitle) * 14))
        this.MinWindowWidth := Max(760,
            this.TitleWidth + 42 + this.Sources.Length * 96)
        IniWrite(this.BarTitle, this.ConfigPath, "General", "BarTitle")
        this.Title.Text := this.BarTitle
        this.Window.Opt("+Resize +MinSize" this.MinWindowWidth
            . "x52 +MaxSize2400x52")
        this.ContentWindow.Opt("+MinSize" this.MinWindowWidth "x320")
        try {
            this.Window.GetClientPos(, , &clientWidth, &clientHeight)
            this.OnSize(this.Window, 0, clientWidth, clientHeight)
            this.ContentWindow.GetClientPos(, ,
                &contentWidth, &contentHeight)
            this.OnSize(this.ContentWindow, 0,
                contentWidth, contentHeight)
        }
        A_IconTip := this.BarTitle
        this.Window.Title := this.BarTitle " · "
            . this.Sources[this.CurrentSourceIndex].Name
        this.ContentWindow.Title := this.Window.Title
    }

    ConfigureUIFont(*) {
        result := InputBox("输入字体名称和字号，用逗号分隔：`n"
            . "例如：Microsoft YaHei UI, 9",
            "界面字体", "w440 h180",
            this.UIFontName ", " this.UIFontSize)
        if result.Result != "OK"
            return
        if !RegExMatch(Trim(result.Value),
            "^(.*?)[,，]\s*(\d+)$", &match)
            || Trim(match[1]) = "" {
            MsgBox("格式不正确，请使用“字体名称, 字号”。",
                "界面字体", "Icon!")
            return
        }
        fontSize := Integer(match[2])
        if fontSize < 8 || fontSize > 14 {
            MsgBox("字号请输入 8–14 之间的整数。",
                "界面字体", "Icon!")
            return
        }
        answer := MsgBox("应用新字体需要重新载入。`n"
            . "未收藏的临时文字会被清空，是否继续？",
            "界面字体", "YesNo Icon!")
        if answer != "Yes"
            return
        IniWrite(Trim(match[1]), this.ConfigPath,
            "General", "UIFontName")
        IniWrite(fontSize, this.ConfigPath, "General", "UIFontSize")
        Reload()
    }

    ConfigureSourceCount(*) {
        currentCount := this.Sources.Length - 2
        result := InputBox("普通文件夹标签数量（1–10）：",
            "普通素材标签数量", "w380 h150", currentCount)
        if result.Result != "OK"
            return
        try count := Integer(Trim(result.Value))
        catch {
            MsgBox("请输入 1–10 之间的整数。",
                "普通素材标签数量", "Icon!")
            return
        }
        if count < 1 || count > 10 {
            MsgBox("请输入 1–10 之间的整数。",
                "普通素材标签数量", "Icon!")
            return
        }
        if count = currentCount
            return
        answer := MsgBox("调整标签数量需要重新载入。`n"
            . "未收藏的临时文字会被清空，是否继续？",
            "普通素材标签数量", "YesNo Icon!")
        if answer != "Yes"
            return
        IniWrite(count, this.ConfigPath, "Sources", "Count")
        Loop count {
            section := "Source" A_Index
            if Trim(IniRead(this.ConfigPath, section, "Name", "")) = ""
                IniWrite("文件夹" A_Index, this.ConfigPath,
                    section, "Name")
            if Trim(IniRead(this.ConfigPath, section, "Path", "")) = ""
                IniWrite("%USERPROFILE%\Desktop", this.ConfigPath,
                    section, "Path")
        }
        Reload()
    }

    OnDropFiles(guiObj, guiCtrl, files, x, y) {
        source := this.Sources[this.CurrentSourceIndex]
        if source.Kind != "screenshots" {
            screenshotName := this.Sources[this.Sources.Length - 1].Name
            this.Status.Text := "请先切换到“" screenshotName
                . "”再拖入图片"
            return
        }
        this.ImportImages(files)
    }

    ImportImagesFromDialog(*) {
        screenshotSource := this.Sources[this.Sources.Length - 1]
        selected := FileSelect("M", screenshotSource.Path,
            "导入图片", "图片 (*.png; *.jpg; *.jpeg; *.webp; *.gif; *.bmp; *.tif; *.tiff)")
        if !selected
            return
        if !IsObject(selected)
            selected := [selected]
        this.ImportImages(selected)
    }

    ImportImages(paths) {
        screenshotIndex := this.Sources.Length - 1
        targetRoot := this.Sources[screenshotIndex].Path
        try DirCreate(targetRoot)
        imported := 0
        skipped := 0
        for path in paths {
            if !FileExist(path) || DirExist(path) || !this.IsImage(path) {
                skipped += 1
                continue
            }
            SplitPath(path, &fileName, , &extension, &nameNoExt)
            destination := targetRoot "\" fileName
            suffix := 1
            while FileExist(destination) {
                destination := targetRoot "\" nameNoExt " (" suffix ")." extension
                suffix += 1
            }
            try {
                FileCopy(path, destination)
                imported += 1
            } catch {
                skipped += 1
            }
        }
        if this.CurrentSourceIndex != screenshotIndex
            this.SelectSource(screenshotIndex)
        else
            this.Refresh()
        this.SetExpanded(true)
        this.Status.Text := imported ? "已导入 " imported " 张图片"
            . (skipped ? "，跳过 " skipped " 项" : "")
            : "没有可导入的图片"
    }

    HandleClipboardChange(dataType) {
        if dataType = 2 {
            SetTimer(ObjBindMethod(this, "CaptureClipboardImage"), -100)
            return
        }
        if dataType != 1
            return
        if this.IgnoreNextClipboardText {
            this.IgnoreNextClipboardText := false
            return
        }
        SetTimer(ObjBindMethod(this, "CaptureClipboardText"), -80)
    }

    CaptureClipboardText(*) {
        if !this.TextCaptureEnabled
            return
        content := A_Clipboard
        if Trim(content) = "" || StrLen(content) > 524288
            return
        for existing in this.GetMemoryTextItems()
            if existing.Content = content
                return

        item := this.BuildTextItem(content)
        this.MemoryTextItems.InsertAt(1, item)
        while this.MemoryTextItems.Length > this.HistoryLimit
            this.MemoryTextItems.Pop()
        if this.Expanded
            && this.Sources[this.CurrentSourceIndex].Kind = "text" {
            this.Refresh()
            this.Status.Text := "已收集文字 · 单击文字块即可复制"
        }
    }

    CaptureClipboardImage(*) {
        sequence := DllCall("user32\GetClipboardSequenceNumber", "uint")
        if sequence && sequence = this.LastClipboardImageSequence
            return
        this.LastClipboardImageSequence := sequence
        if !DllCall("user32\OpenClipboard", "ptr", this.Window.Hwnd, "int")
            return
        copiedBitmap := 0
        try {
            clipboardBitmap := DllCall("user32\GetClipboardData",
                "uint", 2, "ptr") ; CF_BITMAP
            if clipboardBitmap
                copiedBitmap := DllCall("user32\CopyImage",
                    "ptr", clipboardBitmap, "uint", 0,
                    "int", 0, "int", 0, "uint", 0x2000, "ptr")
        } finally {
            DllCall("user32\CloseClipboard")
        }
        if !copiedBitmap
            return
        try DirCreate(this.SessionImageDir)
        stamp := FormatTime(, "yyyyMMdd-HHmmss") "-" A_MSec
        path := this.SessionImageDir "\剪贴板截图-" stamp ".bmp"
        saved := false
        try saved := this.SaveBitmapAsBmp(copiedBitmap, path)
        catch
            saved := false
        finally DllCall("gdi32\DeleteObject", "ptr", copiedBitmap)
        if !saved
            return
        item := {Kind: "file", Name: "剪贴板截图 "
            FormatTime(, "HH-mm-ss") ".bmp", Path: path,
            Extension: "bmp", Modified: FormatTime(, "yyyyMMddHHmmss"),
            IsDir: false, SessionClipboard: true}
        this.ClipboardImageItems.InsertAt(1, item)
        while this.ClipboardImageItems.Length > this.HistoryLimit {
            expired := this.ClipboardImageItems.Pop()
            try FileDelete(expired.Path)
        }
        if this.Expanded
            && this.Sources[this.CurrentSourceIndex].Kind = "screenshots" {
            this.Refresh()
            this.Status.Text := "已收集剪贴板截图"
        }
    }

    SaveBitmapAsBmp(bitmap, path) {
        bitmapObject := Buffer(A_PtrSize = 8 ? 32 : 24, 0)
        if !DllCall("gdi32\GetObjectW", "ptr", bitmap,
            "int", bitmapObject.Size, "ptr", bitmapObject.Ptr, "int")
            return false
        width := Abs(NumGet(bitmapObject, 4, "int"))
        height := Abs(NumGet(bitmapObject, 8, "int"))
        if !width || !height
            return false
        stride := width * 4
        imageSize := stride * height
        info := Buffer(40, 0)
        NumPut("uint", 40, info, 0)
        NumPut("int", width, info, 4)
        NumPut("int", height, info, 8)
        NumPut("ushort", 1, info, 12)
        NumPut("ushort", 32, info, 14)
        NumPut("uint", imageSize, info, 20)
        pixels := Buffer(imageSize, 0)
        screenDC := DllCall("user32\GetDC", "ptr", 0, "ptr")
        try {
            lines := DllCall("gdi32\GetDIBits", "ptr", screenDC,
                "ptr", bitmap, "uint", 0, "uint", height,
                "ptr", pixels.Ptr, "ptr", info.Ptr, "uint", 0, "int")
            if lines != height
                return false
            header := Buffer(14, 0)
            NumPut("ushort", 0x4D42, header, 0)
            NumPut("uint", 14 + 40 + imageSize, header, 2)
            NumPut("uint", 54, header, 10)
            file := FileOpen(path, "w")
            if !IsObject(file)
                return false
            file.RawWrite(header)
            file.RawWrite(info)
            file.RawWrite(pixels)
            file.Close()
            return FileExist(path) != ""
        } finally {
            if screenDC
                DllCall("user32\ReleaseDC", "ptr", 0, "ptr", screenDC)
        }
    }

    AutoRefreshHistory(*) {
        if !this.Expanded
            return
        source := this.Sources[this.CurrentSourceIndex]
        if source.Kind != "screenshots"
            return
        signature := this.ComputeHistoryFingerprint(source.Kind)
        if signature != this.LastHistoryFingerprint
            this.Refresh()
    }

    ComputeHistoryFingerprint(kind) {
        root := this.Sources[this.CurrentSourceIndex].Path
        if !DirExist(root)
            return "missing"
        count := 0
        newest := ""
        totalSize := 0
        Loop Files, root "\*", "F" {
            relevant := this.IsImage(A_LoopFileFullPath)
            if !relevant
                continue
            count += 1
            try totalSize += FileGetSize(A_LoopFileFullPath)
            modified := ""
            try modified := FileGetTime(A_LoopFileFullPath, "M")
            if modified != "" && (newest = ""
                || StrCompare(modified, newest) > 0)
                newest := modified
        }
        return count "|" newest "|" totalSize
    }

    OpenCurrentDirectory(*) {
        source := this.Sources[this.CurrentSourceIndex]
        if source.Kind = "text" {
            this.Status.Text := "未收藏文字仅保存在本次运行；收藏内容保存在本地"
            return
        }
        try Run("explorer.exe `"" this.CurrentPath "`"")
    }

    OpenConfig(*) {
        try Run("notepad.exe `"" this.ConfigPath "`"")
    }

    OnNotify(wParam, lParam, msg, hwnd) {
        if !this.TextCardMode || !this.Expanded || !lParam
            return
        sourceHwnd := NumGet(lParam, 0, "ptr")
        code := NumGet(lParam, A_PtrSize * 2, "int")
        if sourceHwnd != this.List.Hwnd || code != -12 ; NM_CUSTOMDRAW
            return
        stageOffset := A_PtrSize = 8 ? 24 : 12
        drawStage := NumGet(lParam, stageOffset, "uint")
        if drawStage = 0x1 ; CDDS_PREPAINT
            return 0x20 ; CDRF_NOTIFYITEMDRAW
        if drawStage != 0x10001 ; CDDS_ITEMPREPAINT
            return
        hdcOffset := A_PtrSize = 8 ? 32 : 16
        itemOffset := A_PtrSize = 8 ? 56 : 36
        hdc := NumGet(lParam, hdcOffset, "ptr")
        itemIndex := NumGet(lParam, itemOffset, "uptr")
        if this.DrawTextCard(hdc, itemIndex)
            return 0x4 ; CDRF_SKIPDEFAULT
    }

    DrawTextCard(hdc, itemIndex) {
        row := itemIndex + 1
        if !this.Items.Has(row) || this.Items[row].Kind != "text"
            return false
        position := Buffer(8, 0)
        if !DllCall("user32\SendMessageW", "ptr", this.List.Hwnd,
            "uint", 0x1010, "uptr", itemIndex,
            "ptr", position.Ptr, "ptr") ; LVM_GETITEMPOSITION
            return false
        itemX := NumGet(position, 0, "int")
        itemY := NumGet(position, 4, "int")
        cellWidth := Max(240, this.TextCardWidth)
        spacingHeight := Max(62, this.TextCardSpacingHeight)
        gap := Max(8, this.TextCardGap)
        halfGap := Floor(gap / 2)
        column := Max(0, Floor(itemX / cellWidth))
        rowTop := Floor(itemY / spacingHeight) * spacingHeight
        left := column * cellWidth + (column ? halfGap : 0)
        top := rowTop
        right := (column + 1) * cellWidth
            - (column ? 0 : gap - halfGap)
        bottom := top + this.TextCardHeight
        client := Buffer(16, 0)
        DllCall("user32\GetClientRect", "ptr", this.List.Hwnd,
            "ptr", client.Ptr)
        left := Max(0, left)
        top := Max(0, top)
        right := Min(NumGet(client, 8, "int"), right)
        bottom := Min(NumGet(client, 12, "int"), bottom)
        if right <= left || bottom <= top
            return false

        item := this.Items[row]
        color := HasProp(item, "Color")
            ? this.NormalizeTextColor(item.Color) : "yellow"
        selected := this.IsRowSelected(row)
        fillColor := this.TextFillColors[color]
        borderColor := selected ? 0x2684FF : this.TextBorderColors[color]
        textColor := 0x172033
        pen := DllCall("gdi32\CreatePen", "int", 0,
            "int", selected ? 2 : 1,
            "uint", this.ToColorRef(borderColor), "ptr")
        brush := DllCall("gdi32\CreateSolidBrush",
            "uint", this.ToColorRef(fillColor), "ptr")
        saved := DllCall("gdi32\SaveDC", "ptr", hdc, "int")
        try {
            DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", pen, "ptr")
            DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", brush, "ptr")
            DllCall("gdi32\RoundRect", "ptr", hdc,
                "int", left, "int", top, "int", right, "int", bottom,
                "int", 12, "int", 12)
            DllCall("gdi32\SetBkMode", "ptr", hdc, "int", 1)
            DllCall("gdi32\SetTextColor", "ptr", hdc,
                "uint", this.ToColorRef(textColor))
            textRect := Buffer(16, 0)
            NumPut("int", left + 10, textRect, 0)
            NumPut("int", top + 6, textRect, 4)
            NumPut("int", right - 10, textRect, 8)
            NumPut("int", bottom - 6, textRect, 12)
            cardText := (HasProp(item, "Favorite") && item.Favorite
                ? "★  " : "") item.Excerpt
            DllCall("user32\DrawTextW", "ptr", hdc,
                "str", cardText, "int", -1,
                "ptr", textRect.Ptr, "uint", 0x8824)
        } finally {
            if saved
                DllCall("gdi32\RestoreDC", "ptr", hdc, "int", saved)
            if pen
                DllCall("gdi32\DeleteObject", "ptr", pen)
            if brush
                DllCall("gdi32\DeleteObject", "ptr", brush)
        }
        return true
    }

    ToColorRef(rgb) {
        return ((rgb & 0xFF) << 16) | (rgb & 0xFF00)
            | ((rgb >> 16) & 0xFF)
    }

    ApplyRoundedCorners(guiObj) {
        try {
            preference := Buffer(4, 0)
            NumPut("int", 2, preference, 0) ; DWMWCP_ROUND
            DllCall("dwmapi\DwmSetWindowAttribute",
                "ptr", guiObj.Hwnd, "uint", 33,
                "ptr", preference.Ptr, "uint", 4)
        }
    }

    OnMouseDown(wParam, lParam, msg, hwnd) {
        dragTitle := hwnd = this.Title.Hwnd
        if !dragTitle && hwnd = this.Window.Hwnd {
            ; The uncovered top/bottom strips belong to the bar itself.
            ; Treat all of that background as a drag surface instead of only
            ; the narrow portion beneath the title.
            dragTitle := true
        }
        if dragTitle {
            DllCall("user32\ReleaseCapture")
            DllCall("user32\SendMessageW", "ptr", this.Window.Hwnd,
                "uint", 0x00A1, "ptr", 2, "ptr", 0)
            return 0
        }
        if hwnd != this.List.Hwnd
            return
        x := this.SignedWord(lParam & 0xFFFF)
        y := this.SignedWord((lParam >> 16) & 0xFFFF)
        row := this.HitTestRow(x, y)
        if !row
            return
        this.DragArmed := true
        this.DragStarted := false
        this.DragRow := row
        this.DragStartX := x
        this.DragStartY := y
    }

    OnSizeMoveMessage(wParam, lParam, msg, hwnd) {
        entering := msg = 0x0231
        if hwnd = this.Window.Hwnd {
            this.UserSizingBar := entering
            if !entering
                this.PersistBarWindowSize()
        } else if hwnd = this.ContentWindow.Hwnd {
            this.UserSizingContent := entering
            if !entering
                this.PersistContentWindowSize()
        }
    }

    PersistBarWindowSize() {
        if this.SmokeTestMode
            return
        try this.Window.GetClientPos(, , &width, &height)
        catch
            return
        if width >= this.MinWindowWidth
            this.WindowWidth := width
        this.SaveWindowState()
    }

    PersistContentWindowSize() {
        if this.SmokeTestMode
            return
        try this.ContentWindow.GetClientPos(, , &width, &height)
        catch
            return
        contentRect := this.GetWindowRectangle(this.ContentWindow.Hwnd)
        barRect := this.GetWindowRectangle(this.Window.Hwnd)
        if width >= this.MinWindowWidth
            this.WindowWidth := width
        if IsObject(contentRect) && IsObject(barRect)
            this.WindowHeight := contentRect.Height
                + this.PanelGap + barRect.Height
        this.SaveWindowState()
    }

    OnMouseMove(wParam, lParam, msg, hwnd) {
        if hwnd != this.List.Hwnd
            return
        SetTimer(this.PreviewHideTimer, 0)
        x := this.SignedWord(lParam & 0xFFFF)
        y := this.SignedWord((lParam >> 16) & 0xFFFF)
        this.ArmListMouseLeave()
        hoverRow := this.HitTestRow(x, y)
        if hoverRow != this.HoverRow && !this.DragStarted {
            this.HoverRow := hoverRow
            if hoverRow && this.Items.Has(hoverRow)
                this.ShowItemPreview(this.Items[hoverRow])
            else
                this.ShowEmptyPreview("将鼠标移到素材上",
                    "鼠标悬停即可预览；双击文件夹可进入。")
        }
        if !this.DragArmed || this.DragStarted
            return
        if !GetKeyState("LButton", "P") {
            this.DragArmed := false
            return
        }
        if Abs(x - this.DragStartX) < 7 && Abs(y - this.DragStartY) < 7
            return

        this.DragStarted := true
        this.DragArmed := false
        items := this.GetSelectedItems(this.DragRow)
        if !items.Length
            return
        source := this.Sources[this.CurrentSourceIndex]
        try {
            if source.Kind = "text" {
                blocks := []
                for item in items
                    if item.Kind = "text"
                        blocks.Push(this.ReadItemText(item))
                if blocks.Length
                    MBDrag_BeginText(this.Join(blocks, "`r`n`r`n"))
            } else {
                paths := []
                for item in items
                    paths.Push(item.Path)
                MBDrag_BeginFiles(paths)
            }
        } catch as error {
            this.Status.Text := "拖动失败：" error.Message
        }
        return 0
    }

    OnMouseUp(wParam, lParam, msg, hwnd) {
        if hwnd = this.List.Hwnd {
            this.DragArmed := false
            this.DragStarted := false
        }
    }

    ArmListMouseLeave() {
        if this.MouseLeaveArmed
            return
        size := A_PtrSize = 8 ? 24 : 16
        track := Buffer(size, 0)
        NumPut("uint", size, track, 0)
        NumPut("uint", 0x2, track, 4) ; TME_LEAVE
        NumPut("ptr", this.List.Hwnd, track, 8)
        if DllCall("user32\TrackMouseEvent", "ptr", track.Ptr, "int")
            this.MouseLeaveArmed := true
    }

    OnMouseLeave(wParam, lParam, msg, hwnd) {
        if hwnd != this.List.Hwnd
            return
        this.MouseLeaveArmed := false
        if this.DragStarted
            return
        SetTimer(this.PreviewHideTimer, -220)
    }

    HidePreviewIfPointerOutside(*) {
        if this.DragStarted || !DllCall("user32\IsWindowVisible",
            "ptr", this.PreviewWindow.Hwnd, "int")
            return
        point := Buffer(8, 0)
        if !DllCall("user32\GetCursorPos", "ptr", point.Ptr, "int")
            return
        pointValue := NumGet(point, 0, "int64")
        underCursor := DllCall("user32\WindowFromPoint",
            "int64", pointValue, "ptr")
        overPreview := underCursor = this.PreviewWindow.Hwnd
            || DllCall("user32\IsChild", "ptr", this.PreviewWindow.Hwnd,
                "ptr", underCursor, "int")
        overList := underCursor = this.List.Hwnd
            || DllCall("user32\IsChild", "ptr", this.List.Hwnd,
                "ptr", underCursor, "int")
        if overPreview || overList {
            SetTimer(this.PreviewHideTimer, -220)
            return
        }
        this.HoverRow := 0
        this.ShowEmptyPreview()
    }

    HitTestRow(x, y) {
        infoSize := A_PtrSize = 8 ? 24 : 20
        info := Buffer(infoSize, 0)
        NumPut("int", x, info, 0)
        NumPut("int", y, info, 4)
        index := DllCall("user32\SendMessageW", "ptr", this.List.Hwnd,
            "uint", 0x1012, "ptr", 0, "ptr", info.Ptr, "ptr")
        return index = -1 ? 0 : index + 1
    }

    IsRowSelected(row) {
        state := DllCall("user32\SendMessageW", "ptr", this.List.Hwnd,
            "uint", 0x102C, "ptr", row - 1, "ptr", 0x2, "ptr")
        return (state & 0x2) != 0
    }

    SignedWord(value) {
        return value >= 0x8000 ? value - 0x10000 : value
    }

    OnSize(guiObj, minMax, width, height) {
        if minMax = -1
            return
        if guiObj.Hwnd = this.Window.Hwnd {
            this.LayoutBarWindow(width, height)
            if this.UserSizingBar && !this.IgnoreSizePersistence
                this.WindowWidth := width
            return
        }
        if guiObj.Hwnd != this.ContentWindow.Hwnd
            return
        this.LayoutContentWindow(width, height)
        if this.UserSizingContent && !this.IgnoreSizePersistence {
            this.WindowWidth := width
            contentRect := this.GetWindowRectangle(this.ContentWindow.Hwnd)
            barRect := this.GetWindowRectangle(this.Window.Hwnd)
            if IsObject(contentRect) && IsObject(barRect)
                this.WindowHeight := contentRect.Height
                    + this.PanelGap + barRect.Height
        }
        ; Only a real user resize of the content window may move the bar.
        ; Programmatic Show/Move notifications can arrive after the guard in
        ; ShowContentWindow has cleared; reverse-syncing those notifications
        ; causes DPI-dependent drift on secondary monitors.
        if this.Expanded && !this.SyncingWindows && this.UserSizingContent
            SetTimer(ObjBindMethod(this, "SyncBarToContent"), -20)
    }

    LayoutBarWindow(width := 0, height := 0) {
        if !width
            try this.Window.GetClientPos(, , &width, &height)
        actionWidth := 40
        titleWidth := this.TitleWidth
        this.Title.Move(6, 0, titleWidth - 6, this.BarHeight)
        this.PinButton.Move(width - actionWidth + 2, 1,
            actionWidth - 6, 24)
        this.MenuButton.Move(width - actionWidth + 2, 27,
            actionWidth - 6, 24)
        tabsX := titleWidth
        tabsWidth := Max(300, width - tabsX - actionWidth - 2)
        buttonCount := this.SourceButtons.Length
        buttonWidth := Floor(tabsWidth / buttonCount)
        for index, button in this.SourceButtons {
            x := tabsX + (index - 1) * buttonWidth
            widthForButton := index = buttonCount
                ? tabsX + tabsWidth - x : buttonWidth
            button.Move(x, 6, widthForButton,
                this.BarHeight - 12)
        }
    }

    LayoutContentWindow(width := 0, height := 0) {
        if !width
            try this.ContentWindow.GetClientPos(, , &width, &height)
        toolHeight := 28
        toolY := height - toolHeight - 6
        right := width - 10
        viewX := right - 36
        refreshX := viewX - 42
        statusWidth := Min(300, Max(210, Floor(width * 0.28)))
        statusX := refreshX - statusWidth - 6
        captureX := statusX - 90
        pathX := 48

        this.List.Move(10, 10, width - 20, Max(220, toolY - 16))
        this.BackButton.Move(10, toolY, 32, toolHeight)
        isTextSource := this.Sources[this.CurrentSourceIndex].Kind = "text"
        pathRight := isTextSource ? captureX : statusX
        this.PathText.Move(pathX, toolY,
            Max(180, pathRight - pathX - 6), toolHeight)
        this.Status.Move(statusX, toolY, statusWidth, toolHeight)
        this.TextCaptureButton.Move(captureX, toolY, 84, toolHeight)
        this.RefreshButton.Move(refreshX, toolY + 2, 36, 24)
        this.ViewButton.Move(viewX, toolY + 2, 36, 24)
        if this.TextCardMode
            this.UpdateTextCardSpacing()
    }

    UpdatePreviewGeometry() {
        if !this.Expanded
            return
        try this.ContentWindow.GetPos(
            &mainX, &mainY, &mainWidth, &mainHeight)
        catch
            return
        previewWidth := this.PreviewWidth
        previewHeight := this.PreviewHeight
        dpiScale := A_ScreenDPI / 96
        previewPixelWidth := Round(previewWidth * dpiScale)
        mainPixelWidth := Round(mainWidth * dpiScale)
        previewX := mainX - previewPixelWidth - this.PanelGap
        if previewX < 0 {
            candidateX := mainX + mainPixelWidth + this.PanelGap
            previewX := candidateX + previewPixelWidth <= A_ScreenWidth
                ? candidateX : Max(0, mainX + 8)
        }
        previewY := mainY + Max(0,
            Floor((mainHeight - previewHeight) * dpiScale / 2))
        this.PreviewPanelWidth := previewWidth
        this.PreviewPanelHeight := previewHeight
        this.PreviewPanelX := previewX
        this.PreviewPanelY := previewY
        this.LayoutPreview(previewWidth, previewHeight)
    }

    SetPreviewSize(width, height, *) {
        this.PreviewWidth := width
        this.PreviewHeight := height
        IniWrite(width, this.ConfigPath, "General", "PreviewWidth")
        IniWrite(height, this.ConfigPath, "General", "PreviewHeight")
        if !this.Expanded
            return
        this.UpdatePreviewGeometry()
        if DllCall("user32\IsWindowVisible",
            "ptr", this.PreviewWindow.Hwnd, "int") {
            this.IgnorePreviewSizePersistence := true
            this.ShowFloatingPreview()
            SetTimer(ObjBindMethod(this,
                "EndPreviewProgrammaticSize"), -180)
            if this.PreviewHasImage && this.PreviewImagePath != ""
                this.SetPreviewImage(this.PreviewImagePath)
        }
    }

    EndPreviewProgrammaticSize(*) {
        this.IgnorePreviewSizePersistence := false
    }

    OnPreviewSize(guiObj, minMax, width, height) {
        if minMax = -1 || width < 240 || height < 360
            return
        imagePath := this.PreviewImagePath
        this.PreviewPanelWidth := width
        this.PreviewPanelHeight := height
        this.LayoutPreview(width, height)
        if imagePath != "" {
            this.PreviewHasImage := true
            try this.SetPreviewImage(imagePath)
        }
        if this.IgnorePreviewSizePersistence
            return
        this.PreviewWidth := width
        this.PreviewHeight := height
        SetTimer(this.PreviewSaveTimer, -250)
    }

    PersistPreviewSize(*) {
        IniWrite(this.PreviewWidth, this.ConfigPath,
            "General", "PreviewWidth")
        IniWrite(this.PreviewHeight, this.ConfigPath,
            "General", "PreviewHeight")
    }

    ShowFloatingPreview() {
        if !this.Expanded
            return
        this.PreviewWindow.Show("NA x" this.PreviewPanelX
            " y" this.PreviewPanelY " w" this.PreviewPanelWidth
            " h" this.PreviewPanelHeight)
    }

    LayoutPreview(previewWidth := 0, previewHeight := 0) {
        if !previewWidth
            previewWidth := this.PreviewWidth
        if !previewHeight
            previewHeight := this.PreviewHeight
        controlWidth := previewWidth - 28
        contentY := 44
        metaHeight := 110
        metaY := previewHeight - metaHeight - 14
        metaLabelY := metaY - 26
        contentHeight := Max(140, metaLabelY - contentY - 8)
        this.PreviewImageAreaX := 14
        this.PreviewImageAreaY := contentY
        this.PreviewImageAreaWidth := controlWidth
        this.PreviewImageAreaHeight := contentHeight
        this.PreviewTitle.Move(14, 10, controlWidth, 26)
        this.PreviewImage.Move(this.PreviewImageAreaX,
            this.PreviewImageAreaY, this.PreviewImageAreaWidth,
            this.PreviewImageAreaHeight)
        this.PreviewText.Move(14, contentY, controlWidth, contentHeight)
        this.PreviewMetaLabel.Move(14, metaLabelY, controlWidth, 22)
        this.PreviewMeta.Move(14, metaY, controlWidth, metaHeight)
    }

    SaveWindowState() {
        if this.SmokeTestMode
            return
        if this.WindowWidth >= this.MinWindowWidth
            IniWrite(this.WindowWidth, this.ConfigPath,
                "General", "WindowWidth")
        if this.WindowHeight >= 420
            IniWrite(this.WindowHeight, this.ConfigPath,
                "General", "WindowHeight")
        if this.PreviewWidth >= 240
            IniWrite(this.PreviewWidth, this.ConfigPath,
                "General", "PreviewWidth")
        if this.PreviewHeight >= 360
            IniWrite(this.PreviewHeight, this.ConfigPath,
                "General", "PreviewHeight")
    }

    Join(values, separator) {
        output := ""
        for index, value in values
            output .= (index > 1 ? separator : "") value
        return output
    }

    Shutdown() {
        SetTimer(this.ForegroundTimer, 0)
        SetTimer(this.HistoryRefreshTimer, 0)
        SetTimer(this.WindowPairTimer, 0)
        SetTimer(this.PreviewSaveTimer, 0)
        SetTimer(this.PreviewHideTimer, 0)
        try OnClipboardChange(this.ClipboardCallback, 0)
        this.SaveWindowState()
        this.ClearPreviewBitmap()
        try this.PreviewWindow.Destroy()
        try this.ContentWindow.Destroy()
        for editor in this.TextEditors
            try editor.Destroy()
        if this.ImageList {
            try this.List.SetImageList(0, 0)
            try this.List.SetImageList(0, 1)
            DllCall("comctl32\ImageList_Destroy", "ptr", this.ImageList)
            this.ImageList := 0
        }
        for icon in this.AppIconHandles
            try DllCall("user32\DestroyIcon", "ptr", icon)
        if DirExist(this.SessionImageDir)
            try DirDelete(this.SessionImageDir, true)
    }
}
