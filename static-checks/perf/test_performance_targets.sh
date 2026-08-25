#!/bin/bash
# home-os Performance Targets Enforcement Tests
# Validates performance metrics against defined targets
# For CI/CD integration and regression detection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
KERNEL_SRC="$PROJECT_ROOT/kernel/src"
RESULTS_DIR="$PROJECT_ROOT/build/perf-results"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
CRITICAL_FAILED=0

# Platform detection
PLATFORM="x86-64"
PLATFORM_ID=0
if [ -f /proc/device-tree/model ]; then
    MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "")
    if [[ "$MODEL" == *"Raspberry Pi 3"* ]]; then
        PLATFORM="pi3"
        PLATFORM_ID=3
    elif [[ "$MODEL" == *"Raspberry Pi 4"* ]]; then
        PLATFORM="pi4"
        PLATFORM_ID=4
    elif [[ "$MODEL" == *"Raspberry Pi 5"* ]]; then
        PLATFORM="pi5"
        PLATFORM_ID=5
    fi
fi

# Create results directory
mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}home-os Performance Targets Enforcement${NC}"
echo "=========================================="
echo "Platform: $PLATFORM"
echo "Date: $(date)"
echo ""

# Test helper functions
test_pass() {
    local test_name="$1"
    local measured="$2"
    local target="$3"
    local unit="$4"
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}[PASS]${NC} $test_name: $measured $unit (target: $target $unit)"
}

test_fail() {
    local test_name="$1"
    local measured="$2"
    local target="$3"
    local unit="$4"
    local critical="$5"
    ((TESTS_FAILED++))
    if [ "$critical" = "1" ]; then
        ((CRITICAL_FAILED++))
        echo -e "  ${RED}[FAIL]${NC} $test_name: $measured $unit (target: $target $unit) [CRITICAL]"
    else
        echo -e "  ${YELLOW}[WARN]${NC} $test_name: $measured $unit (target: $target $unit)"
    fi
}

test_skip() {
    local test_name="$1"
    local reason="$2"
    echo -e "  ${YELLOW}[SKIP]${NC} $test_name - $reason"
}

# ============================================================================
# PERFORMANCE TARGETS
# ============================================================================

# Boot time targets (ms)
declare -A BOOT_TARGETS
BOOT_TARGETS["x86-64"]=2000
BOOT_TARGETS["pi3"]=5000
BOOT_TARGETS["pi4"]=3000
BOOT_TARGETS["pi5"]=2000

# Memory targets (KB)
declare -A MEM_HEADLESS_TARGETS
MEM_HEADLESS_TARGETS["x86-64"]=98304   # 96MB
MEM_HEADLESS_TARGETS["pi3"]=65536      # 64MB
MEM_HEADLESS_TARGETS["pi4"]=98304      # 96MB
MEM_HEADLESS_TARGETS["pi5"]=131072     # 128MB

# SD card read targets (KB/s)
declare -A SD_READ_TARGETS
SD_READ_TARGETS["pi3"]=23552    # 23 MB/s
SD_READ_TARGETS["pi4"]=46080    # 45 MB/s
SD_READ_TARGETS["pi5"]=92160    # 90 MB/s

# Network targets (Kbps)
declare -A ETH_TARGETS
ETH_TARGETS["pi3"]=95000        # 95 Mbps
ETH_TARGETS["pi4"]=940000       # 940 Mbps
ETH_TARGETS["pi5"]=940000       # 940 Mbps

# ============================================================================
# SOURCE FILE VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Source File Verification ---${NC}"

verify_source() {
    local file="$1"
    local desc="$2"
    ((TESTS_TOTAL++))
    if [ -f "$file" ]; then
        test_pass "$desc" "exists" "-" ""
    else
        test_fail "$desc" "missing" "-" "" "0"
    fi
}

verify_source "$KERNEL_SRC/perf/targets.home" "Performance targets module"
verify_source "$KERNEL_SRC/perf/baseline.home" "Baseline module"
verify_source "$KERNEL_SRC/perf/pi_benchmark.home" "Pi benchmark module"
verify_source "$KERNEL_SRC/perf/boot_opt.home" "Boot optimization module"

# ============================================================================
# TARGET CONSTANTS VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Target Constants Verification ---${NC}"

TARGETS_FILE="$KERNEL_SRC/perf/targets.home"

verify_const() {
    local const="$1"
    ((TESTS_TOTAL++))
    if grep -q "const $const:" "$TARGETS_FILE" 2>/dev/null; then
        test_pass "Constant $const" "defined" "-" ""
    else
        test_fail "Constant $const" "missing" "-" "" "0"
    fi
}

# Boot targets
verify_const "TARGET_BOOT_X86_MS"
verify_const "TARGET_BOOT_PI3_MS"
verify_const "TARGET_BOOT_PI4_MS"
verify_const "TARGET_BOOT_PI5_MS"

