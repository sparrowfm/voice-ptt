#!/bin/bash
# Regression test suite for voice-ptt installer
# Tests fresh install, update scenarios, settings preservation, and user customization safety

# Don't exit on error - we want to run all tests
set +e

INSTALLER="/Users/neelketkar/projects/voice-ptt/install.sh"
HS_DIR="$HOME/.hammerspoon"
INIT_LUA="$HS_DIR/init.lua"
VOICE_PTT_LUA="$HS_DIR/voice-ptt.lua"
CONFIG_DIR="$HOME/.config/voice-ptt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Backup current state
backup_state() {
    echo "Backing up current state..."
    mkdir -p /tmp/voice-ptt-regression-backup
    cp "$INIT_LUA" /tmp/voice-ptt-regression-backup/init.lua 2>/dev/null || true
    cp "$VOICE_PTT_LUA" /tmp/voice-ptt-regression-backup/voice-ptt.lua 2>/dev/null || true
    cp -r "$CONFIG_DIR" /tmp/voice-ptt-regression-backup/config 2>/dev/null || true
}

# Restore state after tests
restore_state() {
    echo "Restoring original state..."
    cp /tmp/voice-ptt-regression-backup/init.lua "$INIT_LUA" 2>/dev/null || true
    cp /tmp/voice-ptt-regression-backup/voice-ptt.lua "$VOICE_PTT_LUA" 2>/dev/null || true
    if [[ -d /tmp/voice-ptt-regression-backup/config ]]; then
        rm -rf "$CONFIG_DIR"
        cp -r /tmp/voice-ptt-regression-backup/config "$CONFIG_DIR"
    fi
    rm -rf /tmp/voice-ptt-regression-backup

    # Reload Hammerspoon
    open -g hammerspoon://reload 2>/dev/null || true
}

# Clean test environment
clean_env() {
    rm -f "$INIT_LUA"
    rm -f "$VOICE_PTT_LUA"
    rm -f "$HS_DIR"/init.lua.backup.*
}

# Test helper
assert_file_exists() {
    local file="$1"
    local msg="$2"
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}PASS${NC}: $msg"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $msg (file not found: $file)"
        ((TESTS_FAILED++))
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local msg="$3"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: $msg"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $msg (pattern not found: $pattern)"
        ((TESTS_FAILED++))
    fi
}

assert_file_not_contains() {
    local file="$1"
    local pattern="$2"
    local msg="$3"
    if ! grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: $msg"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $msg (pattern found but shouldn't be: $pattern)"
        ((TESTS_FAILED++))
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}PASS${NC}: $msg"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $msg (expected: '$expected', got: '$actual')"
        ((TESTS_FAILED++))
    fi
}

assert_hammerspoon_loads() {
    local msg="$1"
    open -g hammerspoon://reload
    sleep 2
    if pgrep -x Hammerspoon > /dev/null; then
        echo -e "${GREEN}PASS${NC}: $msg"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}: $msg (Hammerspoon not running after reload)"
        ((TESTS_FAILED++))
    fi
}

# ============================================================
# TEST 1: Fresh install (no existing files)
# ============================================================
test_fresh_install() {
    echo ""
    echo -e "${YELLOW}TEST 1: Fresh install (no existing files)${NC}"
    echo "================================================"

    clean_env

    bash "$INSTALLER" < /dev/null > /tmp/test1.log 2>&1

    assert_file_exists "$VOICE_PTT_LUA" "voice-ptt.lua created"
    assert_file_exists "$INIT_LUA" "init.lua created"
    assert_file_contains "$INIT_LUA" "require.*voice-ptt" "init.lua loads voice-ptt module"
    assert_file_contains "$VOICE_PTT_LUA" "hs.hotkey.bind" "voice-ptt.lua has hotkey binding"
    assert_file_contains "$VOICE_PTT_LUA" 'local mods = {"alt"}' "Default hotkey mods set"
    assert_file_contains "$VOICE_PTT_LUA" 'local key = "space"' "Default hotkey key set"
    assert_file_contains "$VOICE_PTT_LUA" "ggml-base.en.bin" "Default model set"
    assert_hammerspoon_loads "Hammerspoon loads fresh install"
}

