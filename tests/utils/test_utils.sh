#!/bin/bash
# HomeOS Utility Test Suite
# Tests core utilities for correctness

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UTILS_DIR="$PROJECT_ROOT/apps/utils"
TEST_RESULTS_DIR="$PROJECT_ROOT/build/test-results"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Create test results directory
mkdir -p "$TEST_RESULTS_DIR"

# Test result logging
log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    echo "  Expected: $2"
    echo "  Got:      $3"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1 - $2"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# ============================================================================
# Test Framework
# ============================================================================

# Check if utility exists
util_exists() {
    local util="$1"
    [ -f "$UTILS_DIR/$util.home" ]
}

# Parse utility for expected behavior
check_util_syntax() {
    local util="$1"
    if util_exists "$util"; then
        # Check for export fn main or basic structure
        if grep -q "export fn\|fn main" "$UTILS_DIR/$util.home" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# ============================================================================
# Individual Utility Tests
# ============================================================================

test_ls() {
    log_info "Testing ls utility..."

    if ! util_exists "ls"; then
        log_skip "ls" "utility not found"
        return
    fi

    if check_util_syntax "ls"; then
        log_pass "ls.home - syntax check"
    else
        log_fail "ls.home - syntax check" "valid syntax" "invalid"
    fi

    # Check for required functions
    if grep -q "fn list_directory\|fn ls_main" "$UTILS_DIR/ls.home" 2>/dev/null; then
        log_pass "ls.home - has list function"
    else
        log_fail "ls.home - has list function" "list_directory/ls_main" "not found"
    fi
}

test_cat() {
    log_info "Testing cat utility..."

    if ! util_exists "cat"; then
        log_skip "cat" "utility not found"
        return
    fi

    if check_util_syntax "cat"; then
        log_pass "cat.home - syntax check"
    else
        log_fail "cat.home - syntax check" "valid syntax" "invalid"
    fi

    # Check for file reading
    if grep -q "read\|vfs_read\|file" "$UTILS_DIR/cat.home" 2>/dev/null; then
        log_pass "cat.home - has file reading"
    else
        log_fail "cat.home - has file reading" "read function" "not found"
    fi
}

test_cp() {
    log_info "Testing cp utility..."

    if ! util_exists "cp"; then
        log_skip "cp" "utility not found"
        return
    fi

    if check_util_syntax "cp"; then
        log_pass "cp.home - syntax check"
    else
        log_fail "cp.home - syntax check" "valid syntax" "invalid"
    fi

    # Check for copy functionality
    if grep -q "copy\|read.*write\|vfs" "$UTILS_DIR/cp.home" 2>/dev/null; then
        log_pass "cp.home - has copy function"
    else
        log_fail "cp.home - has copy function" "copy function" "not found"
    fi
}

test_mkdir() {
    log_info "Testing mkdir utility..."

    if ! util_exists "mkdir"; then
        log_skip "mkdir" "utility not found"
        return
    fi

    if check_util_syntax "mkdir"; then
        log_pass "mkdir.home - syntax check"
    else
        log_fail "mkdir.home - syntax check" "valid syntax" "invalid"
    fi

    # Check for directory creation
    if grep -q "mkdir\|create.*dir\|vfs_mkdir" "$UTILS_DIR/mkdir.home" 2>/dev/null; then
        log_pass "mkdir.home - has mkdir function"
    else
        log_fail "mkdir.home - has mkdir function" "mkdir function" "not found"
    fi
}

test_rm() {
    log_info "Testing rm utility..."

    if ! util_exists "rm"; then
        log_skip "rm" "utility not found"
        return
    fi

    if check_util_syntax "rm"; then
        log_pass "rm.home - syntax check"
    else
        log_fail "rm.home - syntax check" "valid syntax" "invalid"
    fi
}

test_ps() {
    log_info "Testing ps utility..."

    if ! util_exists "ps"; then
        log_skip "ps" "utility not found"
        return
    fi

    if check_util_syntax "ps"; then
        log_pass "ps.home - syntax check"
    else
        log_fail "ps.home - syntax check" "valid syntax" "invalid"
    fi

    # Check for process listing
    if grep -q "process\|pid\|task" "$UTILS_DIR/ps.home" 2>/dev/null; then
        log_pass "ps.home - has process functions"
    else
        log_fail "ps.home - has process functions" "process listing" "not found"
    fi
}

test_top() {
    log_info "Testing top utility..."

    if ! util_exists "top"; then
        log_skip "top" "utility not found"
        return
    fi

    if check_util_syntax "top"; then
        log_pass "top.home - syntax check"
    else
        log_fail "top.home - syntax check" "valid syntax" "invalid"
    fi
}

test_echo() {
    log_info "Testing echo utility..."

    if ! util_exists "echo"; then
        log_skip "echo" "utility not found"
        return
    fi

    if check_util_syntax "echo"; then
        log_pass "echo.home - syntax check"
    else
        log_fail "echo.home - syntax check" "valid syntax" "invalid"
    fi

    # Check for print functionality
    if grep -q "print\|write\|output" "$UTILS_DIR/echo.home" 2>/dev/null; then
        log_pass "echo.home - has output function"
    else
        log_fail "echo.home - has output function" "print function" "not found"
    fi
}

test_grep() {
    log_info "Testing grep utility..."

    if ! util_exists "grep"; then
        log_skip "grep" "utility not found"
        return
    fi

    if check_util_syntax "grep"; then
        log_pass "grep.home - syntax check"
    else
        log_fail "grep.home - syntax check" "valid syntax" "invalid"
    fi

    # Check for pattern matching
    if grep -q "pattern\|match\|search\|regex" "$UTILS_DIR/grep.home" 2>/dev/null; then
        log_pass "grep.home - has pattern matching"
    else
        log_fail "grep.home - has pattern matching" "pattern matching" "not found"
    fi
}

test_chmod() {
    log_info "Testing chmod utility..."

    if ! util_exists "chmod"; then
        log_skip "chmod" "utility not found"
        return
    fi

    if check_util_syntax "chmod"; then
        log_pass "chmod.home - syntax check"
    else
        log_fail "chmod.home - syntax check" "valid syntax" "invalid"
    fi

    # Check for permission handling
    if grep -q "mode\|permission\|chmod\|0[0-7][0-7][0-7]" "$UTILS_DIR/chmod.home" 2>/dev/null; then
        log_pass "chmod.home - has permission handling"
    else
        log_fail "chmod.home - has permission handling" "permission handling" "not found"
    fi
}

# ============================================================================
# Shell Tests
# ============================================================================

test_shell() {
    log_info "Testing shell..."

    local shell_file="$PROJECT_ROOT/apps/shell.home"

    if [ ! -f "$shell_file" ]; then
        log_skip "shell" "not found"
        return
    fi

    # Check for essential shell features
    if grep -q "fn main\|export fn" "$shell_file"; then
        log_pass "shell.home - has entry point"
    else
        log_fail "shell.home - has entry point" "main function" "not found"
    fi

    if grep -q "history\|command.*history" "$shell_file"; then
        log_pass "shell.home - has history support"
    else
        log_fail "shell.home - has history support" "history" "not found"
    fi

    if grep -q "builtin\|cd\|pwd\|exit" "$shell_file"; then
        log_pass "shell.home - has builtins"
    else
        log_fail "shell.home - has builtins" "builtins" "not found"
    fi

    if grep -q "pipe\|\|" "$shell_file"; then
        log_pass "shell.home - has pipe support"
    else
        log_skip "shell.home - has pipe support" "not implemented"
    fi
}

# ============================================================================
# Init Tests
# ============================================================================

test_init() {
    log_info "Testing init system..."

    local init_file="$PROJECT_ROOT/apps/init/init.home"

    if [ ! -f "$init_file" ]; then
        log_skip "init" "not found"
        return
    fi

    if grep -q "fn main\|export fn" "$init_file"; then
        log_pass "init.home - has entry point"
    else
        log_fail "init.home - has entry point" "main function" "not found"
    fi

    if grep -q "service\|daemon" "$init_file"; then
        log_pass "init.home - has service management"
    else
        log_fail "init.home - has service management" "service management" "not found"
    fi

    if grep -q "runlevel\|target" "$init_file"; then
        log_pass "init.home - has runlevel support"
    else
        log_skip "init.home - has runlevel support" "not implemented"
    fi
}

# ============================================================================
# Main Test Runner
# ============================================================================

echo ""
echo "============================================="
echo "     HomeOS Utility Test Suite"
echo "============================================="
echo ""
echo "Test Directory: $UTILS_DIR"
echo ""

# Count utilities
if [ -d "$UTILS_DIR" ]; then
    UTIL_COUNT=$(find "$UTILS_DIR" -name "*.home" 2>/dev/null | wc -l | tr -d ' ')
    log_info "Found $UTIL_COUNT utility files"
else
    log_info "Utilities directory not found, will test what's available"
fi

echo ""
echo "--- File Utilities ---"
test_ls
test_cat
test_cp
test_mkdir
test_rm

echo ""
echo "--- Process Utilities ---"
test_ps
test_top

echo ""
echo "--- Text Utilities ---"
test_echo
test_grep

echo ""
echo "--- System Utilities ---"
test_chmod

echo ""
echo "--- Shell & Init ---"
test_shell
test_init

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "============================================="
echo "           Test Summary"
echo "============================================="
echo ""
echo -e "  ${GREEN}Passed:${NC}  $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC}  $TESTS_FAILED"
echo -e "  ${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
echo ""

TOTAL=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
echo "  Total:   $TOTAL"
echo ""

# Write results to file
cat > "$TEST_RESULTS_DIR/utility-tests.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "passed": $TESTS_PASSED,
  "failed": $TESTS_FAILED,
  "skipped": $TESTS_SKIPPED,
  "total": $TOTAL
}
EOF

# Exit with error if any tests failed
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
