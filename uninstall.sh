#!/bin/bash
# uninstall-voice.sh - Remove push-to-talk voice transcription from macOS
# Usage: curl -fsSL URL | bash
#    or: bash uninstall-voice.sh

echo "═══════════════════════════════════════════════════════════════"
echo "  Push-to-Talk Voice Transcription Uninstaller"
echo "═══════════════════════════════════════════════════════════════"
echo

echo "This will remove:"
echo "  • Whisper models (~1.6GB)"
echo "  • Hammerspoon config (init.lua)"
echo
echo "Note: whisper-cpp, sox, and Hammerspoon apps will NOT be removed."
echo "      Run 'brew uninstall whisper-cpp sox' and"
echo "      'brew uninstall --cask hammerspoon' manually if needed."
echo

# Check if running interactively
if [[ -t 0 ]]; then
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
else
    echo "Running non-interactively, proceeding with uninstall..."
fi

echo
echo "Removing components..."
echo "─────────────────────────────────────────────────────────────────"

# Kill any running sox processes
pkill -9 sox 2>/dev/null || true

# Remove Whisper models
MODEL_DIR="$HOME/Library/Application Support/whisper.cpp"
if [[ -d "$MODEL_DIR" ]]; then
    echo "Removing Whisper models..."
    rm -rf "$MODEL_DIR"
    echo "✓ Models removed"
else
    echo "✓ Models already removed"
fi

# Remove Hammerspoon config
CONFIG_FILE="$HOME/.hammerspoon/init.lua"
if [[ -f "$CONFIG_FILE" ]]; then
    if grep -q "Push-to-Talk Whisper" "$CONFIG_FILE" 2>/dev/null; then
        echo "Removing Hammerspoon config..."
        rm "$CONFIG_FILE"
        echo "✓ init.lua removed"
    else
        echo "⚠ init.lua exists but doesn't contain push-to-talk config (skipped)"
    fi
else
    echo "✓ Hammerspoon config already removed"
fi

# Remove temp files
rm -f "$HOME/rec_temp.wav" 2>/dev/null
rm -f "$HOME/transcribed.txt" 2>/dev/null

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Uninstall complete!"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "To fully remove apps, run:"
echo "  brew uninstall whisper-cpp sox"
echo "  brew uninstall --cask hammerspoon"
echo