# ============================================================
# TEST 2: Fresh install with existing non-voice-ptt init.lua
# ============================================================
test_fresh_install_existing_init() {
    echo ""
    echo -e "${YELLOW}TEST 2: Fresh install with existing init.lua${NC}"
    echo "================================================"

    clean_env

    # Create existing init.lua with user customizations
    cat > "$INIT_LUA" << 'EOF'
-- User's custom Hammerspoon config
hs.alert.show("Custom config loaded")

-- Window management
hs.hotkey.bind({"cmd", "alt"}, "left", function()
  local win = hs.window.focusedWindow()
  if win then win:moveToUnit({0, 0, 0.5, 1}) end
end)
EOF

    bash "$INSTALLER" < /dev/null > /tmp/test2.log 2>&1

    assert_file_exists "$VOICE_PTT_LUA" "voice-ptt.lua created"
    assert_file_contains "$INIT_LUA" "require.*voice-ptt" "init.lua loads voice-ptt module"
    assert_file_contains "$INIT_LUA" "Custom config loaded" "User customization preserved"
    assert_file_contains "$INIT_LUA" "Window management" "User comments preserved"
    assert_file_contains "$INIT_LUA" 'cmd.*alt.*left' "User hotkey preserved"
    assert_hammerspoon_loads "Hammerspoon loads with user customizations"
}

# ============================================================
# TEST 3: Update preserves hotkey settings
# ============================================================
test_update_preserves_hotkey() {
    echo ""
    echo -e "${YELLOW}TEST 3: Update preserves hotkey settings${NC}"
    echo "================================================"

    clean_env

    # First install
    bash "$INSTALLER" < /dev/null > /tmp/test3a.log 2>&1

    # Change hotkey to ctrl+space
    sed -i '' 's/{"alt"}/{"ctrl"}/' "$VOICE_PTT_LUA"

    # Run update (simulates voice-ptt-update)
    bash "$INSTALLER" < /dev/null > /tmp/test3b.log 2>&1

    assert_file_contains "$VOICE_PTT_LUA" '{"ctrl"}' "Hotkey mods preserved after update"
    assert_file_contains "$VOICE_PTT_LUA" 'local key = "space"' "Hotkey key preserved after update"
    assert_hammerspoon_loads "Hammerspoon loads after hotkey preservation"
}

# ============================================================
# TEST 4: Update preserves model setting
# ============================================================
test_update_preserves_model() {
    echo ""
    echo -e "${YELLOW}TEST 4: Update preserves model setting${NC}"
    echo "================================================"

    clean_env

    # First install
    bash "$INSTALLER" < /dev/null > /tmp/test4a.log 2>&1

    # Change to medium model
    sed -i '' 's/ggml-base.en.bin/ggml-medium.en.bin/' "$VOICE_PTT_LUA"

    # Run update
    bash "$INSTALLER" < /dev/null > /tmp/test4b.log 2>&1

    assert_file_contains "$VOICE_PTT_LUA" "ggml-medium.en.bin" "Model setting preserved after update"
    assert_hammerspoon_loads "Hammerspoon loads after model preservation"
}

# ============================================================
# TEST 5: Update preserves user init.lua customizations
# ============================================================
test_update_preserves_user_init() {
    echo ""
    echo -e "${YELLOW}TEST 5: Update preserves user init.lua customizations${NC}"
    echo "================================================"

    clean_env

    # First install
    bash "$INSTALLER" < /dev/null > /tmp/test5a.log 2>&1

    # Add user customizations to init.lua
    cat >> "$INIT_LUA" << 'EOF'

-- User's additional customizations after install
hs.hotkey.bind({"cmd", "shift"}, "r", function()
  hs.reload()
end)
EOF

    # Run update
    bash "$INSTALLER" < /dev/null > /tmp/test5b.log 2>&1

    assert_file_contains "$INIT_LUA" "User's additional customizations" "User comment preserved"
    assert_file_contains "$INIT_LUA" 'cmd.*shift.*r' "User reload hotkey preserved"
    assert_file_contains "$INIT_LUA" "require.*voice-ptt" "voice-ptt require still present"
    assert_hammerspoon_loads "Hammerspoon loads with preserved customizations"
}

# ============================================================
# TEST 6: Function order correct (helpers before hotkey.bind)
# ============================================================
test_function_order() {
    echo ""
    echo -e "${YELLOW}TEST 6: Function order correct${NC}"
    echo "================================================"

    clean_env
    bash "$INSTALLER" < /dev/null > /tmp/test6.log 2>&1

    # Get line numbers (use ^hs.hotkey.bind to match actual call, not comments)
    local basic_cleanup_line=$(grep -n "local function basicCleanup" "$VOICE_PTT_LUA" | head -1 | cut -d: -f1)
    local apply_dict_line=$(grep -n "local function applyDictionary" "$VOICE_PTT_LUA" | head -1 | cut -d: -f1)
    local hotkey_bind_line=$(grep -n "^hs.hotkey.bind" "$VOICE_PTT_LUA" | head -1 | cut -d: -f1)

    if [[ $basic_cleanup_line -lt $hotkey_bind_line ]]; then
        echo -e "${GREEN}PASS${NC}: basicCleanup defined before hs.hotkey.bind (line $basic_cleanup_line < $hotkey_bind_line)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}: basicCleanup defined after hs.hotkey.bind (line $basic_cleanup_line >= $hotkey_bind_line)"
        ((TESTS_FAILED++))
    fi

    if [[ $apply_dict_line -lt $hotkey_bind_line ]]; then
        echo -e "${GREEN}PASS${NC}: applyDictionary defined before hs.hotkey.bind (line $apply_dict_line < $hotkey_bind_line)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}: applyDictionary defined after hs.hotkey.bind (line $apply_dict_line >= $hotkey_bind_line)"
        ((TESTS_FAILED++))
    fi
}

