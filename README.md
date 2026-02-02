# voice-ptt

One-command push-to-talk voice transcription for macOS. 100% local, no cloud, powered by Whisper AI on Apple Silicon.

## Why Local?

Your voice is personal. Every word you dictate - emails to colleagues, notes about clients, personal journal entries, medical information, legal documents - deserves privacy.

Cloud-based transcription means your audio is uploaded to remote servers, processed by third parties, and potentially stored indefinitely. With voice-ptt, **nothing ever leaves your Mac**. Your voice data stays on your machine, processed entirely by your own hardware.

- **No subscriptions** - One-time install, works forever
- **No internet required** - Works offline, on airplanes, anywhere
- **No data collection** - Zero telemetry, zero tracking
- **No usage limits** - Transcribe as much as you want

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
- ~200MB disk space (base model)
- ~1.7GB additional if you upgrade to medium model

## How it works

```
Hotkey pressed → sox records audio → Hotkey released → whisper-cli transcribes → pastes to cursor
```

All processing happens locally using Metal GPU acceleration. No data leaves your Mac.

## Switch Models

The installer downloads only the base model (142MB). For better accuracy, you can upgrade to medium:

```bash
voice-ptt-model
```

| Model | Size | Speed | Accuracy |
|-------|------|-------|----------|
| base (default) | 142MB | ~1-3s | Good |
| medium | 1.5GB | ~5-10s | Best |

The medium model downloads on-demand when you first select it.

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

This project stands on the shoulders of giants:

- **[whisper.cpp](https://github.com/ggerganov/whisper.cpp)** by Georgi Gerganov - An incredible feat of engineering that makes OpenAI's Whisper model run blazingly fast on Apple Silicon using Metal GPU acceleration. Without this project, local voice transcription at this speed wouldn't be possible.

- **[Hammerspoon](https://www.hammerspoon.org/)** - A powerful macOS automation tool that's been a cornerstone of the Mac power-user community for years. Its Lua scripting and hotkey system made the push-to-talk interaction seamless.

- **[SoX](http://sox.sourceforge.net/)** - The "Swiss Army knife of audio" has been faithfully processing audio on Unix systems since 1991. Simple, reliable, does exactly what it needs to do.

- **[OpenAI Whisper](https://github.com/openai/whisper)** - The original speech recognition model that made all of this possible. OpenAI's decision to open-source Whisper enabled the entire ecosystem of local, private transcription tools.

## License

MIT License - see [LICENSE](LICENSE) for details.
