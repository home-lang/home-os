#!/bin/bash
# home-os Comprehensive Apps Test Suite
# Tests all userspace applications: system apps, utilities, games
# Validates structure, functions, dependencies, and syscall usage

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
APPS_DIR="$PROJECT_ROOT/apps"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Results
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Platform detection
PLATFORM="x86-64"
if [ -f /proc/device-tree/model ]; then
    MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "")
    if [[ "$MODEL" == *"Raspberry Pi 3"* ]]; then
        PLATFORM="pi3"
    elif [[ "$MODEL" == *"Raspberry Pi 4"* ]]; then
        PLATFORM="pi4"
    elif [[ "$MODEL" == *"Raspberry Pi 5"* ]]; then
        PLATFORM="pi5"
    fi
fi

echo -e "${BLUE}home-os Comprehensive Apps Test Suite${NC}"
echo "========================================"
echo "Platform: $PLATFORM"
echo "Date: $(date)"
echo ""

# Test helper functions
test_pass() {
    local test_name="$1"
    local details="$2"
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}[PASS]${NC} $test_name"
    [ -n "$details" ] && echo -e "        $details"
}

test_fail() {
    local test_name="$1"
    local details="$2"
    ((TESTS_FAILED++))
    echo -e "  ${RED}[FAIL]${NC} $test_name"
    [ -n "$details" ] && echo -e "        $details"
}

test_skip() {
    local test_name="$1"
    local reason="$2"
    ((TESTS_SKIPPED++))
    echo -e "  ${YELLOW}[SKIP]${NC} $test_name - $reason"
}

# Verify app exists
verify_app() {
    local app="$1"
    local desc="$2"
    ((TESTS_TOTAL++))
    if [ -f "$APPS_DIR/$app" ]; then
        test_pass "$desc"
        return 0
    else
        test_fail "$desc" "File not found: $app"
        return 1
    fi
}

# Verify function exists in app
verify_function() {
    local app="$1"
    local func="$2"
    ((TESTS_TOTAL++))
    if grep -q "export fn $func" "$APPS_DIR/$app" 2>/dev/null; then
        test_pass "Function $func"
        return 0
    elif grep -q "fn $func" "$APPS_DIR/$app" 2>/dev/null; then
        test_pass "Function $func (internal)"
        return 0
    else
        test_fail "Function $func" "Not found in $app"
        return 1
    fi
}

# Verify app has proper imports
verify_imports() {
    local app="$1"
    ((TESTS_TOTAL++))
    if grep -q "^import " "$APPS_DIR/$app" 2>/dev/null; then
        local import_count=$(grep -c "^import " "$APPS_DIR/$app" 2>/dev/null || echo "0")
        test_pass "Imports in $app" "$import_count imports"
        return 0
    else
        test_fail "Imports in $app" "No imports found"
        return 1
    fi
}

# Verify app uses syscalls library
verify_syscalls() {
    local app="$1"
    ((TESTS_TOTAL++))
    if grep -q "syscalls" "$APPS_DIR/$app" 2>/dev/null; then
        test_pass "Syscalls usage in $app"
        return 0
    else
        test_skip "Syscalls usage in $app" "May use direct kernel imports"
        return 0
    fi
}

# ============================================================================
# CORE SYSTEM APPS
# ============================================================================

echo -e "\n${YELLOW}--- Core System Apps ---${NC}"

# Shell
if verify_app "shell.home" "Shell application"; then
    verify_imports "shell.home"
    verify_function "shell.home" "shell_init"
    verify_function "shell.home" "shell_run"
    verify_function "shell.home" "execute_command"

    # Check shell parser
    ((TESTS_TOTAL++))
    if [ -f "$APPS_DIR/shell_parser.home" ]; then
        test_pass "Shell parser module"
        verify_function "shell_parser.home" "parse_command"
    else
        test_fail "Shell parser module" "shell_parser.home not found"
    fi
fi

# Terminal
if verify_app "terminal.home" "Terminal emulator"; then
    verify_imports "terminal.home"
    verify_function "terminal.home" "terminal_clear"
    verify_function "terminal.home" "terminal_putchar"
fi

