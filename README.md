# voice-ptt

One-command push-to-talk voice transcription for macOS. 100% local, no cloud, powered by Whisper AI on Apple Silicon.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sparrowfm/voice-ptt/main/install.sh -o /tmp/install.sh && bash /tmp/install.sh
```

The installer will prompt you to choose a hotkey (F12, F11, Ctrl+Shift+Space, etc.).

Then grant Hammerspoon **Accessibility** and **Microphone** permissions in System Settings.

## Usage

Hold **your hotkey** → speak → release → text appears at cursor

## Change Hotkey

After installation, run:

```bash
voice-ptt-hotkey
```

Or manually edit `~/.hammerspoon/init.lua` and change:
```lua
local mods = {}
local key = "F12"
```

Then reload: Hammerspoon menu → Reload Config

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/sparrowfm/voice-ptt/main/uninstall.sh -o /tmp/uninstall.sh && bash /tmp/uninstall.sh
```

To fully remove apps after uninstalling:
```bash
brew uninstall whisper-cpp sox
brew uninstall --cask hammerspoon
```

## Requirements

- macOS on Apple Silicon (M1/M2/M3/M4)
- [Homebrew](https://brew.sh)
- ~2GB disk space

## How it works

```
Hotkey pressed → sox records audio → Hotkey released → whisper-cli transcribes → pastes to cursor
```

All processing happens locally using Metal GPU acceleration. No data leaves your Mac.

## Models

| Model | Size | Speed | Accuracy |
|-------|------|-------|----------|
| base (default) | 142MB | ~1-3s | Good |
| medium | 1.5GB | ~5-10s | Best |

To switch models, edit `~/.hammerspoon/init.lua` line 9:
```lua
-- For better accuracy:
local model = os.getenv("HOME") .. "/Library/Application Support/whisper.cpp/ggml-medium.en.bin"
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Recording..." but nothing happens | Check Microphone permission for Hammerspoon |
| Transcription doesn't paste | Check Accessibility permission for Hammerspoon |
| Hotkey doesn't trigger | Hammerspoon menu → Reload Config |
| Zombie sox processes | Run `pkill -9 sox` |

### Debug install issues

```bash
bash -x /tmp/install.sh 2>&1 | tee /tmp/install.log
```

### Verify installation

```bash
command -v whisper-cli && echo "✓ whisper-cli" || echo "✗ whisper-cli"
command -v sox && echo "✓ sox" || echo "✗ sox"
ls /Applications/Hammerspoon.app && echo "✓ Hammerspoon" || echo "✗ Hammerspoon"
ls ~/Library/Application\ Support/whisper.cpp/*.bin && echo "✓ Models" || echo "✗ Models"
```