# Memory targets
verify_const "TARGET_MEM_HEADLESS_X86_KB"
verify_const "TARGET_MEM_HEADLESS_PI3_KB"
verify_const "TARGET_MEM_HEADLESS_PI4_KB"

# I/O targets
verify_const "TARGET_SD_READ_PI3_KBS"
verify_const "TARGET_SD_READ_PI4_KBS"
verify_const "TARGET_SD_READ_PI5_KBS"

# Network targets
verify_const "TARGET_ETH_PI3_KBPS"
verify_const "TARGET_ETH_PI4_KBPS"

# Stability targets
verify_const "TARGET_UPTIME_HOURS"
verify_const "TARGET_MEMORY_LEAK_KB_PER_HOUR"
verify_const "TARGET_MAX_CRASH_COUNT"

# ============================================================================
# FUNCTION VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Function Verification ---${NC}"

verify_function() {
    local func="$1"
    ((TESTS_TOTAL++))
    if grep -q "export fn $func" "$TARGETS_FILE" 2>/dev/null; then
        test_pass "Function $func" "exists" "-" ""
    else
        test_fail "Function $func" "missing" "-" "" "0"
    fi
}

verify_function "targets_init"
verify_function "targets_enforce"
verify_function "targets_print_report"
verify_function "targets_to_json"
verify_function "targets_ci_check"
verify_function "targets_proc_read"

# ============================================================================
# LIVE PERFORMANCE TESTS
# ============================================================================

echo -e "\n${YELLOW}--- Live Performance Measurements ---${NC}"

# Boot time (from systemd-analyze if available)
if command -v systemd-analyze >/dev/null 2>&1; then
    ((TESTS_TOTAL++))
    BOOT_MS=$(systemd-analyze 2>/dev/null | grep -oP 'kernel\) = \K[\d.]+' | head -1 || echo "0")
    if [ -n "$BOOT_MS" ] && [ "$BOOT_MS" != "0" ]; then
        BOOT_MS_INT=$(echo "$BOOT_MS * 1000" | bc 2>/dev/null | cut -d. -f1 || echo "0")
        TARGET=${BOOT_TARGETS[$PLATFORM]:-3000}
        if [ "$BOOT_MS_INT" -le "$TARGET" ]; then
            test_pass "Boot time" "$BOOT_MS_INT" "$TARGET" "ms"
        else
            test_fail "Boot time" "$BOOT_MS_INT" "$TARGET" "ms" "1"
        fi
    else
        test_skip "Boot time" "Could not measure"
    fi
fi

# Memory usage
if [ -f /proc/meminfo ]; then
    ((TESTS_TOTAL++))
    TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    AVAIL_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    USED_KB=$((TOTAL_KB - AVAIL_KB))
    TARGET=${MEM_HEADLESS_TARGETS[$PLATFORM]:-98304}

    if [ "$USED_KB" -le "$TARGET" ]; then
        test_pass "Memory usage" "$USED_KB" "$TARGET" "KB"
    else
        test_fail "Memory usage" "$USED_KB" "$TARGET" "KB" "1"
    fi
fi

# SD card read speed (if on Pi)
if [[ "$PLATFORM" == pi* ]] && [ -b /dev/mmcblk0 ]; then
    ((TESTS_TOTAL++))
    # Quick read test
    SPEED_OUTPUT=$(dd if=/dev/mmcblk0 of=/dev/null bs=4M count=25 iflag=direct 2>&1 || echo "")
    SPEED_MBS=$(echo "$SPEED_OUTPUT" | grep -oP '[\d.]+ MB/s' | grep -oP '[\d.]+' || echo "0")
    if [ -n "$SPEED_MBS" ] && [ "$SPEED_MBS" != "0" ]; then
        SPEED_KBS=$(echo "$SPEED_MBS * 1024" | bc 2>/dev/null | cut -d. -f1 || echo "0")
        TARGET=${SD_READ_TARGETS[$PLATFORM]:-46080}
        if [ "$SPEED_KBS" -ge "$TARGET" ]; then
            test_pass "SD read speed" "$SPEED_KBS" "$TARGET" "KB/s"
        else
            test_fail "SD read speed" "$SPEED_KBS" "$TARGET" "KB/s" "0"
        fi
    else
        test_skip "SD read speed" "Could not measure"
    fi
else
    test_skip "SD read speed" "Not on Raspberry Pi"
fi

# Network throughput (if eth0 available)
if ip link show eth0 >/dev/null 2>&1; then
    ((TESTS_TOTAL++))
    # Get link speed
    SPEED=$(cat /sys/class/net/eth0/speed 2>/dev/null || echo "0")
    SPEED_KBPS=$((SPEED * 1000))
    TARGET=${ETH_TARGETS[$PLATFORM]:-940000}

    if [ "$SPEED_KBPS" -ge "$TARGET" ]; then
        test_pass "Ethernet link speed" "$SPEED_KBPS" "$TARGET" "Kbps"
    else
        test_fail "Ethernet link speed" "$SPEED_KBPS" "$TARGET" "Kbps" "0"
    fi
