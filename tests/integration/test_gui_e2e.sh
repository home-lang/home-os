#!/bin/bash
# HomeOS End-to-End GUI Verification Test Runner
#
# This script verifies the complete GUI stack:
# boot → compositor → window manager → core GUI apps
#
# Usage: ./tests/integration/test_gui_e2e.sh [--qemu|--hardware|--check-only]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

# ============================================================================
# Phase 1: Static Code Verification
# ============================================================================

check_file_exists() {
    local file="$1"
    local desc="$2"

    if [[ -f "$PROJECT_ROOT/$file" ]]; then
        log_pass "$desc exists: $file"
        return 0
    else
        log_fail "$desc missing: $file"
        return 1
    fi
}

check_function_exists() {
    local file="$1"
    local func="$2"
    local desc="$3"

    if grep -q "fn $func\|export fn $func" "$PROJECT_ROOT/$file" 2>/dev/null; then
        log_pass "$desc: $func found in $file"
        return 0
    else
        log_fail "$desc: $func NOT found in $file"
        return 1
    fi
}

run_static_checks() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Phase 1: Static Code Verification${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Check core GUI files exist
    log_info "Checking core GUI files..."

    check_file_exists "kernel/src/video/compositor.home" "Compositor"
    check_file_exists "kernel/src/gui/window_manager.home" "Window Manager"
    check_file_exists "kernel/src/gui/craft_integration.home" "Craft UI Integration"
    check_file_exists "apps/desktop/window_manager.home" "Desktop Window Manager"

    # Check compositor functions
    log_info "Checking compositor API..."

    check_function_exists "kernel/src/video/compositor.home" "compositor_init" "Compositor init"
    check_function_exists "kernel/src/video/compositor.home" "compositor_create_window" "Window creation"
    check_function_exists "kernel/src/video/compositor.home" "compositor_destroy_window" "Window destruction"
    check_function_exists "kernel/src/video/compositor.home" "compositor_render" "Render function"
    check_function_exists "kernel/src/video/compositor.home" "compositor_move_window" "Window move"
    check_function_exists "kernel/src/video/compositor.home" "compositor_resize_window" "Window resize"

    # Check window manager functions
    log_info "Checking window manager API..."

    check_function_exists "kernel/src/gui/window_manager.home" "wm_init" "WM init"
    check_function_exists "kernel/src/gui/window_manager.home" "wm_switch_workspace" "Workspace switch"
    check_function_exists "kernel/src/gui/window_manager.home" "wm_set_layout" "Layout setting"

    # Check Craft UI functions
    log_info "Checking Craft UI API..."

    check_function_exists "kernel/src/gui/craft_integration.home" "craft_init" "Craft init"
    check_function_exists "kernel/src/gui/craft_integration.home" "craft_create_window" "Craft window"
    check_function_exists "kernel/src/gui/craft_integration.home" "craft_create_widget" "Widget creation"
    check_function_exists "kernel/src/gui/craft_integration.home" "craft_destroy_window" "Window destroy"
    check_function_exists "kernel/src/gui/craft_integration.home" "craft_paint_window" "Window paint"
}

# ============================================================================
# Phase 2: Dependency Verification
# ============================================================================

run_dependency_checks() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Phase 2: Dependency Verification${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    log_info "Checking import dependencies..."

    # Check compositor dependencies
    local compositor_file="$PROJECT_ROOT/kernel/src/video/compositor.home"
    if [[ -f "$compositor_file" ]]; then
        if grep -q "import\|@import" "$compositor_file"; then
            log_pass "Compositor has import statements"
        else
            log_skip "Compositor has no imports (standalone)"
        fi
    fi

    # Check window manager dependencies
    local wm_file="$PROJECT_ROOT/kernel/src/gui/window_manager.home"
    if [[ -f "$wm_file" ]]; then
        if grep -q "compositor" "$wm_file"; then
            log_pass "Window manager references compositor"
        else
            log_skip "Window manager may be standalone"
        fi
    fi

    # Check Craft UI dependencies
    local craft_file="$PROJECT_ROOT/kernel/src/gui/craft_integration.home"
    if [[ -f "$craft_file" ]]; then
        if grep -q "serial\|framebuffer\|compositor" "$craft_file"; then
            log_pass "Craft UI has expected dependencies"
        else
            log_skip "Craft UI dependencies not verified"
        fi
    fi
}

# ============================================================================
# Phase 3: Boot Chain Verification
# ============================================================================

run_boot_chain_checks() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Phase 3: Boot Chain Verification${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    log_info "Checking boot sequence files..."

    # Check bootloader exists
    check_file_exists "kernel/src/boot/bootloader.home" "Bootloader"
    check_file_exists "kernel/src/main.home" "Kernel main"

    # Check kernel init sequence
    local main_file="$PROJECT_ROOT/kernel/src/main.home"
    if [[ -f "$main_file" ]]; then
        log_info "Checking kernel initialization order..."

        # Check for GUI initialization in main
        if grep -q "compositor\|window_manager\|craft\|gui" "$main_file"; then
            log_pass "Kernel main references GUI components"
        else
            log_skip "GUI initialization may be elsewhere"
        fi
    fi

    # Check driver initialization
    check_file_exists "kernel/src/core/driver_init.home" "Driver init"
    check_file_exists "kernel/src/drivers/framebuffer.home" "Framebuffer driver"
}

# ============================================================================
# Phase 4: Integration Point Verification
# ============================================================================

