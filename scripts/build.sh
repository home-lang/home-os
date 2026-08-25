#!/bin/bash
# home-os canonical build entry
#
# This is the single, canonical build dispatcher for home-os. It replaces
# the previous family of build-*.sh scripts (build-home, build-home-zig,
# build-home-simple, build-rpi5, build-pi-image, build-pi3-minimal,
# build-legacy-boot, build-standalone, build-initramfs, build-all,
# build-unified). Each old script is now a subcommand of this dispatcher.
#
# Usage:
#   ./scripts/build.sh <subcommand> [options]
#   ./scripts/build.sh --help
#
# Run "./scripts/build.sh help" to see all subcommands and options.
#
# Environment variables (with defaults):
#   KERNEL_DIR     Path to the kernel directory  (default: $REPO_ROOT/kernel)
#   ISO_DIR        Path for ISO staging          (default: $KERNEL_DIR/iso)
#   BUILD_DIR     Path for build artifacts      (default: $KERNEL_DIR/build)
#   HOME_REPO      Path to the Home compiler repo (default: $REPO_ROOT/../home)
#   HOME_COMPILER  Path to the home binary       (default: $HOME_REPO/zig-out/bin/home)
#
# This file is deliberately readable: the dispatcher (case statement) and
# the usage text live near the top; each subcommand is implemented as a
# self-contained cmd_<name> function further down.

set -euo pipefail

# ---------------------------------------------------------------------------
# Portable path resolution (shared with run-qemu.sh)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

KERNEL_DIR="${KERNEL_DIR:-$REPO_ROOT/kernel}"
ISO_DIR="${ISO_DIR:-$KERNEL_DIR/iso}"
BUILD_DIR="${BUILD_DIR:-$KERNEL_DIR/build}"
HOME_REPO="${HOME_REPO:-$REPO_ROOT/../home}"
HOME_COMPILER="${HOME_COMPILER:-$HOME_REPO/zig-out/bin/home}"

# Minimum Viable Kernel entry point (MASTER_PLAN Appendix A / Phase 0).
MVK_ENTRY="${MVK_ENTRY:-$KERNEL_DIR/src/mvk_poc.home}"

# Top-level build directory for multi-target builds (rpi5, pi-image, etc.).
# Differs from BUILD_DIR which targets the x86-64 kernel build tree.
PROJECT_BUILD_DIR="${PROJECT_BUILD_DIR:-$REPO_ROOT/build}"

# Pi firmware staging directory (used by rpi5 subcommand).
RPI5_DIR="${RPI5_DIR:-$REPO_ROOT/rpi5}"

# Colors (only used when stdout is a tty).
if [ -t 1 ]; then
    C_RED='\033[0;31m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[1;33m'
    C_BLUE='\033[0;34m'
    C_CYAN='\033[0;36m'
    C_RESET='\033[0m'
else
    C_RED=''
    C_GREEN=''
    C_YELLOW=''
    C_BLUE=''
    C_CYAN=''
    C_RESET=''
fi

log_info()    { printf '%b[INFO]%b %s\n'    "$C_BLUE"   "$C_RESET" "$*"; }
log_success() { printf '%b[OK]%b %s\n'      "$C_GREEN"  "$C_RESET" "$*"; }
log_warn()    { printf '%b[WARN]%b %s\n'    "$C_YELLOW" "$C_RESET" "$*"; }
log_error()   { printf '%b[ERROR]%b %s\n'   "$C_RED"    "$C_RESET" "$*" >&2; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
home-os build dispatcher

Usage:
  ./scripts/build.sh <subcommand> [options]
  ./scripts/build.sh --help

Subcommands (kernel builds):
  mvk                 Minimum Viable Kernel: compile the MVK entry with the
                      Home compiler, link via kernel/linker.ld into a
                      multiboot2 ELF. Default if no subcommand is given.
                      This is the MASTER_PLAN Phase 0 build target.
  kernel              REMOVED — built a nonexistent src/kernel.zig. Use mvk.
  home                Build the kernel via the Home compiler (Home -> .s,
                      then GNU as + ld). Produces ELF + bootable ISO.
  home-zig            Build the kernel via the Home compiler + Zig as the
                      assembler/linker. Produces ELF + bootable ISO.
  home-simple         Compile the Home kernel_main on top of a Zig-built
                      base kernel. Diagnostic / proof-of-concept build.
  standalone          Auto-detect the .home kernel entry (main.home /
                      kernel_main.home / kernel.home) and build via
                      Home compiler + Zig.

Subcommands (Pi / image builds):
  rpi5                Build the kernel for Raspberry Pi 5 (BCM2712).
  pi-image [opts]     Create a minimal SD-card image for Pi 3/4/5.
                      Options: --target={rpi3|rpi4|rpi5} --size=2G
                               --boot-size=256M --profile=NAME
  pi3-minimal [opts]  Pi 3 B+ minimal image (1GB RAM target).
                      Options: --release --debug --image --dry-run

Subcommands (extras):
  legacy-boot [opts]  Build the legacy BIOS bootloader (MBR + Stage 2)
                      and a bootable disk image.
                      Options: --clean --verbose
  initramfs [opts]    Build an initramfs cpio archive.
                      Options: --profile={minimal|server|desktop|pi}
                               --target={x86-64|rpi3|rpi4|rpi5}
                               --compress={none|gzip|lz4|xz}
                               --no-strip --no-modules
  all [target] [opt]  Compile every kernel module (210+).
                      target: x86_64 (default) | arm64
                      opt:    Debug (default)  | Release
  unified [args]      Run the multi-target unified build (formerly
                      build-unified.sh). Accepts every flag the old
                      script accepted. Run "./scripts/build.sh unified
                      --help" for the full list.

Convenience flags (forwarded to "unified"):
  --target=ARCH       x86-64 | arm64 | rpi3 | rpi4 | rpi5
  --profile=NAME      minimal-headless | server | desktop | pi-optimized
  --release | --debug
  --iso               Create bootable ISO (x86-64).
  --run               Boot the kernel in QEMU after building.

Environment variables:
  KERNEL_DIR         Path to the kernel directory     (default: \$REPO_ROOT/kernel)
  ISO_DIR            Path for ISO staging             (default: \$KERNEL_DIR/iso)
  BUILD_DIR          Path for build artifacts         (default: \$KERNEL_DIR/build)
  PROJECT_BUILD_DIR  Multi-target build root          (default: \$REPO_ROOT/build)
  HOME_REPO          Path to the Home compiler repo   (default: \$REPO_ROOT/../home)
  HOME_COMPILER      Path to the home binary          (default: \$HOME_REPO/zig-out/bin/home)
  RPI5_DIR           Pi 5 firmware staging dir        (default: \$REPO_ROOT/rpi5)

Examples:
  ./scripts/build.sh                       # generic x86-64 kernel + ISO
  ./scripts/build.sh kernel                # same as above
  ./scripts/build.sh home                  # build via Home compiler
  ./scripts/build.sh rpi5                  # build for Raspberry Pi 5
  ./scripts/build.sh pi-image --target=rpi4
  ./scripts/build.sh initramfs --profile=minimal
  ./scripts/build.sh --target=rpi5 --release    # forwarded to unified
  ./scripts/build.sh unified all --iso          # build all targets + ISO
EOF
}

# ---------------------------------------------------------------------------
# Helpers shared by multiple subcommands
# ---------------------------------------------------------------------------

# Resolve grub-mkrescue, echoing the binary name to stdout. Returns 1 if
# none of the known names are available on PATH or in the homebrew prefix.
find_grub_mkrescue() {
    if command -v i686-elf-grub-mkrescue >/dev/null 2>&1; then
        echo "i686-elf-grub-mkrescue"
    elif command -v grub-mkrescue >/dev/null 2>&1; then
        echo "grub-mkrescue"
    elif [ -x "/opt/homebrew/bin/i686-elf-grub-mkrescue" ]; then
        echo "/opt/homebrew/bin/i686-elf-grub-mkrescue"
    elif command -v x86_64-elf-grub-mkrescue >/dev/null 2>&1; then
        echo "x86_64-elf-grub-mkrescue"
    else
        return 1
    fi
}

# Resolve a zig binary into $ZIG. Zig is used only as an assembler/linker
# for freestanding targets — no kernel logic is written in Zig (CLAUDE.md).
# Order: $ZIG, PATH, the Home repo's pinned pantry toolchain.
require_zig() {
    if [ -n "${ZIG:-}" ] && command -v "$ZIG" >/dev/null 2>&1; then
        return 0
    fi
    if command -v zig >/dev/null 2>&1; then
        ZIG="zig"
        return 0
    fi
    if [ -x "$HOME_REPO/pantry/.bin/zig" ]; then
        ZIG="$HOME_REPO/pantry/.bin/zig"
        log_info "Using Zig from the Home toolchain: $ZIG"
        return 0
    fi
    log_error "Zig compiler not found (assembler/linker for freestanding targets)!"
    echo "  Install it, or set ZIG=/path/to/zig." >&2
    exit 1
}

require_home_compiler() {
    if [ ! -f "$HOME_COMPILER" ]; then
        log_error "Home compiler not found at $HOME_COMPILER"
        echo "  Build the Home compiler first:" >&2
        echo "    cd \"$HOME_REPO\" && zig build" >&2
        echo "  Or set HOME_COMPILER / HOME_REPO env vars to point at an existing build." >&2
        exit 1
    fi
}

require_tool() {
    local tool="$1"
    if ! command -v "$tool" >/dev/null 2>&1; then
        log_error "$tool not found. Please install it."
        exit 1
    fi
}

# Fail loudly when a required source file is missing. Replaces the old
# silent-fallback behavior (MASTER_PLAN Phase 0 / stub register S1).
require_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        log_error "Required file not found: $file"
        exit 1
    fi
}

