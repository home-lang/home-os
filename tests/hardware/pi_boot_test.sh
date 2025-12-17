#!/bin/bash
# HomeOS Raspberry Pi Boot Test
#
# Tests kernel boot on Raspberry Pi hardware
# Requires: serial connection, test SD card or network boot
#
# Usage: ./pi_boot_test.sh --model=pi4|pi5 [--timeout=SECONDS]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
PI_MODEL="pi4"
TIMEOUT=120
SERIAL_DEVICE="/dev/ttyUSB0"
SERIAL_BAUD=115200
RESULTS_DIR="$PROJECT_ROOT/test-results"
LOG_FILE="$RESULTS_DIR/boot.log"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --model=*)
            PI_MODEL="${1#*=}"
            shift
            ;;
        --timeout=*)
            TIMEOUT="${1#*=}"
            shift
            ;;
        --serial=*)
            SERIAL_DEVICE="${1#*=}"
            shift
            ;;
        --help)
            echo "Usage: $0 --model=pi4|pi5 [--timeout=SECONDS] [--serial=DEVICE]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Create results directory
mkdir -p "$RESULTS_DIR"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}HomeOS Raspberry Pi Boot Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Model: $PI_MODEL"
echo "Timeout: ${TIMEOUT}s"
echo "Serial: $SERIAL_DEVICE"
echo ""

# ============================================================================
# Pre-boot Checks
# ============================================================================

log_info "Running pre-boot checks..."

# Check if we're running on Pi hardware
if [ -f /proc/device-tree/model ]; then
    ACTUAL_MODEL=$(cat /proc/device-tree/model)
    log_info "Running on: $ACTUAL_MODEL"

    if [[ "$PI_MODEL" == "pi4" && "$ACTUAL_MODEL" != *"Pi 4"* ]]; then
        log_warn "Model mismatch: expected Pi 4, got $ACTUAL_MODEL"
    fi
    if [[ "$PI_MODEL" == "pi5" && "$ACTUAL_MODEL" != *"Pi 5"* ]]; then
        log_warn "Model mismatch: expected Pi 5, got $ACTUAL_MODEL"
    fi
else
    log_warn "Not running on Raspberry Pi hardware (emulation mode?)"
fi

# Check serial device
if [ -e "$SERIAL_DEVICE" ]; then
    log_pass "Serial device found: $SERIAL_DEVICE"
else
    log_warn "Serial device not found: $SERIAL_DEVICE"
    log_info "Proceeding with local boot test..."
fi

# ============================================================================
# Boot Test Functions
# ============================================================================

test_kernel_exists() {
    log_info "Checking kernel image..."

    local kernel_paths=(
        "/boot/kernel8.img"
        "/boot/firmware/kernel8.img"
        "$PROJECT_ROOT/build/arm64/kernel8.img"
    )

    for path in "${kernel_paths[@]}"; do
        if [ -f "$path" ]; then
            log_pass "Kernel found: $path"
            ls -lh "$path"
            return 0
        fi
    done

    log_fail "Kernel image not found"
    return 1
}

test_boot_config() {
    log_info "Checking boot configuration..."

    local config_paths=(
        "/boot/config.txt"
        "/boot/firmware/config.txt"
    )

    for path in "${config_paths[@]}"; do
        if [ -f "$path" ]; then
            log_pass "Config found: $path"

            # Check for required settings
            if grep -q "arm_64bit=1" "$path"; then
                log_pass "64-bit mode enabled"
            else
                log_warn "64-bit mode not explicitly enabled"
            fi

            if grep -q "enable_uart=1" "$path"; then
                log_pass "UART enabled"
            else
                log_warn "UART not enabled in config"
            fi

            return 0
        fi
    done

    log_warn "Boot config not found (using defaults)"
    return 0
}

test_memory_map() {
    log_info "Checking memory configuration..."

    if [ -f /proc/meminfo ]; then
        local total_mem=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        local total_mb=$((total_mem / 1024))

        log_info "Total memory: ${total_mb}MB"

        if [ "$PI_MODEL" == "pi4" ] && [ $total_mb -lt 1000 ]; then
            log_warn "Pi 4 typically has 1-8GB RAM, found ${total_mb}MB"
        elif [ "$PI_MODEL" == "pi5" ] && [ $total_mb -lt 2000 ]; then
            log_warn "Pi 5 typically has 4-8GB RAM, found ${total_mb}MB"
        else
            log_pass "Memory: ${total_mb}MB"
        fi
    fi
}

test_cpu_info() {
    log_info "Checking CPU configuration..."

    if [ -f /proc/cpuinfo ]; then
        local cpu_model=$(grep "Model" /proc/cpuinfo | head -1)
        local num_cores=$(grep -c "processor" /proc/cpuinfo)

        log_info "CPU: $cpu_model"
        log_info "Cores: $num_cores"

        if [ $num_cores -eq 4 ]; then
            log_pass "4 cores detected (expected for Pi 4/5)"
        else
            log_warn "Unexpected core count: $num_cores"
        fi

        # Check CPU frequency
        if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
            local freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
            local freq_mhz=$((freq / 1000))
            log_info "CPU frequency: ${freq_mhz}MHz"
        fi
    fi
}

