#!/bin/bash
# install-voice.sh - One-command push-to-talk voice transcription setup for macOS
# Usage: curl -fsSL URL -o /tmp/install.sh && bash /tmp/install.sh
#    or: bash install-voice.sh

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

# Hotkey selection
echo "─────────────────────────────────────────────────────────────────"
echo "Choose your push-to-talk hotkey:"
echo ""
echo "  1) Right Option/Alt  (default - single key, hold to record)"
echo "  2) Option+Space      (Alt+Space on Windows keyboards)"
echo "  3) Ctrl+Space"
echo "  4) Cmd+Space         (Windows key+Space, may conflict with Spotlight)"
echo ""

HOTKEY_MODS='{"rightalt"}'
HOTKEY_KEY="space"

# Check if running interactively
if [[ -t 0 ]]; then
    read -p "Enter choice [1-4, default=1]: " -n 1 -r hotkey_choice
    echo ""
    case "$hotkey_choice" in
        2) HOTKEY_MODS='{"alt"}'; HOTKEY_KEY="space" ;;
        3) HOTKEY_MODS='{"ctrl"}'; HOTKEY_KEY="space" ;;
        4) HOTKEY_MODS='{"cmd"}'; HOTKEY_KEY="space" ;;
        *) HOTKEY_MODS='{"rightalt"}'; HOTKEY_KEY="space" ;;
    esac
else
    echo "Running non-interactively, using default: Right Alt"
fi

case "$HOTKEY_MODS" in
    '{"rightalt"}') echo "✓ Hotkey selected: Right Option/Alt (hold to record)" ;;
    '{"alt"}') echo "✓ Hotkey selected: Option+Space (Alt+Space)" ;;
    '{"ctrl"}') echo "✓ Hotkey selected: Ctrl+Space" ;;
    '{"cmd"}') echo "✓ Hotkey selected: Cmd+Space (Win+Space)" ;;
    *) echo "✓ Hotkey selected: $HOTKEY_MODS + $HOTKEY_KEY" ;;
esac
echo

# Install dependencies
echo "Installing dependencies..."
echo "─────────────────────────────────────────────────────────────────"

if ! command -v whisper-cli &> /dev/null; then
    echo "Installing whisper-cpp..."
    if ! brew install whisper-cpp; then
        echo "❌ Failed to install whisper-cpp"
        exit 1
    fi
else
    echo "✓ whisper-cpp already installed"
fi

if ! command -v sox &> /dev/null; then
    echo "Installing sox..."
    if ! brew install sox; then
        echo "❌ Failed to install sox"
        exit 1
    fi
else
    echo "✓ sox already installed"
fi

if [[ ! -d "/Applications/Hammerspoon.app" ]]; then
    echo "Installing Hammerspoon..."
    if ! brew install --cask hammerspoon; then
        echo "❌ Failed to install Hammerspoon"
        exit 1
    fi
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
            return 0
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

download_model "ggml-base.en.bin" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin" || echo "⚠ Continuing without base model"
download_model "ggml-medium.en.bin" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin" || echo "⚠ Continuing without medium model"

echo

# Create Hammerspoon config
echo "Creating Hammerspoon configuration..."
echo "─────────────────────────────────────────────────────────────────"

mkdir -p "$HOME/.hammerspoon"

CONFIG_FILE="$HOME/.hammerspoon/init.lua"
write_config=false

# Backup existing config if it exists and doesn't have our config
if [[ -f "$CONFIG_FILE" ]]; then
    if grep -q "Push-to-Talk Whisper" "$CONFIG_FILE" 2>/dev/null; then
        echo "✓ Push-to-talk config already present in init.lua"
        echo "  (To change hotkey, run: voice-ptt-hotkey)"
    else
        BACKUP_FILE="$HOME/.hammerspoon/init.lua.backup.$(date +%Y%m%d%H%M%S)"
        echo "Backing up existing init.lua to $(basename "$BACKUP_FILE")"
        cp "$CONFIG_FILE" "$BACKUP_FILE"
        echo "Creating new init.lua with push-to-talk config..."
        write_config=true
    fi
else
    echo "Creating init.lua..."
    write_config=true
fi

