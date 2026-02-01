# voice-ptt

One-command push-to-talk voice transcription for macOS. 100% local, no cloud, powered by Whisper AI on Apple Silicon.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sparrowfm/voice-ptt/main/install.sh -o /tmp/install.sh && bash /tmp/install.sh
```

Then grant Hammerspoon **Accessibility** and **Microphone** permissions in System Settings.

## Usage

Hold **F12** → speak → release **F12** → text appears at cursor

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

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Recording..." but nothing happens | Check Microphone permission for Hammerspoon |
| Transcription doesn't paste | Check Accessibility permission for Hammerspoon |
| F12 doesn't trigger | Hammerspoon menu → Reload Config |
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
