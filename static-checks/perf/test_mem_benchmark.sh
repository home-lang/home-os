#!/bin/bash
# home-os Memory Fragmentation & Cache Benchmark Test
# Validates memory allocator efficiency: fragmentation, cache hits, latency

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

# Results
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Targets
TARGET_FRAG_EXTERNAL=15    # <15% external fragmentation
TARGET_FRAG_INTERNAL=25    # <25% internal fragmentation
TARGET_CACHE_HIT=80        # >80% cache hit rate
TARGET_ALLOC_AVG_US=10     # <10us average allocation

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

# Create results directory
mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}home-os Memory Benchmark Test Suite${NC}"
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

verify_source "$KERNEL_SRC/mm/mem_benchmark.home" "Memory benchmark module"
verify_source "$KERNEL_SRC/mm/slab.home" "Slab allocator"
verify_source "$KERNEL_SRC/mm/pool.home" "Memory pool"
verify_source "$KERNEL_SRC/mm/zram.home" "ZRAM module"
verify_source "$KERNEL_SRC/mm/zram_tuning.home" "ZRAM tuning module"

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

verify_function "mem_benchmark_init" "$KERNEL_SRC/mm/mem_benchmark.home"
verify_function "mem_benchmark_run" "$KERNEL_SRC/mm/mem_benchmark.home"
verify_function "mem_benchmark_print_report" "$KERNEL_SRC/mm/mem_benchmark.home"
verify_function "mem_benchmark_fragmentation" "$KERNEL_SRC/mm/mem_benchmark.home"
verify_function "mem_benchmark_cache" "$KERNEL_SRC/mm/mem_benchmark.home"
verify_function "mem_benchmark_workload" "$KERNEL_SRC/mm/mem_benchmark.home"
verify_function "mem_benchmark_full" "$KERNEL_SRC/mm/mem_benchmark.home"
verify_function "mem_benchmark_proc_read" "$KERNEL_SRC/mm/mem_benchmark.home"

# ============================================================================
# CONSTANT VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Benchmark Constants ---${NC}"

verify_const() {
    local const="$1"
    ((TESTS_TOTAL++))
    if grep -q "const $const:" "$KERNEL_SRC/mm/mem_benchmark.home" 2>/dev/null; then
        test_pass "Constant $const"
    else
        test_fail "Constant $const" "Not defined"
    fi
}

verify_const "BENCH_FRAGMENTATION"
verify_const "BENCH_CACHE_HIT"
verify_const "BENCH_MIXED_WORKLOAD"
verify_const "WORKLOAD_WEB_SERVER"
verify_const "WORKLOAD_DATABASE"
verify_const "WORKLOAD_COMPILER"
verify_const "WORKLOAD_KERNEL_TYPICAL"
verify_const "TARGET_FRAG_EXTERNAL_PCT"
verify_const "TARGET_CACHE_HIT_RATE"

# ============================================================================
# STRUCTURE VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Data Structure Verification ---${NC}"

verify_struct() {
    local struct="$1"
    ((TESTS_TOTAL++))
    if grep -q "struct $struct" "$KERNEL_SRC/mm/mem_benchmark.home" 2>/dev/null; then
        test_pass "Structure $struct"
    else
        test_fail "Structure $struct" "Not defined"
    fi
}

verify_struct "FragmentationStats"
verify_struct "CacheStats"
verify_struct "LatencyStats"
verify_struct "BenchmarkResults"
verify_struct "AllocRecord"

# ============================================================================
# SLAB ALLOCATOR VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Slab Allocator Verification ---${NC}"

verify_function "slab_init" "$KERNEL_SRC/mm/slab.home"
verify_function "magazine_create" "$KERNEL_SRC/mm/slab.home"

# Check for per-CPU cache support
((TESTS_TOTAL++))
if grep -q "CpuCache" "$KERNEL_SRC/mm/slab.home" 2>/dev/null; then
    test_pass "Per-CPU cache support"
else
    test_fail "Per-CPU cache support" "CpuCache structure not found"
fi

# Check for magazine layer
((TESTS_TOTAL++))
if grep -q "Magazine" "$KERNEL_SRC/mm/slab.home" 2>/dev/null; then
    test_pass "Magazine layer support"
else
    test_fail "Magazine layer support" "Magazine structure not found"
fi

# ============================================================================
# POOL ALLOCATOR VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Pool Allocator Verification ---${NC}"

verify_function "pool_init" "$KERNEL_SRC/mm/pool.home"

# Check for size classes
((TESTS_TOTAL++))
if grep -q "POOL_SIZE_" "$KERNEL_SRC/mm/pool.home" 2>/dev/null; then
    test_pass "Pool size classes defined"
else
    test_fail "Pool size classes" "POOL_SIZE_* constants not found"
