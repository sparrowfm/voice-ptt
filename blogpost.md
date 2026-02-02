# Building a Local Voice Transcription Tool in One Afternoon

*How we built voice-ptt: push-to-talk dictation that never leaves your Mac*

---

I've been dictating a lot lately. There's something freeing about speaking your thoughts instead of typing them - especially for long-form writing, emails, and brainstorming. But every cloud dictation service I tried had the same problem: my voice was going somewhere else.

Every word I spoke - emails about clients, personal notes, half-formed ideas - was being uploaded to some server, processed by a third party, potentially stored forever. For a few dollars a month, I was trading my privacy for convenience.

I wanted something better: high-quality transcription that was fast, accurate, private, and ideally free after the initial setup. So I built it.

## The Goal

A simple push-to-talk system: hold a key, speak, release, and the transcribed text appears wherever my cursor is. No clicking, no switching apps, no cloud uploads. Just talk and type.

## The Stack

After some research, the pieces fell into place:

- **[whisper.cpp](https://github.com/ggerganov/whisper.cpp)** - Georgi Gerganov's incredible port of OpenAI's Whisper model, optimized for Apple Silicon with Metal GPU acceleration. This is the magic that makes local transcription fast enough to be usable.

- **[Hammerspoon](https://www.hammerspoon.org/)** - A macOS automation tool with Lua scripting. Perfect for binding hotkeys and orchestrating the record → transcribe → paste workflow.

- **[SoX](http://sox.sourceforge.net/)** - The "Swiss Army knife of audio" - a simple command-line tool that's been processing audio since 1991. Records from the mic to a WAV file.

- **Whisper models** - Downloaded once, stored locally. The installer downloads the "base" model (142MB) which transcribes in 1-3 seconds. If you want better accuracy, you can upgrade to the "medium" model (1.5GB, 5-10 seconds) on-demand.

## The Build

The core is a Hammerspoon script that:

1. **On key press**: Start recording with sox
2. **On key release**: Stop recording, run whisper-cli, grab the text, paste it

Sounds simple. It was not.

## Gotcha #1: Async or Die

My first version used Hammerspoon's `hs.execute()` to run whisper-cli. It worked... technically. But `hs.execute()` is synchronous - it blocks the entire Hammerspoon process while whisper runs. Since transcription takes 1-10 seconds depending on the model, this meant the UI froze, alerts didn't show, and everything felt broken.

The fix: `hs.task.new()` for async execution. The transcription runs in the background, calls a callback when done, and the UI stays responsive.

```lua
local whisperTask = hs.task.new(whisper,
  function(exitCode, stdOut, stdErr)
    -- Handle result when transcription completes
  end,
  {"-m", model, "-f", recordFile, "-otxt", "-of", outputBase, "-np"}
)
whisperTask:start()
```

## Gotcha #2: Microphone Permissions Are Weird

macOS won't let you manually add apps to the Microphone permission list. The app has to request it, and then you grant it. But here's the thing: Hammerspoon isn't what records audio - sox is. And sox is a command-line tool that inherits permissions from... something.

We tried triggering the permission prompt during installation by running a quick sox recording:

```bash
/opt/homebrew/bin/sox -d -r 16000 -c 1 /tmp/mic_test.wav trim 0 1
```

This sometimes triggered the prompt, sometimes didn't. The reliable solution: the first time you actually use the hotkey, macOS will prompt for microphone access. Not ideal, but it works.

## Gotcha #3: Function Keys Are a Lie

My first instinct for the hotkey was F12 - easy to reach, not commonly used. Wrong. On a MacBook keyboard:

- F1-F2: Brightness
- F3: Mission Control
- F4: Launchpad
- F5-F6: Keyboard brightness
- F7-F9: Media controls
- F10-F12: Volume

Every single function key is mapped to something by default. You can enable "Use F1, F2, etc. keys as standard function keys" in System Settings, but that's a global change that breaks the media controls.

We ended up defaulting to **Option+Space** (Alt+Space on Windows keyboards). It's two keys, but it's reliable and doesn't conflict with anything important.

## Gotcha #4: Right Alt Isn't What You Think

I thought "what about just the right Alt key as a single-key hotkey?" Hammerspoon supports `rightalt` as a modifier... but modifiers need a regular key to modify. You can't bind to just pressing a modifier key.

There's a workaround using `hs.eventtap` to listen for modifier key events directly, but it's significantly more complex and can interfere with other apps. We stuck with Option+Space.

## Gotcha #5: curl | bash Doesn't Play Nice

The dream was a one-liner install:

```bash
curl -fsSL URL | bash
```

But piping directly to bash causes problems:
- `read` commands don't work (no stdin)
- brew output can corrupt the script parsing
- Error handling becomes unreliable

The solution: download first, then run:

```bash
curl -fsSL URL -o /tmp/install.sh && bash /tmp/install.sh
```

One extra step, but it actually works reliably. The installer also auto-installs Homebrew if it's missing, so users on fresh Macs don't need to do anything first.

## Gotcha #6: ~/bin Isn't in PATH

We created helper commands (`voice-ptt-hotkey`, `voice-ptt-model`) and put them in `~/bin`. But on a fresh Mac, `~/bin` isn't in the PATH. Users ran the command and got "not found."

The fix: the installer now adds this to `~/.zshrc`:

```bash
export PATH="$HOME/bin:$PATH"
```

And reminds users to open a new terminal window.

## Gotcha #7: People Don't Want to Edit Lua

My initial approach for switching models was "just edit line 9 of the Lua file." That's fine for developers. It's not fine for everyone else.

We added `voice-ptt-model` - a simple menu that asks "base or medium?" and does the sed replacement automatically. Same for changing hotkeys with `voice-ptt-hotkey`.

## Gotcha #8: Manual Config Reload Is Annoying

After changing settings, users had to click the Hammerspoon menu bar icon → Reload Config. Easy to forget, easy to miss.

Turns out Hammerspoon has a URL scheme:

```bash
open -g hammerspoon://reload
```

Now the helper commands reload automatically. One less step.

## The Result

**[voice-ptt](https://github.com/sparrowfm/voice-ptt)** - a one-command installer that sets up push-to-talk voice transcription on any M-series Mac.

- Hold Option+Space, speak, release
- Text appears at your cursor in 1-3 seconds
- 100% local - nothing ever leaves your Mac
- No subscriptions, no accounts, no limits

The transcription quality is genuinely good. Whisper handles accents, technical terms, and natural speech better than most cloud services I've tried. And knowing that my words aren't being uploaded somewhere makes me more comfortable dictating freely.

## What's Next?

We're considering:
- Audio feedback (beeps instead of visual alerts)
- Copy-only mode (don't auto-paste)
- Transcription history log
- Multi-language support

If you try it and have ideas, [open an issue](https://github.com/sparrowfm/voice-ptt/issues).

---

*voice-ptt is open source under the MIT license. Built with Claude Code in one afternoon.*