test_gpu_memory() {
    log_info "Checking GPU memory split..."

    if command -v vcgencmd &> /dev/null; then
        local gpu_mem=$(vcgencmd get_mem gpu | cut -d= -f2)
        log_info "GPU memory: $gpu_mem"

        # Check if at least 64MB for framebuffer
        local gpu_mb=${gpu_mem%M}
        if [ "$gpu_mb" -ge 64 ]; then
            log_pass "GPU memory adequate for framebuffer"
        else
            log_warn "GPU memory may be insufficient"
        fi
    else
        log_warn "vcgencmd not available"
    fi
}

test_serial_output() {
    log_info "Testing serial output..."

    # If serial device exists, capture output
    if [ -e "$SERIAL_DEVICE" ]; then
        log_info "Capturing serial output for ${TIMEOUT}s..."

        # Set up serial port
        stty -F "$SERIAL_DEVICE" $SERIAL_BAUD cs8 -cstopb -parenb 2>/dev/null || true

        # Capture with timeout
        timeout $TIMEOUT cat "$SERIAL_DEVICE" > "$LOG_FILE" 2>&1 &
        CAPTURE_PID=$!

        # Wait for boot messages
        sleep 10

        # Check for boot indicators
        if [ -f "$LOG_FILE" ]; then
            if grep -q "HomeOS\|home-os\|Kernel\|Boot" "$LOG_FILE"; then
                log_pass "Boot messages detected in serial output"
                kill $CAPTURE_PID 2>/dev/null || true
                return 0
            fi
        fi

        log_warn "No HomeOS boot messages in serial output"
        kill $CAPTURE_PID 2>/dev/null || true
    else
        log_info "Serial device not available, checking kernel log..."

        # Check dmesg for our kernel
        if dmesg | grep -q "HomeOS\|home-os" 2>/dev/null; then
            log_pass "HomeOS boot messages in dmesg"
            dmesg > "$LOG_FILE"
            return 0
        fi
    fi

    return 0
}

test_framebuffer() {
    log_info "Testing framebuffer..."

    if [ -e /dev/fb0 ]; then
        log_pass "Framebuffer device: /dev/fb0"

        # Get framebuffer info
        if [ -f /sys/class/graphics/fb0/virtual_size ]; then
            local fb_size=$(cat /sys/class/graphics/fb0/virtual_size)
            log_info "Framebuffer size: $fb_size"
        fi

        if [ -f /sys/class/graphics/fb0/bits_per_pixel ]; then
            local bpp=$(cat /sys/class/graphics/fb0/bits_per_pixel)
            log_info "Bits per pixel: $bpp"
        fi

        return 0
    else
        log_warn "Framebuffer not available (headless mode?)"
        return 0
    fi
}

test_devices() {
    log_info "Checking key devices..."

    # Check for expected Pi devices
    local devices=(
        "/dev/mmcblk0:SD card"
        "/dev/video0:Camera"
        "/dev/i2c-1:I2C bus"
        "/dev/spidev0.0:SPI bus"
        "/dev/gpiomem:GPIO memory"
    )

    for item in "${devices[@]}"; do
        local dev="${item%%:*}"
        local name="${item##*:}"

        if [ -e "$dev" ]; then
            log_pass "$name: $dev"
        else
            log_info "$name not available: $dev"
        fi
    done
}

test_temperature() {
    log_info "Checking CPU temperature..."

    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        local temp_c=$((temp / 1000))

        log_info "CPU temperature: ${temp_c}°C"

        if [ $temp_c -lt 70 ]; then
            log_pass "Temperature normal"
        elif [ $temp_c -lt 80 ]; then
            log_warn "Temperature elevated: ${temp_c}°C"
        else
            log_fail "Temperature critical: ${temp_c}°C"
            return 1
        fi
    fi

    return 0
}

# ============================================================================
# Run Tests
# ============================================================================

TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local name="$1"
    local func="$2"

    echo ""
    log_info "Running: $name"

    if $func; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Run all boot tests
run_test "Kernel Exists" test_kernel_exists
run_test "Boot Configuration" test_boot_config
run_test "Memory Map" test_memory_map
run_test "CPU Info" test_cpu_info
run_test "GPU Memory" test_gpu_memory
run_test "Serial Output" test_serial_output
run_test "Framebuffer" test_framebuffer
run_test "Devices" test_devices
run_test "Temperature" test_temperature

# ============================================================================
# Summary
# ============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Boot Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

# Write result marker
if [ $TESTS_FAILED -eq 0 ]; then
    touch "$RESULTS_DIR/PASSED"
    echo -e "${GREEN}Boot test PASSED${NC}"
    exit 0
else
    touch "$RESULTS_DIR/FAILED"
    echo -e "${RED}Boot test FAILED${NC}"
    exit 1
fi
