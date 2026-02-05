#!/bin/bash
# install.sh - One-command push-to-talk voice transcription setup for macOS
# Usage: curl -fsSL URL -o /tmp/install.sh && bash /tmp/install.sh
#    or: bash install.sh

VERSION="1.4.8"  # Update this when making changes

# Configuration constants
readonly WHISPER_MODEL_DIR="$HOME/Library/Application Support/whisper.cpp"
readonly CONFIG_DIR="$HOME/.config/voice-ptt"
readonly HAMMERSPOON_CONFIG="$HOME/.hammerspoon/init.lua"
readonly BIN_DIR="$HOME/bin"

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

# Find or install Homebrew
function find_homebrew() {
    local brew_locations=("/opt/homebrew/bin/brew" "/usr/local/bin/brew")

    # Check if brew is already in PATH
    if command -v brew &> /dev/null; then
        echo "$(command -v brew)"
        return 0
    fi

    # Check common locations
    for brew_path in "${brew_locations[@]}"; do
        if [[ -x "$brew_path" ]]; then
            eval "$($brew_path shellenv)"
            echo "$brew_path"
            return 0
        fi
    done

    return 1
}

if ! BREW_PATH=$(find_homebrew); then
    echo "Homebrew not found. Installing..."
    echo "─────────────────────────────────────────────────────────────────"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if ! BREW_PATH=$(find_homebrew); then
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
function select_hotkey() {
    echo "─────────────────────────────────────────────────────────────────"
    echo "Choose your push-to-talk hotkey:"
    echo ""
    echo "  1) Option+Space      (default - Alt+Space on Windows keyboards)"
    echo "  2) Right Option+Space (Right Alt+Space)"
    echo "  3) Ctrl+Space"
    echo "  4) Cmd+Space         (Windows key+Space, may conflict with Spotlight)"
    echo ""

    # Default values
    HOTKEY_MODS='{"alt"}'
    HOTKEY_KEY="space"
    local display_name="Option+Space (Alt+Space)"

    # Check if running interactively
    if [[ -t 0 ]]; then
        read -p "Enter choice [1-4, default=1]: " -n 1 -r hotkey_choice
        echo ""
        case "$hotkey_choice" in
            2)
                HOTKEY_MODS='{"rightalt"}'
                display_name="Right Option+Space (Right Alt+Space)"
                ;;
            3)
                HOTKEY_MODS='{"ctrl"}'
                display_name="Ctrl+Space"
                ;;
            4)
                HOTKEY_MODS='{"cmd"}'
                display_name="Cmd+Space (Win+Space)"
                ;;
            *)
                # Default already set above
                ;;
        esac
    else
        echo "Running non-interactively, using default: Option+Space"
    fi

    echo "✓ Hotkey selected: $display_name"
    echo
}

select_hotkey

# Install dependencies
function install_dependency() {
    local command_name="$1"
    local package_name="$2"
    local check_path="${3:-}"

    # For cask apps, check app bundle instead of command
    if [[ -n "$check_path" ]]; then
        if [[ -d "$check_path" ]]; then
            echo "✓ $package_name already installed"
            return 0
        fi
    else
        if command -v "$command_name" &> /dev/null; then
            echo "✓ $package_name already installed"
            return 0
        fi
    fi

    echo "Installing $package_name..."
    if [[ "$package_name" == *"--cask"* ]]; then
        if ! brew install $package_name; then
            echo "❌ Failed to install $package_name"
            exit 1
        fi
    else
        if ! brew install "$package_name"; then
            echo "❌ Failed to install $package_name"
            exit 1
        fi
    fi
}

echo "Installing dependencies..."
echo "─────────────────────────────────────────────────────────────────"

install_dependency "whisper-cli" "whisper-cpp"
install_dependency "sox" "sox"
install_dependency "" "--cask hammerspoon" "/Applications/Hammerspoon.app"

echo

# Download models
echo "Downloading Whisper models..."
echo "─────────────────────────────────────────────────────────────────"

mkdir -p "$WHISPER_MODEL_DIR"