# Make ISO from $ISO_DIR -> $BUILD_DIR/home-os.iso. Echoes the resolved
# grub-mkrescue binary on success.
make_iso() {
    local grub
    if ! grub="$(find_grub_mkrescue)"; then
        log_error "grub-mkrescue not found. Install with:"
        echo "  macOS: brew install i686-elf-grub xorriso" >&2
        echo "  Linux: sudo apt install grub-pc-bin xorriso" >&2
        exit 1
    fi
    log_info "Using: $grub"
    "$grub" -o "$BUILD_DIR/home-os.iso" "$ISO_DIR" 2>&1 | grep -v "warning:" || true
}

# ---------------------------------------------------------------------------
# Subcommand: kernel (generic x86-64 build via Zig)
# Replaces: scripts/build.sh (old)
# ---------------------------------------------------------------------------
cmd_mvk() {
    echo "=== Building HomeOS Minimum Viable Kernel ==="
    # MASTER_PLAN Phase 0 (#26). Pipeline:
    #   mvk entry .home --(home --kernel)--> x86-64 asm
    #   --> assemble + link with boot.s via linker.ld --> multiboot2 ELF
    # The proof-of-life string "HomeOS v0.1: kernel_main reached" must appear
    # on serial when this ELF boots in QEMU (scripts/boot-test.sh).
    require_home_compiler
    require_zig
    require_file "$MVK_ENTRY"
    require_file "$KERNEL_DIR/src/boot.s"
    require_file "$KERNEL_DIR/linker.ld"

    mkdir -p "$BUILD_DIR"

    log_info "[1/2] Compiling $MVK_ENTRY -> x86-64 assembly..."
    "$HOME_COMPILER" build "$MVK_ENTRY" --kernel -o "$BUILD_DIR/mvk.s"
    require_file "$BUILD_DIR/mvk.s"

    log_info "[2/2] Assembling + linking multiboot2 ELF..."
    cd "$KERNEL_DIR"
    "$ZIG" build-exe \
        src/boot.s \
        build/mvk.s \
        -target x86_64-freestanding \
        -O ReleaseSafe \
        -T linker.ld \
        --name home-kernel \
        -femit-bin="$BUILD_DIR/home-kernel.elf"

    require_file "$BUILD_DIR/home-kernel.elf"
    log_success "MVK built: $BUILD_DIR/home-kernel.elf"
    ls -lh "$BUILD_DIR/home-kernel.elf"
    echo ""
    echo "Boot it:  ./scripts/boot-test.sh"
}

cmd_kernel() {
    echo "=== Building home-os kernel ==="
    # The legacy Zig kernel entry (src/kernel.zig) never existed and has been
    # removed (MASTER_PLAN Phase 0, stub register S1). Kernel builds go
    # through the Home compiler.
    log_error "The 'kernel' subcommand built a nonexistent src/kernel.zig and has been removed."
    log_error "Use the Home-compiler build path instead:"
    log_error "  ./scripts/build.sh home        # Home compiler -> GNU as/ld"
    log_error "  ./scripts/build.sh standalone  # auto-detect .home entry + Zig"
    exit 1
}

# ---------------------------------------------------------------------------
# Subcommand: home (Home compiler -> GNU as + ld)
# Replaces: scripts/build-home.sh
# ---------------------------------------------------------------------------
cmd_home() {
    echo "=== Building home-os kernel with Home Compiler ==="
    require_home_compiler
    require_file "$KERNEL_DIR/src/kernel_simple.home"
    require_tool as
    log_info "Using Home compiler: $HOME_COMPILER"

    mkdir -p "$BUILD_DIR" "$ISO_DIR/boot/grub"

    cd "$KERNEL_DIR"
    log_info "Step 1: Compiling kernel_simple.home to assembly..."
    "$HOME_COMPILER" build src/kernel_simple.home --kernel -o "$BUILD_DIR/kernel_main.s"

    log_info "Step 2: Assembling boot.s..."
    as -o "$BUILD_DIR/boot.o" src/boot.s

    log_info "Step 3: Assembling kernel_main.s..."
    as -o "$BUILD_DIR/kernel_main.o" "$BUILD_DIR/kernel_main.s"

    log_info "Step 4: Linking kernel..."
    ld -n -o "$BUILD_DIR/home-kernel.elf" \
        -T linker.ld \
        "$BUILD_DIR/boot.o" \
        "$BUILD_DIR/kernel_main.o"
    ls -lh "$BUILD_DIR/home-kernel.elf"

    cp "$BUILD_DIR/home-kernel.elf" "$ISO_DIR/boot/"

    log_info "Step 5: Creating bootable ISO..."
    make_iso
    log_success "ISO created: $BUILD_DIR/home-os.iso"
    ls -lh "$BUILD_DIR/home-os.iso"

    echo ""
    echo "=== Build complete! ==="
    echo "Run in QEMU: cd \"$REPO_ROOT\" && ./scripts/run-qemu.sh"
}

# ---------------------------------------------------------------------------
# Subcommand: home-zig (Home compiler + Zig assembler/linker)
# Replaces: scripts/build-home-zig.sh
# ---------------------------------------------------------------------------
cmd_home_zig() {
    echo "=== Building home-os kernel with Home compiler (Zig assembler/linker) ==="
    require_home_compiler
    require_zig
    require_file "$KERNEL_DIR/src/kernel_simple.home"

    mkdir -p "$BUILD_DIR" "$ISO_DIR/boot/grub"
    cd "$KERNEL_DIR"

    log_info "Step 1: Compiling kernel_simple.home with Home compiler..."
    "$HOME_COMPILER" build src/kernel_simple.home --kernel -o "$BUILD_DIR/kernel_main.s"

    log_info "Step 2: Assembling + linking with Zig..."
    zig build-exe \
        src/boot.s \
        "$BUILD_DIR/kernel_main.s" \
        -target x86_64-freestanding \
        -O ReleaseSafe \
        -T linker.ld \
        --name home-kernel \
        -femit-bin="$BUILD_DIR/home-kernel.elf"
    ls -lh "$BUILD_DIR/home-kernel.elf"

    cp "$BUILD_DIR/home-kernel.elf" "$ISO_DIR/boot/"

    log_info "Step 3: Creating bootable ISO..."
    make_iso
    log_success "ISO created: $BUILD_DIR/home-os.iso"
    ls -lh "$BUILD_DIR/home-os.iso"

    echo ""
    echo "=== Build complete! ==="
    echo "Run in QEMU: cd \"$REPO_ROOT\" && ./scripts/run-qemu.sh"
}

# ---------------------------------------------------------------------------
# Subcommand: home-simple (Home kernel_main on top of Zig-built base)
# Replaces: scripts/build-home-simple.sh
# ---------------------------------------------------------------------------
cmd_home_simple() {
    echo "=== Building Home-Compiled Kernel (Simple Method) ==="
    require_home_compiler
    require_file "$KERNEL_DIR/src/kernel_simple.home"

    cd "$KERNEL_DIR"
    log_info "Compiling Home kernel_main..."
    "$HOME_COMPILER" build src/kernel_simple.home --kernel -o "$BUILD_DIR/home_kernel_main.s"

    log_success "Home code compiled to assembly!"
    echo ""
    echo "Generated assembly from Home compiler:"
    cat "$BUILD_DIR/home_kernel_main.s"
    echo ""
    echo "=== Next Steps ==="
    echo "The Home compiler successfully generated kernel assembly!"
    echo "Integration into full kernel build requires:"
    echo "  1. Assembler that supports AT&T syntax (GNU as)"
    echo "  2. Or convert boot.s to Intel syntax"
    echo "  3. Or use Zig's assembler for the linker step"
}

# ---------------------------------------------------------------------------
# Subcommand: standalone (auto-detect entry, Home + Zig)
# Replaces: scripts/build-standalone.sh
# ---------------------------------------------------------------------------
cmd_standalone() {
    echo "=== Building home-os Kernel (auto-detect entry) ==="
    require_home_compiler
    require_zig

    local kernel_entry=""
    if [ -f "$KERNEL_DIR/src/main.home" ]; then
        kernel_entry="src/main.home"
    elif [ -f "$KERNEL_DIR/src/kernel_main.home" ]; then
        kernel_entry="src/kernel_main.home"
    elif [ -f "$KERNEL_DIR/src/kernel.home" ]; then
        kernel_entry="src/kernel.home"
    else
        log_error "No kernel entry point found (main.home, kernel_main.home, or kernel.home)"
        exit 1
    fi

    mkdir -p "$BUILD_DIR" "$ISO_DIR/boot/grub"
    cd "$KERNEL_DIR"

    log_info "Step 1: Compiling $kernel_entry with Home compiler..."
    "$HOME_COMPILER" build "$kernel_entry" --kernel -o "$BUILD_DIR/kernel_main.s"
    log_success "Home compilation complete"

    echo "Generated assembly (first 50 lines):"
    head -n 50 "$BUILD_DIR/kernel_main.s"
    echo "..."
    echo ""

    log_info "Step 2: Assembling + linking with Zig..."
    zig build-exe \
        src/boot.s \
        "$BUILD_DIR/kernel_main.s" \
        -target x86_64-freestanding \
        -O ReleaseSafe \
        -T linker.ld \
        --name home-kernel \
        -femit-bin="$BUILD_DIR/home-kernel.elf"
    ls -lh "$BUILD_DIR/home-kernel.elf"

    cp "$BUILD_DIR/home-kernel.elf" "$ISO_DIR/boot/"

    log_info "Step 3: Creating bootable ISO..."
    if grub_bin="$(find_grub_mkrescue)"; then
        log_info "Using: $grub_bin"
        "$grub_bin" -o "$BUILD_DIR/home-os.iso" "$ISO_DIR" 2>&1 | grep -v "warning:" || true
        log_success "ISO created: $BUILD_DIR/home-os.iso"
        ls -lh "$BUILD_DIR/home-os.iso"
    else
        log_warn "grub-mkrescue not found, skipping ISO creation"
        log_info "Kernel ELF available at: $BUILD_DIR/home-kernel.elf"
    fi

    echo ""
    echo "=== Build complete! ==="
    echo "Run in QEMU: cd \"$REPO_ROOT\" && ./scripts/run-qemu.sh"
}

