#!/bin/bash
# home-os Pi 3/4/5 Boot & Performance Benchmark Tests
# Integration tests for performance benchmarking with targets
# Runs in QEMU or on real Raspberry Pi hardware

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
KERNEL_SRC="$PROJECT_ROOT/kernel/src"

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

# Platform detection
PLATFORM="x86-64"
PLATFORM_ID=100
MEMORY_MB=0
CPU_FREQ=0

detect_platform() {
    if [ -f /proc/device-tree/model ]; then
        MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "")
        if [[ "$MODEL" == *"Raspberry Pi 3 Model B+"* ]]; then
            PLATFORM="pi3_plus"
            PLATFORM_ID=31
        elif [[ "$MODEL" == *"Raspberry Pi 3"* ]]; then
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

    # Get memory size
    if [ -f /proc/meminfo ]; then
        MEMORY_MB=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024))
    fi

    # Get CPU frequency
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq ]; then
        CPU_FREQ=$(($(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq) / 1000))
    fi
}

detect_platform

echo -e "${BLUE}home-os Pi Boot & Performance Benchmark Tests${NC}"
echo "================================================"
echo "Platform:  $PLATFORM"
echo "Memory:    ${MEMORY_MB}MB"
echo "CPU Freq:  ${CPU_FREQ}MHz"
echo "Date:      $(date)"
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

verify_source_file "$KERNEL_SRC/perf/pi_benchmark.home" "Pi benchmark module"
verify_source_file "$KERNEL_SRC/perf/boot_opt.home" "Boot optimization module"
verify_source_file "$KERNEL_SRC/perf/sd_benchmark.home" "SD benchmark module"

# ============================================================================
# BENCHMARK MODULE VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Benchmark Module Verification ---${NC}"

BENCH_FILE="$KERNEL_SRC/perf/pi_benchmark.home"

# Verify core functions
verify_function() {
    local func="$1"
    ((TESTS_TOTAL++))

    if grep -q "export fn $func" "$BENCH_FILE" 2>/dev/null; then
        test_pass "Function $func exists"
    else
        test_fail "Function $func missing"
    fi
}

# Initialization
verify_function "pi_benchmark_init"

# Boot benchmarks
verify_function "bench_boot_time"

# Memory benchmarks
verify_function "bench_memory_footprint"
verify_function "bench_memory_bandwidth"

# I/O benchmarks
verify_function "bench_sd_io"

# CPU benchmarks
verify_function "bench_cpu_integer"
verify_function "bench_cpu_multicore"

# Network benchmarks
verify_function "bench_network_throughput"

# Full suite
verify_function "pi_benchmark_run_all"

# Reporting
verify_function "pi_benchmark_print_summary"
verify_function "pi_benchmark_to_json"
verify_function "pi_benchmark_proc_read"

# ============================================================================
# PLATFORM CONSTANTS VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Platform Constants Verification ---${NC}"

verify_const() {
    local const="$1"
    ((TESTS_TOTAL++))

    if grep -q "const $const:" "$BENCH_FILE" 2>/dev/null; then
        test_pass "Constant $const defined"
    else
        test_fail "Constant $const missing"
    fi
}

verify_const "PLATFORM_PI3"
verify_const "PLATFORM_PI3_PLUS"
verify_const "PLATFORM_PI4_1GB"
verify_const "PLATFORM_PI4_4GB"
verify_const "PLATFORM_PI4_8GB"
verify_const "PLATFORM_PI5_4GB"
verify_const "PLATFORM_PI5_8GB"
verify_const "PLATFORM_X86_64"

# ============================================================================
# PERFORMANCE TARGET VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Performance Target Verification ---${NC}"

# Boot targets
verify_const "TARGET_BOOT_PI3_US"
verify_const "TARGET_BOOT_PI4_US"
verify_const "TARGET_BOOT_PI5_US"

# Memory targets
verify_const "TARGET_RAM_HEADLESS_PI3"
verify_const "TARGET_RAM_HEADLESS_PI4"
verify_const "TARGET_RAM_GUI_PI4"
verify_const "TARGET_RAM_GUI_PI5"

# I/O targets
verify_const "TARGET_SD_READ_PI3"
verify_const "TARGET_SD_WRITE_PI3"
verify_const "TARGET_SD_READ_PI4"
verify_const "TARGET_SD_WRITE_PI4"
verify_const "TARGET_SD_READ_PI5"
verify_const "TARGET_SD_WRITE_PI5"

# CPU targets
verify_const "TARGET_CPU_INT_PI3"
verify_const "TARGET_CPU_INT_PI4"
verify_const "TARGET_CPU_INT_PI5"

# Network targets
verify_const "TARGET_NET_ETH_PI3"
verify_const "TARGET_NET_ETH_PI4"

# ============================================================================
# DATA STRUCTURE VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Data Structure Verification ---${NC}"

verify_struct() {
    local struct="$1"
    ((TESTS_TOTAL++))

    if grep -q "struct $struct" "$BENCH_FILE" 2>/dev/null; then
        test_pass "Struct $struct defined"
    else
        test_fail "Struct $struct missing"
    fi
}

verify_struct "PiBenchmarkConfig"
verify_struct "BenchmarkResult"
verify_struct "BenchmarkSuite"

# ============================================================================
# BENCHMARK CATEGORY VERIFICATION
# ============================================================================

echo -e "\n${YELLOW}--- Benchmark Category Verification ---${NC}"

verify_const "BENCH_CAT_BOOT"
verify_const "BENCH_CAT_MEMORY"
verify_const "BENCH_CAT_IO"
verify_const "BENCH_CAT_CPU"
verify_const "BENCH_CAT_NETWORK"

# ============================================================================
# LIVE PERFORMANCE MEASUREMENTS (if on Pi)
# ============================================================================

