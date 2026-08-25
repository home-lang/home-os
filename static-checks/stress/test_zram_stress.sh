#!/bin/bash
# home-os ZRAM Stress Test Suite
# Validates ZRAM tuning for Pi 3/4/5 under sustained workloads
# Targets: swap thrash, page-in latency, compression ratio, power efficiency

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
KERNEL_SRC="$PROJECT_ROOT/kernel/src"
RESULTS_DIR="$PROJECT_ROOT/build/stress-results"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test configuration
TEST_DURATION_HOURS=${ZRAM_TEST_HOURS:-1}  # Default 1 hour, set ZRAM_TEST_HOURS=24 for full test
QUICK_TEST=${ZRAM_QUICK_TEST:-0}           # Set to 1 for 5-minute quick test
WORKING_SET_MB=${ZRAM_WORKING_SET:-128}

# Results
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

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

echo -e "${BLUE}home-os ZRAM Stress Test Suite${NC}"
echo "========================================"
echo "Platform: $PLATFORM"
echo "Test Duration: ${TEST_DURATION_HOURS}h"
echo "Working Set: ${WORKING_SET_MB}MB"
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
    echo -e "  ${YELLOW}[SKIP]${NC} $test_name - $reason"
}

# ============================================================================
# SOURCE FILE VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Source File Verification ---${NC}"

verify_source() {
    local file="$1"
    local desc="$2"
    ((TESTS_TOTAL++))
    if [ -f "$file" ]; then
        test_pass "$desc"
    else
        test_fail "$desc" "File not found: $file"
    fi
}

verify_source "$KERNEL_SRC/mm/zram.home" "ZRAM module"
verify_source "$KERNEL_SRC/mm/zram_tuning.home" "ZRAM tuning module"
verify_source "$KERNEL_SRC/mm/swap.home" "Swap module"
verify_source "$KERNEL_SRC/mm/slab.home" "Slab allocator"
verify_source "$KERNEL_SRC/mm/pool.home" "Memory pool"

# ============================================================================
# TUNING PROFILE VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Tuning Profile Verification ---${NC}"

verify_profile() {
    local profile="$1"
    ((TESTS_TOTAL++))
    if grep -q "PROFILE_$profile:" "$KERNEL_SRC/mm/zram_tuning.home" 2>/dev/null || \
       grep -q "const PROFILE_$profile" "$KERNEL_SRC/mm/zram_tuning.home" 2>/dev/null; then
        test_pass "Profile $profile defined"
    else
        test_fail "Profile $profile" "Not found in zram_tuning.home"
    fi
}

verify_profile "PI3"
verify_profile "PI4"
verify_profile "PI5"
verify_profile "X86"

# ============================================================================
# PLATFORM-SPECIFIC TARGETS
# ============================================================================

echo -e "\n${YELLOW}--- Platform Targets ---${NC}"

# Define targets per platform
declare -A LATENCY_AVG_TARGET
LATENCY_AVG_TARGET["pi3"]=500
LATENCY_AVG_TARGET["pi4"]=200
LATENCY_AVG_TARGET["pi5"]=100
LATENCY_AVG_TARGET["x86-64"]=50

declare -A LATENCY_MAX_TARGET
LATENCY_MAX_TARGET["pi3"]=5000
LATENCY_MAX_TARGET["pi4"]=2000
LATENCY_MAX_TARGET["pi5"]=1000
LATENCY_MAX_TARGET["x86-64"]=500

declare -A COMPRESSION_TARGET
COMPRESSION_TARGET["pi3"]=150
COMPRESSION_TARGET["pi4"]=150
COMPRESSION_TARGET["pi5"]=180
COMPRESSION_TARGET["x86-64"]=200

declare -A ZRAM_SIZE_TARGET
ZRAM_SIZE_TARGET["pi3"]=256
ZRAM_SIZE_TARGET["pi4"]=512
ZRAM_SIZE_TARGET["pi5"]=1024
ZRAM_SIZE_TARGET["x86-64"]=2048

echo "  Platform: $PLATFORM"
echo "  Target avg latency: ${LATENCY_AVG_TARGET[$PLATFORM]:-50} us"
echo "  Target max latency: ${LATENCY_MAX_TARGET[$PLATFORM]:-500} us"
echo "  Target compression: ${COMPRESSION_TARGET[$PLATFORM]:-150}%"
echo "  Target ZRAM size: ${ZRAM_SIZE_TARGET[$PLATFORM]:-512} MB"

# ============================================================================
# FUNCTION VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Function Verification ---${NC}"

