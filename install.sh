#!/bin/bash
# install-voice.sh - One-command push-to-talk voice transcription setup for macOS
# Usage: curl -fsSL URL -o /tmp/install.sh && bash /tmp/install.sh
#    or: bash install-voice.sh

VERSION="1.3.0"  # Update this when making changes

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
    echo "Homebrew not found. Installing..."
    echo "─────────────────────────────────────────────────────────────────"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Set up brew path after install
    if [[ -x "/opt/homebrew/bin/brew" ]]; then
        BREW_PATH="/opt/homebrew/bin/brew"
        eval "$($BREW_PATH shellenv)"
    elif [[ -x "/usr/local/bin/brew" ]]; then
        BREW_PATH="/usr/local/bin/brew"
        eval "$($BREW_PATH shellenv)"
    else
        echo "❌ Homebrew installation failed."
        exit 1
    fi
    echo "✓ Homebrew installed"
    echo
fi

echo "✓ macOS on Apple Silicon detected"
echo "✓ Homebrew found at $BREW_PATH"
echo

# Hotkey selection
echo "─────────────────────────────────────────────────────────────────"
echo "Choose your push-to-talk hotkey:"
echo ""
echo "  1) Option+Space      (default - Alt+Space on Windows keyboards)"
echo "  2) Right Option+Space (Right Alt+Space)"
echo "  3) Ctrl+Space"
echo "  4) Cmd+Space         (Windows key+Space, may conflict with Spotlight)"
echo ""

HOTKEY_MODS='{"alt"}'
HOTKEY_KEY="space"

# Check if running interactively
if [[ -t 0 ]]; then
    read -p "Enter choice [1-4, default=1]: " -n 1 -r hotkey_choice
    echo ""
    case "$hotkey_choice" in
        2) HOTKEY_MODS='{"rightalt"}'; HOTKEY_KEY="space" ;;
        3) HOTKEY_MODS='{"ctrl"}'; HOTKEY_KEY="space" ;;
        4) HOTKEY_MODS='{"cmd"}'; HOTKEY_KEY="space" ;;
        *) HOTKEY_MODS='{"alt"}'; HOTKEY_KEY="space" ;;
    esac
else
    echo "Running non-interactively, using default: Option+Space"
fi

case "$HOTKEY_MODS" in
    '{"alt"}') echo "✓ Hotkey selected: Option+Space (Alt+Space)" ;;
    '{"rightalt"}') echo "✓ Hotkey selected: Right Option+Space (Right Alt+Space)" ;;
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

download_model "ggml-base.en.bin" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin" || {
    echo "❌ Failed to download base model. Cannot continue."
    exit 1
}

echo ""
echo "ℹ️  Using base model (fast, ~1-3s transcription)"
echo "   For better accuracy, run: voice-ptt-model"
echo "   (Downloads 1.5GB medium model on demand)"

echo

# Optional: Advanced cleanup
echo "─────────────────────────────────────────────────────────────────"
echo "Text Cleanup Options"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "Basic cleanup (always enabled):"
echo "  • Removes filler words: um, uh, like, you know"
echo "  • Instant, no performance impact"
echo ""
echo "Advanced cleanup (optional):"
echo "  • LLM-based intelligent cleanup"
echo "  • Better punctuation and context awareness"
echo "  • Requires Ollama + llama3.2:1b (~1.3GB)"
echo "  • Adds ~1-2s to transcription time"
echo ""

ENABLE_ADVANCED_CLEANUP=false

# Check if running interactively
if [[ -t 0 ]]; then
    # Check if Ollama is available
    if command -v ollama &> /dev/null; then
        echo "✓ Ollama detected: $(command -v ollama)"
        read -p "Enable advanced cleanup? [Y/n] " -n 1 -r cleanup_choice
        echo ""
        if [[ ! $cleanup_choice =~ ^[Nn]$ ]]; then
            ENABLE_ADVANCED_CLEANUP=true
            echo "Downloading llama3.2:1b model (~1.3GB)..."
            echo "This may take a few minutes..."
            if ollama pull llama3.2:1b; then
                echo "✓ Model downloaded successfully"
            else
                echo "❌ Model download failed, advanced cleanup will be disabled"
                ENABLE_ADVANCED_CLEANUP=false
            fi
        else
            echo "Skipping advanced cleanup (can enable later with: voice-ptt-cleanup enable)"
        fi
    else
        echo "Ollama not found. Skipping advanced cleanup."
        echo "To enable later: brew install ollama && voice-ptt-cleanup enable"
    fi