function download_model() {
    local name="$1"
    local url="$2"
    local path="$WHISPER_MODEL_DIR/$name"
    local min_size="${3:-10000000}"  # Default 10MB minimum

    if [[ -f "$path" ]]; then
        echo "✓ $name already downloaded"
        return 0
    fi

    echo "Downloading $name..."
    local tmp_path="${path}.tmp"

    if ! curl -L --progress-bar -o "$tmp_path" "$url"; then
        rm -f "$tmp_path"
        echo "❌ $name download failed"
        return 1
    fi

    # Verify file is not empty/corrupt
    local size=$(stat -f%z "$tmp_path" 2>/dev/null || echo "0")
    if [[ "$size" -lt "$min_size" ]]; then
        rm -f "$tmp_path"
        echo "❌ $name download failed (file too small: $size bytes)"
        return 1
    fi

    mv "$tmp_path" "$path"
    echo "✓ $name downloaded successfully"
    return 0
}

download_model "ggml-base.en.bin" \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin" || {
    echo "❌ Failed to download base model. Cannot continue."
    exit 1
}

echo ""
echo "ℹ️  Using base model (fast, ~1-3s transcription)"
echo "   For better accuracy, run: voice-ptt-model"
echo "   (Downloads 1.5GB medium model on demand)"

echo

# Optional: Advanced cleanup
function configure_advanced_cleanup() {
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
    echo "  • Requires Ollama + llama3.2:3b (~2GB)"
    echo "  • Adds ~1-2s to transcription time"
    echo ""

    ENABLE_ADVANCED_CLEANUP=false

    # Check if running interactively
    if [[ ! -t 0 ]]; then
        echo "Running non-interactively, skipping advanced cleanup prompt"
        echo
        return
    fi

    # Check if Ollama is available
    if ! command -v ollama &> /dev/null; then
        echo "Ollama not found. Skipping advanced cleanup."
        echo "To enable later: brew install ollama && voice-ptt-cleanup enable"
        echo
        return
    fi

    echo "✓ Ollama detected: $(command -v ollama)"
    read -p "Enable advanced cleanup? [Y/N] " -n 1 -r cleanup_choice
    echo ""

    if [[ $cleanup_choice =~ ^[Nn]$ ]]; then
        echo "Skipping advanced cleanup (can enable later with: voice-ptt-cleanup enable)"
        echo
        return
    fi

    ENABLE_ADVANCED_CLEANUP=true

    # Start Ollama service if not running
    if ! pgrep -x "ollama" > /dev/null; then
        echo "Starting Ollama service..."
        ollama serve > /dev/null 2>&1 &
        sleep 2  # Give it time to start
        echo "✓ Ollama service started"
    fi

    echo "Downloading llama3.2:3b model (~2GB)..."
    echo "This may take a few minutes..."
    if ! ollama pull llama3.2:3b; then
        echo "❌ Model download failed, advanced cleanup will be disabled"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check if Ollama service is running: pgrep ollama"
        echo "  2. Try manually: ollama serve (in another terminal)"
        echo "  3. Then run: voice-ptt-cleanup enable"
        ENABLE_ADVANCED_CLEANUP=false
    else
        echo "✓ Model downloaded successfully"
    fi

    echo
}

configure_advanced_cleanup

