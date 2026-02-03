# 🎤 voice-ptt

**Talk. Done.** One-command push-to-talk voice transcription for macOS. 100% local, no cloud, powered by Whisper AI on Apple Silicon.

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%20Apple%20Silicon-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/privacy-100%25%20local-green?style=flat-square" alt="Privacy">
  <img src="https://img.shields.io/github/v/release/sparrowfm/voice-ptt?style=flat-square" alt="Release">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey?style=flat-square" alt="License">
</p>

---

## ⚡ Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/sparrowfm/voice-ptt/main/install.sh | bash
```

**That's it.** Choose your hotkey, grant permissions, start dictating.

Hold **Option+Space** (or your chosen hotkey) → speak → release → text appears instantly at your cursor. No clicking, no menus, no interruptions.

---

## 🔒 Why Local?

Your voice is personal. **Every. Single. Word.** Emails to colleagues. Notes about clients. Personal journal entries. Medical information. Legal documents.

**Cloud transcription = Your audio uploaded to remote servers, processed by third parties, potentially stored indefinitely.**

**voice-ptt = Nothing ever leaves your Mac.** Your voice data stays on your machine, processed entirely by your own hardware.

### The Freedom of Local

- 🚫 **No subscriptions** - One-time install, yours forever
- ✈️ **No internet required** - Works offline, on planes, in the wilderness
- 👻 **No data collection** - Zero telemetry, zero tracking, zero surveillance
- ∞ **No usage limits** - Transcribe as much as you want, whenever you want

---

## 🎯 Features

### ⚡ Lightning Fast
- **Base model**: 1-3 seconds transcription time
- **Metal GPU acceleration** on Apple Silicon
- Push-to-talk feels instant

### 🧹 Smart Cleanup (Two-Tier)

**Basic cleanup (always on, instant):**
- Removes filler words: "um", "uh", "like", "you know"
- Capitalizes first letter
- Collapses extra whitespace

**Advanced cleanup (optional, +1-2s):**
- Intelligent punctuation fixes
- Context-aware filler word detection
- Preserves your speaking style and meaning
- Powered by local LLM (Ollama + llama3.2:1b)

### 🔄 Auto-Updates
Checks GitHub every 7 days, notifies you when updates are available. One command to update:
```bash
voice-ptt-update
```

### 🎛️ Flexible Configuration
- Switch between base (142MB) and medium (1.5GB) models
- Change hotkey anytime
- Toggle advanced cleanup on/off
- All settings preserved across updates

---

## 📦 Installation

### One-Line Install
```bash
curl -fsSL https://raw.githubusercontent.com/sparrowfm/voice-ptt/main/install.sh | bash
```

The installer will:
1. Install Homebrew (if needed)
2. Install dependencies (Whisper, SoX, Hammerspoon)
3. Download the Whisper base model (~142MB)
4. Prompt you to choose a hotkey
5. Configure advanced cleanup (optional, if Ollama detected)

**Then grant permissions:**
- System Settings → Privacy & Security → Accessibility → Enable Hammerspoon
- System Settings → Privacy & Security → Microphone → Enable Hammerspoon

**Done.** Start dictating.

### Requirements

- macOS on Apple Silicon (M1/M2/M3/M4)
- ~200MB disk space (base model)
- ~1.7GB additional for medium model (optional)
- ~1.3GB additional for advanced cleanup (optional)

Homebrew is installed automatically if not present.

---

## 🚀 Usage

### Basic Dictation

1. **Position cursor** where you want text
2. **Hold hotkey** (Option+Space by default)
3. **Speak naturally**
4. **Release hotkey**
5. **Text appears** instantly

That's it. No clicking, no switching apps, no breaking your flow.

### Switch Models

```bash
voice-ptt-model
```

| Model | Size | Speed | Accuracy | Best For |
|-------|------|-------|----------|----------|
| **base** (default) | 142MB | 1-3s | Good | Quick notes, emails, casual writing |
| **medium** | 1.5GB | 5-10s | Excellent | Technical writing, accuracy-critical work |

### Change Hotkey

```bash
voice-ptt-hotkey
```

Or manually edit `~/.hammerspoon/init.lua`:
```lua
local mods = {"alt"}      -- "alt", "ctrl", "cmd", "shift"
local key = "space"       -- Any key
```

Then reload: **Hammerspoon menu → Reload Config**

### Advanced Cleanup

Enable LLM-based text refinement (requires Ollama):

```bash
# Install Ollama (if not already installed)
brew install ollama

