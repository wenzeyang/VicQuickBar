# Vic快捷栏

面向 AI 视频制作素材调用场景的 Windows 置顶快捷栏。它把常用文件夹、历史截图和历史文本集中在一条可移动的底栏中，需要时向上展开，用完即可收起。

## 下载

请从本仓库的 Releases 下载 `VicQuickBar-v1.0.2-win-x64-portable.zip`。解压后直接运行 `VicQuickBar.exe`，无需安装 AutoHotkey，也不依赖 PopDrop 主程序。

## 主要功能

- 多个可自定义素材目录标签，支持直接拖出文件上传。
- 历史截图：截图目录、手动导入图片和剪贴板临时图片统一展示。
- 历史文本：自动收集本次运行复制的文字，单击即可重新复制；主动收藏后可持续保存。
- 超大图标、大图标、中图标、小图标和列表五种显示模式。
- 悬浮预览、预览窗口自由缩放，以及 `512 × 512`、`768 × 768`、`512 × 768`、`768 × 512` 快捷尺寸。
- 展示区与底部快捷栏是两个独立圆角窗口，可置顶、移动并保持对齐。
- 点击标签时展示窗口使用 Windows 原生滑动动画快速升起或收回，无常驻动画线程。
- 默认使用 `F3` 显示或隐藏。

## 数据与隐私

程序只在自身目录保存配置和用户主动收藏的数据：

- `material-bar.ini`：目录、标签和界面设置。
- `data/material-bar-state.ini`：截图排序与收藏状态。
- `data/favorite-texts/`：主动收藏的历史文本。

未收藏的历史文本和剪贴板临时图片在程序退出后清理。上述路径均已加入 `.gitignore`，不会进入源码仓库。

## 从源码运行

1. 安装 AutoHotkey v2。
2. 双击 `MaterialBar.ahk`。
3. 首次运行会根据 `material-bar.example.ini` 生成本地配置。

## 构建便携版

安装 AutoHotkey v2 和官方 Ahk2Exe 后，在 PowerShell 中运行：

```powershell
.\build-vic-quickbar-portable.ps1
```

构建脚本会编译 x64 EXE、执行启动检查，并在 `dist/` 下生成 ZIP 和 SHA-256 文件。

## 来源与致谢

Vic快捷栏是基于 [PopDrop](https://github.com/hiforrest/PopDrop) 使用场景进行的独立二次构建。感谢 PopDrop 作者 `hiforrest` 的原始项目与设计启发。详细说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