# Create Hammerspoon config
function setup_hammerspoon_config() {
    echo "Creating Hammerspoon configuration..."
    echo "─────────────────────────────────────────────────────────────────"

    mkdir -p "$HOME/.hammerspoon"

    local voice_ptt_file="$HOME/.hammerspoon/voice-ptt.lua"
    local is_update=false
    local saved_model=""

    # Check for existing voice-ptt module (update scenario)
    if [[ -f "$voice_ptt_file" ]]; then
        is_update=true
        # Extract existing settings to preserve them
        local existing_mods=$(grep "^local mods = " "$voice_ptt_file" | head -1 | sed 's/.*= //')
        local existing_key=$(grep "^local key = " "$voice_ptt_file" | head -1 | sed 's/.*= //' | tr -d '"')
        saved_model=$(grep "ggml-.*\.bin" "$voice_ptt_file" | head -1 | grep -o "ggml-[^\"]*\.bin")

        if [[ -n "$existing_mods" ]]; then
            HOTKEY_MODS="$existing_mods"
        fi
        if [[ -n "$existing_key" ]]; then
            HOTKEY_KEY="$existing_key"
        fi

        echo "✓ Existing voice-ptt config detected - updating"
        echo "  Hotkey: $HOTKEY_MODS + \"$HOTKEY_KEY\""
        if [[ -n "$saved_model" ]]; then
            echo "  Model: $saved_model"
        fi
    fi

    # Set display name for alert
    local hotkey_display
    case "$HOTKEY_MODS" in
        '{"alt"}') hotkey_display="Option+Space" ;;
        '{"rightalt"}') hotkey_display="Right Option+Space" ;;
        '{"ctrl"}') hotkey_display="Ctrl+Space" ;;
        '{"cmd"}') hotkey_display="Cmd+Space" ;;
        *) hotkey_display="$HOTKEY_KEY" ;;
    esac

    # Write the voice-ptt module (always safe to overwrite - it's our file)
    write_voice_ptt_module "$hotkey_display"

    # Restore model setting if this was an update with non-default model
    if [[ "$is_update" == "true" && -n "$saved_model" && "$saved_model" != "ggml-base.en.bin" ]]; then
        sed -i '' "s|ggml-base.en.bin|$saved_model|g" "$voice_ptt_file"
        echo "✓ Model setting restored: $saved_model"
    fi

    # Ensure init.lua loads voice-ptt (only add if not already present)
    if [[ ! -f "$HAMMERSPOON_CONFIG" ]]; then
        # No init.lua - create minimal one that loads voice-ptt
        cat > "$HAMMERSPOON_CONFIG" << 'INITEOF'
-- Hammerspoon configuration
-- Add your customizations here

-- Load voice-ptt push-to-talk transcription
require('voice-ptt')
INITEOF
        echo "✓ Created init.lua with voice-ptt loader"
    elif ! grep -q "require.*voice-ptt" "$HAMMERSPOON_CONFIG" 2>/dev/null; then
        # init.lua exists but doesn't load voice-ptt - add it
        echo "" >> "$HAMMERSPOON_CONFIG"
        echo "-- Load voice-ptt push-to-talk transcription" >> "$HAMMERSPOON_CONFIG"
        echo "require('voice-ptt')" >> "$HAMMERSPOON_CONFIG"
        echo "✓ Added voice-ptt loader to existing init.lua"
    else
        echo "✓ init.lua already loads voice-ptt"
    fi

    if [[ "$is_update" == "true" ]]; then
        echo "✓ voice-ptt.lua updated"
    else
        echo "✓ voice-ptt.lua created"
    fi
}