else
    echo "Running non-interactively, skipping advanced cleanup prompt"
fi

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
    '{"alt"}') HOTKEY_DISPLAY="Option+Space" ;;
    '{"rightalt"}') HOTKEY_DISPLAY="Right Option+Space" ;;
    '{"ctrl"}') HOTKEY_DISPLAY="Ctrl+Space" ;;
    '{"cmd"}') HOTKEY_DISPLAY="Cmd+Space" ;;
    *) HOTKEY_DISPLAY="$HOTKEY_KEY" ;;
esac
cat > "$CONFIG_FILE" << LUAEOF
-- Push-to-Talk Whisper Transcription
-- Hold hotkey to record, release to transcribe and paste
-- 100% local - no cloud, no data leaves your Mac

-- Hide console window on startup
if hs.console.hswindow() then
  hs.console.hswindow():close()
end

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
            -- Remove internal newlines (whisper adds these during segmentation)
            text = text:gsub("\n", " "):gsub("^%s+", ""):gsub("%s+$", "")

            if text and text ~= "" then
              -- Apply basic cleanup (always enabled)
              text = basicCleanup(text)

              -- Apply advanced LLM cleanup if enabled
              if advancedCleanupEnabled and ollamaPath then
                local cleaned = advancedCleanup(text, ollamaPath)
                if cleaned then
                  text = cleaned
                end
              end

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

-- Text cleanup functions
local function basicCleanup(text)
  -- Remove common filler words (basic regex approach)
  text = text:gsub("%f[%a]um%f[%A]", "")
  text = text:gsub("%f[%a]uh%f[%A]", "")
  text = text:gsub("%f[%a]like%f[%A]", "")
  text = text:gsub("%f[%a]you know%f[%A]", "")

  -- Collapse multiple spaces
  text = text:gsub("%s+", " ")

  -- Capitalize first letter
  text = text:gsub("^%l", string.upper)

  return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function findOllama()
  -- Check PATH first
  local inPath = hs.execute("command -v ollama 2>/dev/null")
  if inPath and inPath ~= "" then
    return inPath:gsub("\n", "")
  end

  -- Common install locations
  local locations = {
    "/opt/homebrew/bin/ollama",
    "/usr/local/bin/ollama",
    os.getenv("HOME") .. "/.ollama/ollama",
    "/Applications/Ollama.app/Contents/Resources/ollama"
  }

  for _, path in ipairs(locations) do
    local check = io.open(path, "r")
    if check then
      check:close()
      return path
    end
  end

  return nil
end

local function advancedCleanup(text, ollamaPath)
  -- LLM-based cleanup (requires Ollama)
  local prompt = "Remove filler words (um, uh, like, you know) and fix punctuation. Keep meaning and style. Output only the cleaned text:\n\n" .. text

  -- Escape single quotes for shell
  prompt = prompt:gsub("'", "'\\\\''")

  local cmd = ollamaPath .. " run llama3.2:1b '" .. prompt .. "' 2>/dev/null"
  local result, status = hs.execute(cmd)

  if status and result and result ~= "" then
    return result:gsub("^%s+", ""):gsub("%s+$", "")
  end

  return nil  -- Fallback to basic cleanup
end

-- Check if advanced cleanup is enabled
local advancedCleanupEnabled = false
local ollamaPath = nil

local cleanupConfigFile = os.getenv("HOME") .. "/.config/voice-ptt/cleanup-enabled"
local f = io.open(cleanupConfigFile, "r")
if f then
  f:close()
  ollamaPath = findOllama()
  if ollamaPath then
    advancedCleanupEnabled = true
  end
end

