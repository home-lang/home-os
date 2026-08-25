#!/bin/bash
# HomeOS Raspberry Pi GPIO Test
#
# Tests GPIO functionality on Raspberry Pi hardware
# Requires: GPIO access, optionally test LEDs/buttons connected
#
# Usage: ./pi_gpio_test.sh --model=pi4|pi5 [--loopback]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
RESULTS_DIR="$PROJECT_ROOT/test-results"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
PI_MODEL="pi4"
LOOPBACK_MODE=0
TEST_PIN_OUT=17  # BCM GPIO17 (pin 11)
TEST_PIN_IN=27   # BCM GPIO27 (pin 13)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --model=*)
            PI_MODEL="${1#*=}"
            shift
            ;;
        --loopback)
            LOOPBACK_MODE=1
            shift
            ;;
        --help)
            echo "Usage: $0 --model=pi4|pi5 [--loopback]"
            echo ""
            echo "Options:"
            echo "  --loopback  Enable loopback test (requires GPIO17-GPIO27 jumper)"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

mkdir -p "$RESULTS_DIR"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}HomeOS Raspberry Pi GPIO Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Model: $PI_MODEL"
echo "Loopback mode: $LOOPBACK_MODE"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# GPIO Test Functions
# ============================================================================

test_gpio_sysfs() {
    log_info "Testing GPIO sysfs interface..."

    if [ -d /sys/class/gpio ]; then
        log_pass "GPIO sysfs available"

        # List exported GPIOs
        local exported=$(ls /sys/class/gpio/ | grep -c gpio[0-9] || echo 0)
        log_info "Currently exported GPIOs: $exported"

        return 0
    else
        log_fail "GPIO sysfs not available"
        return 1
    fi
}

test_gpio_mem() {
    log_info "Testing GPIO memory interface..."

    if [ -e /dev/gpiomem ]; then
        log_pass "GPIO memory device available"

        # Check permissions
        local perms=$(stat -c %a /dev/gpiomem)
        log_info "Permissions: $perms"

        return 0
    elif [ -e /dev/mem ]; then
        log_warn "/dev/gpiomem not available, /dev/mem exists (needs root)"
        return 0
    else
        log_fail "No GPIO memory access"
        return 1
    fi
}

test_gpio_chip() {
    log_info "Testing GPIO character device (libgpiod)..."

    local chips=(/dev/gpiochip*)
    if [ -e "${chips[0]}" ]; then
        log_pass "GPIO chip devices found: ${#chips[@]}"

        for chip in "${chips[@]}"; do
            if command -v gpioinfo &> /dev/null; then
                local lines=$(gpioinfo "$chip" 2>/dev/null | wc -l)
                log_info "$chip: $lines GPIO lines"
            else
                log_info "Found: $chip"
            fi
        done

        return 0
    else
        log_warn "No GPIO chip devices (gpiochip*)"
        return 0
    fi
}

test_gpio_export() {
    log_info "Testing GPIO export/unexport..."

    local gpio=$TEST_PIN_OUT

    # Export GPIO
    if [ ! -d "/sys/class/gpio/gpio$gpio" ]; then
        echo $gpio > /sys/class/gpio/export 2>/dev/null || {
            log_warn "Cannot export GPIO$gpio (may need root)"
            return 0
        }
    fi

    if [ -d "/sys/class/gpio/gpio$gpio" ]; then
        log_pass "GPIO$gpio exported"

        # Set direction
        echo "out" > "/sys/class/gpio/gpio$gpio/direction" 2>/dev/null || true

        local dir=$(cat "/sys/class/gpio/gpio$gpio/direction" 2>/dev/null)
        log_info "GPIO$gpio direction: $dir"

        # Unexport
        echo $gpio > /sys/class/gpio/unexport 2>/dev/null || true
        log_pass "GPIO$gpio unexported"

        return 0
    else
        log_fail "GPIO export failed"
        return 1
    fi
}

test_gpio_output() {
    log_info "Testing GPIO output..."

    local gpio=$TEST_PIN_OUT

    # Export and configure
    [ ! -d "/sys/class/gpio/gpio$gpio" ] && echo $gpio > /sys/class/gpio/export 2>/dev/null
    echo "out" > "/sys/class/gpio/gpio$gpio/direction" 2>/dev/null || {
        log_warn "Cannot configure GPIO$gpio"
        return 0
    }

    # Toggle output
    echo 1 > "/sys/class/gpio/gpio$gpio/value" 2>/dev/null
    local val1=$(cat "/sys/class/gpio/gpio$gpio/value" 2>/dev/null)

    echo 0 > "/sys/class/gpio/gpio$gpio/value" 2>/dev/null
    local val2=$(cat "/sys/class/gpio/gpio$gpio/value" 2>/dev/null)

    # Cleanup
    echo $gpio > /sys/class/gpio/unexport 2>/dev/null || true

    if [ "$val1" == "1" ] && [ "$val2" == "0" ]; then
        log_pass "GPIO output toggle works"
        return 0
    else
        log_fail "GPIO output not responding correctly"
        return 1
    fi
}