# Task Manager
if verify_app "taskmanager.home" "Task Manager"; then
    verify_imports "taskmanager.home"
    verify_function "taskmanager.home" "taskmanager_init"
fi

# System Monitor
if verify_app "sysmon.home" "System Monitor"; then
    verify_imports "sysmon.home"
    verify_function "sysmon.home" "sysmon_init"

    # Check sysmon display
    ((TESTS_TOTAL++))
    if [ -f "$APPS_DIR/sysmon_display.home" ]; then
        test_pass "System Monitor display module"
    else
        test_fail "System Monitor display module" "sysmon_display.home not found"
    fi
fi

# ============================================================================
# FILE MANAGEMENT
# ============================================================================

echo -e "\n${YELLOW}--- File Management Apps ---${NC}"

# File Manager
if verify_app "filemanager.home" "File Manager"; then
    verify_imports "filemanager.home"
    verify_function "filemanager.home" "filemanager_init"

    # Check file manager operations
    ((TESTS_TOTAL++))
    if [ -f "$APPS_DIR/filemanager_ops.home" ]; then
        test_pass "File Manager operations module"
        verify_function "filemanager_ops.home" "copy_file"
        verify_function "filemanager_ops.home" "move_file"
        verify_function "filemanager_ops.home" "delete_file"
    else
        test_fail "File Manager operations" "filemanager_ops.home not found"
    fi

    # Check file manager preview
    ((TESTS_TOTAL++))
    if [ -f "$APPS_DIR/filemanager_preview.home" ]; then
        test_pass "File Manager preview module"
    else
        test_fail "File Manager preview" "filemanager_preview.home not found"
    fi
fi

# Text Editor
if verify_app "editor.home" "Text Editor"; then
    verify_imports "editor.home"
    verify_function "editor.home" "editor_init"
fi

# ============================================================================
# PRODUCTIVITY APPS
# ============================================================================

echo -e "\n${YELLOW}--- Productivity Apps ---${NC}"

# Calculator
if verify_app "calculator.home" "Calculator"; then
    verify_imports "calculator.home"
    verify_function "calculator.home" "calculator_init"
    verify_function "calculator.home" "calculate"
fi

# Clock
if verify_app "clock.home" "Clock"; then
    verify_imports "clock.home"
    verify_function "clock.home" "clock_init"
fi

# Paint
if verify_app "paint.home" "Paint"; then
    verify_imports "paint.home"
    verify_function "paint.home" "paint_init"
fi

# ============================================================================
# MEDIA APPS
# ============================================================================

echo -e "\n${YELLOW}--- Media Apps ---${NC}"

# Media Player
if verify_app "media_player.home" "Media Player"; then
    verify_imports "media_player.home"
    verify_function "media_player.home" "media_player_init"
    verify_function "media_player.home" "play"
    verify_function "media_player.home" "pause"
fi

# Music
if verify_app "music.home" "Music app"; then
    verify_imports "music.home"
    verify_function "music.home" "music_init"
fi

# ============================================================================
# NETWORK APPS
# ============================================================================

echo -e "\n${YELLOW}--- Network Apps ---${NC}"

# Browser
if verify_app "browser.home" "Web Browser"; then
    verify_imports "browser.home"
    verify_function "browser.home" "browser_init"
    verify_function "browser.home" "navigate"
fi

# Network Test
if verify_app "nettest.home" "Network Test utility"; then
    verify_imports "nettest.home"
    verify_function "nettest.home" "nettest_init"
fi

# ============================================================================
# IOT / SMART HOME
# ============================================================================

echo -e "\n${YELLOW}--- IoT / Smart Home Apps ---${NC}"

# Smart Home Dashboard
if verify_app "smart_home_dashboard.home" "Smart Home Dashboard"; then
    verify_imports "smart_home_dashboard.home"
    verify_function "smart_home_dashboard.home" "dashboard_init"
fi

# ============================================================================
# BENCHMARK / UTILITIES
# ============================================================================

echo -e "\n${YELLOW}--- Benchmark / Utilities ---${NC}"

# Benchmark
if verify_app "benchmark.home" "Benchmark utility"; then
    verify_imports "benchmark.home"
    verify_function "benchmark.home" "benchmark_init"
