# Manual Testing Guide

Follow these scenarios to validate STTPortable end-to-end on Windows 10/11.

## 1. Happy Path – Notepad

1. Launch Notepad and click into the blank document.
2. Press **Win+Ctrl+T** to start recording, then speak “testing one two”.
3. Press **Win+Ctrl+T** again. After transcription finishes, the text should appear in Notepad at the caret.

## 2. Paste Blocked Simulation

1. Open Settings and set **Insert mode** to `type`.
2. Focus a field that blocks pasting (e.g., a browser URL bar or secure form).
3. Press **Win+Ctrl+T** to record and again to stop. The text should be typed into the field even if paste is blocked.

## 3. Change Hotkey

1. Open Settings and change the toggle hotkey to **Win+Alt+T**.
2. Click **Save**. The settings window closes and a tray tip confirms the change.
3. Use **Win+Alt+T** to start and stop a recording. The new binding should work immediately.

## 4. Missing Model Handling

1. Temporarily rename the GGUF model file in the `models` folder.
2. Press the toggle hotkey. STTPortable should display a clear error message.
3. Open `logs\sttportable.log` to confirm a timestamped entry was added describing the missing model.

## 5. Mic Device Override

1. Run `ffmpeg -list_devices true -f dshow -i dummy` in PowerShell to view available devices.
2. Copy the exact string for your preferred microphone (e.g., `audio=Microphone (USB Audio Device)`).
3. Edit `config\config.ini` and replace `mic_device` with that string.
4. Restart the app and confirm recordings use the specified microphone.