# Write config if needed (new install or backup was made)
if [[ "$write_config" == "true" ]]; then
# Set display name for alert
case "$HOTKEY_MODS" in
    '{"rightalt"}') HOTKEY_DISPLAY="Right Option/Alt" ;;
    '{"alt"}') HOTKEY_DISPLAY="Option+Space" ;;
    '{"ctrl"}') HOTKEY_DISPLAY="Ctrl+Space" ;;
    '{"cmd"}') HOTKEY_DISPLAY="Cmd+Space" ;;
    *) HOTKEY_DISPLAY="$HOTKEY_KEY" ;;
esac
cat > "$CONFIG_FILE" << LUAEOF
-- Push-to-Talk Whisper Transcription
-- Hold hotkey to record, release to transcribe and paste
-- 100% local - no cloud, no data leaves your Mac

local whisper = "/opt/homebrew/bin/whisper-cli"
local sox = "/opt/homebrew/bin/sox"

-- SWITCH MODELS: Change "base" to "medium" for better accuracy (slower)
local model = os.getenv("HOME") .. "/Library/Application Support/whisper.cpp/ggml-base.en.bin"

local recordFile = os.getenv("HOME") .. "/rec_temp.wav"
local outputBase = os.getenv("HOME") .. "/transcribed"
local outputFile = outputBase .. ".txt"

local recordingTask = nil

-- HOTKEY CONFIG (change with voice-ptt-hotkey command)
local mods = $HOTKEY_MODS
local key = "$HOTKEY_KEY"

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

hs.alert.show("Voice transcription ready ($HOTKEY_DISPLAY)")
LUAEOF
    echo "✓ Hammerspoon config created"
fi

# Create hotkey change script
echo "Creating hotkey configuration command..."
cat > /usr/local/bin/voice-ptt-hotkey << 'HOTKEYEOF'
#!/bin/bash
# voice-ptt-hotkey - Change the push-to-talk hotkey

CONFIG_FILE="$HOME/.hammerspoon/init.lua"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Hammerspoon config not found. Run the installer first."
    exit 1
fi

echo "Current hotkey configuration:"
grep -E "^local (mods|key) = " "$CONFIG_FILE" | head -2
echo ""
echo "Choose new hotkey:"
echo ""
echo "  1) Right Option/Alt  (single key, hold to record)"
echo "  2) Option+Space      (Alt+Space on Windows keyboards)"
echo "  3) Ctrl+Space"
echo "  4) Cmd+Space         (Windows key+Space, may conflict with Spotlight)"
echo ""
read -p "Enter choice [1-4]: " -n 1 -r choice
echo ""

case "$choice" in
    1) NEW_MODS='{"rightalt"}'; NEW_KEY="space" ;;
    2) NEW_MODS='{"alt"}'; NEW_KEY="space" ;;
    3) NEW_MODS='{"ctrl"}'; NEW_KEY="space" ;;
    4) NEW_MODS='{"cmd"}'; NEW_KEY="space" ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

# Update the config file
sed -i '' "s/^local mods = .*/local mods = $NEW_MODS/" "$CONFIG_FILE"
sed -i '' "s/^local key = .*/local key = \"$NEW_KEY\"/" "$CONFIG_FILE"

# Set display name and update the alert message
case "$NEW_MODS" in
    '{"rightalt"}') NEW_DISPLAY="Right Option/Alt" ;;
    '{"alt"}') NEW_DISPLAY="Option+Space" ;;
    '{"ctrl"}') NEW_DISPLAY="Ctrl+Space" ;;
    '{"cmd"}') NEW_DISPLAY="Cmd+Space" ;;
    *) NEW_DISPLAY="$NEW_KEY" ;;
esac
sed -i '' "s/Voice transcription ready ([^)]*)/Voice transcription ready ($NEW_DISPLAY)/" "$CONFIG_FILE"