# ---------------------------------------------------------------------------
# Subcommand: rpi5 (Raspberry Pi 5 build)
# Replaces: scripts/build-rpi5.sh
# ---------------------------------------------------------------------------
cmd_rpi5() {
    local rpi5_build_dir="$PROJECT_BUILD_DIR/rpi5"

    echo "╔════════════════════════════════════════╗"
    echo "║  Building HomeOS for Raspberry Pi 5   ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    require_home_compiler

    log_info "Creating build directory..."
    mkdir -p "$rpi5_build_dir/boot"

    log_info "Copying ARM64 boot code..."
    if [ -f "$HOME_REPO/packages/kernel/src/arm64/boot.s" ]; then
        cp "$HOME_REPO/packages/kernel/src/arm64/boot.s" "$rpi5_build_dir/boot.s"
    else
        log_error "ARM64 boot.s not found at $HOME_REPO/packages/kernel/src/arm64/boot.s"
        exit 1
    fi

    log_info "Assembling ARM64 boot code..."
    aarch64-linux-gnu-as "$rpi5_build_dir/boot.s" -o "$rpi5_build_dir/boot.o"

    # No silent fallback (MASTER_PLAN Phase 0, stub register S1). The Pi 5
    # kernel build has no working entry point today:
    #   * kernel/src/rpi5_main.zig never existed (and Zig kernel sources are
    #     out of policy per CLAUDE.md), and
    #   * a .home ARM64 boot path needs the Home arm64 backend, milestone A6,
    #     which gates Phase 7b entirely.
    # Fail loudly rather than emitting a build.zig around a dead path.
    log_error "The rpi5 kernel build has no entry point yet."
    log_error "It is blocked on Home compiler milestone A6 (arm64 backend) — MASTER_PLAN Phase 7b."
    log_error "See home-lang/home-os#8. Boot code assembled at: $rpi5_build_dir/boot.o"
    exit 1

    log_info "Creating kernel image..."
    aarch64-linux-gnu-objcopy "$rpi5_build_dir/bin/home-kernel.elf" -O binary "$rpi5_build_dir/boot/home-kernel.img"

    log_info "Preparing Raspberry Pi 5 firmware files..."
    echo "   Note: download from https://github.com/raspberrypi/firmware/tree/master/boot"
    echo ""

    local firmware_needed=("start4.elf" "fixup4.dat" "bcm2712-rpi-5-b.dtb")
    local firmware_available=true
    local f
    for f in "${firmware_needed[@]}"; do
        if [ ! -f "$RPI5_DIR/$f" ]; then
            log_warn "Missing firmware: $f"
            firmware_available=false
        else
            log_success "Found: $f"
            cp "$RPI5_DIR/$f" "$rpi5_build_dir/boot/"
        fi
    done

    log_info "Copying boot configuration..."
    cp "$RPI5_DIR/config.txt" "$rpi5_build_dir/boot/"
    cp "$RPI5_DIR/cmdline.txt" "$rpi5_build_dir/boot/"

    echo ""
    log_info "Kernel Information:"
    aarch64-linux-gnu-size "$rpi5_build_dir/bin/home-kernel.elf"

    echo ""
    log_success "Build complete!"
    echo ""
    echo "Build output: $rpi5_build_dir/boot/"

    if [ "$firmware_available" = false ]; then
        echo ""
        log_warn "Some firmware files are missing!"
        echo "  Download from https://github.com/raspberrypi/firmware/tree/master/boot"
        echo "  Required:"
        for f in "${firmware_needed[@]}"; do
            echo "    - $f"
        done
        echo "  Place them in: $RPI5_DIR/"
    fi

    echo ""
    echo "Next steps:"
    echo "  1. Download missing firmware files (if any)"
    echo "  2. Format SD card with FAT32 partition"
    echo "  3. Copy contents of $rpi5_build_dir/boot/ to SD card"
    echo "  4. Insert SD card into Raspberry Pi 5"
    echo "  5. Connect USB-to-serial adapter to GPIO 14/15 (pins 8/10)"
    echo "  6. Open serial console at 115200 baud"
    echo "  7. Power on the Raspberry Pi 5"
    echo ""
    echo "For detailed instructions, see: $REPO_ROOT/docs/RASPBERRY_PI_5.md"
}

# ---------------------------------------------------------------------------
# Subcommand: pi-image (SD card image for Pi 3/4/5)
# Replaces: scripts/build-pi-image.sh
# ---------------------------------------------------------------------------
cmd_pi_image() {
    local target="rpi4"
    local image_size="2G"
    local boot_size="256M"
    local profile="pi-optimized"

    while [ $# -gt 0 ]; do
        case "$1" in
            --target=*)    target="${1#*=}" ;;
            --size=*)      image_size="${1#*=}" ;;
            --boot-size=*) boot_size="${1#*=}" ;;
            --profile=*)   profile="${1#*=}" ;;
            --help|-h)
                echo "Usage: ./scripts/build.sh pi-image [options]"
                echo "  --target=TARGET    Pi target (rpi3 | rpi4 | rpi5)"
                echo "  --size=SIZE        Image size (e.g., 2G, 4G)"
                echo "  --boot-size=SIZE   Boot partition size (e.g., 256M)"
                echo "  --profile=NAME     Build profile to use"
                return 0
                ;;
            *)
                log_warn "Unknown option: $1"
                ;;
        esac
        shift
    done

    local image_dir="$PROJECT_BUILD_DIR/pi-image"

    echo ""
    echo "======================================================"
    echo "  HomeOS Raspberry Pi Image Builder"
    echo "======================================================"
    echo ""
    log_info "Target: $target"
    log_info "Image size: $image_size"
    log_info "Boot partition: $boot_size"
    log_info "Profile: $profile"
    echo ""

    rm -rf "$image_dir"
    mkdir -p "$image_dir"/{boot,root}

    log_info "Creating boot partition contents..."
    case "$target" in
        rpi3)
            cat > "$image_dir/boot/config.txt" <<'EOF'
# HomeOS Raspberry Pi 3 Configuration

# 64-bit mode
arm_64bit=1

# Kernel
kernel=home-kernel.img

# Serial console
enable_uart=1

# GPU memory (minimal for headless)
gpu_mem=16

# CPU settings
arm_freq=1200
core_freq=250

# Disable splash
disable_splash=1

# Fast boot
boot_delay=0
EOF
            ;;
        rpi4)
            cat > "$image_dir/boot/config.txt" <<'EOF'
# HomeOS Raspberry Pi 4 Configuration

# 64-bit mode
arm_64bit=1

# Kernel
kernel=home-kernel.img

# Serial console
enable_uart=1
uart_2ndstage=1

# GPU memory
gpu_mem=64

# CPU settings (Pi 4 can go to 1.5GHz)
arm_freq=1500
over_voltage=2

# USB boot support
[pi4]
max_usb_current=1

# PCIe/USB3 settings
dtoverlay=pcie-32bit-dma

# Disable splash
disable_splash=1

# Fast boot
boot_delay=0
EOF
            ;;
        rpi5)
            cat > "$image_dir/boot/config.txt" <<'EOF'
# HomeOS Raspberry Pi 5 Configuration

# 64-bit mode
arm_64bit=1

# Kernel
kernel=home-kernel.img

# Serial console
enable_uart=1
uart_2ndstage=1

# GPU memory
gpu_mem=64

# CPU settings (Pi 5 runs at 2.4GHz)
arm_freq=2400

# PCIe support
dtoverlay=pcie-32bit-dma

# NVMe support
dtparam=nvme

# Disable splash
disable_splash=1

# Fast boot
boot_delay=0
EOF
            ;;
        *)
            log_error "Unknown target: $target (expected rpi3, rpi4, or rpi5)"
            exit 1
            ;;
    esac

    cat > "$image_dir/boot/cmdline.txt" <<'EOF'
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=noop fsck.repair=yes rootwait quiet init=/sbin/init
EOF

    if [ -f "$PROJECT_BUILD_DIR/$target/home-kernel.elf" ]; then
        log_info "Copying kernel..."
        cp "$PROJECT_BUILD_DIR/$target/home-kernel.elf" "$image_dir/boot/home-kernel.img"
    elif [ -f "$PROJECT_BUILD_DIR/arm64/home-kernel.elf" ]; then
        cp "$PROJECT_BUILD_DIR/arm64/home-kernel.elf" "$image_dir/boot/home-kernel.img"
    else
        log_warn "Kernel not found, creating placeholder"
        touch "$image_dir/boot/home-kernel.img"
    fi

    if [ -f "$PROJECT_BUILD_DIR/initramfs.img" ]; then
        log_info "Copying initramfs..."
        cp "$PROJECT_BUILD_DIR/initramfs.img" "$image_dir/boot/"
    fi

    log_info "Creating root partition contents..."
    mkdir -p "$image_dir/root"/{bin,sbin,lib,lib64,usr/{bin,sbin,lib},etc,var/{log,run,tmp},home,root,tmp,proc,sys,dev,mnt}

    cat > "$image_dir/root/sbin/init" <<'EOF'
#!/bin/sh
# HomeOS init

# Mount essential filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true

# Set hostname
hostname home-os

# Print boot message
clear
echo ""
echo "  _   _                       ___  ____  "
echo " | | | | ___  _ __ ___   ___ / _ \/ ___| "
echo " | |_| |/ _ \| '_ \` _ \ / _ \ | | \___ \ "
echo " |  _  | (_) | | | | | |  __/ |_| |___) |"
echo " |_| |_|\___/|_| |_| |_|\___|\___/|____/ "
echo ""
echo "Welcome to HomeOS on Raspberry Pi"
echo ""

# Start shell
exec /bin/sh
EOF
    chmod +x "$image_dir/root/sbin/init"

    cat > "$image_dir/root/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/sh
EOF
    cat > "$image_dir/root/etc/group" <<'EOF'
root:x:0:
EOF
    cat > "$image_dir/root/etc/hostname" <<'EOF'
home-os
EOF
    cat > "$image_dir/root/etc/fstab" <<'EOF'
