# voice-ptt

One-command push-to-talk voice transcription for macOS. 100% local, no cloud, powered by Whisper AI on Apple Silicon.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sparrowfm/voice-ptt/main/install.sh | bash
```

Then grant Hammerspoon **Accessibility** and **Microphone** permissions in System Settings.

## Usage

Hold **F12** → speak → release **F12** → text appears at cursor

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/sparrowfm/voice-ptt/main/uninstall.sh | bash
```

## Requirements

- macOS on Apple Silicon (M1/M2/M3/M4)
- [Homebrew](https://brew.sh)
- ~2GB disk space

## How it works

```
F12 pressed → sox records audio → F12 released → whisper-cli transcribes → pastes to cursor
```

All processing happens locally using Metal GPU acceleration. No data leaves your Mac.

## Configuration

Edit `~/.hammerspoon/init.lua`:

- **Change hotkey**: Modify `local key = "F12"` (line 19)
- **Switch model**: Change `ggml-base.en.bin` to `ggml-medium.en.bin` (line 9) for better accuracy

Reload config: Hammerspoon menu → Reload Config

## Models

| Model | Size | Speed | Accuracy |
|-------|------|-------|----------|
| base (default) | 142MB | ~1-3s | Good |
| medium | 1.5GB | ~5-10s | Best |

---

## Debugging

If installation fails, run with debug output:

```bash
bash -x <(curl -fsSL https://raw.githubusercontent.com/sparrowfm/voice-ptt/main/install.sh) 2>&1 | head -100
```

Check if Hammerspoon exists:

```bash
ls -la /Applications/Hammerspoon.app
mdfind -name "Hammerspoon.app"
brew list --cask | grep hammer
```