echo "✓ Hotkey changed to: $NEW_DISPLAY"
echo ""
echo "Reload Hammerspoon config: menu bar icon → Reload Config"
HOTKEYEOF
chmod +x /usr/local/bin/voice-ptt-hotkey 2>/dev/null || {
    # If /usr/local/bin isn't writable, put it in ~/bin
    mkdir -p "$HOME/bin"
    mv /usr/local/bin/voice-ptt-hotkey "$HOME/bin/voice-ptt-hotkey" 2>/dev/null || cat > "$HOME/bin/voice-ptt-hotkey" << 'HOTKEYEOF'
#!/bin/bash
# voice-ptt-hotkey - Change the push-to-talk hotkey

CONFIG_FILE="$HOME/.hammerspoon/init.lua"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Hammerspoon config not found. Run the installer first."
    exit 1
fi

echo "Current hotkey configuration:"
grep -E "^local (mods|key) = " "$CONFIG_FILE" | head -2
echo ""
echo "Choose new hotkey:"
echo ""
echo "  1) Right Option/Alt  (single key, hold to record)"
echo "  2) Option+Space      (Alt+Space on Windows keyboards)"
echo "  3) Ctrl+Space"
echo "  4) Cmd+Space         (Windows key+Space, may conflict with Spotlight)"
echo ""
read -p "Enter choice [1-4]: " -n 1 -r choice
echo ""

case "$choice" in
    1) NEW_MODS='{"rightalt"}'; NEW_KEY="space" ;;
    2) NEW_MODS='{"alt"}'; NEW_KEY="space" ;;
    3) NEW_MODS='{"ctrl"}'; NEW_KEY="space" ;;
    4) NEW_MODS='{"cmd"}'; NEW_KEY="space" ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

# Update the config file
sed -i '' "s/^local mods = .*/local mods = $NEW_MODS/" "$CONFIG_FILE"
sed -i '' "s/^local key = .*/local key = \"$NEW_KEY\"/" "$CONFIG_FILE"

# Set display name and update the alert message
case "$NEW_MODS" in
    '{"rightalt"}') NEW_DISPLAY="Right Option/Alt" ;;
    '{"alt"}') NEW_DISPLAY="Option+Space" ;;
    '{"ctrl"}') NEW_DISPLAY="Ctrl+Space" ;;
    '{"cmd"}') NEW_DISPLAY="Cmd+Space" ;;
    *) NEW_DISPLAY="$NEW_KEY" ;;
esac
sed -i '' "s/Voice transcription ready ([^)]*)/Voice transcription ready ($NEW_DISPLAY)/" "$CONFIG_FILE"

echo "✓ Hotkey changed to: $NEW_DISPLAY"
echo ""
echo "Reload Hammerspoon config: menu bar icon → Reload Config"
HOTKEYEOF
    chmod +x "$HOME/bin/voice-ptt-hotkey"
    # Add ~/bin to PATH in .zshrc if not already there
    if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.zshrc" 2>/dev/null; then
        echo '' >> "$HOME/.zshrc"
        echo '# Added by voice-ptt installer' >> "$HOME/.zshrc"
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
        echo "✓ Added ~/bin to PATH in ~/.zshrc"
    fi
    echo "✓ Hotkey command installed to ~/bin/voice-ptt-hotkey"
}

echo

# Final instructions
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
case "$HOTKEY_MODS" in
    '{"rightalt"}') echo "3. Test it: Hold Right Option/Alt, speak, release" ;;
    '{"alt"}') echo "3. Test it: Hold Option+Space (Alt+Space), speak, release" ;;
    '{"ctrl"}') echo "3. Test it: Hold Ctrl+Space, speak, release" ;;
    '{"cmd"}') echo "3. Test it: Hold Cmd+Space (Win+Space), speak, release" ;;
    *) echo "3. Test it: Hold hotkey, speak, release" ;;
esac
echo
echo "─────────────────────────────────────────────────────────────────"
echo "To change hotkey later, run: voice-ptt-hotkey"
echo "─────────────────────────────────────────────────────────────────"
echo

# Trigger microphone permission for sox
echo "─────────────────────────────────────────────────────────────────"
echo "Triggering microphone permission..."
echo "⚠️  If prompted, click ALLOW for microphone access!"
echo ""
/opt/homebrew/bin/sox -d -r 16000 -c 1 /tmp/mic_test.wav trim 0 1 2>/dev/null || true
rm -f /tmp/mic_test.wav 2>/dev/null
echo "✓ Microphone permission triggered"
echo

# Open Hammerspoon
echo "Opening Hammerspoon..."
open -a Hammerspoon

echo
echo "Done! You can close this terminal window."
