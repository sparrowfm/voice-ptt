# voice-ptt

One-command push-to-talk voice transcription for macOS. 100% local, no cloud, powered by Whisper AI on Apple Silicon.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sparrowfm/voice-ptt/main/install.sh -o /tmp/install.sh && bash /tmp/install.sh
```

The installer will prompt you to choose a hotkey (Option+Space, Ctrl+Space, etc.).

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
local mods = {"alt"}
local key = "space"
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

## Switch Models

```bash
voice-ptt-model
```

| Model | Size | Speed | Accuracy |
|-------|------|-------|----------|
| base (default) | 142MB | ~1-3s | Good |
| medium | 1.5GB | ~5-10s | Best |

Then reload: Hammerspoon menu → Reload Config

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

## Feedback & Ideas

Have ideas for new features? [Open an issue](https://github.com/sparrowfm/voice-ptt/issues) or start a discussion.

Some things we're considering:
- Audio feedback (beep) instead of visual alerts
- Copy-only mode (don't auto-paste)
- Transcription history log
- Multi-language support

## Credits

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - High-performance Whisper inference by Georgi Gerganov
- [Hammerspoon](https://www.hammerspoon.org/) - macOS automation tool
- [SoX](http://sox.sourceforge.net/) - Sound eXchange audio utility
- [OpenAI Whisper](https://github.com/openai/whisper) - Original speech recognition model

## License

MIT License - see [LICENSE](LICENSE) for details.