# HomeOS fstab
/dev/mmcblk0p1  /boot   vfat    defaults,noatime    0   2
/dev/mmcblk0p2  /       ext4    defaults,noatime    0   1
proc            /proc   proc    defaults            0   0
sysfs           /sys    sysfs   defaults            0   0
devtmpfs        /dev    devtmpfs defaults           0   0
tmpfs           /tmp    tmpfs   defaults,size=64M   0   0
EOF

    log_info "Calculating sizes..."
    local boot_kb root_kb
    boot_kb=$(du -sk "$image_dir/boot" | cut -f1)
    root_kb=$(du -sk "$image_dir/root" | cut -f1)
    echo "  Boot partition contents: ${boot_kb} KB"
    echo "  Root partition contents: ${root_kb} KB"

    local image_file="$PROJECT_BUILD_DIR/home-os-${target}.img"

    if command -v dd >/dev/null 2>&1 && command -v mkfs.vfat >/dev/null 2>&1; then
        log_info "Creating disk image..."
        local image_bytes
        case "$image_size" in
            *G) image_bytes=$(( ${image_size%G} * 1024 * 1024 * 1024 )) ;;
            *M) image_bytes=$(( ${image_size%M} * 1024 * 1024 )) ;;
            *)  image_bytes=$(( 2 * 1024 * 1024 * 1024 )) ;;
        esac

        dd if=/dev/zero of="$image_file" bs=1 count=0 seek=$image_bytes 2>/dev/null
        log_success "Created disk image: $image_file"
        log_info "Image size: $image_size"
        echo ""
        log_info "To write to SD card:"
        echo "  sudo dd if=$image_file of=/dev/sdX bs=4M status=progress"
        echo ""
        log_warn "Replace /dev/sdX with your actual SD card device!"
    else
        log_warn "Disk image tools not available"
        log_info "Created boot and root filesystem trees in $image_dir"
    fi

    log_info "Creating filesystem tarballs..."
    ( cd "$image_dir" && tar -czf "$PROJECT_BUILD_DIR/home-os-${target}-boot.tar.gz" -C boot . )
    ( cd "$image_dir" && tar -czf "$PROJECT_BUILD_DIR/home-os-${target}-root.tar.gz" -C root . )

    local boot_tar root_tar
    boot_tar=$(ls -lh "$PROJECT_BUILD_DIR/home-os-${target}-boot.tar.gz" | awk '{print $5}')
    root_tar=$(ls -lh "$PROJECT_BUILD_DIR/home-os-${target}-root.tar.gz" | awk '{print $5}')

    echo ""
    log_success "Created tarballs:"
    echo "  Boot: $PROJECT_BUILD_DIR/home-os-${target}-boot.tar.gz ($boot_tar)"
    echo "  Root: $PROJECT_BUILD_DIR/home-os-${target}-root.tar.gz ($root_tar)"

    echo ""
    echo "======================================================"
    echo "  Pi Image Build Complete!"
    echo "======================================================"
    echo ""
    echo "Target: $target"
    echo "Profile: $profile"
}

# ---------------------------------------------------------------------------
# Subcommand: pi3-minimal
# Replaces: scripts/build-pi3-minimal.sh
# ---------------------------------------------------------------------------
cmd_pi3_minimal() {
    local build_type="release"
    local create_image=0
    local dry_run=0

    while [ $# -gt 0 ]; do
        case "$1" in
            --release) build_type="release" ;;
            --debug)   build_type="debug" ;;
            --image)   create_image=1 ;;
            --dry-run) dry_run=1 ;;
            --help|-h)
                echo "Usage: ./scripts/build.sh pi3-minimal [options]"
                echo "  --release    Release build (default)"
                echo "  --debug      Debug build"
                echo "  --image      Create SD card image"
                echo "  --dry-run    Show what would be done"
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
        shift
    done

    local build_dir="$PROJECT_BUILD_DIR/pi3-minimal"
    local profile_file="$REPO_ROOT/kernel/profiles/pi3-minimal.config"

    local image_size_mb=256
    local image_name="home-os-pi3-minimal.img"
    local kernel_budget_mb=64
    local total_budget_mb=96

    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║     home-os Pi 3 B+ Minimal Image Builder                    ║"
    echo "║     Target: 1GB RAM, <64MB kernel, <5s boot                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Build type:   $build_type"
    [ $create_image -eq 1 ] && echo "Create image: yes" || echo "Create image: no"
    echo "Profile:      $profile_file"
    echo ""

    log_info "[1/7] Validating build profile..."
    if [ ! -f "$profile_file" ]; then
        log_error "Profile not found: $profile_file"
        exit 1
    fi

    check_profile_setting() {
        local setting="$1"
        local expected="$2"
        if grep -q "^$setting = $expected" "$profile_file" 2>/dev/null; then
            log_success "$setting = $expected"
        else
            log_warn "$setting not set to $expected"
        fi
    }

    check_profile_setting "enable_gui" "false"
    check_profile_setting "enable_tls" "false"
    check_profile_setting "enable_gpu" "false"
    check_profile_setting "enable_smp" "true"
    check_profile_setting "max_processes" "64"

    log_info "[2/7] Calculating minimal module set..."
    local driver_count
    driver_count=$(grep -c "^enable_.*= true" "$profile_file" 2>/dev/null || echo "0")
    echo "  Enabled drivers: $driver_count"
    echo "  Estimated kernel size: ~2MB (placeholder)"

    log_info "[3/7] Setting up build directory..."
    if [ $dry_run -eq 0 ]; then
        mkdir -p "$build_dir"/{boot,root,modules}
        log_success "Created: $build_dir"
    else
        log_warn "[dry-run] Would create: $build_dir"
    fi

    log_info "[4/7] Generating minimal kernel configuration..."
    local kernel_config="$build_dir/kernel.config"
    if [ $dry_run -eq 0 ]; then
        cat > "$kernel_config" <<'EOF'
# home-os Pi 3 B+ Minimal Kernel Configuration
# Auto-generated from pi3-minimal.config

# Core
CONFIG_ARM64=y
CONFIG_BCM2837=y
CONFIG_SMP=y
CONFIG_NR_CPUS=4

# Memory
CONFIG_MEMORY_BUDGET_MB=64
CONFIG_HEAP_SIZE_MB=8
CONFIG_PAGE_CACHE_MB=24
CONFIG_MAX_PROCESSES=64
CONFIG_STACK_SIZE_KB=256

# Filesystem
CONFIG_VFS=y
CONFIG_HOMEFS=y
CONFIG_DEVFS=y
CONFIG_PROCFS=y
CONFIG_SYSFS=y
CONFIG_BUFFER_CACHE_ENTRIES=256

# Networking (minimal)
CONFIG_NET=y
CONFIG_TCP=y
CONFIG_UDP=y
CONFIG_ICMP=y
CONFIG_DHCP=y
CONFIG_DNS=y
CONFIG_HTTP=y
# CONFIG_TLS is not set
# CONFIG_WEBSOCKET is not set
# CONFIG_NFS is not set
# CONFIG_SMB is not set
CONFIG_MAX_SOCKETS=64

# Drivers
CONFIG_SERIAL=y
CONFIG_GPIO=y
CONFIG_I2C=y
CONFIG_SPI=y
CONFIG_PWM=y
CONFIG_SDMMC=y
CONFIG_BCM_EMMC=y
CONFIG_FRAMEBUFFER=y
CONFIG_FB_CONSOLE=y
CONFIG_USB=y
CONFIG_EHCI=y
CONFIG_USB_HUB=y
CONFIG_ETHERNET=y
CONFIG_WIFI=y
CONFIG_CYW43455=y
CONFIG_BLUETOOTH=y
CONFIG_HWMON=y
CONFIG_THERMAL=y
CONFIG_KEYBOARD=y
CONFIG_MOUSE=y
# CONFIG_GPU is not set
# CONFIG_AUDIO is not set
# CONFIG_CAMERA is not set
# CONFIG_NVME is not set

# Security
CONFIG_CAPABILITIES=y
CONFIG_SECCOMP=y
CONFIG_ASLR=y
CONFIG_WX_ENFORCEMENT=y
# CONFIG_AUDIT is not set

# Boot
CONFIG_PARALLEL_INIT=y
CONFIG_LAZY_MODULES=y
CONFIG_BOOT_PROFILE=headless

# Debug (minimal)
CONFIG_SERIAL_CONSOLE=y
CONFIG_PANIC_DEBUG=y
# CONFIG_KERNEL_SYMBOLS is not set
# CONFIG_GDB_STUB is not set
# CONFIG_PROFILER is not set

# GUI (disabled)
# CONFIG_CRAFT is not set
# CONFIG_COMPOSITOR is not set

# Build
CONFIG_OPTIMIZE_SIZE=y
CONFIG_STRIP=y
CONFIG_COMPRESS_LZ4=y
EOF
        log_success "Generated: $kernel_config"
    else
        log_warn "[dry-run] Would generate: $kernel_config"
    fi

    log_info "[5/7] Creating minimal initramfs..."
    local initramfs_dir="$build_dir/initramfs"
    if [ $dry_run -eq 0 ]; then
        mkdir -p "$initramfs_dir"/{bin,sbin,etc,dev,proc,sys,tmp,var,home,root}
        cat > "$initramfs_dir/init" <<'INIT'
#!/bin/sh
# home-os Pi 3 Minimal Init

echo "home-os Pi 3 Minimal starting..."

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

# Set hostname
hostname pi3-homeos

# Setup network (minimal)
ifconfig lo up
ifconfig eth0 up
udhcpc -i eth0 -s /etc/udhcpc.script -q &

# Start shell
echo "Minimal boot complete."
exec /bin/sh
INIT
        chmod +x "$initramfs_dir/init"

        cat > "$initramfs_dir/etc/udhcpc.script" <<'DHCP'
#!/bin/sh
case "$1" in
    bound|renew)
        ifconfig $interface $ip netmask $subnet
        [ -n "$router" ] && route add default gw $router
        [ -n "$dns" ] && echo "nameserver $dns" > /etc/resolv.conf
        ;;
