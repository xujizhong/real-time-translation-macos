# Subtitle (macOS)

System audio live captions with an always‑on‑top overlay, built for macOS using ScreenCaptureKit and Speech. Optionally translates captions on‑device on macOS 15+.

[中文说明 (Chinese)](README.zh-CN.md)

## Features

- Real‑time transcription of system audio (not the microphone)
- Floating caption bubble, always on top, draggable
- Minimal YouTube‑style look with shadowed text
- Language picker for recognition and translation
- On‑device translation when available (macOS 15+, Apple Translation framework)
- First‑run privacy prompts for Screen Recording and Speech Recognition

## Requirements

- macOS 13 or later recommended
- macOS 15 or later for on‑device translation
- Xcode 15 or later to build

## Build & Run

1. Open `subtitle.xcodeproj` in Xcode.
2. Select the `subtitle` scheme and set your Signing Team if needed.
3. Build and Run. On first launch macOS will prompt for:
   - Screen Recording permission (for capturing system audio via ScreenCaptureKit)
   - Speech Recognition permission (for transcribing audio)

No external dependencies are required.

## Usage

- Choose the recognition language (source) and the translation target.
- Click Start to begin capturing and transcribing system audio.
- A draggable, always‑on‑top caption bubble appears on screen.
- Press Space to quickly start when idle. Click Stop to end.

Notes:
- The app maps the selected translation source (e.g. `en`, `ja`, `zh-Hans`) to a suitable Speech locale automatically.
- On macOS versions earlier than 15, captions show the original transcription (translation falls back to source text).
- The app captures system audio from the selected display, not microphone input.

## Customize the Overlay

Adjust the caption bubble style and layout in code:
- `subtitle/OverlayCaptionView.swift:10` defines `OverlayConfig` (max lines, font size, padding, corner radius, opacity).
- Set `fixedPixelWidth` (default 800) or set it to `nil` to use the `widthRatio` of the active screen.

## Privacy

- Uses Apple frameworks on device (ScreenCaptureKit, Speech, and Translation on macOS 15+).
- Your audio is processed locally by the system frameworks.

## Troubleshooting

- If you see “Speech not authorized”, enable it in System Settings → Privacy & Security → Speech Recognition.
- If transcription does not start, grant Screen Recording in System Settings → Privacy & Security → Screen Recording.

## Acknowledgements

- Apple ScreenCaptureKit, Speech, and Translation frameworks.

## License

Licensed under the MIT License. See `LICENSE` for details.
