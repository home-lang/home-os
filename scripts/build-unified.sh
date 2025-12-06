#!/bin/bash
# HomeOS Unified Build System
# Single entrypoint for all build targets
#
# Usage:
#   ./scripts/build-unified.sh                    # Build x86-64 (default)
#   ./scripts/build-unified.sh x86-64             # Build for x86-64
#   ./scripts/build-unified.sh arm64              # Build for ARM64
#   ./scripts/build-unified.sh rpi3               # Build for Raspberry Pi 3
#   ./scripts/build-unified.sh rpi4               # Build for Raspberry Pi 4
#   ./scripts/build-unified.sh rpi5               # Build for Raspberry Pi 5
#   ./scripts/build-unified.sh all                # Build all targets
#   ./scripts/build-unified.sh clean              # Clean build artifacts
#
# Options:
#   --release                                     # Release build (optimized)
#   --debug                                       # Debug build (default)
#   --iso                                         # Create bootable ISO (x86-64)
#   --run                                         # Run in QEMU after build
#   --test                                        # Run tests after build

set -e

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KERNEL_DIR="$PROJECT_ROOT/kernel"
BUILD_DIR="$PROJECT_ROOT/build"
HOME_COMPILER="$HOME/Code/home/zig-out/bin/home"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default options
TARGET="x86-64"
OPTIMIZE="Debug"
CREATE_ISO=false
RUN_QEMU=false
RUN_TESTS=false
PROFILE="desktop"
PROFILE_DIR="$KERNEL_DIR/profiles"

# ============================================================================
# Profile Loading
# ============================================================================