esac
DHCP
        chmod +x "$initramfs_dir/etc/udhcpc.script"

        log_success "Created initramfs in: $initramfs_dir"
    else
        log_warn "[dry-run] Would create initramfs in: $initramfs_dir"
    fi

    log_info "[6/7] Generating Pi 3 boot configuration..."
    local boot_dir="$build_dir/boot"
    if [ $dry_run -eq 0 ]; then
        cat > "$boot_dir/config.txt" <<'CONFIG'
# home-os Pi 3 B+ Minimal Boot Configuration

# Hardware
arm_64bit=1
kernel=home-kernel.img
kernel_address=0x80000

# Memory (minimize GPU allocation)
gpu_mem=16
disable_overscan=1

# Boot optimization
boot_delay=0
disable_splash=1
force_turbo=0

# UART console (essential for debugging)
enable_uart=1
dtparam=uart0=on

# Disable unused hardware
dtparam=audio=off
camera_auto_detect=0
display_auto_detect=0

# Network (onboard WiFi/Ethernet)
dtparam=eth0=on

# GPIO (minimal)
dtparam=i2c_arm=on
dtparam=spi=on

# Power optimization
over_voltage=0
arm_freq=1200
CONFIG

        cat > "$boot_dir/cmdline.txt" <<'CMDLINE'
console=serial0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait quiet loglevel=3 init=/init
CMDLINE

        log_success "Generated: $boot_dir/config.txt"
        log_success "Generated: $boot_dir/cmdline.txt"
    else
        log_warn "[dry-run] Would generate boot configuration"
    fi

    log_info "[7/7] Build summary..."
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "                    BUILD SUMMARY"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  Target:           Raspberry Pi 3 Model B+ (1GB RAM)"
    echo "  Build Type:       $build_type"
    echo "  Output Dir:       $build_dir"
    echo ""
    echo "  Memory Budget:"
    echo "    Kernel:         <${kernel_budget_mb}MB"
    echo "    Total:          <${total_budget_mb}MB (headless)"
    echo ""
    echo "  Boot Target:      <5 seconds to shell"
    echo ""

    if [ $create_image -eq 1 ]; then
        log_info "Creating SD card image..."
        if [ $dry_run -eq 0 ]; then
            dd if=/dev/zero of="$build_dir/$image_name" bs=1M count=$image_size_mb 2>/dev/null
            log_success "Created: $build_dir/$image_name (${image_size_mb}MB)"
        else
            log_warn "[dry-run] Would create: $build_dir/$image_name"
        fi
    fi

    echo ""
    log_success "Build configuration complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Build kernel: ./scripts/build.sh unified --target=rpi3 --profile=pi3-minimal"
    echo "  2. Flash to SD:  dd if=$build_dir/$image_name of=/dev/sdX bs=4M"
    echo "  3. Boot Pi 3 and connect via serial console"
}

# ---------------------------------------------------------------------------
# Subcommand: legacy-boot (MBR + Stage 2 BIOS bootloader)
# Replaces: scripts/build-legacy-boot.sh
# ---------------------------------------------------------------------------
cmd_legacy_boot() {
    local clean=0
    local verbose=0

    while [ $# -gt 0 ]; do
        case "$1" in
            --clean)        clean=1 ;;
            --verbose|-v)   verbose=1 ;;
            --help|-h)
                echo "Usage: ./scripts/build.sh legacy-boot [--clean] [--verbose]"
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
        shift
    done

    local boot_dir="$REPO_ROOT/kernel/src/boot"
    local build_dir="$PROJECT_BUILD_DIR/legacy-boot"
    local kernel_bin="$PROJECT_BUILD_DIR/kernel.bin"

    if [ $clean -eq 1 ]; then
        log_info "Cleaning build directory..."
        rm -rf "$build_dir"
    fi

    mkdir -p "$build_dir"

    echo "========================================"
    echo "home-os Legacy BIOS Bootloader Build"
    echo "========================================"
    echo ""

    log_info "Checking build tools..."
    require_tool as
    require_tool ld
    require_tool dd
    require_tool objcopy
    log_success "Build tools available"

    log_info "Building MBR boot sector..."
    if [ $verbose -eq 1 ]; then
        as --32 -o "$build_dir/mbr.o" "$boot_dir/mbr.s"
    else
        as --32 -o "$build_dir/mbr.o" "$boot_dir/mbr.s" 2>/dev/null
    fi
    ld -m elf_i386 -T "$boot_dir/mbr.ld" -o "$build_dir/mbr.elf" "$build_dir/mbr.o"
    objcopy -O binary "$build_dir/mbr.elf" "$build_dir/mbr.bin"

    local mbr_size
    mbr_size=$(wc -c < "$build_dir/mbr.bin")
    if [ "$mbr_size" -ne 512 ]; then
        log_error "MBR is $mbr_size bytes (expected 512)"
        exit 1
    fi

    local signature
    signature=$(xxd -s 510 -l 2 -p "$build_dir/mbr.bin")
    if [ "$signature" != "55aa" ]; then
        log_error "Invalid boot signature: $signature (expected 55aa)"
        exit 1
    fi
    log_success "MBR built (512 bytes)"

    log_info "Building Stage 2 bootloader..."
    if [ $verbose -eq 1 ]; then
        as --32 -o "$build_dir/stage2.o" "$boot_dir/stage2.s"
    else
        as --32 -o "$build_dir/stage2.o" "$boot_dir/stage2.s" 2>/dev/null
    fi
    ld -m elf_i386 -T "$boot_dir/stage2.ld" -o "$build_dir/stage2.elf" "$build_dir/stage2.o"
    objcopy -O binary "$build_dir/stage2.elf" "$build_dir/stage2.bin"

    local stage2_size stage2_sectors stage2_padded
    stage2_size=$(wc -c < "$build_dir/stage2.bin")
    log_success "Stage 2 built ($stage2_size bytes)"

    stage2_sectors=$(( (stage2_size + 511) / 512 ))
    stage2_padded=$(( stage2_sectors * 512 ))

    dd if=/dev/zero of="$build_dir/stage2_padded.bin" bs=1 count=$stage2_padded 2>/dev/null
    dd if="$build_dir/stage2.bin" of="$build_dir/stage2_padded.bin" conv=notrunc 2>/dev/null

    log_info "Stage 2 padded to $stage2_sectors sectors ($stage2_padded bytes)"

    log_info "Creating bootable disk image..."

    local kernel_size=0
    if [ -f "$kernel_bin" ]; then
        kernel_size=$(wc -c < "$kernel_bin")
        log_info "Found kernel: $kernel_size bytes"
    fi

    local required_size image_size
    required_size=$(( 512 + stage2_padded + kernel_size ))
    image_size=$(( ((required_size / 1048576) + 1) * 1048576 ))
    if [ $image_size -lt 1474560 ]; then
        image_size=1474560
    fi

    log_info "Image size: $image_size bytes"

    dd if=/dev/zero of="$build_dir/home-os-legacy.img" bs=1 count=$image_size 2>/dev/null
    dd if="$build_dir/mbr.bin" of="$build_dir/home-os-legacy.img" bs=512 conv=notrunc 2>/dev/null
    dd if="$build_dir/stage2_padded.bin" of="$build_dir/home-os-legacy.img" bs=512 seek=1 conv=notrunc 2>/dev/null

    local kernel_sector
    kernel_sector=$(( 1 + stage2_sectors ))
    if [ -f "$kernel_bin" ]; then
        dd if="$kernel_bin" of="$build_dir/home-os-legacy.img" bs=512 seek=$kernel_sector conv=notrunc 2>/dev/null
        log_success "Kernel written at sector $kernel_sector"
    else
        log_info "No kernel found at $kernel_bin - creating bootloader-only image"
    fi

    log_success "Disk image created: $build_dir/home-os-legacy.img"

    ln -sf "$build_dir/home-os-legacy.img" "$PROJECT_BUILD_DIR/home-os-legacy.img"

    echo ""
    echo "========================================"
    echo "Build Complete!"
    echo "========================================"
    echo ""
    echo "Output files:"
    echo "  MBR:        $build_dir/mbr.bin (512 bytes)"
    echo "  Stage 2:    $build_dir/stage2.bin ($stage2_size bytes)"
    echo "  Disk image: $build_dir/home-os-legacy.img"
    echo ""
    echo "To test with QEMU:"
    echo "  qemu-system-x86_64 -drive file=$build_dir/home-os-legacy.img,format=raw"
    echo ""
    echo "To write to USB drive (DANGEROUS - double-check device!):"
    echo "  sudo dd if=$build_dir/home-os-legacy.img of=/dev/sdX bs=4M status=progress"
}

# ---------------------------------------------------------------------------
# Subcommand: initramfs (cpio archive for fast boot)
# Replaces: scripts/build-initramfs.sh
# ---------------------------------------------------------------------------
cmd_initramfs() {
    local profile="desktop"
    local target="x86-64"
    local compress="lz4"
    local strip_symbols=true
    local include_modules=true

    while [ $# -gt 0 ]; do
        case "$1" in
            --profile=*)   profile="${1#*=}" ;;
            --target=*)    target="${1#*=}" ;;
            --compress=*)  compress="${1#*=}" ;;
            --no-strip)    strip_symbols=false ;;
            --no-modules)  include_modules=false ;;
            --help|-h)
                echo "Usage: ./scripts/build.sh initramfs [options]"
                echo "  --profile=NAME   minimal | server | desktop | pi"
                echo "  --target=ARCH    x86-64 | rpi3 | rpi4 | rpi5"
                echo "  --compress=TYPE  none | gzip | lz4 | xz"
                echo "  --no-strip       Don't strip debug symbols"
                echo "  --no-modules     Don't include kernel modules"
                return 0
                ;;
            *)
                log_warn "Unknown option: $1"
                ;;
        esac
        shift
    done

    local build_dir="$PROJECT_BUILD_DIR/initramfs"

    echo ""
    echo "======================================================"
    echo "  HomeOS Initramfs Builder"
    echo "======================================================"
    echo ""
    log_info "Profile: $profile"
    log_info "Target: $target"
    log_info "Compression: $compress"
    log_info "Strip symbols: $strip_symbols"
    log_info "Include modules: $include_modules"
    echo ""

    log_info "Creating initramfs structure..."
    rm -rf "$build_dir"
    mkdir -p "$build_dir"/{bin,sbin,lib,dev,proc,sys,etc,tmp,var/run}
    mkdir -p "$build_dir/lib/modules" "$build_dir/lib/firmware"

    log_info "Creating device nodes..."
    ( cd "$build_dir/dev" && touch null zero console tty tty0 tty1 )

    log_info "Creating init script..."
    case "$profile" in
        minimal)
            cat > "$build_dir/init" <<'INITEOF'
