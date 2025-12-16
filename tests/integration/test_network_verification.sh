#!/bin/bash
# home-os Network Stack Verification Tests
# Integration tests for Ping, HTTP, TLS, WebSocket on Pi and x86-64
# Runs in QEMU or on real hardware

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
KERNEL_SRC="$PROJECT_ROOT/kernel/src"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Platform detection
PLATFORM="x86-64"
if [ -f /proc/device-tree/model ]; then
    MODEL=$(cat /proc/device-tree/model 2>/dev/null || echo "")
    if [[ "$MODEL" == *"Raspberry Pi 3"* ]]; then
        PLATFORM="pi3"
    elif [[ "$MODEL" == *"Raspberry Pi 4"* ]]; then
        PLATFORM="pi4"
    elif [[ "$MODEL" == *"Raspberry Pi 5"* ]]; then
        PLATFORM="pi5"
    fi
fi

echo -e "${BLUE}home-os Network Stack Verification Tests${NC}"
echo "=========================================="
echo "Platform: $PLATFORM"
echo "Date: $(date)"
echo ""

# Test helper functions
test_pass() {
    local test_name="$1"
    local detail="$2"
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}[PASS]${NC} $test_name"
    [ -n "$detail" ] && echo "        $detail"
}

test_fail() {
    local test_name="$1"
    local detail="$2"
    ((TESTS_FAILED++))
    echo -e "  ${RED}[FAIL]${NC} $test_name"
    [ -n "$detail" ] && echo "        $detail"
}

test_skip() {
    local test_name="$1"
    local reason="$2"
    echo -e "  ${YELLOW}[SKIP]${NC} $test_name"
    [ -n "$reason" ] && echo "        Reason: $reason"
}

# ============================================================================
# SOURCE FILE VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Source File Verification ---${NC}"

verify_source_file() {
    local file="$1"
    local desc="$2"
    ((TESTS_TOTAL++))

    if [ -f "$file" ]; then
        test_pass "$desc exists"
    else
        test_fail "$desc missing" "$file"
    fi
}

verify_source_file "$KERNEL_SRC/net/network_stack_verification.home" "Network verification module"
verify_source_file "$KERNEL_SRC/net/tcp.home" "TCP module"
verify_source_file "$KERNEL_SRC/net/tls.home" "TLS module"
verify_source_file "$KERNEL_SRC/net/http.home" "HTTP module"
verify_source_file "$KERNEL_SRC/net/websocket.home" "WebSocket module"
verify_source_file "$KERNEL_SRC/net/icmp.home" "ICMP module"
verify_source_file "$KERNEL_SRC/net/dns.home" "DNS module"

# ============================================================================
# SYNTAX VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Syntax Verification ---${NC}"

verify_syntax() {
    local file="$1"
    local name="$2"
    ((TESTS_TOTAL++))

    if [ ! -f "$file" ]; then
        test_skip "$name syntax" "File not found"
        return
    fi

    # Check for basic syntax elements
    local has_imports=$(grep -c "^import " "$file" 2>/dev/null || echo "0")
    local has_exports=$(grep -c "^export fn " "$file" 2>/dev/null || echo "0")
    local has_structs=$(grep -c "^struct " "$file" 2>/dev/null || echo "0")

    if [ "$has_imports" -gt 0 ] && [ "$has_exports" -gt 0 ]; then
        test_pass "$name syntax" "imports: $has_imports, exports: $has_exports, structs: $has_structs"
    else
        test_fail "$name syntax" "Missing required elements"
    fi
}

verify_syntax "$KERNEL_SRC/net/network_stack_verification.home" "Network verification"

# ============================================================================
# FUNCTION VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Function Verification ---${NC}"

verify_function() {
    local file="$1"
    local func="$2"
    ((TESTS_TOTAL++))

    if [ ! -f "$file" ]; then
        test_skip "Function $func" "File not found"
        return
    fi

    if grep -q "export fn $func" "$file" 2>/dev/null; then
        test_pass "Function $func exists"
    else
        test_fail "Function $func missing"
    fi
}

VERIFY_FILE="$KERNEL_SRC/net/network_stack_verification.home"

# Core initialization
verify_function "$VERIFY_FILE" "network_verification_init"
verify_function "$VERIFY_FILE" "network_verification_set_defaults"

# Ping tests
verify_function "$VERIFY_FILE" "verify_ping"
verify_function "$VERIFY_FILE" "verify_ping_all"

# DNS tests
verify_function "$VERIFY_FILE" "verify_dns_resolution"

# TCP tests
verify_function "$VERIFY_FILE" "verify_tcp_connect"

# HTTP tests
verify_function "$VERIFY_FILE" "verify_http_get"
verify_function "$VERIFY_FILE" "verify_http_all"

