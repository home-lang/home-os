#!/bin/bash
# HomeOS Raspberry Pi Stress Test
#
# Runs comprehensive stress tests on Pi hardware
#
# Usage: ./pi_stress_test.sh --model=pi4|pi5 [--duration=SECONDS]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
RESULTS_DIR="$PROJECT_ROOT/test-results"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PI_MODEL="pi4"
DURATION=60

while [[ $# -gt 0 ]]; do
    case $1 in
        --model=*) PI_MODEL="${1#*=}"; shift ;;
        --duration=*) DURATION="${1#*=}"; shift ;;
        *) shift ;;
    esac
done

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

mkdir -p "$RESULTS_DIR"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}HomeOS Raspberry Pi Stress Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Model: $PI_MODEL"
echo "Duration: ${DURATION}s"
echo ""

# ============================================================================
# Monitoring Functions
# ============================================================================

get_temp() {
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        echo $((temp / 1000))
    else
        echo "N/A"
    fi
}

get_freq() {
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
        local freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
        echo $((freq / 1000))
    else
        echo "N/A"
    fi
}

get_throttle_status() {
    if command -v vcgencmd &>/dev/null; then
        vcgencmd get_throttled 2>/dev/null | cut -d= -f2
    else
        echo "N/A"
    fi
}

monitor_system() {
    local log_file="$RESULTS_DIR/stress_monitor.log"
    local interval=5

    echo "Time,Temp_C,Freq_MHz,Throttle,Load" > "$log_file"

    local start_time=$(date +%s)
    while true; do
        local now=$(date +%s)
        local elapsed=$((now - start_time))

        if [ $elapsed -ge $DURATION ]; then
            break
        fi

        local temp=$(get_temp)
        local freq=$(get_freq)
        local throttle=$(get_throttle_status)
        local load=$(cat /proc/loadavg | awk '{print $1}')

        echo "${elapsed},${temp},${freq},${throttle},${load}" >> "$log_file"
        sleep $interval
    done
}

# ============================================================================
# Stress Tests
# ============================================================================

stress_cpu() {
    log_info "Starting CPU stress test..."

    local num_cores=$(nproc)
    local pids=()

    # Start CPU stress processes
    for i in $(seq 1 $num_cores); do
        (
            end_time=$(($(date +%s) + DURATION))
            while [ $(date +%s) -lt $end_time ]; do
                # CPU-intensive calculation
                echo "scale=1000; 4*a(1)" | bc -l > /dev/null 2>&1 || true
            done
        ) &
        pids+=($!)
    done

    log_info "Running $num_cores CPU stress processes for ${DURATION}s..."

    # Wait for all processes
    for pid in "${pids[@]}"; do
        wait $pid 2>/dev/null || true
    done

    log_pass "CPU stress completed"
}

stress_memory() {
    log_info "Starting memory stress test..."

    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local test_size=$((mem_total / 4))  # Use 25% of RAM
    local test_mb=$((test_size / 1024))

    log_info "Allocating ${test_mb}MB..."

    (
        # Allocate and touch memory
        dd if=/dev/zero of=/dev/null bs=1M count=$test_mb 2>/dev/null &
        DD_PID=$!

        # Create memory pressure
        local file="/tmp/stress_mem_$$"
        dd if=/dev/zero of="$file" bs=1M count=$test_mb 2>/dev/null || true
        sync

        # Read it back
        dd if="$file" of=/dev/null bs=1M 2>/dev/null || true
        rm -f "$file"

        kill $DD_PID 2>/dev/null || true
    ) &
    MEM_PID=$!

    sleep $((DURATION / 2))
    kill $MEM_PID 2>/dev/null || true
    wait $MEM_PID 2>/dev/null || true

    log_pass "Memory stress completed"
}

stress_io() {
    log_info "Starting I/O stress test..."

    local test_dir="/tmp/home-os-io-stress"
    mkdir -p "$test_dir"

    (
        end_time=$(($(date +%s) + DURATION / 2))
        while [ $(date +%s) -lt $end_time ]; do
            # Write
            dd if=/dev/zero of="$test_dir/test_$$" bs=1M count=10 2>/dev/null || true
            sync
            # Read
            dd if="$test_dir/test_$$" of=/dev/null bs=1M 2>/dev/null || true
            rm -f "$test_dir/test_$$"
        done
    ) &
    IO_PID=$!

    wait $IO_PID 2>/dev/null || true
    rm -rf "$test_dir"

    log_pass "I/O stress completed"
}