-- Auto-update checker (runs every 7 days)
local function checkForUpdates()
  local versionFile = os.getenv("HOME") .. "/.config/voice-ptt/version"
  local lastCheckFile = os.getenv("HOME") .. "/.config/voice-ptt/last-check"

  -- Check if it's time to check for updates (every 7 days)
  local shouldCheck = false
  local lastCheckF = io.open(lastCheckFile, "r")
  if lastCheckF then
    local lastCheck = tonumber(lastCheckF:read("*all"))
    lastCheckF:close()
    local daysSinceCheck = (os.time() - lastCheck) / 86400
    shouldCheck = daysSinceCheck >= 7
  else
    shouldCheck = true  -- First run
  end

  if not shouldCheck then
    return
  end

  -- Update last check time
  local f = io.open(lastCheckFile, "w")
  if f then
    f:write(tostring(os.time()))
    f:close()
  end

  -- Read local version
  local localVersion = "unknown"
  local vf = io.open(versionFile, "r")
  if vf then
    localVersion = vf:read("*all"):gsub("\n", "")
    vf:close()
  end

  -- Check GitHub for latest version
  local output, status = hs.execute("curl -fsSL https://raw.githubusercontent.com/sparrowfm/voice-ptt/main/install.sh 2>/dev/null | grep '^VERSION=' | head -1 | cut -d'\"' -f2")

  if status and output then
    local remoteVersion = output:gsub("\n", "")
    if remoteVersion ~= "" and remoteVersion ~= localVersion then
      -- Show notification about available update
      hs.notify.new({
        title = "voice-ptt update available",
        informativeText = "Version " .. remoteVersion .. " is available (you have " .. localVersion .. ")\n\nRun: voice-ptt-update",
        hasActionButton = false,
        withdrawAfter = 0  -- Don't auto-dismiss
      }):send()
    end
  end
end

-- Check for updates 30 seconds after launch, then every 7 days
hs.timer.doAfter(30, checkForUpdates)

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
echo "  1) Option+Space      (Alt+Space on Windows keyboards)"
echo "  2) Right Option+Space (Right Alt+Space)"
echo "  3) Ctrl+Space"
echo "  4) Cmd+Space         (Windows key+Space, may conflict with Spotlight)"
echo ""
read -p "Enter choice [1-4]: " -n 1 -r choice
echo ""

case "$choice" in
    1) NEW_MODS='{"alt"}'; NEW_KEY="space" ;;
    2) NEW_MODS='{"rightalt"}'; NEW_KEY="space" ;;
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
    '{"alt"}') NEW_DISPLAY="Option+Space" ;;
    '{"rightalt"}') NEW_DISPLAY="Right Option+Space" ;;
    '{"ctrl"}') NEW_DISPLAY="Ctrl+Space" ;;
    '{"cmd"}') NEW_DISPLAY="Cmd+Space" ;;
    *) NEW_DISPLAY="$NEW_KEY" ;;
esac
sed -i '' "s/Voice transcription ready ([^)]*)/Voice transcription ready ($NEW_DISPLAY)/" "$CONFIG_FILE"

echo "✓ Hotkey changed to: $NEW_DISPLAY"
open -g hammerspoon://reload
echo "✓ Hammerspoon config reloaded"
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
echo "  1) Option+Space      (Alt+Space on Windows keyboards)"
echo "  2) Right Option+Space (Right Alt+Space)"
echo "  3) Ctrl+Space"
echo "  4) Cmd+Space         (Windows key+Space, may conflict with Spotlight)"
echo ""
read -p "Enter choice [1-4]: " -n 1 -r choice
echo ""

case "$choice" in
    1) NEW_MODS='{"alt"}'; NEW_KEY="space" ;;
    2) NEW_MODS='{"rightalt"}'; NEW_KEY="space" ;;
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
    '{"alt"}') NEW_DISPLAY="Option+Space" ;;
    '{"rightalt"}') NEW_DISPLAY="Right Option+Space" ;;
    '{"ctrl"}') NEW_DISPLAY="Ctrl+Space" ;;
    '{"cmd"}') NEW_DISPLAY="Cmd+Space" ;;
    *) NEW_DISPLAY="$NEW_KEY" ;;
esac
sed -i '' "s/Voice transcription ready ([^)]*)/Voice transcription ready ($NEW_DISPLAY)/" "$CONFIG_FILE"

echo "✓ Hotkey changed to: $NEW_DISPLAY"
open -g hammerspoon://reload
echo "✓ Hammerspoon config reloaded"
HOTKEYEOF
    chmod +x "$HOME/bin/voice-ptt-hotkey"
    echo "✓ Hotkey command installed"
}

# Create model switch script
cat > "$HOME/bin/voice-ptt-model" << 'MODELEOF'
#!/bin/bash
# voice-ptt-model - Switch between Whisper models

CONFIG_FILE="$HOME/.hammerspoon/init.lua"
MODEL_DIR="$HOME/Library/Application Support/whisper.cpp"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Hammerspoon config not found. Run the installer first."
    exit 1
fi

# Check current model
current=$(grep "^local model = " "$CONFIG_FILE" | grep -o "ggml-[^.]*")
echo "Current model: $current"
echo ""
echo "Choose model:"
echo ""
echo "  1) base   - Fast (~1-3s), good accuracy, 142MB"
echo "  2) medium - Slower (~5-10s), best accuracy, 1.5GB"
echo ""
read -p "Enter choice [1-2]: " -n 1 -r choice
echo ""