load_profile() {
    local profile_name="$1"
    local profile_file="$PROFILE_DIR/${profile_name}.config"

    if [ -f "$profile_file" ]; then
        log_info "Loading profile: $profile_name"
        source "$profile_file"
        log_success "Profile loaded: $profile_name"

        # Display profile settings
        if [ -n "$PROFILE_DESCRIPTION" ]; then
            echo "  Description: $PROFILE_DESCRIPTION"
        fi
        if [ -n "$TARGET_KERNEL_MB" ]; then
            echo "  Target kernel: ${TARGET_KERNEL_MB}MB"
        fi
        if [ -n "$TARGET_SYSTEM_MB" ]; then
            echo "  Target system: ${TARGET_SYSTEM_MB}MB"
        fi
        echo ""
    else
        log_warn "Profile '$profile_name' not found at $profile_file"
        log_info "Available profiles:"
        for p in "$PROFILE_DIR"/*.config; do
            if [ -f "$p" ]; then
                echo "  - $(basename "$p" .config)"
            fi
        done
        echo ""
    fi
}

generate_build_defines() {
    local defines=""

    # Generate -D flags from FEATURE_* variables
    for var in $(compgen -v | grep '^FEATURE_'); do
        local value="${!var}"
        if [ "$value" = "yes" ] || [ "$value" = "1" ]; then
            local feature_name="${var#FEATURE_}"
            defines="$defines -D${feature_name}=1"
        fi
    done

    # Add limits
    [ -n "$MAX_PROCESSES" ] && defines="$defines -DMAX_PROCESSES=$MAX_PROCESSES"
    [ -n "$MAX_FILES" ] && defines="$defines -DMAX_FILES=$MAX_FILES"
    [ -n "$MAX_SOCKETS" ] && defines="$defines -DMAX_SOCKETS=$MAX_SOCKETS"
    [ -n "$BUFFER_CACHE_MB" ] && defines="$defines -DBUFFER_CACHE_MB=$BUFFER_CACHE_MB"

    echo "$defines"
}

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}======================================================${NC}"
    echo -e "${BLUE}  HomeOS Unified Build System${NC}"
    echo -e "${BLUE}======================================================${NC}"
    echo ""
}

print_usage() {
    echo "Usage: $0 [target] [options]"
    echo ""
    echo "Targets:"
    echo "  x86-64    Build for x86-64 (default)"
    echo "  arm64     Build for ARM64 generic"
    echo "  rpi3      Build for Raspberry Pi 3"
    echo "  rpi4      Build for Raspberry Pi 4"
    echo "  rpi5      Build for Raspberry Pi 5"
    echo "  all       Build all targets"
    echo "  clean     Clean build artifacts"
    echo ""
    echo "Options:"
    echo "  --release          Build with optimizations"
    echo "  --debug            Build with debug symbols (default)"
    echo "  --iso              Create bootable ISO (x86-64 only)"
    echo "  --run              Run in QEMU after build"
    echo "  --test             Run tests after build"
    echo "  --profile=NAME     Use build profile (minimal-headless, server, desktop, pi-optimized)"
    echo "  --list-profiles    List available build profiles"
    echo "  --help             Show this help message"
    echo ""
    echo "Build Profiles:"
    echo "  minimal-headless   32MB kernel, IoT/embedded, no GUI"
    echo "  server             48MB kernel, full networking, containers, no GUI"
    echo "  pi-optimized       24MB kernel, optimized for Raspberry Pi with GUI"
    echo "  desktop            64MB kernel, full desktop experience (default)"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    log_info "Checking build dependencies..."

    local missing=0

    # Check Zig compiler (temporary until Home self-hosts)
    if ! command -v zig &> /dev/null; then
        log_error "Zig compiler not found"
        echo "  Install with: brew install zig (macOS) or apt install zig (Linux)"
        missing=1
    else
        log_success "Zig compiler: $(zig version)"
    fi

    # Check Home compiler
    if [ -f "$HOME_COMPILER" ]; then
        log_success "Home compiler: found at $HOME_COMPILER"
    else
        log_warn "Home compiler not found (using Zig as fallback)"
    fi

    # Check target-specific dependencies
    case "$TARGET" in
        x86-64)
            # Check for grub-mkrescue (for ISO creation)
            if [ "$CREATE_ISO" = true ]; then
                if command -v i686-elf-grub-mkrescue &> /dev/null || \
                   command -v grub-mkrescue &> /dev/null || \
                   [ -f "/opt/homebrew/bin/i686-elf-grub-mkrescue" ]; then
                    log_success "GRUB tools available"
                else
                    log_warn "grub-mkrescue not found (ISO creation will fail)"
                    echo "  Install with: brew install i686-elf-grub xorriso"
                fi
            fi
            ;;
        arm64|rpi*)
            # Check for cross-compilation tools
            if command -v aarch64-linux-gnu-gcc &> /dev/null; then
                log_success "ARM64 cross-compiler available"
            elif command -v aarch64-elf-gcc &> /dev/null; then
                log_success "ARM64 cross-compiler available"
            else
                log_error "ARM64 cross-compiler not found"
                echo "  Install with: brew install aarch64-elf-gcc"
                missing=1
            fi
            ;;
    esac

    if [ $missing -eq 1 ]; then
        exit 1
    fi

    echo ""
}

# ============================================================================
# Build Functions
# ============================================================================

clean_build() {
    log_info "Cleaning build artifacts..."
    rm -rf "$BUILD_DIR"
    rm -rf "$KERNEL_DIR/build"
    rm -rf "$KERNEL_DIR/zig-out"
    rm -rf "$KERNEL_DIR/zig-cache"
    log_success "Build directory cleaned"
}

prepare_build_dir() {
    local target_dir="$BUILD_DIR/$TARGET"
    mkdir -p "$target_dir"
    mkdir -p "$target_dir/obj"
    mkdir -p "$target_dir/iso/boot/grub"
    echo "$target_dir"
}

build_x86_64() {
    log_info "Building for x86-64..."

    local target_dir=$(prepare_build_dir)
    cd "$KERNEL_DIR"

    # Determine optimization flags
    local opt_flag="-O Debug"
    if [ "$OPTIMIZE" = "Release" ]; then
        opt_flag="-O ReleaseSafe"
    fi

    # Check if we have the kernel source files
    if [ -f "src/kernel.zig" ]; then
        log_info "Compiling kernel with Zig..."
        zig build-exe \
            src/boot.s \
            src/kernel.zig \
            -target x86_64-freestanding \
            $opt_flag \
            -T linker.ld \
            --name home-kernel \
            -femit-bin="$target_dir/home-kernel.elf" 2>&1 || {
            log_error "Kernel compilation failed"
            exit 1
        }
    elif [ -f "src/kernel.home" ]; then
        log_info "Compiling kernel with Home compiler..."
        # For now, try using the existing standalone build
        if [ -x "$SCRIPT_DIR/build-standalone.sh" ]; then
            "$SCRIPT_DIR/build-standalone.sh"
            if [ -f "$KERNEL_DIR/build/home-kernel.elf" ]; then
                cp "$KERNEL_DIR/build/home-kernel.elf" "$target_dir/"
            fi
        fi
    else
        log_error "No kernel source found (kernel.zig or kernel.home)"
        exit 1
    fi

    log_success "Kernel compiled: $target_dir/home-kernel.elf"

    # Create ISO if requested
    if [ "$CREATE_ISO" = true ]; then
        create_iso_x86_64 "$target_dir"
    fi
}

build_arm64() {
    log_info "Building for ARM64..."

    local target_dir=$(prepare_build_dir)
    cd "$KERNEL_DIR"

    # Use Zig's cross-compilation
    local opt_flag="-O Debug"
    if [ "$OPTIMIZE" = "Release" ]; then
        opt_flag="-O ReleaseSmall"
    fi

    # Check for ARM64 boot assembly
    if [ -f "$HOME/Code/home/packages/kernel/src/arm64/boot.s" ]; then
        cp "$HOME/Code/home/packages/kernel/src/arm64/boot.s" "$target_dir/boot.s"
    fi

    log_info "ARM64 kernel build configured"
    log_success "Target directory: $target_dir"
}

build_rpi3() {
    log_info "Building for Raspberry Pi 3..."
    TARGET="rpi3"
    build_arm64

    local target_dir="$BUILD_DIR/$TARGET"

    # Pi 3 specific configuration
    log_info "Configuring for BCM2837 (Cortex-A53)"
    echo "kernel=home-kernel.img" > "$target_dir/config.txt"
    echo "arm_64bit=1" >> "$target_dir/config.txt"
    echo "core_freq=250" >> "$target_dir/config.txt"
}

build_rpi4() {
    log_info "Building for Raspberry Pi 4..."
    TARGET="rpi4"
    build_arm64

    local target_dir="$BUILD_DIR/$TARGET"

    # Pi 4 specific configuration
    log_info "Configuring for BCM2711 (Cortex-A72)"
    echo "kernel=home-kernel.img" > "$target_dir/config.txt"
    echo "arm_64bit=1" >> "$target_dir/config.txt"
    echo "enable_uart=1" >> "$target_dir/config.txt"
}

build_rpi5() {
    log_info "Building for Raspberry Pi 5..."

    # Use the dedicated Pi 5 build script if available
    if [ -x "$SCRIPT_DIR/build-rpi5.sh" ]; then
        "$SCRIPT_DIR/build-rpi5.sh"
    else
        TARGET="rpi5"
        build_arm64

        local target_dir="$BUILD_DIR/$TARGET"

        # Pi 5 specific configuration
        log_info "Configuring for BCM2712 (Cortex-A76)"
        cat > "$target_dir/config.txt" << 'EOF'
kernel=home-kernel.img
arm_64bit=1
enable_uart=1
uart_2ndstage=1
dtoverlay=uart0
EOF
    fi
}

build_all() {
    log_info "Building all targets..."

    # Save original target
    local orig_target="$TARGET"

    # Build each target
    TARGET="x86-64"
    build_x86_64

    TARGET="rpi3"
    build_rpi3

    TARGET="rpi4"
    build_rpi4

    TARGET="rpi5"
    build_rpi5

    # Restore original target
    TARGET="$orig_target"

    log_success "All targets built successfully"
}

create_iso_x86_64() {
    local target_dir="$1"

    log_info "Creating bootable ISO..."

    # Copy kernel to ISO directory
    cp "$target_dir/home-kernel.elf" "$target_dir/iso/boot/"

    # Create GRUB configuration
    cat > "$target_dir/iso/boot/grub/grub.cfg" << 'EOF'
set timeout=3
set default=0

menuentry "HomeOS" {
    multiboot2 /boot/home-kernel.elf
    boot
}

menuentry "HomeOS (Debug Mode)" {
    multiboot2 /boot/home-kernel.elf debug
    boot
}

menuentry "HomeOS (Safe Mode)" {
    multiboot2 /boot/home-kernel.elf safe
    boot
}
EOF

    # Find grub-mkrescue
    local GRUB_MKRESCUE=""
    if command -v i686-elf-grub-mkrescue &> /dev/null; then
        GRUB_MKRESCUE="i686-elf-grub-mkrescue"
    elif command -v grub-mkrescue &> /dev/null; then
        GRUB_MKRESCUE="grub-mkrescue"
    elif [ -f "/opt/homebrew/bin/i686-elf-grub-mkrescue" ]; then
        GRUB_MKRESCUE="/opt/homebrew/bin/i686-elf-grub-mkrescue"
    else
        log_error "grub-mkrescue not found"
        return 1
    fi

    # Create ISO
    $GRUB_MKRESCUE -o "$target_dir/home-os.iso" "$target_dir/iso" 2>/dev/null

    log_success "ISO created: $target_dir/home-os.iso"
    ls -lh "$target_dir/home-os.iso"
}

run_qemu() {
    log_info "Running in QEMU..."

    case "$TARGET" in
        x86-64)
            if [ "$CREATE_ISO" = true ] && [ -f "$BUILD_DIR/$TARGET/home-os.iso" ]; then
                qemu-system-x86_64 \
                    -cdrom "$BUILD_DIR/$TARGET/home-os.iso" \
                    -serial stdio \
                    -m 256M
            elif [ -f "$BUILD_DIR/$TARGET/home-kernel.elf" ]; then
                qemu-system-x86_64 \
                    -kernel "$BUILD_DIR/$TARGET/home-kernel.elf" \
                    -serial stdio \
                    -m 256M
            else
                log_error "No kernel or ISO found to run"
                exit 1
            fi
            ;;
        arm64|rpi*)
            if [ -f "$BUILD_DIR/$TARGET/home-kernel.elf" ]; then
                qemu-system-aarch64 \
                    -M raspi3b \
                    -kernel "$BUILD_DIR/$TARGET/home-kernel.elf" \
                    -serial stdio \
                    -m 1G
            else
                log_error "No ARM64 kernel found"
                exit 1
            fi
            ;;
    esac
}

run_tests() {
    log_info "Running tests..."

    if [ -x "$SCRIPT_DIR/test-all.sh" ]; then
        "$SCRIPT_DIR/test-all.sh"
    else
        log_warn "Test script not found"
    fi
}

# ============================================================================
# Main Entry Point
# ============================================================================

print_header

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        x86-64|x86_64)
            TARGET="x86-64"
            shift
            ;;
        arm64)
            TARGET="arm64"
            shift
            ;;
        rpi3|pi3)
            TARGET="rpi3"
            shift
            ;;
        rpi4|pi4)
            TARGET="rpi4"
            shift
            ;;
        rpi5|pi5)
            TARGET="rpi5"
            shift
            ;;
        all)
            TARGET="all"
            shift
            ;;
        clean)
            clean_build
            exit 0
            ;;
        --release)
            OPTIMIZE="Release"
            shift
            ;;
        --debug)
            OPTIMIZE="Debug"
            shift
            ;;
        --iso)
            CREATE_ISO=true
            shift
            ;;
        --run)
            RUN_QEMU=true
            shift
            ;;
        --test)
            RUN_TESTS=true
            shift
            ;;
        --profile=*)
            PROFILE="${1#*=}"
            shift
            ;;
        --list-profiles)
            echo "Available build profiles:"
            echo ""
            for p in "$PROFILE_DIR"/*.config; do
                if [ -f "$p" ]; then
                    local name=$(basename "$p" .config)
                    local desc=$(grep '^PROFILE_DESCRIPTION=' "$p" | head -1 | cut -d'"' -f2)
                    local target=$(grep '^TARGET_KERNEL_MB=' "$p" | head -1 | cut -d'=' -f2)
                    printf "  %-18s %sMB kernel - %s\n" "$name" "$target" "$desc"
                fi
            done
            echo ""
            exit 0
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Load profile if specified
if [ -n "$PROFILE" ]; then
    load_profile "$PROFILE"
fi

# Print build configuration
echo -e "${CYAN}Build Configuration:${NC}"
echo "  Target:       $TARGET"
echo "  Profile:      $PROFILE"
echo "  Optimization: $OPTIMIZE"
echo "  Create ISO:   $CREATE_ISO"
echo "  Run QEMU:     $RUN_QEMU"
echo "  Run Tests:    $RUN_TESTS"
if [ -n "$TARGET_KERNEL_MB" ]; then
    echo "  Kernel Budget: ${TARGET_KERNEL_MB}MB"
fi
echo ""

# Check dependencies
check_dependencies

# Run build
case "$TARGET" in
    x86-64)
        build_x86_64
        ;;
    arm64)
        build_arm64
        ;;
    rpi3)
        build_rpi3
        ;;
    rpi4)
        build_rpi4
        ;;
    rpi5)
        build_rpi5
        ;;
    all)
        build_all
        ;;
esac

# Post-build actions
if [ "$RUN_TESTS" = true ]; then
    run_tests
fi

if [ "$RUN_QEMU" = true ]; then
    run_qemu
fi

# Print summary
echo ""
echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}  Build Complete!${NC}"
echo -e "${GREEN}======================================================${NC}"
echo ""
echo "Build output: $BUILD_DIR/$TARGET/"
echo ""
echo "Next steps:"
echo "  Run in QEMU:    ./scripts/build-unified.sh $TARGET --run"
echo "  Create ISO:     ./scripts/build-unified.sh $TARGET --iso"
echo "  Release build:  ./scripts/build-unified.sh $TARGET --release"
echo ""