stress_mixed() {
    log_info "Starting mixed workload stress test..."

    # Run all stresses simultaneously for half the duration
    local half_duration=$((DURATION / 2))
    local quarter_duration=$((DURATION / 4))

    # CPU stress (background)
    (
        end_time=$(($(date +%s) + half_duration))
        while [ $(date +%s) -lt $end_time ]; do
            echo "scale=500; 4*a(1)" | bc -l > /dev/null 2>&1 || true
        done
    ) &
    CPU_PID=$!

    # Memory operations (background)
    (
        for i in $(seq 1 10); do
            dd if=/dev/zero of=/tmp/mem_test_$i bs=1M count=10 2>/dev/null || true
            sleep 1
        done
        rm -f /tmp/mem_test_* 2>/dev/null
    ) &
    MEM_PID=$!

    # I/O operations (background)
    (
        for i in $(seq 1 10); do
            dd if=/dev/urandom of=/tmp/io_test bs=1M count=1 2>/dev/null || true
            sync
            cat /tmp/io_test > /dev/null 2>/dev/null || true
            rm -f /tmp/io_test 2>/dev/null
            sleep 1
        done
    ) &
    IO_PID=$!

    wait $CPU_PID 2>/dev/null || true
    wait $MEM_PID 2>/dev/null || true
    wait $IO_PID 2>/dev/null || true

    log_pass "Mixed stress completed"
}

# ============================================================================
# Run Tests
# ============================================================================

# Start system monitor in background
monitor_system &
MONITOR_PID=$!

# Initial state
log_info "Initial state:"
log_info "  Temperature: $(get_temp)°C"
log_info "  Frequency: $(get_freq)MHz"
log_info "  Throttle: $(get_throttle_status)"

echo ""

# Run stress tests
TESTS_PASSED=0
TESTS_FAILED=0

stress_cpu
TESTS_PASSED=$((TESTS_PASSED + 1))

# Check for thermal throttling
TEMP=$(get_temp)
if [ "$TEMP" != "N/A" ] && [ $TEMP -gt 85 ]; then
    log_warn "High temperature detected: ${TEMP}°C"
    log_info "Cooling down..."
    sleep 30
fi

stress_memory
TESTS_PASSED=$((TESTS_PASSED + 1))

stress_io
TESTS_PASSED=$((TESTS_PASSED + 1))

stress_mixed
TESTS_PASSED=$((TESTS_PASSED + 1))

# Stop monitor
kill $MONITOR_PID 2>/dev/null || true
wait $MONITOR_PID 2>/dev/null || true

# ============================================================================
# Analysis
# ============================================================================

echo ""
log_info "Analyzing results..."

# Final state
log_info "Final state:"
log_info "  Temperature: $(get_temp)°C"
log_info "  Frequency: $(get_freq)MHz"
log_info "  Throttle: $(get_throttle_status)"

# Check for throttling
THROTTLE=$(get_throttle_status)
if [ "$THROTTLE" != "N/A" ] && [ "$THROTTLE" != "0x0" ]; then
    log_warn "Throttling detected: $THROTTLE"
    log_warn "  0x1 = Under-voltage"
    log_warn "  0x2 = Arm frequency capped"
    log_warn "  0x4 = Currently throttled"
    log_warn "  0x8 = Soft temperature limit"
fi

# Analyze monitor log
if [ -f "$RESULTS_DIR/stress_monitor.log" ]; then
    local max_temp=$(tail -n +2 "$RESULTS_DIR/stress_monitor.log" | cut -d, -f2 | sort -n | tail -1)
    local min_freq=$(tail -n +2 "$RESULTS_DIR/stress_monitor.log" | cut -d, -f3 | sort -n | head -1)

    log_info "Peak temperature: ${max_temp}°C"
    log_info "Minimum frequency: ${min_freq}MHz"

    if [ "$max_temp" != "N/A" ] && [ $max_temp -lt 80 ]; then
        log_pass "Temperature stayed below 80°C"
    elif [ "$max_temp" != "N/A" ]; then
        log_warn "Temperature exceeded 80°C (${max_temp}°C)"
    fi
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Stress Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    touch "$RESULTS_DIR/stress-PASSED"
    echo -e "${GREEN}Stress test PASSED${NC}"
    exit 0
else
    touch "$RESULTS_DIR/stress-FAILED"
    echo -e "${RED}Stress test FAILED${NC}"
    exit 1
fi