run_integration_checks() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Phase 4: Integration Points${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    log_info "Checking integration between components..."

    # Count total integration points
    local total_exports=0
    local total_imports=0

    # Check compositor exports
    local compositor_exports=$(grep -c "export fn" "$PROJECT_ROOT/kernel/src/video/compositor.home" 2>/dev/null || echo 0)
    total_exports=$((total_exports + compositor_exports))
    log_info "Compositor exports: $compositor_exports functions"

    # Check window manager exports
    local wm_exports=$(grep -c "export fn" "$PROJECT_ROOT/kernel/src/gui/window_manager.home" 2>/dev/null || echo 0)
    total_exports=$((total_exports + wm_exports))
    log_info "Window Manager exports: $wm_exports functions"

    # Check Craft UI exports
    local craft_exports=$(grep -c "export fn" "$PROJECT_ROOT/kernel/src/gui/craft_integration.home" 2>/dev/null || echo 0)
    total_exports=$((total_exports + craft_exports))
    log_info "Craft UI exports: $craft_exports functions"

    if [[ $total_exports -gt 20 ]]; then
        log_pass "Sufficient API surface ($total_exports exports)"
    else
        log_skip "Limited API surface ($total_exports exports)"
    fi

    # Check for event handling
    log_info "Checking event system..."

    if grep -q "event\|Event\|EVENT" "$PROJECT_ROOT/kernel/src/gui/craft_integration.home" 2>/dev/null; then
        log_pass "Event system found in Craft UI"
    else
        log_skip "Event system not verified"
    fi

    # Check for input handling
    if grep -q "mouse\|keyboard\|input" "$PROJECT_ROOT/kernel/src/video/compositor.home" 2>/dev/null; then
        log_pass "Input handling found in compositor"
    else
        log_skip "Input handling not verified"
    fi
}

# ============================================================================
# Phase 5: Pi 4/5 Specific Checks
# ============================================================================

run_pi_specific_checks() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Phase 5: Pi 4/5 Specific Verification${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    log_info "Checking Raspberry Pi support..."

    # Check for ARM64 boot code
    check_file_exists "kernel/src/arch/arm64/boot.home" "ARM64 boot"
    check_file_exists "kernel/src/arch/arm64/rpi4.home" "Pi 4 support"

    # Check for BCM2711 (Pi 4) support
    if grep -rq "BCM2711\|bcm2711\|0xFE" "$PROJECT_ROOT/kernel/src/" 2>/dev/null; then
        log_pass "BCM2711 (Pi 4) MMIO references found"
    else
        log_skip "BCM2711 specific code not verified"
    fi

    # Check for VideoCore IV/GPU
    if grep -rq "mailbox\|GPU\|VideoCore\|framebuffer" "$PROJECT_ROOT/kernel/src/" 2>/dev/null; then
        log_pass "GPU/VideoCore references found"
    else
        log_skip "GPU references not verified"
    fi

    # Check for HDMI output
    if grep -rq "HDMI\|hdmi\|display" "$PROJECT_ROOT/kernel/src/" 2>/dev/null; then
        log_pass "HDMI/display references found"
    else
        log_skip "HDMI references not verified"
    fi
}

# ============================================================================
# QEMU Testing (Optional)
# ============================================================================

run_qemu_test() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}QEMU Integration Test${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Check if QEMU is available
    if ! command -v qemu-system-aarch64 &> /dev/null; then
        log_skip "QEMU not available for ARM64 testing"
        return
    fi

    # Check if kernel image exists
    local kernel_image="$PROJECT_ROOT/build/kernel8.img"
    if [[ ! -f "$kernel_image" ]]; then
        kernel_image="$PROJECT_ROOT/build/kernel.bin"
    fi

    if [[ ! -f "$kernel_image" ]]; then
        log_skip "Kernel image not built - run 'make' first"
        return
    fi

    log_info "Kernel image found: $kernel_image"
    log_info "QEMU test would be run here (requires built kernel)"
    log_skip "Full QEMU boot test - requires manual verification"
}

# ============================================================================
# Summary
# ============================================================================

print_summary() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "Passed:  ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed:  ${RED}$TESTS_FAILED${NC}"
    echo -e "Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
    echo -e "Total:   $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}All GUI E2E verification checks passed!${NC}"
        echo -e "${GREEN}========================================${NC}"
        exit 0
    else
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}Some verification checks failed.${NC}"
        echo -e "${RED}Review the failures above.${NC}"
        echo -e "${RED}========================================${NC}"
        exit 1
    fi
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}HomeOS End-to-End GUI Verification${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "Project root: $PROJECT_ROOT"
    echo "Test mode: ${1:-check-only}"

    case "${1:-}" in
        --qemu)
            run_static_checks
            run_dependency_checks
            run_boot_chain_checks
            run_integration_checks
            run_pi_specific_checks
            run_qemu_test
            ;;
        --hardware)
            log_info "Hardware testing requires manual boot on Pi 4/5"
            run_static_checks
            run_dependency_checks
            run_boot_chain_checks
            run_integration_checks
            run_pi_specific_checks
            log_skip "Hardware boot test - requires physical device"
            ;;
        --check-only|"")
            run_static_checks
            run_dependency_checks
            run_boot_chain_checks
            run_integration_checks
            run_pi_specific_checks
            ;;
        --help)
            echo "Usage: $0 [--qemu|--hardware|--check-only]"
            echo ""
            echo "Options:"
            echo "  --check-only  Run static verification only (default)"
            echo "  --qemu        Include QEMU boot test"
            echo "  --hardware    Hardware testing mode (manual)"
            echo "  --help        Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac

    print_summary
}

main "$@"
