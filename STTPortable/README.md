# STTPortable

STTPortable is a portable Windows 10/11 utility that captures audio from your microphone, transcribes it offline with whisper.cpp, and inserts the resulting text at the current caret position without leaving your active application. No installation is required once you provide the transcription model and command-line tools.

> _Screenshot placeholder — drop a screenshot of the Settings window here when available._

## Quick Start

1. Download a Windows build of **ffmpeg.exe** and **whisper.exe**. Place both executables in the [`bin/`](bin/) folder.
2. Download an English-only Whisper GGUF model such as `ggml-medium.en.gguf` and copy it into [`models/`](models/).
3. Double-click `src/TalkPaste.ahk` (AutoHotkey v2 script) or compile it with `build/build.bat` to produce `build/TalkPaste.exe`.
4. Position your text caret anywhere, press **Win+Ctrl+T** to start recording, speak, then press the hotkey again. The transcription appears where the caret was.

## Default Hotkeys

| Action | Hotkey |
| --- | --- |
| Toggle record / transcribe / insert | `Win+Ctrl+T` |
| Open Settings | `Win+Ctrl+,` |
| Cancel recording | `Win+Ctrl+X` |
| Toggle insert mode (paste/type) | `Win+Ctrl+Y` |

All hotkeys can be changed in **Settings**.

## Settings

Open the Settings window from the tray icon or with **Win+Ctrl+,**. You can:

- Assign a new toggle hotkey using the Hotkey control (rebinding applies immediately after saving).
- Choose the transcription model path.
- Select the insert mode: **Paste** (clipboard round-trip and Ctrl+V) or **Type** (SendText).

Settings persist in `config/config.ini`. The file is created automatically after the first save.

## Microphone Configuration

STTPortable defaults to the DirectShow `audio=Default` device at 16 kHz mono. To see all available devices, run:

```
ffmpeg -list_devices true -f dshow -i dummy
```

Copy the exact device name (e.g., `audio=Microphone (USB Audio Device)`) and paste it into the `mic_device` value in `config/config.ini` if you need a different input.

## Models and Performance

Whisper GGUF models vary in size and speed:

- `ggml-tiny.en.gguf`: smallest, fastest, lowest accuracy.
- `ggml-base.en.gguf`: balanced speed and accuracy.
- `ggml-medium.en.gguf` (recommended): higher accuracy for desktop CPUs.
- `ggml-large-v2.en.gguf`: best accuracy, slowest CPU transcription.

English-only `.en` models run faster than multilingual equivalents. Consider your CPU capabilities when choosing a model.

## Troubleshooting

- **Paste blocked** (e.g., elevated apps, secure fields): press **Win+Ctrl+Y** to switch to **Type** mode and retry.
- **Missing binaries or model**: the app shows an error dialog and logs details to [`logs/sttportable.log`](logs/).
- **Permission or antivirus warnings**: whitelist the folder or run the script compiled with Ahk2Exe.
- **Audio device issues**: confirm the microphone is accessible in Windows privacy settings. Override `mic_device` if necessary.

## Logging

Error conditions append timestamped entries to `logs/sttportable.log`. Include this file when reporting issues.

## Build

Run `build/build.bat` to compile `src/TalkPaste.ahk` into a standalone executable. The script auto-detects an optional icon (`src/mic.ico`). Ensure Ahk2Exe is installed and available on your PATH.

## Manual Tests

See [TESTING.md](TESTING.md) for end-to-end scenarios that verify recording, transcription, hotkey changes, and failure handling.

## What to Do Next

1. Copy `ffmpeg.exe` and `whisper.exe` into the [`bin/`](bin/) folder.
2. Place your chosen English GGUF model (for example, `ggml-medium.en.gguf`) inside [`models/`](models/).
3. Launch the script with AutoHotkey v2 (`src/TalkPaste.ahk`) or compile it via [`build/build.bat`](build/build.bat).
4. Put the caret in any text field and press the toggle hotkey (default **Win+Ctrl+T**) to record, then press it again to transcribe and insert the text.

If you cannot launch the script by double-clicking it, run this one-line PowerShell command instead:

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\src\TalkPaste.ahk
```

## Credits

- [ffmpeg](https://ffmpeg.org/)
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp)
- [AutoHotkey v2](https://www.autohotkey.com/v2/)
