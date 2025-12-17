#!/bin/bash
# home-os Legacy BIOS Bootloader Build Script
#
# Builds the MBR and Stage 2 bootloader for legacy BIOS systems.
# Creates a bootable disk image that can boot without GRUB.
#
# Usage: ./scripts/build-legacy-boot.sh [--clean] [--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BOOT_DIR="$PROJECT_ROOT/kernel/src/boot"
BUILD_DIR="$PROJECT_ROOT/build/legacy-boot"
KERNEL_BIN="$PROJECT_ROOT/build/kernel.bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Options
CLEAN=0
VERBOSE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN=1
            shift
            ;;
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--clean] [--verbose]"
            exit 1
            ;;
    esac
done

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Clean build directory
if [ $CLEAN -eq 1 ]; then
    log_info "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
fi

# Create build directory
mkdir -p "$BUILD_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}home-os Legacy BIOS Bootloader Build${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check for required tools
log_info "Checking build tools..."

check_tool() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 not found. Please install it."
        exit 1
    fi
}

check_tool as
check_tool ld
check_tool dd
check_tool objcopy

log_success "Build tools available"

# Build MBR
log_info "Building MBR boot sector..."

if [ $VERBOSE -eq 1 ]; then
    as --32 -o "$BUILD_DIR/mbr.o" "$BOOT_DIR/mbr.s"
else
    as --32 -o "$BUILD_DIR/mbr.o" "$BOOT_DIR/mbr.s" 2>/dev/null
fi

ld -m elf_i386 -T "$BOOT_DIR/mbr.ld" -o "$BUILD_DIR/mbr.elf" "$BUILD_DIR/mbr.o"
objcopy -O binary "$BUILD_DIR/mbr.elf" "$BUILD_DIR/mbr.bin"

# Verify MBR is exactly 512 bytes
MBR_SIZE=$(wc -c < "$BUILD_DIR/mbr.bin")
if [ "$MBR_SIZE" -ne 512 ]; then
    log_error "MBR is $MBR_SIZE bytes (expected 512)"
    exit 1
fi

# Verify boot signature
SIGNATURE=$(xxd -s 510 -l 2 -p "$BUILD_DIR/mbr.bin")
if [ "$SIGNATURE" != "55aa" ]; then
    log_error "Invalid boot signature: $SIGNATURE (expected 55aa)"
    exit 1
fi

log_success "MBR built (512 bytes)"

# Build Stage 2
log_info "Building Stage 2 bootloader..."

if [ $VERBOSE -eq 1 ]; then
    as --32 -o "$BUILD_DIR/stage2.o" "$BOOT_DIR/stage2.s"
else
    as --32 -o "$BUILD_DIR/stage2.o" "$BOOT_DIR/stage2.s" 2>/dev/null
fi

ld -m elf_i386 -T "$BOOT_DIR/stage2.ld" -o "$BUILD_DIR/stage2.elf" "$BUILD_DIR/stage2.o"
objcopy -O binary "$BUILD_DIR/stage2.elf" "$BUILD_DIR/stage2.bin"

STAGE2_SIZE=$(wc -c < "$BUILD_DIR/stage2.bin")
log_success "Stage 2 built ($STAGE2_SIZE bytes)"

# Pad Stage 2 to sector boundary (512 bytes)
STAGE2_SECTORS=$(( (STAGE2_SIZE + 511) / 512 ))
STAGE2_PADDED=$(( STAGE2_SECTORS * 512 ))

dd if=/dev/zero of="$BUILD_DIR/stage2_padded.bin" bs=1 count=$STAGE2_PADDED 2>/dev/null
dd if="$BUILD_DIR/stage2.bin" of="$BUILD_DIR/stage2_padded.bin" conv=notrunc 2>/dev/null

log_info "Stage 2 padded to $STAGE2_SECTORS sectors ($STAGE2_PADDED bytes)"

# Create bootable disk image
log_info "Creating bootable disk image..."

# Calculate image size (MBR + Stage2 + Kernel + padding)
# Minimum 1.44MB for floppy compatibility, or larger for kernel
KERNEL_SIZE=0
if [ -f "$KERNEL_BIN" ]; then
    KERNEL_SIZE=$(wc -c < "$KERNEL_BIN")
    log_info "Found kernel: $KERNEL_SIZE bytes"
fi

# Calculate required size
REQUIRED_SIZE=$(( 512 + STAGE2_PADDED + KERNEL_SIZE ))
# Round up to nearest MB
IMAGE_SIZE=$(( ((REQUIRED_SIZE / 1048576) + 1) * 1048576 ))
# Minimum 1.44MB
if [ $IMAGE_SIZE -lt 1474560 ]; then
    IMAGE_SIZE=1474560
fi

log_info "Image size: $IMAGE_SIZE bytes"

# Create empty image
dd if=/dev/zero of="$BUILD_DIR/home-os-legacy.img" bs=1 count=$IMAGE_SIZE 2>/dev/null

# Write MBR (sector 0)
dd if="$BUILD_DIR/mbr.bin" of="$BUILD_DIR/home-os-legacy.img" bs=512 conv=notrunc 2>/dev/null

# Write Stage 2 (starting at sector 1)
dd if="$BUILD_DIR/stage2_padded.bin" of="$BUILD_DIR/home-os-legacy.img" bs=512 seek=1 conv=notrunc 2>/dev/null

# Write kernel (starting after Stage 2)
KERNEL_SECTOR=$(( 1 + STAGE2_SECTORS ))
if [ -f "$KERNEL_BIN" ]; then
    dd if="$KERNEL_BIN" of="$BUILD_DIR/home-os-legacy.img" bs=512 seek=$KERNEL_SECTOR conv=notrunc 2>/dev/null
    log_success "Kernel written at sector $KERNEL_SECTOR"
else
    log_info "No kernel found at $KERNEL_BIN - creating bootloader-only image"
fi

log_success "Disk image created: $BUILD_DIR/home-os-legacy.img"

# Create convenience symlink
ln -sf "$BUILD_DIR/home-os-legacy.img" "$PROJECT_ROOT/build/home-os-legacy.img"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Output files:"
echo "  MBR:        $BUILD_DIR/mbr.bin (512 bytes)"
echo "  Stage 2:    $BUILD_DIR/stage2.bin ($STAGE2_SIZE bytes)"
echo "  Disk image: $BUILD_DIR/home-os-legacy.img"
echo ""
echo "To test with QEMU:"
echo "  qemu-system-x86_64 -drive file=$BUILD_DIR/home-os-legacy.img,format=raw"
echo ""
echo "To write to USB drive (DANGEROUS - double-check device!):"
echo "  sudo dd if=$BUILD_DIR/home-os-legacy.img of=/dev/sdX bs=4M status=progress"
echo ""
