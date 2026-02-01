#!/bin/bash
# install-voice.sh - One-command push-to-talk voice transcription setup for macOS
# Usage: curl -fsSL URL | bash
#    or: bash install-voice.sh

set -e

echo "═══════════════════════════════════════════════════════════════"
echo "  Push-to-Talk Voice Transcription Installer"
echo "  100% Local • No Cloud • Whisper AI on Apple Silicon"
echo "═══════════════════════════════════════════════════════════════"
echo

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ This script is for macOS only."
    exit 1
fi

# Check Apple Silicon
if [[ "$(uname -m)" != "arm64" ]]; then
    echo "❌ This script requires Apple Silicon (M1/M2/M3/M4)."
    exit 1
fi

# Check for Homebrew (including common install locations)
BREW_PATH=""
if command -v brew &> /dev/null; then
    BREW_PATH="$(command -v brew)"
elif [[ -x "/opt/homebrew/bin/brew" ]]; then
    BREW_PATH="/opt/homebrew/bin/brew"
    eval "$($BREW_PATH shellenv)"
elif [[ -x "/usr/local/bin/brew" ]]; then
    BREW_PATH="/usr/local/bin/brew"
    eval "$($BREW_PATH shellenv)"
fi

if [[ -z "$BREW_PATH" ]]; then
    echo "❌ Homebrew not found. Install it first:"
    echo '   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo ""
    echo "   Then run this installer again."
    exit 1
fi

echo "✓ macOS on Apple Silicon detected"
echo "✓ Homebrew found at $BREW_PATH"
echo

# Install dependencies
echo "Installing dependencies..."
echo "─────────────────────────────────────────────────────────────────"

if ! command -v whisper-cli &> /dev/null; then
    echo "Installing whisper-cpp..."
    brew install whisper-cpp
else
    echo "✓ whisper-cpp already installed"
fi

if ! command -v sox &> /dev/null; then
    echo "Installing sox..."
    brew install sox
else
    echo "✓ sox already installed"
fi

if [[ ! -d "/Applications/Hammerspoon.app" ]]; then
    echo "Installing Hammerspoon..."
    brew install --cask hammerspoon
else
    echo "✓ Hammerspoon already installed"
fi

echo

# Download models
echo "Downloading Whisper models..."
echo "─────────────────────────────────────────────────────────────────"

MODEL_DIR="$HOME/Library/Application Support/whisper.cpp"
mkdir -p "$MODEL_DIR"

download_model() {
    local name="$1"
    local url="$2"
    local path="$MODEL_DIR/$name"

    if [[ -f "$path" ]]; then
        echo "✓ $name already downloaded"
        return 0
    fi

    echo "Downloading $name..."
    local tmp_path="${path}.tmp"

    if curl -L --progress-bar -o "$tmp_path" "$url"; then
        # Verify file is not empty/corrupt (at least 10MB for base model)
        local size=$(stat -f%z "$tmp_path" 2>/dev/null || echo "0")
        if [[ "$size" -gt 10000000 ]]; then
            mv "$tmp_path" "$path"
            echo "✓ $name downloaded successfully"
        else
            rm -f "$tmp_path"
            echo "❌ $name download failed (file too small: $size bytes)"
            return 1
        fi
    else
        rm -f "$tmp_path"
        echo "❌ $name download failed"
        return 1
    fi
}

download_model "ggml-base.en.bin" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
download_model "ggml-medium.en.bin" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin"

echo

# Create Hammerspoon config
echo "Creating Hammerspoon configuration..."
echo "─────────────────────────────────────────────────────────────────"

mkdir -p "$HOME/.hammerspoon"

CONFIG_FILE="$HOME/.hammerspoon/init.lua"

# Backup existing config if it exists and doesn't have our config
if [[ -f "$CONFIG_FILE" ]]; then
    if grep -q "Push-to-Talk Whisper" "$CONFIG_FILE"; then
        echo "✓ Push-to-talk config already present in init.lua"
    else
        BACKUP_FILE="$HOME/.hammerspoon/init.lua.backup.$(date +%Y%m%d%H%M%S)"
        echo "Backing up existing init.lua to $(basename "$BACKUP_FILE")"
        cp "$CONFIG_FILE" "$BACKUP_FILE"
        echo "Creating new init.lua with push-to-talk config..."
        # Write new config (replaces existing)
        write_config=true
    fi