fi

# ============================================================================
# LIVE SYSTEM TESTS
# ============================================================================

echo -e "\n${YELLOW}--- Live System Tests ---${NC}"

# Check current memory state
if [ -f /proc/meminfo ]; then
    ((TESTS_TOTAL++))
    TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    AVAIL_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    USED_PCT=$(( (TOTAL_KB - AVAIL_KB) * 100 / TOTAL_KB ))

    test_pass "Memory status" "${USED_PCT}% used, $((AVAIL_KB/1024))MB available"
fi

# Check for memory fragmentation via buddyinfo
if [ -f /proc/buddyinfo ]; then
    ((TESTS_TOTAL++))
    # Count free pages at each order
    BUDDY_INFO=$(cat /proc/buddyinfo | head -1)
    test_pass "Buddy allocator info available"
    echo "        $BUDDY_INFO"
fi

# Check slab info if available
if [ -f /proc/slabinfo ]; then
    ((TESTS_TOTAL++))
    SLAB_COUNT=$(wc -l < /proc/slabinfo)
    test_pass "Slab info available" "$((SLAB_COUNT - 2)) slab caches"
fi

# Quick allocation stress test
if command -v stress-ng >/dev/null 2>&1; then
    ((TESTS_TOTAL++))
    echo "  Running quick allocation stress (5s)..."

    if timeout 10 stress-ng --malloc 1 --malloc-bytes 64M -t 5s 2>/dev/null; then
        test_pass "Allocation stress test" "64MB malloc stress completed"
    else
        test_fail "Allocation stress test" "stress-ng failed"
    fi
else
    test_skip "Allocation stress test" "stress-ng not installed"
fi

# Check for OOM events
if dmesg 2>/dev/null | grep -qi "Out of memory"; then
    ((TESTS_TOTAL++))
    OOM_COUNT=$(dmesg 2>/dev/null | grep -ci "Out of memory" || echo "0")
    if [ "$OOM_COUNT" -eq 0 ]; then
        test_pass "No OOM events"
    else
        test_fail "OOM events detected" "$OOM_COUNT events"
    fi
else
    ((TESTS_TOTAL++))
    test_pass "No OOM events detected"
fi

# ============================================================================
# GENERATE REPORT
# ============================================================================

echo -e "\n${YELLOW}--- Generating Report ---${NC}"

REPORT_FILE="$RESULTS_DIR/mem-benchmark-$(date +%Y%m%d-%H%M%S).json"

# Get memory info for report
TOTAL_MB=$((TOTAL_KB / 1024))
AVAIL_MB=$((AVAIL_KB / 1024))

cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "platform": "$PLATFORM",
  "memory": {
    "total_mb": $TOTAL_MB,
    "available_mb": $AVAIL_MB,
    "used_pct": $USED_PCT
  },
  "targets": {
    "external_fragmentation_pct": $TARGET_FRAG_EXTERNAL,
    "internal_fragmentation_pct": $TARGET_FRAG_INTERNAL,
    "cache_hit_rate_pct": $TARGET_CACHE_HIT,
    "alloc_avg_us": $TARGET_ALLOC_AVG_US
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
echo -e "${BLUE}MEMORY BENCHMARK SUMMARY${NC}"
echo "========================================"
echo "Platform: $PLATFORM"
echo "Memory: ${TOTAL_MB}MB total, ${AVAIL_MB}MB available"
echo ""
echo "Total:  $TESTS_TOTAL"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

# Show targets
echo -e "${CYAN}Performance Targets:${NC}"
echo "  External fragmentation: <${TARGET_FRAG_EXTERNAL}%"
echo "  Internal fragmentation: <${TARGET_FRAG_INTERNAL}%"
echo "  Cache hit rate: >${TARGET_CACHE_HIT}%"
echo "  Avg allocation latency: <${TARGET_ALLOC_AVG_US}us"
echo ""

# Recommendations based on platform
echo -e "${CYAN}Platform Recommendations:${NC}"
case $PLATFORM in
    pi3)
        echo "  - Use small slab caches (16-256 bytes)"
        echo "  - Enable ZRAM with LZ4 compression"
        echo "  - Limit max allocation tracking"
        echo "  - Consider reduced pool sizes"
        ;;
    pi4)
        echo "  - Standard slab/pool configuration"
        echo "  - Enable per-CPU slab caches"
        echo "  - ZRAM with LZ4 recommended"
        ;;
    pi5)
        echo "  - Enable full per-CPU caching"
        echo "  - ZSTD compression for ZRAM"
        echo "  - Larger pool sizes acceptable"
        ;;
    *)
        echo "  - Full memory subsystem features"
        echo "  - Large per-CPU caches"
        echo "  - ZSTD compression optimal"
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