case "$choice" in
    1) NEW_MODEL="ggml-base.en.bin" ;;
    2) NEW_MODEL="ggml-medium.en.bin" ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

# Check if model exists
if [[ ! -f "$MODEL_DIR/$NEW_MODEL" ]]; then
    echo "Model not downloaded. Downloading now..."
    if [[ "$NEW_MODEL" == "ggml-base.en.bin" ]]; then
        curl -L --progress-bar -o "$MODEL_DIR/$NEW_MODEL" \
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
    else
        curl -L --progress-bar -o "$MODEL_DIR/$NEW_MODEL" \
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin"
    fi
fi

# Update config
sed -i '' "s|ggml-base.en.bin|$NEW_MODEL|g" "$CONFIG_FILE"
sed -i '' "s|ggml-medium.en.bin|$NEW_MODEL|g" "$CONFIG_FILE"

echo "✓ Model changed to: $NEW_MODEL"
open -g hammerspoon://reload
echo "✓ Hammerspoon config reloaded"
MODELEOF
chmod +x "$HOME/bin/voice-ptt-model"
echo "✓ Model command installed"

# Create update script
cat > "$HOME/bin/voice-ptt-update" << 'UPDATEEOF'
#!/bin/bash
# voice-ptt-update - Update voice-ptt to the latest version

REPO_URL="https://raw.githubusercontent.com/sparrowfm/voice-ptt/main/install.sh"
CONFIG_FILE="$HOME/.hammerspoon/init.lua"

echo "═══════════════════════════════════════════════════════════════"
echo "  Voice-PTT Update Checker"
echo "═══════════════════════════════════════════════════════════════"
echo

# Check if voice-ptt is installed
if [[ ! -f "$CONFIG_FILE" ]] || ! grep -q "Push-to-Talk Whisper" "$CONFIG_FILE" 2>/dev/null; then
    echo "❌ voice-ptt not installed. Run the installer first:"
    echo "   curl -fsSL https://raw.githubusercontent.com/sparrowfm/voice-ptt/main/install.sh -o /tmp/install.sh && bash /tmp/install.sh"
    exit 1
fi

echo "Checking for updates..."

# Save current hotkey configuration
CURRENT_MODS=$(grep "^local mods = " "$CONFIG_FILE" | head -1 | sed 's/.*= //')
CURRENT_KEY=$(grep "^local key = " "$CONFIG_FILE" | head -1 | sed 's/.*= //')

echo "✓ Current installation found"
echo "  Hotkey: $CURRENT_MODS + $CURRENT_KEY"
echo

# Download latest installer
TMP_INSTALLER="/tmp/voice-ptt-update-$$.sh"
if ! curl -fsSL "$REPO_URL" -o "$TMP_INSTALLER"; then
    echo "❌ Failed to download latest version"
    exit 1
fi

echo "✓ Downloaded latest version"
echo