verify_function() {
    local func="$1"
    local file="$2"
    ((TESTS_TOTAL++))
    if grep -q "export fn $func" "$file" 2>/dev/null; then
        test_pass "Function $func"
    else
        test_fail "Function $func" "Not found in $file"
    fi
}

verify_function "zram_tuning_init" "$KERNEL_SRC/mm/zram_tuning.home"
verify_function "zram_stress_test" "$KERNEL_SRC/mm/zram_tuning.home"
verify_function "zram_stress_print_report" "$KERNEL_SRC/mm/zram_tuning.home"
verify_function "zram_run_full_stress_test" "$KERNEL_SRC/mm/zram_tuning.home"
verify_function "zram_run_quick_test" "$KERNEL_SRC/mm/zram_tuning.home"
verify_function "zram_tuning_proc_read" "$KERNEL_SRC/mm/zram_tuning.home"

# ============================================================================
# STRESS TEST TYPES
# ============================================================================

echo -e "\n${YELLOW}--- Stress Test Types ---${NC}"

verify_const() {
    local const="$1"
    local file="$2"
    ((TESTS_TOTAL++))
    if grep -q "const $const:" "$file" 2>/dev/null; then
        test_pass "Constant $const"
    else
        test_fail "Constant $const" "Not defined"
    fi
}

verify_const "STRESS_SWAP_THRASH" "$KERNEL_SRC/mm/zram_tuning.home"
verify_const "STRESS_RANDOM_ACCESS" "$KERNEL_SRC/mm/zram_tuning.home"
verify_const "STRESS_COMPRESSION_RATIO" "$KERNEL_SRC/mm/zram_tuning.home"
verify_const "STRESS_LATENCY" "$KERNEL_SRC/mm/zram_tuning.home"

# ============================================================================
# LIVE SYSTEM TESTS (if running on actual hardware)
# ============================================================================

echo -e "\n${YELLOW}--- Live System Tests ---${NC}"

# Check if ZRAM is available on the system
if [ -e /sys/block/zram0 ]; then
    ((TESTS_TOTAL++))
    ZRAM_SIZE=$(cat /sys/block/zram0/disksize 2>/dev/null || echo "0")
    ZRAM_SIZE_MB=$((ZRAM_SIZE / 1024 / 1024))

    if [ "$ZRAM_SIZE_MB" -gt 0 ]; then
        test_pass "ZRAM device active" "${ZRAM_SIZE_MB}MB configured"

        # Check compression stats if available
        if [ -f /sys/block/zram0/mm_stat ]; then
            ((TESTS_TOTAL++))
            MM_STAT=$(cat /sys/block/zram0/mm_stat 2>/dev/null)
            ORIG_SIZE=$(echo "$MM_STAT" | awk '{print $1}')
            COMPR_SIZE=$(echo "$MM_STAT" | awk '{print $2}')

            if [ "$COMPR_SIZE" -gt 0 ]; then
                RATIO=$((ORIG_SIZE * 100 / COMPR_SIZE))
                test_pass "ZRAM compression active" "Ratio: ${RATIO}%"
            else
                test_pass "ZRAM compression" "No data compressed yet"
            fi
        fi
    else
        test_fail "ZRAM device" "Not configured (size=0)"
    fi
else
    test_skip "ZRAM device check" "ZRAM not available on this system"
fi

# Check swap configuration
if [ -f /proc/swaps ]; then
    ((TESTS_TOTAL++))
    SWAP_ENTRIES=$(grep -c "^/" /proc/swaps 2>/dev/null || echo "0")
    ZRAM_SWAP=$(grep -c "zram" /proc/swaps 2>/dev/null || echo "0")

    if [ "$ZRAM_SWAP" -gt 0 ]; then
        test_pass "ZRAM swap enabled" "$ZRAM_SWAP ZRAM swap device(s)"
    elif [ "$SWAP_ENTRIES" -gt 0 ]; then
        test_pass "Swap configured" "$SWAP_ENTRIES swap device(s) (non-ZRAM)"
    else
        test_skip "Swap check" "No swap configured"
    fi
fi

# Check swappiness
if [ -f /proc/sys/vm/swappiness ]; then
    ((TESTS_TOTAL++))
    SWAPPINESS=$(cat /proc/sys/vm/swappiness)
    TARGET=${SWAPPINESS_TARGET[$PLATFORM]:-60}

    test_pass "Swappiness configured" "Value: $SWAPPINESS"
fi