# ============================================================
# TEST 7: Utility commands point to voice-ptt.lua
# ============================================================
test_utility_commands() {
    echo ""
    echo -e "${YELLOW}TEST 7: Utility commands use voice-ptt.lua${NC}"
    echo "================================================"

    clean_env
    bash "$INSTALLER" < /dev/null > /tmp/test7.log 2>&1

    assert_file_contains "$HOME/bin/voice-ptt-hotkey" "voice-ptt.lua" "voice-ptt-hotkey uses voice-ptt.lua"
    assert_file_contains "$HOME/bin/voice-ptt-model" "voice-ptt.lua" "voice-ptt-model uses voice-ptt.lua"
    assert_file_contains "$HOME/bin/voice-ptt-update" "voice-ptt.lua" "voice-ptt-update uses voice-ptt.lua"

    # Ensure they don't reference init.lua for config
    assert_file_not_contains "$HOME/bin/voice-ptt-hotkey" 'CONFIG_FILE=.*init.lua' "voice-ptt-hotkey doesn't use init.lua as config"
    assert_file_not_contains "$HOME/bin/voice-ptt-model" 'CONFIG_FILE=.*init.lua' "voice-ptt-model doesn't use init.lua as config"
}

# ============================================================
# TEST 8: Consecutive updates don't duplicate require statement
# ============================================================
test_no_duplicate_require() {
    echo ""
    echo -e "${YELLOW}TEST 8: No duplicate require statements${NC}"
    echo "================================================"

    clean_env

    # Run installer 3 times
    bash "$INSTALLER" < /dev/null > /tmp/test8a.log 2>&1
    bash "$INSTALLER" < /dev/null > /tmp/test8b.log 2>&1
    bash "$INSTALLER" < /dev/null > /tmp/test8c.log 2>&1

    local require_count=$(grep -c "require.*voice-ptt" "$INIT_LUA" 2>/dev/null || echo "0")

    if [[ "$require_count" == "1" ]]; then
        echo -e "${GREEN}PASS${NC}: Only one require statement after 3 installs"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL${NC}: Found $require_count require statements (expected 1)"
        ((TESTS_FAILED++))
    fi
}

# ============================================================
# TEST 9: Combined settings preservation (hotkey + model)
# ============================================================
test_combined_settings() {
    echo ""
    echo -e "${YELLOW}TEST 9: Combined settings preservation${NC}"
    echo "================================================"

    clean_env

    # First install
    bash "$INSTALLER" < /dev/null > /tmp/test9a.log 2>&1

    # Change both hotkey and model
    sed -i '' 's/{"alt"}/{"rightalt"}/' "$VOICE_PTT_LUA"
    sed -i '' 's/ggml-base.en.bin/ggml-medium.en.bin/' "$VOICE_PTT_LUA"

    # Run update
    bash "$INSTALLER" < /dev/null > /tmp/test9b.log 2>&1

    assert_file_contains "$VOICE_PTT_LUA" '{"rightalt"}' "Hotkey mods preserved"
    assert_file_contains "$VOICE_PTT_LUA" "ggml-medium.en.bin" "Model preserved"
    assert_hammerspoon_loads "Hammerspoon loads with combined settings"
}

# ============================================================
# TEST 10: voice-ptt.lua has correct header comments
# ============================================================
test_module_header() {
    echo ""
    echo -e "${YELLOW}TEST 10: Module header comments${NC}"
    echo "================================================"

    clean_env
    bash "$INSTALLER" < /dev/null > /tmp/test10.log 2>&1

    assert_file_contains "$VOICE_PTT_LUA" "This file is managed by voice-ptt installer" "Management notice present"
    assert_file_contains "$VOICE_PTT_LUA" "Safe to update" "Safety notice present"
}

# ============================================================
# MAIN
# ============================================================

echo "=============================================="
echo "  voice-ptt Regression Test Suite"
echo "=============================================="
echo ""

# Trap to restore state on exit
trap restore_state EXIT

backup_state

# Run all tests
test_fresh_install
test_fresh_install_existing_init
test_update_preserves_hotkey
test_update_preserves_model
test_update_preserves_user_init
test_function_order
test_utility_commands
test_no_duplicate_require
test_combined_settings
test_module_header

# Summary
echo ""
echo "=============================================="
echo "  TEST SUMMARY"
echo "=============================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