else
    echo "Creating init.lua..."
    write_config=true
fi

# Write config if needed (new install or backup was made)
if [[ "$write_config" == "true" ]] || [[ ! -f "$CONFIG_FILE" ]]; then
cat > "$CONFIG_FILE" << 'LUAEOF'
-- Push-to-Talk Whisper Transcription
-- Hold F12 to record, release to transcribe and paste
-- 100% local - no cloud, no data leaves your Mac

local whisper = "/opt/homebrew/bin/whisper-cli"
local sox = "/opt/homebrew/bin/sox"

-- SWITCH MODELS: Change "base" to "medium" for better accuracy (slower)
local model = os.getenv("HOME") .. "/Library/Application Support/whisper.cpp/ggml-base.en.bin"

local recordFile = os.getenv("HOME") .. "/rec_temp.wav"
local outputBase = os.getenv("HOME") .. "/transcribed"
local outputFile = outputBase .. ".txt"

local recordingTask = nil

-- CHANGE HOTKEY HERE if needed
local mods = {}
local key = "F12"

hs.hotkey.bind(mods, key,
  function()
    hs.alert.show("Recording...")
    recordingTask = hs.task.new(sox, nil, {"-d", "-r", "16000", "-c", "1", recordFile})
    recordingTask:start()
  end,
  function()
    hs.alert.show("Transcribing...")

    if recordingTask then
      recordingTask:terminate()
      recordingTask = nil
    end
    hs.execute("pkill -9 sox 2>/dev/null", true)
    hs.timer.usleep(300000)

    local recCheck = io.open(recordFile, "r")
    if recCheck then
      recCheck:close()
    else
      hs.alert.show("No recording!")
      return
    end

    local whisperTask = hs.task.new(whisper,
      function(exitCode, stdOut, stdErr)
        if exitCode == 0 then
          local f = io.open(outputFile, "r")
          if f then
            local text = f:read("*all")
            f:close()
            text = text:gsub("^%s+", ""):gsub("%s+$", "")
            if text and text ~= "" then
              hs.pasteboard.setContents(text)
              hs.eventtap.keyStroke({"cmd"}, "v")
              hs.alert.show("Done")
            else
              hs.alert.show("No speech detected")
            end
          else
            hs.alert.show("Transcription failed")
          end
        else
          hs.alert.show("Error: " .. tostring(exitCode))
        end
        os.remove(recordFile)
        os.remove(outputFile)
      end,
      {"-m", model, "-f", recordFile, "-otxt", "-of", outputBase, "-np"}
    )
    whisperTask:start()
  end
)

hs.alert.show("Voice transcription ready (F12)")
LUAEOF
    echo "✓ Hammerspoon config created"
fi

echo

# Open Hammerspoon
echo "═══════════════════════════════════════════════════════════════"
echo "  Installation complete!"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "NEXT STEPS (one-time setup):"
echo
echo "1. Hammerspoon is opening now. Grant permissions when prompted:"
echo "   • System Settings → Privacy & Security → Accessibility → Hammerspoon ✓"
echo "   • System Settings → Privacy & Security → Microphone → Hammerspoon ✓"
echo
echo "2. Click the Hammerspoon menu bar icon (hammer) → Reload Config"
echo
echo "3. Test it: Hold F12, speak, release F12"
echo
echo "─────────────────────────────────────────────────────────────────"
echo "Models installed:"
echo "  • base (current)  - Fast (~1-3s)"
echo "  • medium          - Accurate (~5-10s)"
echo
echo "To switch models, edit ~/.hammerspoon/init.lua line 8"
echo "─────────────────────────────────────────────────────────────────"
echo

# Open Hammerspoon
open -a Hammerspoon

echo "Done! You can close this terminal window."