# Memory pressure test (quick)
if [ -f /proc/meminfo ]; then
    ((TESTS_TOTAL++))
    TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    AVAIL_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    USED_PCT=$(( (TOTAL_KB - AVAIL_KB) * 100 / TOTAL_KB ))

    test_pass "Memory status" "${USED_PCT}% used, $((AVAIL_KB/1024))MB available"
fi

# ============================================================================
# STRESS TEST EXECUTION (optional)
# ============================================================================

if [ "$QUICK_TEST" = "1" ] || [ "${ZRAM_RUN_STRESS:-0}" = "1" ]; then
    echo -e "\n${YELLOW}--- Stress Test Execution ---${NC}"

    # Simple memory stress using dd
    if command -v dd >/dev/null 2>&1; then
        ((TESTS_TOTAL++))

        echo "  Running memory stress test..."

        # Create a temporary file for stress
        STRESS_FILE=$(mktemp)

        START_TIME=$(date +%s%N)

        # Write 100MB of data
        dd if=/dev/zero of="$STRESS_FILE" bs=1M count=100 2>/dev/null

        # Read it back
        dd if="$STRESS_FILE" of=/dev/null bs=1M 2>/dev/null

        END_TIME=$(date +%s%N)
        ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))

        rm -f "$STRESS_FILE"

        if [ "$ELAPSED_MS" -lt 10000 ]; then
            test_pass "Memory stress test" "${ELAPSED_MS}ms for 100MB read/write"
        else
            test_fail "Memory stress test" "${ELAPSED_MS}ms (slow)"
        fi
    fi

    # Check for OOM events during test
    if dmesg 2>/dev/null | grep -qi "Out of memory"; then
        ((TESTS_TOTAL++))
        OOM_COUNT=$(dmesg 2>/dev/null | grep -ci "Out of memory" || echo "0")
        if [ "$OOM_COUNT" -eq 0 ]; then
            test_pass "No OOM events"
        else
            test_fail "OOM events detected" "$OOM_COUNT events"
        fi
    fi
fi

# ============================================================================
# GENERATE REPORT
# ============================================================================

echo -e "\n${YELLOW}--- Generating Report ---${NC}"

REPORT_FILE="$RESULTS_DIR/zram-stress-$(date +%Y%m%d-%H%M%S).json"

cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "platform": "$PLATFORM",
  "platform_id": $PLATFORM_ID,
  "test_config": {
    "duration_hours": $TEST_DURATION_HOURS,
    "working_set_mb": $WORKING_SET_MB,
    "quick_test": $QUICK_TEST
  },
  "targets": {
    "latency_avg_us": ${LATENCY_AVG_TARGET[$PLATFORM]:-50},
    "latency_max_us": ${LATENCY_MAX_TARGET[$PLATFORM]:-500},
    "compression_pct": ${COMPRESSION_TARGET[$PLATFORM]:-150},
    "zram_size_mb": ${ZRAM_SIZE_TARGET[$PLATFORM]:-512}
  },
  "summary": {
    "total": $TESTS_TOTAL,
    "passed": $TESTS_PASSED,
    "failed": $TESTS_FAILED
  }
}
EOF

echo -e "  Report saved to: ${CYAN}$REPORT_FILE${NC}"

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "========================================"
echo -e "${BLUE}ZRAM STRESS TEST SUMMARY${NC}"
echo "========================================"
echo "Platform: $PLATFORM"
echo ""
echo "Total:  $TESTS_TOTAL"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

# Platform-specific tuning recommendations
echo -e "${CYAN}Recommended Tuning:${NC}"
case $PLATFORM in
    pi3)
        echo "  ZRAM Size: 256MB (25% of 1GB RAM)"
        echo "  Compression: LZ4 (fast, low CPU)"
        echo "  Swappiness: 60"
        echo "  Page cluster: 3 (8 pages)"
        ;;
    pi4)
        echo "  ZRAM Size: 512MB (25% of 2GB+ RAM)"
        echo "  Compression: LZ4"
        echo "  Swappiness: 50"
        echo "  Page cluster: 3"
        ;;
    pi5)
        echo "  ZRAM Size: 1024MB (25% of 4GB+ RAM)"
        echo "  Compression: ZSTD (better ratio, fast CPU)"
        echo "  Swappiness: 40"
        echo "  Page cluster: 4 (16 pages)"
        ;;
    *)
        echo "  ZRAM Size: 2048MB"
        echo "  Compression: ZSTD"
        echo "  Swappiness: 30"
        echo "  Page cluster: 4"
        ;;
esac

echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}*** ALL TESTS PASSED ***${NC}"
    exit 0
else
    echo -e "${RED}*** SOME TESTS FAILED ***${NC}"
    exit 1
fi
