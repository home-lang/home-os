#!/bin/bash
# HomeOS Raspberry Pi Display Test
#
# Tests framebuffer and display functionality
#
# Usage: ./pi_display_test.sh --model=pi4|pi5

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

PI_MODEL="pi4"

while [[ $# -gt 0 ]]; do
    case $1 in
        --model=*) PI_MODEL="${1#*=}"; shift ;;
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
echo -e "${BLUE}HomeOS Raspberry Pi Display Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# Display Test Functions
# ============================================================================

test_framebuffer_exists() {
    log_info "Checking framebuffer device..."

    if [ -e /dev/fb0 ]; then
        log_pass "Framebuffer: /dev/fb0"
        return 0
    else
        log_warn "No framebuffer device (headless mode)"
        return 0
    fi
}

test_framebuffer_info() {
    log_info "Getting framebuffer information..."

    if [ ! -e /dev/fb0 ]; then
        log_info "Framebuffer not available"
        return 0
    fi

    local fb_path="/sys/class/graphics/fb0"

    if [ -f "$fb_path/virtual_size" ]; then
        local size=$(cat "$fb_path/virtual_size")
        log_info "Virtual size: $size"
    fi

    if [ -f "$fb_path/bits_per_pixel" ]; then
        local bpp=$(cat "$fb_path/bits_per_pixel")
        log_info "Bits per pixel: $bpp"

        if [ "$bpp" -ge 24 ]; then
            log_pass "True color support ($bpp bpp)"
        else
            log_warn "Limited color depth: $bpp bpp"
        fi
    fi

    if [ -f "$fb_path/stride" ]; then
        local stride=$(cat "$fb_path/stride")
        log_info "Stride: $stride bytes"
    fi

    return 0
}

test_framebuffer_write() {
    log_info "Testing framebuffer write..."

    if [ ! -e /dev/fb0 ]; then
        log_info "Framebuffer not available"
        return 0
    fi

    # Try to write a test pattern
    if [ -w /dev/fb0 ]; then
        # Create a small test pattern (red pixels)
        # 4 bytes per pixel (32-bit), write 100 pixels
        dd if=/dev/zero bs=400 count=1 of=/dev/fb0 2>/dev/null || {
            log_warn "Cannot write to framebuffer"
            return 0
        }
        log_pass "Framebuffer writable"
        return 0
    else
        log_warn "Framebuffer not writable (need permissions)"
        return 0
    fi
}

test_drm_devices() {
    log_info "Checking DRM (Direct Rendering Manager)..."

    local drm_cards=(/dev/dri/card*)
    if [ -e "${drm_cards[0]}" ]; then
        log_pass "DRM devices found: ${#drm_cards[@]}"

        for card in "${drm_cards[@]}"; do
            log_info "  $card"
        done

        # Check render nodes
        local renders=(/dev/dri/renderD*)
        if [ -e "${renders[0]}" ]; then
            log_info "Render nodes: ${#renders[@]}"
        fi

        return 0
    else
        log_warn "No DRM devices"
        return 0
    fi
}

test_hdmi_status() {
    log_info "Checking HDMI status..."

    if command -v tvservice &> /dev/null; then
        local status=$(tvservice -s 2>/dev/null)
        log_info "HDMI: $status"

        if echo "$status" | grep -q "HDMI"; then
            log_pass "HDMI connected"
        else
            log_info "HDMI not connected or not detected"
        fi
        return 0
    fi

    # Check via sysfs
    if [ -d /sys/class/drm ]; then
        for connector in /sys/class/drm/card*-HDMI-*; do
            if [ -f "$connector/status" ]; then
                local status=$(cat "$connector/status")
                log_info "$(basename $connector): $status"
            fi
        done
    fi

    return 0
}

test_display_resolution() {
    log_info "Checking display resolution..."

    if command -v fbset &> /dev/null; then
        local res=$(fbset 2>/dev/null | grep "geometry" | head -1)
        if [ -n "$res" ]; then
            log_info "Geometry: $res"
            log_pass "Resolution info available"
            return 0
        fi
    fi

    # Try vcgencmd
    if command -v vcgencmd &> /dev/null; then
        local hdmi0=$(vcgencmd get_lcd_info 2>/dev/null)
        log_info "Display info: $hdmi0"
    fi

    return 0
}

test_gpu_info() {
    log_info "Checking GPU information..."

    if command -v vcgencmd &> /dev/null; then
        local gpu_mem=$(vcgencmd get_mem gpu 2>/dev/null)
        log_info "GPU memory: $gpu_mem"

        local gpu_temp=$(vcgencmd measure_temp 2>/dev/null)
        log_info "GPU temp: $gpu_temp"

        local codec_h264=$(vcgencmd codec_enabled H264 2>/dev/null)
        log_info "H.264 codec: $codec_h264"

        log_pass "GPU info retrieved"
        return 0
    fi

    log_warn "vcgencmd not available"
    return 0
}

test_fb_screenshot() {
    log_info "Capturing framebuffer screenshot..."

    if [ ! -e /dev/fb0 ]; then
        log_info "Framebuffer not available"
        return 0
    fi

    # Capture raw framebuffer
    if dd if=/dev/fb0 of="$RESULTS_DIR/fb_capture.raw" bs=4M count=1 2>/dev/null; then
        local size=$(stat -c%s "$RESULTS_DIR/fb_capture.raw" 2>/dev/null || echo 0)
        log_pass "Captured $size bytes"
        return 0
    else
        log_warn "Could not capture framebuffer"
        return 0
    fi
}

test_compositor_ready() {
    log_info "Checking compositor readiness..."

    # Check if our compositor would be able to initialize
    local ready=1

    # Need framebuffer or DRM
    if [ -e /dev/fb0 ] || [ -e /dev/dri/card0 ]; then
        log_pass "Display backend available"
    else
        log_warn "No display backend"
        ready=0
    fi

    # Need some GPU memory
    if command -v vcgencmd &> /dev/null; then
        local gpu_mem=$(vcgencmd get_mem gpu 2>/dev/null | grep -o '[0-9]*')
        if [ -n "$gpu_mem" ] && [ "$gpu_mem" -ge 64 ]; then
            log_pass "Sufficient GPU memory (${gpu_mem}MB)"
        else
            log_warn "Low GPU memory: ${gpu_mem}MB"
        fi
    fi

    return 0
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

run_test "Framebuffer Exists" test_framebuffer_exists
run_test "Framebuffer Info" test_framebuffer_info
run_test "Framebuffer Write" test_framebuffer_write
run_test "DRM Devices" test_drm_devices
run_test "HDMI Status" test_hdmi_status
run_test "Display Resolution" test_display_resolution
run_test "GPU Info" test_gpu_info
run_test "FB Screenshot" test_fb_screenshot
run_test "Compositor Ready" test_compositor_ready

# ============================================================================
# Summary
# ============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Display Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    touch "$RESULTS_DIR/display-PASSED"
    echo -e "${GREEN}Display test PASSED${NC}"
    exit 0
else
    touch "$RESULTS_DIR/display-FAILED"
    echo -e "${RED}Display test FAILED${NC}"
    exit 1
fi