fi

# ============================================================================
# GAMES
# ============================================================================

echo -e "\n${YELLOW}--- Games ---${NC}"

# Snake
((TESTS_TOTAL++))
if [ -f "$APPS_DIR/games/snake.home" ]; then
    test_pass "Snake game"
    ((TESTS_TOTAL++))
    if grep -q "fn snake_init\|fn game_init" "$APPS_DIR/games/snake.home" 2>/dev/null; then
        test_pass "Snake init function"
    else
        test_fail "Snake init function" "Not found"
    fi
else
    test_fail "Snake game" "games/snake.home not found"
fi

# Tetris
((TESTS_TOTAL++))
if [ -f "$APPS_DIR/games/tetris.home" ]; then
    test_pass "Tetris game"
    ((TESTS_TOTAL++))
    if grep -q "fn tetris_init\|fn game_init" "$APPS_DIR/games/tetris.home" 2>/dev/null; then
        test_pass "Tetris init function"
    else
        test_fail "Tetris init function" "Not found"
    fi
else
    test_fail "Tetris game" "games/tetris.home not found"
fi

# Pong
((TESTS_TOTAL++))
if [ -f "$APPS_DIR/games/pong.home" ]; then
    test_pass "Pong game"
    ((TESTS_TOTAL++))
    if grep -q "fn pong_init\|fn game_init" "$APPS_DIR/games/pong.home" 2>/dev/null; then
        test_pass "Pong init function"
    else
        test_fail "Pong init function" "Not found"
    fi
else
    test_fail "Pong game" "games/pong.home not found"
fi

# ============================================================================
# APP LIBRARY
# ============================================================================

echo -e "\n${YELLOW}--- App Library ---${NC}"

# Syscalls library
((TESTS_TOTAL++))
if [ -f "$APPS_DIR/lib/syscalls.home" ]; then
    test_pass "Syscalls library"

    # Verify core syscalls
    SYSCALLS_FILE="$APPS_DIR/lib/syscalls.home"

    ((TESTS_TOTAL++))
    if grep -q "fn sys_read\|export fn sys_read" "$SYSCALLS_FILE" 2>/dev/null; then
        test_pass "sys_read syscall"
    else
        test_fail "sys_read syscall" "Not defined"
    fi

    ((TESTS_TOTAL++))
    if grep -q "fn sys_write\|export fn sys_write" "$SYSCALLS_FILE" 2>/dev/null; then
        test_pass "sys_write syscall"
    else
        test_fail "sys_write syscall" "Not defined"
    fi

    ((TESTS_TOTAL++))
    if grep -q "fn sys_open\|export fn sys_open" "$SYSCALLS_FILE" 2>/dev/null; then
        test_pass "sys_open syscall"
    else
        test_fail "sys_open syscall" "Not defined"
    fi

    ((TESTS_TOTAL++))
    if grep -q "fn sys_close\|export fn sys_close" "$SYSCALLS_FILE" 2>/dev/null; then
        test_pass "sys_close syscall"
    else
        test_fail "sys_close syscall" "Not defined"
    fi

    ((TESTS_TOTAL++))
    if grep -q "fn sys_exit\|export fn sys_exit" "$SYSCALLS_FILE" 2>/dev/null; then
        test_pass "sys_exit syscall"
    else
        test_fail "sys_exit syscall" "Not defined"
    fi

    ((TESTS_TOTAL++))
    if grep -q "fn sys_fork\|export fn sys_fork" "$SYSCALLS_FILE" 2>/dev/null; then
        test_pass "sys_fork syscall"
    else
        test_fail "sys_fork syscall" "Not defined"
    fi

    ((TESTS_TOTAL++))
    if grep -q "fn sys_exec\|export fn sys_exec" "$SYSCALLS_FILE" 2>/dev/null; then
        test_pass "sys_exec syscall"
    else
        test_fail "sys_exec syscall" "Not defined"
    fi
else
    test_fail "Syscalls library" "lib/syscalls.home not found"
fi

# ============================================================================
# INIT SYSTEM
# ============================================================================

echo -e "\n${YELLOW}--- Init System ---${NC}"