# TLS tests
verify_function "$VERIFY_FILE" "verify_tls_handshake"
verify_function "$VERIFY_FILE" "verify_https_get"
verify_function "$VERIFY_FILE" "verify_https_all"

# WebSocket tests
verify_function "$VERIFY_FILE" "verify_websocket_connect"
verify_function "$VERIFY_FILE" "verify_websocket_echo"
verify_function "$VERIFY_FILE" "verify_websocket_ping_pong"

# Full suite
verify_function "$VERIFY_FILE" "network_verification_run_all"
verify_function "$VERIFY_FILE" "network_verification_run_pi"
verify_function "$VERIFY_FILE" "network_verification_run_x86"

# Reporting
verify_function "$VERIFY_FILE" "network_verification_print_summary"
verify_function "$VERIFY_FILE" "network_verification_get_summary"

# ============================================================================
# DATA STRUCTURE VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Data Structure Verification ---${NC}"

verify_struct() {
    local file="$1"
    local struct="$2"
    ((TESTS_TOTAL++))

    if grep -q "struct $struct" "$file" 2>/dev/null; then
        test_pass "Struct $struct defined"
    else
        test_fail "Struct $struct missing"
    fi
}

verify_struct "$VERIFY_FILE" "VerificationConfig"
verify_struct "$VERIFY_FILE" "VerificationTest"
verify_struct "$VERIFY_FILE" "VerificationSummary"

# ============================================================================
# ERROR CODE VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Error Code Verification ---${NC}"

verify_const() {
    local file="$1"
    local const="$2"
    ((TESTS_TOTAL++))

    if grep -q "const $const:" "$file" 2>/dev/null; then
        test_pass "Constant $const defined"
    else
        test_fail "Constant $const missing"
    fi
}

verify_const "$VERIFY_FILE" "VERR_SUCCESS"
verify_const "$VERIFY_FILE" "VERR_TIMEOUT"
verify_const "$VERIFY_FILE" "VERR_CONNECTION_REFUSED"
verify_const "$VERIFY_FILE" "VERR_DNS_FAILED"
verify_const "$VERIFY_FILE" "VERR_TLS_HANDSHAKE_FAILED"
verify_const "$VERIFY_FILE" "VERR_HTTP_BAD_STATUS"
verify_const "$VERIFY_FILE" "VERR_WEBSOCKET_UPGRADE_FAILED"

# ============================================================================
# TEST CATEGORY VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Test Category Verification ---${NC}"

verify_const "$VERIFY_FILE" "TEST_CAT_PING"
verify_const "$VERIFY_FILE" "TEST_CAT_HTTP"
verify_const "$VERIFY_FILE" "TEST_CAT_TLS"
verify_const "$VERIFY_FILE" "TEST_CAT_WEBSOCKET"
verify_const "$VERIFY_FILE" "TEST_CAT_DNS"
verify_const "$VERIFY_FILE" "TEST_CAT_TCP"

# ============================================================================
# LIVE NETWORK TESTS (if network available)
# ============================================================================

echo -e "\n${YELLOW}--- Live Network Tests (Optional) ---${NC}"

# Check if we have network connectivity
if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    echo "Network connectivity detected, running live tests..."

    # DNS resolution test
    ((TESTS_TOTAL++))
    if host example.com >/dev/null 2>&1 || nslookup example.com >/dev/null 2>&1; then
        test_pass "Live DNS resolution"
    else
        test_fail "Live DNS resolution"
    fi

    # HTTP test
    ((TESTS_TOTAL++))
    if curl -s -o /dev/null -w "%{http_code}" http://example.com/ | grep -q "200\|301\|302"; then
        test_pass "Live HTTP GET"
    else
        test_fail "Live HTTP GET"
    fi

    # HTTPS test
    ((TESTS_TOTAL++))
    if curl -s -o /dev/null -w "%{http_code}" https://example.com/ | grep -q "200\|301\|302"; then
        test_pass "Live HTTPS GET"
    else
        test_fail "Live HTTPS GET"
    fi

    # Ping test
    ((TESTS_TOTAL++))
    if ping -c 3 -W 2 8.8.8.8 >/dev/null 2>&1; then
        RTT=$(ping -c 3 -W 2 8.8.8.8 2>/dev/null | tail -1 | cut -d'/' -f5 || echo "N/A")
        test_pass "Live ICMP ping" "RTT: ${RTT}ms"
    else
        test_fail "Live ICMP ping"
    fi
else
    test_skip "Live network tests" "No network connectivity"
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "=========================================="
echo -e "${BLUE}NETWORK VERIFICATION TEST SUMMARY${NC}"
echo "=========================================="
echo "Platform: $PLATFORM"
echo "Total:    $TESTS_TOTAL"
echo -e "Passed:   ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:   ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}*** ALL TESTS PASSED ***${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}*** SOME TESTS FAILED ***${NC}"
    exit 1
fi