test_gpio_input() {
    log_info "Testing GPIO input..."

    local gpio=$TEST_PIN_IN

    # Export and configure
    [ ! -d "/sys/class/gpio/gpio$gpio" ] && echo $gpio > /sys/class/gpio/export 2>/dev/null
    echo "in" > "/sys/class/gpio/gpio$gpio/direction" 2>/dev/null || {
        log_warn "Cannot configure GPIO$gpio"
        return 0
    }

    # Read input
    local val=$(cat "/sys/class/gpio/gpio$gpio/value" 2>/dev/null)
    log_info "GPIO$gpio input value: $val"

    # Cleanup
    echo $gpio > /sys/class/gpio/unexport 2>/dev/null || true

    if [ "$val" == "0" ] || [ "$val" == "1" ]; then
        log_pass "GPIO input readable"
        return 0
    else
        log_fail "GPIO input not readable"
        return 1
    fi
}

test_gpio_loopback() {
    if [ $LOOPBACK_MODE -eq 0 ]; then
        log_info "Skipping loopback test (use --loopback to enable)"
        return 0
    fi

    log_info "Testing GPIO loopback (GPIO$TEST_PIN_OUT -> GPIO$TEST_PIN_IN)..."

    # Export both pins
    [ ! -d "/sys/class/gpio/gpio$TEST_PIN_OUT" ] && echo $TEST_PIN_OUT > /sys/class/gpio/export 2>/dev/null
    [ ! -d "/sys/class/gpio/gpio$TEST_PIN_IN" ] && echo $TEST_PIN_IN > /sys/class/gpio/export 2>/dev/null

    # Configure
    echo "out" > "/sys/class/gpio/gpio$TEST_PIN_OUT/direction" 2>/dev/null
    echo "in" > "/sys/class/gpio/gpio$TEST_PIN_IN/direction" 2>/dev/null

    local errors=0

    # Test high
    echo 1 > "/sys/class/gpio/gpio$TEST_PIN_OUT/value" 2>/dev/null
    sleep 0.01
    local val=$(cat "/sys/class/gpio/gpio$TEST_PIN_IN/value" 2>/dev/null)
    if [ "$val" != "1" ]; then
        log_fail "Loopback test: expected 1, got $val"
        errors=$((errors + 1))
    fi

    # Test low
    echo 0 > "/sys/class/gpio/gpio$TEST_PIN_OUT/value" 2>/dev/null
    sleep 0.01
    val=$(cat "/sys/class/gpio/gpio$TEST_PIN_IN/value" 2>/dev/null)
    if [ "$val" != "0" ]; then
        log_fail "Loopback test: expected 0, got $val"
        errors=$((errors + 1))
    fi

    # Cleanup
    echo $TEST_PIN_OUT > /sys/class/gpio/unexport 2>/dev/null || true
    echo $TEST_PIN_IN > /sys/class/gpio/unexport 2>/dev/null || true

    if [ $errors -eq 0 ]; then
        log_pass "GPIO loopback test passed"
        return 0
    else
        log_fail "GPIO loopback test failed"
        return 1
    fi
}

test_gpio_pinctrl() {
    log_info "Checking GPIO pin controller..."

    if [ -d /sys/kernel/debug/pinctrl ]; then
        local controllers=$(ls /sys/kernel/debug/pinctrl/ 2>/dev/null | head -5)
        if [ -n "$controllers" ]; then
            log_pass "Pin controllers found"
            for ctrl in $controllers; do
                log_info "  $ctrl"
            done
            return 0
        fi
    fi

    log_warn "Pin controller info not available (needs debugfs)"
    return 0
}

test_i2c_bus() {
    log_info "Testing I2C bus..."

    if [ -e /dev/i2c-1 ]; then
        log_pass "I2C bus 1 available"

        if command -v i2cdetect &> /dev/null; then
            log_info "Scanning I2C bus (may take a moment)..."
            i2cdetect -y 1 2>/dev/null | head -5 || true
        fi
        return 0
    else
        log_warn "I2C bus not available"
        return 0
    fi
}

test_spi_bus() {
    log_info "Testing SPI bus..."

    if [ -e /dev/spidev0.0 ]; then
        log_pass "SPI bus available: /dev/spidev0.0"
        return 0
    else
        log_warn "SPI not available (may need to enable in config.txt)"
        return 0
    fi
}

# ============================================================================
# Run Tests
# ============================================================================

run_test() {
    local name="$1"
    local func="$2"

    echo ""
    if $func; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

run_test "GPIO Sysfs" test_gpio_sysfs
run_test "GPIO Memory" test_gpio_mem
run_test "GPIO Chip" test_gpio_chip
run_test "GPIO Export" test_gpio_export
run_test "GPIO Output" test_gpio_output
run_test "GPIO Input" test_gpio_input
run_test "GPIO Loopback" test_gpio_loopback
run_test "GPIO Pinctrl" test_gpio_pinctrl
run_test "I2C Bus" test_i2c_bus
run_test "SPI Bus" test_spi_bus

# ============================================================================
# Summary
# ============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GPIO Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    touch "$RESULTS_DIR/gpio-PASSED"
    echo -e "${GREEN}GPIO test PASSED${NC}"
    exit 0
else
    touch "$RESULTS_DIR/gpio-FAILED"
    echo -e "${RED}GPIO test FAILED${NC}"
    exit 1
fi