# Backup current config
BACKUP_FILE="$HOME/.hammerspoon/init.lua.backup.$(date +%Y%m%d%H%M%S)"
if [[ -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo "✓ Backed up config to $(basename "$BACKUP_FILE")"
    echo
fi

echo "─────────────────────────────────────────────────────────────────"
read -p "Apply update? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Update cancelled"
    rm -f "$TMP_INSTALLER"
    exit 0
fi

echo
echo "Applying update..."
echo "─────────────────────────────────────────────────────────────────"

# Run installer in non-interactive mode
bash "$TMP_INSTALLER" < /dev/null

# Restore hotkey settings
if [[ -f "$CONFIG_FILE" ]]; then
    sed -i '' "s/^local mods = .*/local mods = $CURRENT_MODS/" "$CONFIG_FILE" 2>/dev/null
    sed -i '' "s/^local key = .*/local key = $CURRENT_KEY/" "$CONFIG_FILE" 2>/dev/null
fi

rm -f "$TMP_INSTALLER"

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Update complete!"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "Your hotkey settings have been preserved: $CURRENT_MODS + $CURRENT_KEY"
echo
echo "Reloading Hammerspoon..."
open -g hammerspoon://reload
echo "✓ Done"
UPDATEEOF
chmod +x "$HOME/bin/voice-ptt-update"
echo "✓ Update command installed"

# Create cleanup toggle script
cat > "$HOME/bin/voice-ptt-cleanup" << 'CLEANUPEOF'
#!/bin/bash
# voice-ptt-cleanup - Toggle advanced LLM-based text cleanup

CLEANUP_FILE="$HOME/.config/voice-ptt/cleanup-enabled"

show_status() {
  echo "==================================================================="
  echo "  voice-ptt Text Cleanup Status"
  echo "==================================================================="
  echo ""
  echo "Basic cleanup: ENABLED (always on)"
  echo "  - Removes: um, uh, like, you know"
  echo "  - Capitalizes first letter"
  echo "  - No performance impact"
  echo ""

  if [[ -f "$CLEANUP_FILE" ]]; then
    echo "Advanced cleanup: ENABLED"
    if command -v ollama &> /dev/null; then
      echo "  - Ollama: $(command -v ollama)"
      if ollama list 2>/dev/null | grep -q "llama3.2:1b"; then
        echo "  - Model: llama3.2:1b (ready)"
      else
        echo "  - Model: llama3.2:1b (not downloaded)"
      fi
    else
      echo "  - Ollama: NOT FOUND (cleanup won't work)"
    fi
    echo "  - Adds ~1-2s latency"
  else
    echo "Advanced cleanup: DISABLED"
  fi
}

enable_advanced() {
  echo "==================================================================="
  echo "  Enable Advanced Cleanup"
  echo "==================================================================="
  echo ""

  # Check for Ollama
  if ! command -v ollama &> /dev/null; then
    echo "❌ Ollama not found."
    echo ""
    echo "Install Ollama first:"
    echo "  brew install ollama"
    echo "  OR visit https://ollama.ai"
    exit 1
  fi

  echo "✓ Ollama found: $(command -v ollama)"
  echo ""

  # Check if model exists
  if ! ollama list 2>/dev/null | grep -q "llama3.2:1b"; then
    echo "Downloading llama3.2:1b model (~1.3GB, one-time)..."
    echo "This may take a few minutes..."
    echo ""
    if ! ollama pull llama3.2:1b; then
      echo "❌ Failed to download model"
      exit 1
    fi
  else
    echo "✓ Model llama3.2:1b already downloaded"
  fi

  # Enable cleanup
  mkdir -p "$(dirname "$CLEANUP_FILE")"
  touch "$CLEANUP_FILE"

  # Reload Hammerspoon
  open -g hammerspoon://reload

  echo ""
  echo "✓ Advanced cleanup enabled"
  echo "  Adds ~1-2s to transcription time"
  echo ""
  echo "To disable: voice-ptt-cleanup disable"
}

disable_advanced() {
  rm -f "$CLEANUP_FILE"
  open -g hammerspoon://reload
  echo "✓ Advanced cleanup disabled"
  echo "  Basic cleanup still active (always on)"
}

case "${1:-status}" in
  enable)
    enable_advanced
    ;;
  disable)
    disable_advanced
    ;;
  status)
    show_status
    ;;
  *)
    echo "Usage: voice-ptt-cleanup [enable|disable|status]"
    echo ""
    echo "Commands:"
    echo "  enable   - Enable advanced LLM cleanup (requires Ollama)"
    echo "  disable  - Disable advanced cleanup (basic cleanup remains)"
    echo "  status   - Show current cleanup status (default)"
    exit 1
    ;;
esac
CLEANUPEOF
chmod +x "$HOME/bin/voice-ptt-cleanup"
echo "✓ Cleanup command installed"

# Store version for update checking
mkdir -p "$HOME/.config/voice-ptt"
echo "$VERSION" > "$HOME/.config/voice-ptt/version"

# Enable advanced cleanup if user opted in during install
if [[ "$ENABLE_ADVANCED_CLEANUP" == "true" ]]; then
    touch "$HOME/.config/voice-ptt/cleanup-enabled"
    echo "✓ Advanced cleanup enabled"
fi

# Add ~/bin to PATH in .zshrc if not already there
if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.zshrc" 2>/dev/null; then
    echo '' >> "$HOME/.zshrc"
    echo '# Added by voice-ptt installer' >> "$HOME/.zshrc"
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
    echo "✓ Added ~/bin to PATH in ~/.zshrc"
fi

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
    '{"alt"}') echo "3. Test it: Hold Option+Space (Alt+Space), speak, release" ;;
    '{"rightalt"}') echo "3. Test it: Hold Right Option+Space (Right Alt+Space), speak, release" ;;
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

# Open Hammerspoon (in background, without showing console)
echo "Opening Hammerspoon..."
open -g -a Hammerspoon

echo
echo "Done! You can close this terminal window."