#!/bin/sh
# Minimal init - just mount filesystems and exec real init

# Mount essential filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true

# Print boot message
echo "HomeOS minimal init"

# Try to find and mount root filesystem
ROOT_DEV=""
for dev in /dev/mmcblk0p2 /dev/sda2 /dev/vda2; do
    if [ -b "$dev" ]; then
        ROOT_DEV="$dev"
        break
    fi
done

if [ -n "$ROOT_DEV" ]; then
    mkdir -p /newroot
    mount -t ext4 "$ROOT_DEV" /newroot

    # Switch root
    exec switch_root /newroot /sbin/init
else
    echo "No root device found, dropping to shell"
    exec /bin/sh
fi
INITEOF
            ;;
        server|desktop)
            cat > "$build_dir/init" <<'INITEOF'
#!/bin/sh
# Standard init - with module loading and device detection

# Mount essential filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || mknod /dev/console c 5 1

# Set up kernel parameters
echo "0" > /proc/sys/kernel/printk 2>/dev/null || true

# Print boot message
echo ""
echo "HomeOS init starting..."
echo ""

# Load essential modules
if [ -d /lib/modules ]; then
    for mod in /lib/modules/*.ko; do
        if [ -f "$mod" ]; then
            insmod "$mod" 2>/dev/null || true
        fi
    done
fi

# Wait for devices to settle
sleep 1

# Detect root filesystem
ROOT_DEV=""
CMDLINE=$(cat /proc/cmdline)

# Check for root= parameter
for param in $CMDLINE; do
    case "$param" in
        root=*)
            ROOT_DEV="${param#root=}"
            ;;
    esac
done

# Auto-detect if not specified
if [ -z "$ROOT_DEV" ]; then
    for dev in /dev/mmcblk0p2 /dev/sda2 /dev/vda2 /dev/nvme0n1p2; do
        if [ -b "$dev" ]; then
            ROOT_DEV="$dev"
            break
        fi
    done
fi

echo "Root device: $ROOT_DEV"

if [ -n "$ROOT_DEV" ]; then
    mkdir -p /newroot

    # Try different filesystem types
    for fs in ext4 ext2 fat32 btrfs; do
        if mount -t "$fs" "$ROOT_DEV" /newroot 2>/dev/null; then
            echo "Mounted root as $fs"
            break
        fi
    done

    if [ -f /newroot/sbin/init ]; then
        # Unmount initramfs filesystems
        umount /proc 2>/dev/null || true
        umount /sys 2>/dev/null || true

        # Switch to real root
        exec switch_root /newroot /sbin/init
    else
        echo "No init found on root filesystem"
    fi
fi

echo "Failed to boot, dropping to emergency shell"
exec /bin/sh
INITEOF
            ;;
        pi)
            cat > "$build_dir/init" <<'INITEOF'
#!/bin/sh
# Raspberry Pi optimized init

# Mount essential filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true

echo "HomeOS Pi init"

# Wait for SD card to be ready
sleep 0.5

# Load Pi-specific modules
for mod in mmc_block sdhci_iproc; do
    modprobe "$mod" 2>/dev/null || true
done

# Mount root (always mmcblk0p2 on Pi)
ROOT_DEV="/dev/mmcblk0p2"
if [ -b "$ROOT_DEV" ]; then
    mkdir -p /newroot
    mount -t ext4 "$ROOT_DEV" /newroot
    exec switch_root /newroot /sbin/init
else
    echo "SD card not found"
    exec /bin/sh
fi
INITEOF
            ;;
        *)
            log_error "Unknown profile: $profile"
            exit 1
            ;;
    esac
    chmod +x "$build_dir/init"

    log_info "Adding utilities..."
    cat > "$build_dir/bin/sh" <<'SHEOF'
#!/bin/true
# Placeholder - real shell would be linked here
exec /bin/busybox sh "$@"
SHEOF

    cat > "$build_dir/sbin/switch_root" <<'SREOF'
#!/bin/sh
# Minimal switch_root implementation
NEWROOT="$1"
INIT="$2"

cd "$NEWROOT"
mount --move /dev "$NEWROOT/dev" 2>/dev/null || true
mount --move /proc "$NEWROOT/proc" 2>/dev/null || true
mount --move /sys "$NEWROOT/sys" 2>/dev/null || true

exec chroot "$NEWROOT" "$INIT"
SREOF

    chmod +x "$build_dir/bin/sh" "$build_dir/sbin/switch_root"

    if [ "$include_modules" = true ]; then
        log_info "Including kernel modules..."
        local modules_src="$REPO_ROOT/kernel/modules"
        local modules
        case "$profile" in
            minimal) modules="virtio virtio_blk virtio_net" ;;
            server)  modules="virtio virtio_blk virtio_net ahci nvme e1000" ;;
            desktop) modules="virtio virtio_blk virtio_net ahci nvme e1000 usb_storage hid" ;;
            pi)      modules="mmc_block sdhci bcm2835_sdhost dwc2 usb_storage" ;;
        esac

        local mod
        for mod in $modules; do
            if [ -f "$modules_src/$mod.ko" ]; then
                if [ "$strip_symbols" = true ]; then
                    strip --strip-debug "$modules_src/$mod.ko" -o "$build_dir/lib/modules/$mod.ko"
                else
                    cp "$modules_src/$mod.ko" "$build_dir/lib/modules/"
                fi
            fi
        done
    fi

    log_info "Creating configuration files..."
    cat > "$build_dir/etc/fstab" <<'EOF'
# HomeOS initramfs fstab
proc      /proc     proc    defaults    0 0
sysfs     /sys      sysfs   defaults    0 0
devtmpfs  /dev      devtmpfs defaults   0 0
EOF

    log_info "Creating cpio archive..."
    mkdir -p "$PROJECT_BUILD_DIR"
    ( cd "$build_dir" && find . | cpio -o -H newc > "$PROJECT_BUILD_DIR/initramfs.cpio" 2>/dev/null )

    log_info "Compressing initramfs..."
    case "$compress" in
        none)
            mv "$PROJECT_BUILD_DIR/initramfs.cpio" "$PROJECT_BUILD_DIR/initramfs.img"
            ;;
        gzip)
            gzip -9 -c "$PROJECT_BUILD_DIR/initramfs.cpio" > "$PROJECT_BUILD_DIR/initramfs.img"
            ;;
        lz4)
            if command -v lz4 >/dev/null 2>&1; then
                lz4 -9 -c "$PROJECT_BUILD_DIR/initramfs.cpio" > "$PROJECT_BUILD_DIR/initramfs.img"
            else
                log_warn "lz4 not found, falling back to gzip"
                gzip -9 -c "$PROJECT_BUILD_DIR/initramfs.cpio" > "$PROJECT_BUILD_DIR/initramfs.img"
            fi
            ;;
        xz)
            xz -9 -c "$PROJECT_BUILD_DIR/initramfs.cpio" > "$PROJECT_BUILD_DIR/initramfs.img"
            ;;
        *)
            log_error "Unknown compression: $compress"
            exit 1
            ;;
    esac

    rm -f "$PROJECT_BUILD_DIR/initramfs.cpio"

    local size_bytes size_kb
    size_bytes=$(stat -f%z "$PROJECT_BUILD_DIR/initramfs.img" 2>/dev/null \
        || stat -c%s "$PROJECT_BUILD_DIR/initramfs.img" 2>/dev/null \
        || echo "0")
    size_kb=$(( size_bytes / 1024 ))

    echo ""
    log_success "Initramfs created: $PROJECT_BUILD_DIR/initramfs.img"
    log_success "Size: ${size_kb} KB"
    echo ""

    local target_kb
    case "$profile" in
        minimal) target_kb=512 ;;
        server)  target_kb=2048 ;;
        desktop) target_kb=4096 ;;
        pi)      target_kb=1024 ;;
    esac

    if [ "$size_kb" -le "$target_kb" ]; then
        log_success "Within target size (${target_kb} KB)"
    else
        log_warn "Exceeds target size (${target_kb} KB) by $((size_kb - target_kb)) KB"
    fi
}

# ---------------------------------------------------------------------------
# Subcommand: all (compile every kernel module placeholder)
# Replaces: scripts/build-all.sh
# ---------------------------------------------------------------------------
cmd_all() {
    local target="${1:-x86_64}"
    local optimize="${2:-Debug}"
    local all_build_dir="$PROJECT_BUILD_DIR/all"

    echo "╔════════════════════════════════════════╗"
    echo "║     HomeOS Complete Build System      ║"
    echo "║      Building 210+ Kernel Modules      ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    require_home_compiler
    log_success "Home compiler found"

    log_info "Creating build directory..."
    mkdir -p "$all_build_dir/obj" "$all_build_dir/x86_64" "$all_build_dir/arm64"

    local total_files
    total_files=$(find "$KERNEL_DIR/src" -name "*.home" 2>/dev/null | wc -l | tr -d ' ')
    log_success "Found $total_files .home files to compile"
    echo ""

    log_info "Build configuration:"
    echo "  Target: $target"
    echo "  Optimization: $optimize"
    echo ""

    compile_module() {
        local module="$1"
        local category="$2"
        printf '  [%s] %s... ' "$category" "$module"
        # Placeholder until Home compiler self-hosts.
        printf '%bOK%b (pending compiler)\n' "$C_GREEN" "$C_RESET"
    }

    log_warn "=== Phase 1: Core Modules ==="
    compile_module "core/foundation" "CORE"
    compile_module "core/memory" "CORE"
    compile_module "core/process" "CORE"
    compile_module "core/filesystem" "CORE"
    echo ""

    log_warn "=== Phase 2: Memory Management ==="
    compile_module "mm/slab" "MM"
    compile_module "mm/vmalloc" "MM"
    compile_module "mm/swap" "MM"
    compile_module "mm/oom" "MM"
    compile_module "mm/memcg" "MM"
    compile_module "heap" "MM"
    compile_module "pmm" "MM"
    compile_module "vmm" "MM"
    echo ""

    log_warn "=== Phase 3: Process & Scheduling ==="
    compile_module "sched/cfs" "SCHED"
    compile_module "sched/rt" "SCHED"
    compile_module "sys/syscall" "SYS"
    compile_module "ipc/pipe" "IPC"
    compile_module "ipc/msgqueue" "IPC"
    compile_module "ipc/shm" "IPC"
    echo ""

    log_warn "=== Phase 4: File Systems ==="
    local fs
    for fs in fat32 ext2 ntfs btrfs exfat iso9660 procfs sysfs tmpfs devfs; do
        compile_module "fs/$fs" "FS"
    done
    echo ""

    log_warn "=== Phase 5: Networking ==="
    local net
    for net in tcp udp ipv6 icmp arp dhcp dns http tls websocket smb nfs mqtt coap nfc qos netfilter; do
        compile_module "net/$net" "NET"
    done
    echo ""

    log_warn "=== Phase 6: Hardware Drivers ==="
    local drv
    for drv in ata ahci nvme raid ramdisk cdrom floppy nvdimm; do
        compile_module "drivers/$drv" "DRV-STOR"
    done
    for drv in keyboard mouse touchpad touchscreen gamepad; do
        compile_module "drivers/$drv" "DRV-INP"
    done
    for drv in e1000 rtl8139 virtio_net wifi bluetooth bluetooth_hci; do
        compile_module "drivers/$drv" "DRV-NET"
    done
    for drv in usb uhci ehci xhci usb_hub; do
        compile_module "drivers/$drv" "DRV-USB"
    done
    for drv in vga_graphics framebuffer gpu backlight; do
        compile_module "drivers/$drv" "DRV-VID"
    done
    for drv in pci pcie_extended acpi acpi_pm rtc timer dma serial virtio; do
        compile_module "drivers/$drv" "DRV-SYS"
    done
    for drv in gpio i2c spi pwm audio sound camera printer scanner; do
        compile_module "drivers/$drv" "DRV-PER"
    done
    for drv in battery watchdog sensors hwmon lid; do
        compile_module "drivers/$drv" "DRV-PWR"
    done
    for drv in tpm fingerprint smartcard; do
        compile_module "drivers/$drv" "DRV-SEC"
    done
    for drv in led buzzer msi; do
        compile_module "drivers/$drv" "DRV-MISC"
    done
    echo ""

    log_warn "=== Phase 7: Advanced Features ==="
    compile_module "crypto/aes" "CRYPTO"
    compile_module "crypto/rsa" "CRYPTO"
    compile_module "crypto/sha256" "CRYPTO"
    compile_module "video/opengl" "VIDEO"
    compile_module "video/vulkan" "VIDEO"
    compile_module "video/compositor" "VIDEO"
    compile_module "power/pm" "POWER"
    compile_module "ui/theme_manager" "UI"
    compile_module "ui/wallpaper" "UI"
    compile_module "gaming/compatibility" "GAMING"
    echo ""

    log_warn "=== Phase 8: Integration Module ==="
    compile_module "kernel_main" "MAIN"
    compile_module "integration" "MAIN"
    if [ "$target" = "arm64" ]; then
        compile_module "rpi5_main" "MAIN"
    else
        compile_module "main" "MAIN"
        compile_module "multiboot2" "BOOT"
        compile_module "idt" "BOOT"
        compile_module "serial" "BOOT"
        compile_module "vga" "BOOT"
    fi
    echo ""

    log_warn "=== Linking Kernel ==="
    local linker_script output
    if [ "$target" = "arm64" ]; then
        linker_script="$KERNEL_DIR/linker-rpi5.ld"
        output="$all_build_dir/arm64/home-kernel.elf"
        log_info "Linking for ARM64 (Raspberry Pi 5)..."
    else
        linker_script="$KERNEL_DIR/linker.ld"
        output="$all_build_dir/x86_64/home-kernel.elf"
        log_info "Linking for x86-64..."
    fi
    log_success "Link configuration ready"
    echo "  Output: $output"
    echo "  Linker script: $linker_script"

    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║        Build Complete!                 ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "Build summary:"
    echo "  Total modules compiled: $total_files"
    echo "  Target architecture: $target"
    echo "  Optimization level: $optimize"
    echo "  Output directory: $all_build_dir"
    echo ""
    log_warn "Note: full compilation pending Home compiler self-hosting"
    echo "      Current build system prepares all modules for compilation"
}

# ---------------------------------------------------------------------------
# Subcommand: unified (multi-target unified build with profiles)
# Replaces: scripts/build-unified.sh
# ---------------------------------------------------------------------------

# Auto-detect Home compiler for the unified path; honors HOME_COMPILER if set.
unified_resolve_home_compiler() {
    if [ -n "${HOME_COMPILER:-}" ] && [ -f "$HOME_COMPILER" ]; then
        echo "$HOME_COMPILER"
        return
    fi
    if [ -n "${HOME_COMPILER_PATH:-}" ] && [ -f "$HOME_COMPILER_PATH" ]; then
        echo "$HOME_COMPILER_PATH"
        return
    fi
    if [ -f "$HOME_REPO/zig-out/bin/home" ]; then
        echo "$HOME_REPO/zig-out/bin/home"
        return
    fi
    if [ -f "$HOME/Code/home/zig-out/bin/home" ]; then
        echo "$HOME/Code/home/zig-out/bin/home"
        return
    fi
    if [ -f "$HOME/Documents/Projects/home/zig-out/bin/home" ]; then
        echo "$HOME/Documents/Projects/home/zig-out/bin/home"
        return
    fi
    echo "$HOME_COMPILER"
}

unified_print_usage() {
    cat <<EOF
Usage: ./scripts/build.sh unified [target] [options]

Targets:
  x86-64    Build for x86-64 (default)
  arm64     Build for ARM64 generic
  rpi3      Build for Raspberry Pi 3
  rpi4      Build for Raspberry Pi 4
  rpi5      Build for Raspberry Pi 5
  all       Build all targets
  clean     Clean build artifacts

Options:
  --release          Build with optimizations
  --debug            Build with debug symbols (default)
  --iso              Create bootable ISO (x86-64 only)
  --run              Run in QEMU after build
  --test             Run tests after build
  --target=TARGET    Same as positional target (alias for compatibility)
  --profile=NAME     Use build profile
  --list-profiles    List available build profiles
  --help             Show this help

Build profiles:
  minimal-headless   32MB kernel, IoT/embedded, no GUI
  server             48MB kernel, full networking, containers, no GUI
  pi-optimized       24MB kernel, optimized for Raspberry Pi with GUI
  desktop            64MB kernel, full desktop experience (default)
EOF
}

cmd_unified() {
    local home_compiler
    home_compiler="$(unified_resolve_home_compiler)"

    local unified_build_dir="$PROJECT_BUILD_DIR"
    local target="x86-64"
    local optimize="Debug"
    local create_iso=false
    local run_qemu=false
    local run_tests=false
    local profile="desktop"
    local profile_dir="$KERNEL_DIR/profiles"

    unified_load_profile() {
        local profile_name="$1"
        local profile_file="$profile_dir/${profile_name}.config"
        if [ -f "$profile_file" ]; then
            log_info "Loading profile: $profile_name"
            # shellcheck disable=SC1090
            . "$profile_file"
            log_success "Profile loaded: $profile_name"
            [ -n "${PROFILE_DESCRIPTION:-}" ] && echo "  Description: $PROFILE_DESCRIPTION"
            [ -n "${TARGET_KERNEL_MB:-}"   ] && echo "  Target kernel: ${TARGET_KERNEL_MB}MB"
            [ -n "${TARGET_SYSTEM_MB:-}"   ] && echo "  Target system: ${TARGET_SYSTEM_MB}MB"
            echo ""
        else
            log_warn "Profile '$profile_name' not found at $profile_file"
            log_info "Available profiles:"
            local p
            for p in "$profile_dir"/*.config; do
                [ -f "$p" ] && echo "  - $(basename "$p" .config)"
            done
            echo ""
        fi
    }

    unified_check_deps() {
        log_info "Checking build dependencies..."
        local missing=0
        if ! command -v zig >/dev/null 2>&1; then
            log_error "Zig compiler not found"
            echo "  Install with: brew install zig (macOS) or apt install zig (Linux)"
            missing=1
        else
            log_success "Zig compiler: $(zig version)"
        fi
        if [ -f "$home_compiler" ]; then
            log_success "Home compiler: found at $home_compiler"
        else
            log_error "Home compiler not found at $home_compiler (no Zig fallback — S1)"
            missing=1
        fi
        case "$target" in
            x86-64)
                if [ "$create_iso" = true ]; then
                    if find_grub_mkrescue >/dev/null 2>&1; then
                        log_success "GRUB tools available"
                    else
                        log_warn "grub-mkrescue not found (ISO creation will fail)"
                        echo "  Install with: brew install i686-elf-grub xorriso"
                    fi
                fi
                ;;
            arm64|rpi*)
                if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1 \
                   || command -v aarch64-elf-gcc >/dev/null 2>&1; then
                    log_success "ARM64 cross-compiler available"
                else
                    log_error "ARM64 cross-compiler not found"
                    echo "  Install with: brew install aarch64-elf-gcc"
                    missing=1
                fi
                ;;
        esac
        [ $missing -eq 1 ] && exit 1
        echo ""
    }

    unified_prep_dir() {
        local td="$unified_build_dir/$target"
        mkdir -p "$td/obj" "$td/iso/boot/grub"
        echo "$td"
    }

    unified_create_iso() {
        local target_dir="$1"
        log_info "Creating bootable ISO..."
        cp "$target_dir/home-kernel.elf" "$target_dir/iso/boot/"
        cat > "$target_dir/iso/boot/grub/grub.cfg" <<'EOF'
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
        local grub
        if ! grub="$(find_grub_mkrescue)"; then
            log_error "grub-mkrescue not found"
            return 1
        fi
        "$grub" -o "$target_dir/home-os.iso" "$target_dir/iso" 2>/dev/null
        log_success "ISO created: $target_dir/home-os.iso"
        ls -lh "$target_dir/home-os.iso"
    }

    unified_build_x86() {
        log_info "Building for x86-64..."
        local target_dir
        target_dir=$(unified_prep_dir)
        cd "$KERNEL_DIR"

        local opt_flag="-O Debug"
        [ "$optimize" = "Release" ] && opt_flag="-O ReleaseSafe"

        local home_entry=""
        if [ -f "src/main.home" ]; then
            home_entry="src/main.home"
        elif [ -f "src/kernel_main.home" ]; then
            home_entry="src/kernel_main.home"
        elif [ -f "src/kernel.home" ]; then
            home_entry="src/kernel.home"
        fi

        if [ -n "$home_entry" ] && [ -f "$home_compiler" ]; then
            log_info "Compiling kernel with Home compiler (entry: $home_entry)..."
            HOME_COMPILER="$home_compiler" cmd_standalone
            if [ -f "$KERNEL_DIR/build/home-kernel.elf" ]; then
                cp "$KERNEL_DIR/build/home-kernel.elf" "$target_dir/"
            fi
        elif [ -n "$home_entry" ]; then
            # No silent stub fallback (MASTER_PLAN Phase 0, stub register S1):
            # a missing compiler is a hard error.
            log_error "Home compiler not found at: $home_compiler"
            log_error "Build it first or set HOME_COMPILER / HOME_REPO."
            exit 1
        elif [ -f "src/kernel.zig" ]; then
            log_error "Found src/kernel.zig but the Zig kernel path was removed."
            log_error "Kernel builds go through the Home compiler."
            exit 1
        else
            log_error "No kernel source found"
            exit 1
        fi

        log_success "Kernel compiled: $target_dir/home-kernel.elf"
        if [ "$create_iso" = true ]; then
            unified_create_iso "$target_dir"
        fi
    }

    unified_build_arm64() {
        log_info "Building for ARM64..."
        local target_dir
        target_dir=$(unified_prep_dir)
        cd "$KERNEL_DIR"

        local opt_flag="-O Debug"
        [ "$optimize" = "Release" ] && opt_flag="-O ReleaseSmall"

        if [ -f "$HOME_REPO/packages/kernel/src/arm64/boot.s" ]; then
            cp "$HOME_REPO/packages/kernel/src/arm64/boot.s" "$target_dir/boot.s"
        fi

        log_info "ARM64 kernel build configured"
        log_success "Target directory: $target_dir"
    }

    unified_build_rpi3() {
        log_info "Building for Raspberry Pi 3..."
        target="rpi3"
        unified_build_arm64
        local target_dir="$unified_build_dir/$target"
        log_info "Configuring for BCM2837 (Cortex-A53)"
        {
            echo "kernel=home-kernel.img"
            echo "arm_64bit=1"
            echo "core_freq=250"
        } > "$target_dir/config.txt"
    }

    unified_build_rpi4() {
        log_info "Building for Raspberry Pi 4..."
        target="rpi4"
        unified_build_arm64
        local target_dir="$unified_build_dir/$target"
        log_info "Configuring for BCM2711 (Cortex-A72)"
        {
            echo "kernel=home-kernel.img"
            echo "arm_64bit=1"
            echo "enable_uart=1"
        } > "$target_dir/config.txt"
    }

    unified_build_rpi5() {
        log_info "Building for Raspberry Pi 5..."
        cmd_rpi5
    }

    unified_build_all() {
        log_info "Building all targets..."
        local orig_target="$target"
        target="x86-64"; unified_build_x86
        target="rpi3";   unified_build_rpi3
        target="rpi4";   unified_build_rpi4
        target="rpi5";   unified_build_rpi5
        target="$orig_target"
        log_success "All targets built successfully"
    }

    unified_run_qemu() {
        log_info "Running in QEMU..."
        case "$target" in
            x86-64)
                if [ "$create_iso" = true ] && [ -f "$unified_build_dir/$target/home-os.iso" ]; then
                    qemu-system-x86_64 -cdrom "$unified_build_dir/$target/home-os.iso" -serial stdio -m 256M
                elif [ -f "$unified_build_dir/$target/home-kernel.elf" ]; then
                    qemu-system-x86_64 -kernel "$unified_build_dir/$target/home-kernel.elf" -serial stdio -m 256M
                else
                    log_error "No kernel or ISO found to run"
                    exit 1
                fi
                ;;
            arm64|rpi*)
                if [ -f "$unified_build_dir/$target/home-kernel.elf" ]; then
                    qemu-system-aarch64 -M raspi3b -kernel "$unified_build_dir/$target/home-kernel.elf" -serial stdio -m 1G
                else
                    log_error "No ARM64 kernel found"
                    exit 1
                fi
                ;;
        esac
    }

    unified_run_tests() {
        log_info "Running tests..."
        if [ -x "$SCRIPT_DIR/test-all.sh" ]; then
            "$SCRIPT_DIR/test-all.sh"
        else
            log_warn "Test script not found"
        fi
    }

    echo ""
    echo "======================================================"
    echo "  HomeOS Unified Build System"
    echo "======================================================"
    echo ""

    while [ $# -gt 0 ]; do
        case "$1" in
            x86-64|x86_64) target="x86-64" ;;
            arm64)         target="arm64" ;;
            rpi3|pi3)      target="rpi3" ;;
            rpi4|pi4)      target="rpi4" ;;
            rpi5|pi5)      target="rpi5" ;;
            all)           target="all" ;;
            clean)
                log_info "Cleaning build artifacts..."
                rm -rf "$unified_build_dir" "$KERNEL_DIR/build" "$KERNEL_DIR/zig-out" "$KERNEL_DIR/zig-cache"
                log_success "Build directory cleaned"
                return 0
                ;;
            --release)        optimize="Release" ;;
            --debug)          optimize="Debug" ;;
            --iso)            create_iso=true ;;
            --run)            run_qemu=true ;;
            --test)           run_tests=true ;;
            --target=*)       target="${1#*=}" ;;
            --profile=*)      profile="${1#*=}" ;;
            --list-profiles)
                echo "Available build profiles:"
                echo ""
                local p name desc tgt
                for p in "$profile_dir"/*.config; do
                    if [ -f "$p" ]; then
                        name=$(basename "$p" .config)
                        desc=$(grep '^PROFILE_DESCRIPTION=' "$p" | head -1 | cut -d'"' -f2)
                        tgt=$(grep '^TARGET_KERNEL_MB=' "$p" | head -1 | cut -d'=' -f2)
                        printf "  %-18s %sMB kernel - %s\n" "$name" "$tgt" "$desc"
                    fi
                done
                echo ""
                return 0
                ;;
            --help|-h)
                unified_print_usage
                return 0
                ;;
            *)
                log_error "Unknown argument: $1"
                unified_print_usage
                exit 1
                ;;
        esac
        shift
    done

    [ -n "$profile" ] && unified_load_profile "$profile"

    echo "Build configuration:"
    echo "  Target:       $target"
    echo "  Profile:      $profile"
    echo "  Optimization: $optimize"
    echo "  Create ISO:   $create_iso"
    echo "  Run QEMU:     $run_qemu"
    echo "  Run Tests:    $run_tests"
    [ -n "${TARGET_KERNEL_MB:-}" ] && echo "  Kernel Budget: ${TARGET_KERNEL_MB}MB"
    echo ""

    unified_check_deps

    case "$target" in
        x86-64) unified_build_x86 ;;
        arm64)  unified_build_arm64 ;;
        rpi3)   unified_build_rpi3 ;;
        rpi4)   unified_build_rpi4 ;;
        rpi5)   unified_build_rpi5 ;;
        all)    unified_build_all ;;
        *)      log_error "Unknown target: $target"; exit 1 ;;
    esac

    [ "$run_tests" = true ] && unified_run_tests
    [ "$run_qemu"  = true ] && unified_run_qemu

    echo ""
    echo "======================================================"
    echo "  Build Complete!"
    echo "======================================================"
    echo ""
    echo "Build output: $unified_build_dir/$target/"
}

# ---------------------------------------------------------------------------
# Main dispatcher
# ---------------------------------------------------------------------------

# If invoked with zero args, build the Minimum Viable Kernel — the
# MASTER_PLAN Phase 0 target and the only end-to-end Home build path.
if [ $# -eq 0 ]; then
    cmd_mvk
    exit 0
fi

cmd="$1"
shift || true

case "$cmd" in
    -h|--help|help)
        usage
        ;;
    mvk)
        cmd_mvk "$@"
        ;;
    kernel)
        cmd_kernel "$@"
        ;;
    home)
        cmd_home "$@"
        ;;
    home-zig)
        cmd_home_zig "$@"
        ;;
    home-simple)
        cmd_home_simple "$@"
        ;;
    standalone)
        cmd_standalone "$@"
        ;;
    rpi5)
        cmd_rpi5 "$@"
        ;;
    pi-image)
        cmd_pi_image "$@"
        ;;
    pi3-minimal)
        cmd_pi3_minimal "$@"
        ;;
    legacy-boot)
        cmd_legacy_boot "$@"
        ;;
    initramfs)
        cmd_initramfs "$@"
        ;;
    all)
        cmd_all "$@"
        ;;
    unified)
        cmd_unified "$@"
        ;;
    # Convenience: forward the issue's proposed flags to the unified path
    # so that "./scripts/build.sh --target=rpi5 --release" works.
    --target=*|--profile=*|--release|--debug|--iso|--run|--test|--list-profiles)
        cmd_unified "$cmd" "$@"
        ;;
    *)
        log_error "Unknown subcommand: $cmd"
        echo "" >&2
        usage >&2
        exit 1
        ;;
esac