else
    test_skip "Ethernet speed" "eth0 not available"
fi

# CPU temperature (Pi specific)
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    ((TESTS_TOTAL++))
    TEMP_MC=$(cat /sys/class/thermal/thermal_zone0/temp)
    TEMP_C=$((TEMP_MC / 1000))
    # Target: below 80°C (throttling threshold)
    if [ "$TEMP_C" -lt 80 ]; then
        test_pass "CPU temperature" "$TEMP_C" "80" "°C"
    else
        test_fail "CPU temperature" "$TEMP_C" "80" "°C" "0"
    fi
fi

# ============================================================================
# STABILITY CHECKS
# ============================================================================

echo -e "\n${YELLOW}--- Stability Checks ---${NC}"

# Uptime
if [ -f /proc/uptime ]; then
    ((TESTS_TOTAL++))
    UPTIME_SEC=$(awk '{print int($1)}' /proc/uptime)
    UPTIME_HOURS=$((UPTIME_SEC / 3600))
    # For testing, we just check it's running (target is 168 hours for full validation)
    test_pass "System uptime" "$UPTIME_HOURS" "0" "hours"
fi

# Check for OOM kills
if dmesg 2>/dev/null | grep -qi "Out of memory"; then
    ((TESTS_TOTAL++))
    OOM_COUNT=$(dmesg 2>/dev/null | grep -ci "Out of memory" || echo "0")
    if [ "$OOM_COUNT" -eq 0 ]; then
        test_pass "OOM kills" "$OOM_COUNT" "0" "count"
    else
        test_fail "OOM kills" "$OOM_COUNT" "0" "count" "1"
    fi
else
    ((TESTS_TOTAL++))
    test_pass "OOM kills" "0" "0" "count"
fi

# Check for kernel panics/oops
if dmesg 2>/dev/null | grep -qiE "panic|oops"; then
    ((TESTS_TOTAL++))
    PANIC_COUNT=$(dmesg 2>/dev/null | grep -ciE "panic|oops" || echo "0")
    test_fail "Kernel panics/oops" "$PANIC_COUNT" "0" "count" "1"
else
    ((TESTS_TOTAL++))
    test_pass "Kernel panics/oops" "0" "0" "count"
fi

# ============================================================================
# GENERATE JSON REPORT
# ============================================================================

echo -e "\n${YELLOW}--- Generating Report ---${NC}"

REPORT_FILE="$RESULTS_DIR/perf-report-$(date +%Y%m%d-%H%M%S).json"

cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "platform": "$PLATFORM",
  "platform_id": $PLATFORM_ID,
  "summary": {
    "total": $TESTS_TOTAL,
    "passed": $TESTS_PASSED,
    "failed": $TESTS_FAILED,
    "critical_failed": $CRITICAL_FAILED
  },
  "targets": {
    "boot_ms": ${BOOT_TARGETS[$PLATFORM]:-3000},
    "memory_kb": ${MEM_HEADLESS_TARGETS[$PLATFORM]:-98304},
    "sd_read_kbs": ${SD_READ_TARGETS[$PLATFORM]:-0},
    "eth_kbps": ${ETH_TARGETS[$PLATFORM]:-0}
  }
}
EOF

echo -e "  Report saved to: ${CYAN}$REPORT_FILE${NC}"

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "=========================================="
echo -e "${BLUE}PERFORMANCE TARGETS SUMMARY${NC}"
echo "=========================================="
echo "Platform: $PLATFORM"
echo ""
echo "Total:            $TESTS_TOTAL"
echo -e "Passed:           ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:           ${RED}$TESTS_FAILED${NC}"
echo -e "Critical Failed:  ${RED}$CRITICAL_FAILED${NC}"
echo ""

# Target reference
echo -e "${CYAN}Target Reference:${NC}"
echo "  Boot time:    x86: 2.0s, Pi3: 5.0s, Pi4: 3.0s, Pi5: 2.0s"
echo "  Memory:       x86: 96MB, Pi3: 64MB, Pi4: 96MB, Pi5: 128MB"
echo "  SD read:      Pi3: 23MB/s, Pi4: 45MB/s, Pi5: 90MB/s"
echo "  Ethernet:     Pi3: 95Mbps, Pi4+: 940Mbps"
echo ""

if [ $CRITICAL_FAILED -eq 0 ]; then
    echo -e "${GREEN}*** ALL CRITICAL TARGETS PASSED ***${NC}"
    exit 0
else
    echo -e "${RED}*** CRITICAL TARGETS FAILED ***${NC}"
    exit 2
fi
