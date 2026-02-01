#!/bin/bash
# uninstall-voice.sh - Remove push-to-talk voice transcription from macOS
# Usage: bash uninstall-voice.sh

set -e

echo "═══════════════════════════════════════════════════════════════"
echo "  Push-to-Talk Voice Transcription Uninstaller"
echo "═══════════════════════════════════════════════════════════════"
echo

# Confirm
echo "This will remove:"
echo "  • Whisper models (~1.6GB)"
echo "  • Hammerspoon config (init.lua)"
echo "  • Optionally: whisper-cpp, sox, Hammerspoon apps"
echo
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
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
    if grep -q "Push-to-Talk Whisper" "$CONFIG_FILE"; then
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

# Ask about uninstalling apps
echo "─────────────────────────────────────────────────────────────────"
echo "Optional: Uninstall applications?"
echo
read -p "Uninstall whisper-cpp? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    brew uninstall whisper-cpp 2>/dev/null && echo "✓ whisper-cpp uninstalled" || echo "⚠ whisper-cpp not installed"
fi

read -p "Uninstall sox? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    brew uninstall sox 2>/dev/null && echo "✓ sox uninstalled" || echo "⚠ sox not installed"
fi

read -p "Uninstall Hammerspoon? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Quit Hammerspoon first
    osascript -e 'quit app "Hammerspoon"' 2>/dev/null || true
    sleep 1
    brew uninstall --cask hammerspoon 2>/dev/null && echo "✓ Hammerspoon uninstalled" || echo "⚠ Hammerspoon not installed via brew"
    # Also remove Hammerspoon preferences
    rm -rf "$HOME/.hammerspoon" 2>/dev/null
    rm -rf "$HOME/Library/Preferences/org.hammerspoon.Hammerspoon.plist" 2>/dev/null
fi

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Uninstall complete!"
echo "═══════════════════════════════════════════════════════════════"
echo