# Enable advanced cleanup
voice-ptt-cleanup enable
```

**What it adds:**
- Better punctuation
- Context-aware filler word removal
- Style preservation
- ~1-2s additional processing time

**Commands:**
```bash
voice-ptt-cleanup enable    # Enable advanced cleanup
voice-ptt-cleanup disable   # Disable (basic cleanup remains)
voice-ptt-cleanup status    # Check current status
```

---

## 🔧 Commands

After installation, these commands are available:

| Command | Purpose |
|---------|---------|
| `voice-ptt-update` | Update to latest version |
| `voice-ptt-hotkey` | Change hotkey binding |
| `voice-ptt-model` | Switch between base/medium models |
| `voice-ptt-cleanup` | Enable/disable/check advanced cleanup |

---

## 🛠️ Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "Recording..." but nothing happens | Grant Microphone permission for Hammerspoon |
| Transcription doesn't paste | Grant Accessibility permission for Hammerspoon |
| Hotkey doesn't trigger | Hammerspoon menu → Reload Config |
| Zombie sox processes | `pkill -9 sox` |

### Debug Install

```bash
bash -x /tmp/install.sh 2>&1 | tee /tmp/install.log
```

### Verify Installation

```bash
command -v whisper-cli && echo "✓ whisper-cli" || echo "✗ whisper-cli"
command -v sox && echo "✓ sox" || echo "✗ sox"
ls /Applications/Hammerspoon.app && echo "✓ Hammerspoon" || echo "✗ Hammerspoon"
ls ~/Library/Application\ Support/whisper.cpp/*.bin && echo "✓ Models" || echo "✗ Models"
```

---

## 🗑️ Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/sparrowfm/voice-ptt/main/uninstall.sh | bash
```

To fully remove all components:
```bash
brew uninstall whisper-cpp sox
brew uninstall --cask hammerspoon
```

---

## 🎨 How It Works

```
Hotkey pressed → sox records audio → Hotkey released → whisper-cli transcribes → cleanup → paste
```

All processing happens locally using Metal GPU acceleration. **No data leaves your Mac. Ever.**

---

## 💡 Future Ideas

Want to help shape the roadmap? [Open an issue](https://github.com/sparrowfm/voice-ptt/issues) or start a discussion.

**Considering:**
- 🔔 Audio feedback (beep) instead of visual alerts
- 📋 Copy-only mode (don't auto-paste)
- 📜 Transcription history log
- 🌍 Multi-language support
- 🎯 Custom vocabulary injection
- ⌨️ Text macro expansion

---

## 🙏 Credits

This project stands on the shoulders of giants:

- **[whisper.cpp](https://github.com/ggerganov/whisper.cpp)** by Georgi Gerganov - An incredible feat of engineering that makes OpenAI's Whisper model run blazingly fast on Apple Silicon using Metal GPU acceleration. Without this project, local voice transcription at this speed wouldn't be possible.

- **[Hammerspoon](https://www.hammerspoon.org/)** - A powerful macOS automation tool that's been a cornerstone of the Mac power-user community for years. Its Lua scripting and hotkey system made the push-to-talk interaction seamless.

- **[SoX](http://sox.sourceforge.net/)** - The "Swiss Army knife of audio" has been faithfully processing audio on Unix systems since 1991. Simple, reliable, does exactly what it needs to do.

- **[OpenAI Whisper](https://github.com/openai/whisper)** - The original speech recognition model that made all of this possible. OpenAI's decision to open-source Whisper enabled the entire ecosystem of local, private transcription tools.

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>Built with ❤️ for privacy-conscious Mac users</strong><br>
  <sub>No telemetry. No tracking. No cloud. Just you and your voice.</sub>
</p>