function write_voice_ptt_module() {
    local hotkey_display="$1"
    local voice_ptt_file="$HOME/.hammerspoon/voice-ptt.lua"
    cat > "$voice_ptt_file" << LUAEOF
-- Push-to-Talk Whisper Transcription
-- Hold hotkey to record, release to transcribe and paste
-- 100% local - no cloud, no data leaves your Mac
--
-- This file is managed by voice-ptt installer.
-- Safe to update - your init.lua customizations are preserved.

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

-- ============================================================
-- HELPER FUNCTIONS (must be defined before hs.hotkey.bind)
-- ============================================================

-- Custom dictionary for text replacements
local dictionaryEntries = {}

local function loadDictionary()
  local dictFile = os.getenv("HOME") .. "/.config/voice-ptt/dictionary.txt"
  local f = io.open(dictFile, "r")
  if not f then
    return
  end

  dictionaryEntries = {}
  for line in f:lines() do
    -- Skip empty lines and comments
    if line:match("%S") and not line:match("^%s*#") then
      -- Parse format: FIND -> REPLACE or FIND|REPLACE
      local find, replace = line:match("^%s*(.-)%s*%->%s*(.-)%s*$")
      if not find then
        find, replace = line:match("^%s*(.-)%s*|%s*(.-)%s*$")
      end

      if find and replace then
        -- Check for case-insensitive marker (?i)
        local caseInsensitive = false
        if find:match("^%(%?i%)") then
          caseInsensitive = true
          find = find:gsub("^%(%?i%)", "")
        end

        table.insert(dictionaryEntries, {
          find = find,
          replace = replace,
          caseInsensitive = caseInsensitive
        })
      end
    end
  end
  f:close()
end

local function applyDictionary(text)
  if #dictionaryEntries == 0 then
    return text
  end

  for _, entry in ipairs(dictionaryEntries) do
    if entry.caseInsensitive then
      -- Case-insensitive replacement
      local pattern = entry.find:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
      text = text:gsub("(" .. pattern .. ")", function(match)
        -- Preserve original case of first letter if replacing single word
        if entry.replace:match("^%u") and match:match("^%l") then
          return entry.replace:gsub("^%u", string.lower)
        end
        return entry.replace
      end)
    else
      -- Case-sensitive replacement (simple)
      text = text:gsub(entry.find, entry.replace)
    end
  end

  return text
end

-- Load dictionary on startup
loadDictionary()

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
  -- LLM-based cleanup using JSON format mode (no preamble possible)
  -- Escape for valid JSON: backslashes, quotes, and control characters
  local escapedText = text
    :gsub('\\\\', '\\\\\\\\')  -- backslash
    :gsub('"', '\\\\"')        -- double quote
    :gsub('\\t', ' ')          -- tab -> space
    :gsub('\\r', '')           -- carriage return -> remove
    :gsub('\\n', ' ')          -- newline -> space (shouldn't happen, but safety)

  -- Build prompt with optional dictionary context
  local prompt = 'Remove ONLY filler words (um, uh, like, you know) from the text. Keep all other words and meaning intact. Fix punctuation if needed.'

  -- Add dictionary context if entries exist
  if #dictionaryEntries > 0 then
    prompt = prompt .. ' Also apply these preferred terms:'
    for _, entry in ipairs(dictionaryEntries) do
      prompt = prompt .. ' Use "' .. entry.replace .. '" instead of "' .. entry.find .. '".'
    end
  end

  prompt = prompt .. ' Return {"result": "cleaned text here"}\\n\\nText: "' .. escapedText .. '"'

  -- Escape single quotes for shell
  prompt = prompt:gsub("'", "'\\\\''")

  local cmd = ollamaPath .. " run llama3.2:3b --format json '" .. prompt .. "' 2>/dev/null"
  local result, status = hs.execute(cmd)

  if status and result and result ~= "" then
    -- Parse JSON response to extract the cleaned text
    local cleaned = result:match('"result"%s*:%s*"(.-)"')
    if cleaned then
      -- Unescape JSON string escapes
      cleaned = cleaned
        :gsub('\\\\n', ' ')        -- escaped newline -> space
        :gsub('\\\\t', ' ')        -- escaped tab -> space
        :gsub('\\\\"', '"')        -- escaped quote -> quote
        :gsub('\\\\\\\\', '\\\\')  -- escaped backslash -> backslash
      return cleaned:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    end
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

-- ============================================================
-- HOTKEY BINDING (uses functions defined above)
-- ============================================================

hs.hotkey.bind(mods, key,
  function()
    hs.alert.show("Recording...")
    recordingTask = hs.task.new(sox, nil, {"-d", "-r", "16000", "-c", "1", recordFile})
    recordingTask:start()
  end,
  function()
    -- Show persistent indicator (won't auto-dismiss)
    hs.alert.show("Transcribing...", 999)

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
      hs.alert.closeAll()  -- Clear "Transcribing..." indicator
      hs.alert.show("No recording!")
      return
    end

    local whisperTask = hs.task.new(whisper,
      function(exitCode, stdOut, stdErr)
        hs.alert.closeAll()  -- Clear "Transcribing..." indicator

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

              -- Apply custom dictionary (always enabled, fast)
              text = applyDictionary(text)

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

-- ============================================================
-- AUTO-UPDATE CHECKER
-- ============================================================

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

hs.alert.show("Voice transcription ready ($hotkey_display)")
LUAEOF
}

setup_hammerspoon_config

# Create utility commands
function create_utility_commands() {
    echo "Creating utility commands..."

    mkdir -p "$BIN_DIR"

    # Create hotkey change script
    create_hotkey_command
    create_model_command
    create_update_command
    create_cleanup_command
    create_dictionary_command

    echo "✓ Utility commands installed"
}

function create_hotkey_command() {
    cat > "$BIN_DIR/voice-ptt-hotkey" << 'HOTKEYEOF'
#!/bin/bash
# voice-ptt-hotkey - Change the push-to-talk hotkey

CONFIG_FILE="$HOME/.hammerspoon/voice-ptt.lua"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ voice-ptt not installed. Run the installer first."
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
    chmod +x "$BIN_DIR/voice-ptt-hotkey"
}

function create_model_command() {
    cat > "$BIN_DIR/voice-ptt-model" << 'MODELEOF'
#!/bin/bash
# voice-ptt-model - Switch between Whisper models

CONFIG_FILE="$HOME/.hammerspoon/voice-ptt.lua"
MODEL_DIR="$HOME/Library/Application Support/whisper.cpp"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ voice-ptt not installed. Run the installer first."
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
    chmod +x "$BIN_DIR/voice-ptt-model"
}

function create_update_command() {
    cat > "$BIN_DIR/voice-ptt-update" << 'UPDATEEOF'
#!/bin/bash
# voice-ptt-update - Update voice-ptt to the latest version

REPO_URL="https://raw.githubusercontent.com/sparrowfm/voice-ptt/main/install.sh"
CONFIG_FILE="$HOME/.hammerspoon/voice-ptt.lua"

echo "═══════════════════════════════════════════════════════════════"
echo "  Voice-PTT Update Checker"
echo "═══════════════════════════════════════════════════════════════"
echo

# Check if voice-ptt is installed
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ voice-ptt not installed. Run the installer first:"
    echo "   curl -fsSL https://raw.githubusercontent.com/sparrowfm/voice-ptt/main/install.sh -o /tmp/install.sh && bash /tmp/install.sh"
    exit 1
fi

echo "Checking for updates..."

# Show current settings (installer will preserve these)
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
# The installer will:
# - Preserve hotkey and model settings from voice-ptt.lua
# - Update voice-ptt.lua with latest code
# - Leave init.lua unchanged (user customizations preserved)
bash "$TMP_INSTALLER" < /dev/null

# Cleanup installer will preserve settings, no need to restore manually
CLEANUP_FILE="$HOME/.config/voice-ptt/cleanup-enabled"
if [[ -f "$CLEANUP_FILE" ]]; then
    echo "✓ Advanced cleanup setting preserved"
# If they didn't have it before, offer to install and enable it now
elif [[ -t 0 ]]; then
    # Check if Ollama is installed (real app, not just wrapper)
    OLLAMA_INSTALLED=false
    OLLAMA_WRAPPER_ONLY=false

    if [[ -d "/Applications/Ollama.app" ]] || ollama list &> /dev/null 2>&1; then
        OLLAMA_INSTALLED=true
    elif command -v ollama &> /dev/null; then
        OLLAMA_WRAPPER_ONLY=true
    fi

    if [[ "$OLLAMA_INSTALLED" == "false" ]]; then
        echo
        echo "─────────────────────────────────────────────────────────────────"
        echo "⭐ NEW: Advanced Cleanup Feature"
        echo "─────────────────────────────────────────────────────────────────"
        echo ""
        echo "voice-ptt can use Ollama (local LLM) for smarter text cleanup:"
        echo "  • Better punctuation and context awareness"
        echo "  • Uses dictionary entries intelligently"
        echo "  • 100% local, ~1-2s additional processing"
        echo ""

        if [[ "$OLLAMA_WRAPPER_ONLY" == "true" ]]; then
            echo "⚠️  Ollama CLI wrapper detected, but Ollama.app not installed."
            echo "   The Homebrew 'ollama' package is just a wrapper."
            echo ""
        fi

        read -p "Install Ollama and enable advanced cleanup? [Y/N] " -n 1 -r install_choice
        echo ""

        if [[ $install_choice =~ ^[Yy]$ ]]; then
            echo "Installing Ollama.app..."
            if brew install --cask ollama; then
                echo "✓ Ollama.app installed"
                echo ""

                # Wait a moment for app to be ready
                sleep 2

                # Now enable advanced cleanup
                echo "Enabling advanced cleanup..."

                # Start service
                if ! pgrep -x "ollama" > /dev/null; then
                    echo "Starting Ollama service..."
                    /Applications/Ollama.app/Contents/Resources/ollama serve > /dev/null 2>&1 &
                    sleep 3
                fi

                # Download model
                echo "Downloading llama3.2:3b model (~2GB)..."
                if /Applications/Ollama.app/Contents/Resources/ollama pull llama3.2:3b; then
                    touch "$CLEANUP_FILE"
                    echo "✓ Advanced cleanup enabled"
                else
                    echo "❌ Model download failed. Try later: voice-ptt-cleanup enable"
                fi
            else
                echo "❌ Ollama installation failed"
                echo "   Install manually: brew install --cask ollama"
                echo "   Then run: voice-ptt-cleanup enable"
            fi
        else
            echo "Skipped (install later with: brew install --cask ollama)"
            echo "Then enable with: voice-ptt-cleanup enable"
        fi
        echo ""
    else
        echo
        echo "─────────────────────────────────────────────────────────────────"
        echo "⭐ NEW: Advanced Cleanup Feature"
        echo "─────────────────────────────────────────────────────────────────"
        echo ""
        echo "Ollama detected on this system. Enable advanced LLM cleanup?"
        echo "  • Better punctuation and context awareness"
        echo "  • Uses dictionary entries intelligently"
        echo "  • Adds ~1-2s to transcription time"
        echo ""
        read -p "Enable now? [Y/N] " -n 1 -r enable_choice
        echo ""
        if [[ $enable_choice =~ ^[Yy]$ ]]; then
            # Start service if needed
            if ! pgrep -x "ollama" > /dev/null; then
                echo "Starting Ollama service..."
                ollama serve > /dev/null 2>&1 &
                sleep 3
            fi

            echo "Downloading llama3.2:3b model (~2GB)..."
            if ollama pull llama3.2:3b; then
                touch "$CLEANUP_FILE"
                echo "✓ Advanced cleanup enabled"
            else
                echo "❌ Model download failed, you can try later with: voice-ptt-cleanup enable"
            fi
        else
            echo "Skipped (enable later with: voice-ptt-cleanup enable)"
        fi
    fi
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
    chmod +x "$BIN_DIR/voice-ptt-update"
}

function create_cleanup_command() {
    cat > "$BIN_DIR/voice-ptt-cleanup" << 'CLEANUPEOF'
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
    local ollama_path=""
    if ollama_path=$(find_ollama); then
      echo "  - Ollama: $ollama_path"
      if "$ollama_path" list 2>/dev/null | grep -q "llama3.2:3b"; then
        echo "  - Model: llama3.2:3b (ready)"
      else
        echo "  - Model: llama3.2:3b (not downloaded)"
      fi
    else
      echo "  - Ollama: NOT FOUND (cleanup won't work)"
    fi
    echo "  - Adds ~1-2s latency"
  else
    echo "Advanced cleanup: DISABLED"
  fi
}

find_ollama() {
  # Check PATH first
  if command -v ollama &> /dev/null; then
    command -v ollama
    return 0
  fi

  # Check common install locations
  local locations=(
    "/opt/homebrew/bin/ollama"
    "/usr/local/bin/ollama"
    "$HOME/.ollama/ollama"
    "/Applications/Ollama.app/Contents/Resources/ollama"
  )

  for path in "${locations[@]}"; do
    if [[ -x "$path" ]]; then
      echo "$path"
      return 0
    fi
  done

  return 1
}

enable_advanced() {
  echo "==================================================================="
  echo "  Enable Advanced Cleanup"
  echo "==================================================================="
  echo ""

  # Check for Ollama in PATH and common locations
  OLLAMA_PATH=""
  if OLLAMA_PATH=$(find_ollama); then
    echo "✓ Ollama found: $OLLAMA_PATH"
  else
    echo "❌ Ollama not found."
    echo ""
    echo "Install Ollama first:"
    echo "  brew install ollama"
    echo "  OR visit https://ollama.ai"
    echo ""
    echo "After installing, either:"
    echo "  1. Restart your terminal"
    echo "  2. Or run: source ~/.zshrc"
    exit 1
  fi

  echo ""

  # Start Ollama service if not running
  if ! pgrep -x "ollama" > /dev/null; then
    echo "Starting Ollama service..."
    echo "Command: $OLLAMA_PATH serve"
    "$OLLAMA_PATH" serve > /tmp/ollama-serve.log 2>&1 &
    OLLAMA_PID=$!
    sleep 3  # Give it more time to start

    # Verify it started
    if pgrep -x "ollama" > /dev/null; then
      echo "✓ Ollama service started (PID: $(pgrep -x ollama))"
    else
      echo "⚠️  Ollama may not have started. Check: cat /tmp/ollama-serve.log"
    fi
    echo ""
  else
    echo "✓ Ollama service already running"
    echo ""
  fi

  # Test connection
  echo "Testing Ollama API connection..."
  if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "✓ Can connect to Ollama API"
  else
    echo "❌ Cannot connect to Ollama API"
    echo "Troubleshooting:"
    echo "  1. Check service logs: cat /tmp/ollama-serve.log"
    echo "  2. Try manually: $OLLAMA_PATH serve (in another terminal)"
    echo "  3. Then run: voice-ptt-cleanup enable"
    exit 1
  fi
  echo ""

  # Check if model exists
  if ! "$OLLAMA_PATH" list 2>/dev/null | grep -q "llama3.2:3b"; then
    echo "Downloading llama3.2:3b model (~2GB, one-time)..."
    echo "This may take a few minutes..."
    echo ""
    if ! "$OLLAMA_PATH" pull llama3.2:3b 2>&1 | tee /tmp/ollama-pull.log; then
      echo ""
      echo "❌ Failed to download model"
      echo ""
      echo "Diagnostics:"
      echo "  - Pull error log: cat /tmp/ollama-pull.log"
      echo "  - Service log: cat /tmp/ollama-serve.log"
      echo ""
      echo "Try manually:"
      echo "  1. $OLLAMA_PATH serve (in another terminal)"
      echo "  2. voice-ptt-cleanup enable"
      exit 1
    fi
  else
    echo "✓ Model llama3.2:3b already downloaded"
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
    chmod +x "$BIN_DIR/voice-ptt-cleanup"
}

function create_dictionary_command() {
    cat > "$BIN_DIR/voice-ptt-dictionary" << 'DICTEOF'
#!/bin/bash
# voice-ptt-dictionary - Manage custom text replacements

DICT_FILE="$HOME/.config/voice-ptt/dictionary.txt"

show_help() {
  echo "voice-ptt-dictionary - Manage custom text replacements"
  echo ""
  echo "Usage:"
  echo "  voice-ptt-dictionary                 # Open dictionary in \$EDITOR"
  echo "  voice-ptt-dictionary list            # Show current entries"
  echo "  voice-ptt-dictionary add FIND REPLACE"
  echo "  voice-ptt-dictionary clear           # Clear all entries"
  echo "  voice-ptt-dictionary help            # Show this help"
  echo ""
  echo "Dictionary Format:"
  echo "  FIND -> REPLACE          # Case-sensitive"
  echo "  (?i)FIND -> REPLACE      # Case-insensitive"
  echo "  # Comments start with #"
  echo ""
  echo "Examples:"
  echo "  kubernetes -> Kubernetes"
  echo "  BTW -> by the way"
  echo "  (?i)anthropic -> Anthropic"
}

list_entries() {
  if [[ ! -f "$DICT_FILE" ]]; then
    echo "No dictionary entries yet."
    echo ""
    echo "Add entries with:"
    echo "  voice-ptt-dictionary add FIND REPLACE"
    echo "Or edit directly:"
    echo "  voice-ptt-dictionary"
    return
  fi

  echo "═══════════════════════════════════════════════════════════════"
  echo "  Custom Dictionary Entries"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  local count=0
  while IFS= read -r line; do
    # Skip empty lines and comments
    if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    ((count++))
    echo "$count. $line"
  done < "$DICT_FILE"

  if [[ $count -eq 0 ]]; then
    echo "No active entries (only comments)."
  fi
  echo ""
  echo "Total: $count entries"
}

add_entry() {
  local find="$1"
  local replace="$2"

  if [[ -z "$find" ]] || [[ -z "$replace" ]]; then
    echo "❌ Usage: voice-ptt-dictionary add FIND REPLACE"
    exit 1
  fi

  # Create config dir if needed
  mkdir -p "$(dirname "$DICT_FILE")"

  # Create file with header if it doesn't exist
  if [[ ! -f "$DICT_FILE" ]]; then
    cat > "$DICT_FILE" << 'HEADER'
# voice-ptt Custom Dictionary
# Format: FIND -> REPLACE
# Use (?i) prefix for case-insensitive matching
# Examples:
#   kubernetes -> Kubernetes
#   BTW -> by the way
#   (?i)anthropic -> Anthropic

HEADER
  fi

  # Add entry
  echo "$find -> $replace" >> "$DICT_FILE"
  echo "✓ Added: $find -> $replace"
  echo ""
  echo "Reload Hammerspoon to apply changes"
  open -g hammerspoon://reload
}

clear_entries() {
  if [[ ! -f "$DICT_FILE" ]]; then
    echo "Dictionary already empty."
    return
  fi

  echo "═══════════════════════════════════════════════════════════════"
  echo "  Clear Dictionary"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  list_entries
  echo ""
  read -p "Delete all entries? [y/N] " -n 1 -r
  echo ""

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    return
  fi

  rm -f "$DICT_FILE"
  echo "✓ Dictionary cleared"
  open -g hammerspoon://reload
}

edit_dictionary() {
  # Create config dir if needed
  mkdir -p "$(dirname "$DICT_FILE")"

  # Create file with header if it doesn't exist
  if [[ ! -f "$DICT_FILE" ]]; then
    cat > "$DICT_FILE" << 'HEADER'
# voice-ptt Custom Dictionary
# Format: FIND -> REPLACE (or FIND|REPLACE)
# Use (?i) prefix for case-insensitive matching
#
# Examples:
#   kubernetes -> Kubernetes
#   BTW -> by the way
#   (?i)anthropic -> Anthropic
#   (?i)hammerspoon -> Hammerspoon
#
# Technical terms:
#   api -> API
#   aws -> AWS
#   llm -> LLM
#
# Your entries below:

HEADER
  fi

  # Open in editor
  ${EDITOR:-nano} "$DICT_FILE"

  echo ""
  echo "✓ Dictionary saved"
  echo "Reloading Hammerspoon to apply changes..."
  open -g hammerspoon://reload
  echo "✓ Done"
}

case "${1:-edit}" in
  list|ls)
    list_entries
    ;;
  add)
    add_entry "$2" "$3"
    ;;
  clear)
    clear_entries
    ;;
  help|--help|-h)
    show_help
    ;;
  edit|"")
    edit_dictionary
    ;;
  *)
    echo "❌ Unknown command: $1"
    echo ""
    show_help
    exit 1
    ;;
