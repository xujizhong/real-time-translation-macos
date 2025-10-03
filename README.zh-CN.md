# Subtitle（macOS）

基于 ScreenCaptureKit 与 Speech 的 macOS 系统音频实时字幕工具，可在 macOS 15+ 上使用 Apple Translation 框架进行本地翻译。

[English README](README.md)

## 特性

- 实时转写系统音频（不是麦克风）
- 浮动字幕气泡，置顶显示，可拖动
- 类 YouTube 的简洁样式，带阴影
- 支持识别语言与翻译目标切换
- macOS 15+ 可使用本地翻译（Apple Translation）
- 首次运行自动申请“屏幕录制”和“语音识别”权限

## 环境要求

- 推荐 macOS 13 或更高版本
- 本地翻译需要 macOS 15 或更高版本
- 使用 Xcode 15 或更高版本进行构建

## 构建与运行

1. 使用 Xcode 打开 `subtitle.xcodeproj`。
2. 选择 `subtitle` scheme，并在需要时设置 Signing Team。
3. 编译并运行。首次启动会弹出权限请求：
   - 屏幕录制（用于通过 ScreenCaptureKit 捕获系统音频）
   - 语音识别（用于将音频转写为文本）

无需额外第三方依赖。

## 使用方法

- 选择识别语言（源语言）与翻译目标。
- 点击“开始”以捕获并转写系统音频。
- 屏幕上会出现可拖动、始终置顶的字幕气泡。
- 空格键可快速开始（空闲时）；点击“停止”结束。

说明：
- 应用会将所选翻译源（如 `en`、`ja`、`zh-Hans`）映射到合适的 Speech 识别区域设置。
- 在 macOS 15 以下版本，翻译功能会退化为原文显示（即不翻译）。
- 当前仅捕获所选显示器的系统音频，不包含麦克风输入。

## 自定义叠加层

可在代码中调整样式与排版：
- `subtitle/OverlayCaptionView.swift:10` 定义了 `OverlayConfig`（最大行数、字体大小、内边距、圆角与背景不透明度等）。
- 可设置 `fixedPixelWidth`（默认 800），若设为 `nil` 则按屏幕宽度比例 `widthRatio` 计算。

## 隐私与权限

- 使用 Apple 原生框架（ScreenCaptureKit、Speech，以及 macOS 15+ 的 Translation），在本地处理。
- 音频处理由系统框架完成，不会上传到远端。

## 常见问题

- 若提示“语音识别未授权”，请到 系统设置 → 隐私与安全性 → 语音识别 中开启。
- 若无转写结果，请到 系统设置 → 隐私与安全性 → 屏幕录制 中为本应用授权。

## 致谢

- Apple 的 ScreenCaptureKit、Speech 与 Translation 框架。

## 许可协议

本项目使用 MIT 协议开源，详见 `LICENSE` 文件。