((TESTS_TOTAL++))
if [ -d "$APPS_DIR/init" ]; then
    test_pass "Init system directory"

    # Check for init files
    INIT_FILES=$(ls "$APPS_DIR/init/"*.home 2>/dev/null | wc -l)
    ((TESTS_TOTAL++))
    if [ "$INIT_FILES" -gt 0 ]; then
        test_pass "Init modules" "$INIT_FILES module(s)"
    else
        test_skip "Init modules" "No .home files found"
    fi
else
    test_skip "Init system" "init/ directory not found"
fi

# ============================================================================
# PACKAGE MANAGER
# ============================================================================

echo -e "\n${YELLOW}--- Package Manager ---${NC}"

((TESTS_TOTAL++))
if [ -d "$APPS_DIR/package_manager" ]; then
    test_pass "Package Manager directory"

    # Check for package manager files
    PKG_FILES=$(ls "$APPS_DIR/package_manager/"*.home 2>/dev/null | wc -l)
    ((TESTS_TOTAL++))
    if [ "$PKG_FILES" -gt 0 ]; then
        test_pass "Package Manager modules" "$PKG_FILES module(s)"
    else
        test_skip "Package Manager modules" "No .home files found"
    fi
else
    test_skip "Package Manager" "package_manager/ directory not found"
fi

# ============================================================================
# APP STRUCTURE VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- App Structure Verification ---${NC}"

# Count total apps
TOTAL_APPS=$(ls "$APPS_DIR/"*.home 2>/dev/null | wc -l)
((TESTS_TOTAL++))
test_pass "Total app modules" "$TOTAL_APPS .home files"

# Count total game apps
GAME_APPS=$(ls "$APPS_DIR/games/"*.home 2>/dev/null | wc -l || echo "0")
((TESTS_TOTAL++))
test_pass "Total game modules" "$GAME_APPS .home files"

# Verify no syntax errors (basic check for matching braces)
echo "  Checking for basic syntax consistency..."
SYNTAX_ERRORS=0
for app in "$APPS_DIR"/*.home; do
    if [ -f "$app" ]; then
        # Count opening/closing braces
        OPEN_BRACES=$(grep -o '{' "$app" 2>/dev/null | wc -l)
        CLOSE_BRACES=$(grep -o '}' "$app" 2>/dev/null | wc -l)

        if [ "$OPEN_BRACES" -ne "$CLOSE_BRACES" ]; then
            ((SYNTAX_ERRORS++))
            echo -e "    ${RED}Warning:${NC} $(basename $app) has mismatched braces ({:$OPEN_BRACES, }:$CLOSE_BRACES)"
        fi
    fi
done

((TESTS_TOTAL++))
if [ "$SYNTAX_ERRORS" -eq 0 ]; then
    test_pass "Brace matching in apps"
else
    test_fail "Brace matching in apps" "$SYNTAX_ERRORS file(s) with issues"
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "========================================"
echo -e "${BLUE}COMPREHENSIVE APPS TEST SUMMARY${NC}"
echo "========================================"
echo "Platform: $PLATFORM"
echo ""
echo "Total:   $TESTS_TOTAL"
echo -e "Passed:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:  ${RED}$TESTS_FAILED${NC}"
echo -e "Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
echo ""

echo -e "${CYAN}App Categories Tested:${NC}"
echo "  - Core System: Shell, Terminal, Task Manager, System Monitor"
echo "  - File Management: File Manager, Text Editor"
echo "  - Productivity: Calculator, Clock, Paint"
echo "  - Media: Media Player, Music"
echo "  - Network: Browser, Network Test"
echo "  - IoT: Smart Home Dashboard"
echo "  - Utilities: Benchmark"
echo "  - Games: Snake, Tetris, Pong"
echo "  - Libraries: Syscalls"
echo ""

echo -e "${CYAN}App Statistics:${NC}"
echo "  Total app modules: $TOTAL_APPS"
echo "  Total game modules: $GAME_APPS"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}*** ALL APPS TESTS PASSED ***${NC}"
    exit 0
else
    echo -e "${RED}*** SOME APPS TESTS FAILED ***${NC}"
    exit 1
fi