esac
DICTEOF
    chmod +x "$BIN_DIR/voice-ptt-dictionary"
}

create_utility_commands

# Store version and cleanup settings
function finalize_installation() {
    # Store version for update checking
    mkdir -p "$CONFIG_DIR"
    echo "$VERSION" > "$CONFIG_DIR/version"

    # Enable advanced cleanup if user opted in during install
    if [[ "$ENABLE_ADVANCED_CLEANUP" == "true" ]]; then
        touch "$CONFIG_DIR/cleanup-enabled"
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
}

finalize_installation

# Final setup and instructions
function show_final_instructions() {
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

    # Show hotkey test instructions based on selection
    local test_instruction
    case "$HOTKEY_MODS" in
        '{"alt"}')
            test_instruction="Hold Option+Space (Alt+Space), speak, release"
            ;;
        '{"rightalt"}')
            test_instruction="Hold Right Option+Space (Right Alt+Space), speak, release"
            ;;
        '{"ctrl"}')
            test_instruction="Hold Ctrl+Space, speak, release"
            ;;
        '{"cmd"}')
            test_instruction="Hold Cmd+Space (Win+Space), speak, release"
            ;;
        *)
            test_instruction="Hold hotkey, speak, release"
            ;;
    esac
    echo "3. Test it: $test_instruction"
    echo
    echo "─────────────────────────────────────────────────────────────────"
    echo "To change hotkey later, run: voice-ptt-hotkey"
    echo "─────────────────────────────────────────────────────────────────"
    echo
}

function trigger_permissions() {
    echo "─────────────────────────────────────────────────────────────────"
    echo "Triggering microphone permission..."
    echo "⚠️  If prompted, click ALLOW for microphone access!"
    echo ""
    /opt/homebrew/bin/sox -d -r 16000 -c 1 /tmp/mic_test.wav trim 0 1 2>/dev/null || true
    rm -f /tmp/mic_test.wav 2>/dev/null
    echo "✓ Microphone permission triggered"
    echo
}

function launch_hammerspoon() {
    echo "Opening Hammerspoon..."
    open -g -a Hammerspoon
    echo
    echo "Done! You can close this terminal window."
}

show_final_instructions
trigger_permissions
launch_hammerspoon
