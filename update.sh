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

# Compare versions by checking if install scripts differ
if diff -q "$TMP_INSTALLER" "$(command -v install.sh 2>/dev/null || echo /dev/null)" &>/dev/null; then
    echo "✓ You're already running the latest version!"
    rm -f "$TMP_INSTALLER"
    exit 0
fi

# Show what would change
echo "─────────────────────────────────────────────────────────────────"
echo "Update available! Changes:"
echo "─────────────────────────────────────────────────────────────────"

# Extract embedded Lua script from both versions for comparison
extract_lua() {
    sed -n '/^cat > "\$CONFIG_FILE" << LUAEOF$/,/^LUAEOF$/p' "$1" |
    sed '1d;$d' |
    grep -v "^\$HOTKEY_"
}

OLD_LUA=$(extract_lua "$(command -v install.sh 2>/dev/null || echo /dev/null)" 2>/dev/null)
NEW_LUA=$(extract_lua "$TMP_INSTALLER")

if [[ -n "$OLD_LUA" && "$OLD_LUA" != "$NEW_LUA" ]]; then
    echo "• Hammerspoon configuration will be updated"
fi

# Check for new helper scripts
if grep -q "voice-ptt-" "$TMP_INSTALLER"; then
    echo "• Helper commands may be updated or added"
fi

echo "─────────────────────────────────────────────────────────────────"
echo
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

# Backup current config
BACKUP_FILE="$HOME/.hammerspoon/init.lua.backup.$(date +%Y%m%d%H%M%S)"
if [[ -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo "✓ Backed up config to $(basename "$BACKUP_FILE")"
fi

# Run installer in non-interactive mode with saved hotkey preference
# The installer checks if config exists and won't overwrite unnecessarily
export HOTKEY_MODS="$CURRENT_MODS"
export HOTKEY_KEY="$CURRENT_KEY"

# Run the new installer
bash "$TMP_INSTALLER"

# Restore hotkey settings if they changed
if [[ -f "$CONFIG_FILE" ]]; then
    sed -i '' "s/^local mods = .*/local mods = $CURRENT_MODS/" "$CONFIG_FILE"
    sed -i '' "s/^local key = .*/local key = $CURRENT_KEY/" "$CONFIG_FILE"
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