echo -e "\n${YELLOW}--- Live Performance Tests ---${NC}"

if [[ "$PLATFORM" == pi* ]]; then
    echo "Running on Raspberry Pi, executing live performance tests..."

    # Memory test
    ((TESTS_TOTAL++))
    if [ -f /proc/meminfo ]; then
        FREE_MB=$(($(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024))
        USED_MB=$((MEMORY_MB - FREE_MB))
        test_pass "Memory measurement" "Used: ${USED_MB}MB, Free: ${FREE_MB}MB"
    else
        test_fail "Memory measurement" "/proc/meminfo not found"
    fi

    # CPU frequency test
    ((TESTS_TOTAL++))
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
        CUR_FREQ=$(($(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq) / 1000))
        test_pass "CPU frequency" "Current: ${CUR_FREQ}MHz"
    else
        test_fail "CPU frequency" "cpufreq not available"
    fi

    # Temperature test (Pi specific)
    ((TESTS_TOTAL++))
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        TEMP_MC=$(cat /sys/class/thermal/thermal_zone0/temp)
        TEMP_C=$((TEMP_MC / 1000))
        if [ $TEMP_C -lt 85 ]; then
            test_pass "CPU temperature" "${TEMP_C}°C (under throttle threshold)"
        else
            test_fail "CPU temperature" "${TEMP_C}°C (throttling likely)"
        fi
    else
        test_skip "CPU temperature" "Thermal zone not found"
    fi

    # SD card speed test (simple)
    ((TESTS_TOTAL++))
    if [ -b /dev/mmcblk0 ]; then
        # Read speed test
        SPEED=$(dd if=/dev/mmcblk0 of=/dev/null bs=4M count=100 iflag=direct 2>&1 | grep -oP '\d+\.?\d* [MG]B/s' || echo "N/A")
        if [ "$SPEED" != "N/A" ]; then
            test_pass "SD read speed" "$SPEED"
        else
            test_skip "SD read speed" "Could not measure"
        fi
    else
        test_skip "SD read speed" "SD card not found"
    fi

    # Simple CPU benchmark
    ((TESTS_TOTAL++))
    START_TIME=$(date +%s%N)
    # Count to 10 million
    seq 1 10000000 > /dev/null
    END_TIME=$(date +%s%N)
    DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))
    test_pass "CPU integer benchmark" "10M iterations in ${DURATION_MS}ms"

else
    test_skip "Live Pi tests" "Not running on Raspberry Pi"
fi

# ============================================================================
# BOOT TIME ANALYSIS (if available)
# ============================================================================

echo -e "\n${YELLOW}--- Boot Time Analysis ---${NC}"

if command -v systemd-analyze >/dev/null 2>&1; then
    ((TESTS_TOTAL++))
    BOOT_TIME=$(systemd-analyze 2>/dev/null | grep "Startup finished" | grep -oP '\d+\.\d+s' | head -1 || echo "N/A")
    if [ "$BOOT_TIME" != "N/A" ]; then
        test_pass "Boot time measurement" "$BOOT_TIME"
    else
        test_skip "Boot time measurement" "Could not parse systemd-analyze"
    fi
elif [ -f /proc/uptime ]; then
    ((TESTS_TOTAL++))
    UPTIME=$(awk '{print $1}' /proc/uptime)
    test_pass "System uptime" "${UPTIME}s"
else
    test_skip "Boot time analysis" "No timing data available"
fi

# Check kernel boot messages for timing
if dmesg 2>/dev/null | grep -q "Freeing unused kernel"; then
    ((TESTS_TOTAL++))
    KERNEL_BOOT=$(dmesg 2>/dev/null | grep "Freeing unused kernel" | head -1 | grep -oP '^\[\s*\d+\.\d+\]' | tr -d '[]' | xargs || echo "N/A")
    if [ "$KERNEL_BOOT" != "N/A" ]; then
        test_pass "Kernel boot time" "${KERNEL_BOOT}s to init"
    else
        test_skip "Kernel boot time" "Could not parse dmesg"
    fi
fi

# ============================================================================
# INTEGRATION WITH CI/CD
# ============================================================================

echo -e "\n${YELLOW}--- CI/CD Integration Check ---${NC}"

# Check for JSON output capability
((TESTS_TOTAL++))
if grep -q "pi_benchmark_to_json" "$BENCH_FILE" 2>/dev/null; then
    test_pass "JSON output support"
else
    test_fail "JSON output support missing"
fi

# Check for procfs integration
((TESTS_TOTAL++))
if grep -q "pi_benchmark_proc_read" "$BENCH_FILE" 2>/dev/null; then
    test_pass "Procfs integration"
else
    test_fail "Procfs integration missing"
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "================================================"
echo -e "${BLUE}PI BENCHMARK TEST SUMMARY${NC}"
echo "================================================"
echo "Platform:  $PLATFORM"
echo "Memory:    ${MEMORY_MB}MB"
echo "CPU Freq:  ${CPU_FREQ}MHz"
echo ""
echo "Total:     $TESTS_TOTAL"
echo -e "Passed:    ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:    ${RED}$TESTS_FAILED${NC}"

# Performance targets summary
echo ""
echo -e "${CYAN}Performance Targets:${NC}"
echo "  Boot time:    Pi3: 5.0s, Pi4: 3.0s, Pi5: 2.0s"
echo "  RAM (headless): Pi3: 64MB, Pi4: 96MB"
echo "  SD read:      Pi3: 23MB/s, Pi4: 45MB/s, Pi5: 90MB/s"
echo "  SD write:     Pi3: 10MB/s, Pi4: 25MB/s, Pi5: 45MB/s"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}*** ALL TESTS PASSED ***${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}*** SOME TESTS FAILED ***${NC}"
    exit 1
fi
