#!/bin/bash
# Build script for home-os kernel using Home compiler
# This builds a minimal kernel to test the Home language compiler
#
# Required env vars (with defaults):
#   HOME_REPO       Path to the Home compiler repo (default: $REPO_ROOT/../home)
#   HOME_COMPILER   Path to the Home compiler binary (default: $HOME_REPO/zig-out/bin/home)
#   KERNEL_DIR      Path to the home-os kernel dir (default: $REPO_ROOT/kernel)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

KERNEL_DIR="${KERNEL_DIR:-$REPO_ROOT/kernel}"
HOME_REPO="${HOME_REPO:-$REPO_ROOT/../home}"
ISO_DIR="${ISO_DIR:-$KERNEL_DIR/iso}"
BUILD_DIR="${BUILD_DIR:-$KERNEL_DIR/build}"
HOME_COMPILER="${HOME_COMPILER:-$HOME_REPO/zig-out/bin/home}"

echo "=== Building home-os kernel with Home Compiler ==="
echo ""

# Check for Home compiler
if [ ! -f "$HOME_COMPILER" ]; then
    echo "Error: Home compiler not found at $HOME_COMPILER"
    echo "Please build the Home compiler first:"
    echo "  cd \"$HOME_REPO\" && zig build"
    echo "Or set HOME_COMPILER / HOME_REPO env vars to point at an existing build."
    exit 1
fi

echo "Using Home compiler: $HOME_COMPILER"

# Check for assembler
if ! command -v as &> /dev/null; then
    echo "Error: GNU assembler 'as' not found!"
    exit 1
fi

# Create build directories
mkdir -p "$BUILD_DIR"
mkdir -p "$ISO_DIR/boot/grub"

cd "$KERNEL_DIR"

echo ""
echo "Step 1: Compiling kernel_simple.home to assembly..."
"$HOME_COMPILER" build src/kernel_simple.home --kernel -o "$BUILD_DIR/kernel_main.s"

echo "Home compilation successful!"
echo ""

echo "Step 2: Assembling boot.s..."
as -o "$BUILD_DIR/boot.o" src/boot.s

echo "boot.s assembled successfully!"
echo ""

echo "Step 3: Assembling kernel_main.s..."
as -o "$BUILD_DIR/kernel_main.o" "$BUILD_DIR/kernel_main.s"

echo "kernel_main.s assembled successfully!"
echo ""

echo "Step 4: Linking kernel..."
ld -n -o "$BUILD_DIR/home-kernel.elf" \
    -T linker.ld \
    "$BUILD_DIR/boot.o" \
    "$BUILD_DIR/kernel_main.o"

echo "Kernel linked successfully!"
ls -lh "$BUILD_DIR/home-kernel.elf"
echo ""

# Copy kernel to ISO directory
cp "$BUILD_DIR/home-kernel.elf" "$ISO_DIR/boot/"

echo "Step 5: Creating bootable ISO..."

# Find grub-mkrescue
GRUB_MKRESCUE=""
if command -v i686-elf-grub-mkrescue &> /dev/null; then
    GRUB_MKRESCUE="i686-elf-grub-mkrescue"
elif command -v grub-mkrescue &> /dev/null; then
    GRUB_MKRESCUE="grub-mkrescue"
elif [ -f "/opt/homebrew/bin/i686-elf-grub-mkrescue" ]; then
    GRUB_MKRESCUE="/opt/homebrew/bin/i686-elf-grub-mkrescue"
elif command -v x86_64-elf-grub-mkrescue &> /dev/null; then
    GRUB_MKRESCUE="x86_64-elf-grub-mkrescue"
else
    echo "Warning: grub-mkrescue not found. Install with:"
    echo "  macOS: brew install i686-elf-grub xorriso"
    echo "  Linux: sudo apt install grub-pc-bin xorriso"
    exit 1
fi

echo "Using: $GRUB_MKRESCUE"
$GRUB_MKRESCUE -o "$BUILD_DIR/home-os.iso" "$ISO_DIR" 2>&1 | grep -v "warning:"

echo ""
echo "ISO created: $BUILD_DIR/home-os.iso"
ls -lh "$BUILD_DIR/home-os.iso"

echo ""
echo "=== Build complete! ==="
echo ""
echo "Home compiler successfully compiled kernel!"
echo "Kernel assembled and linked!"
echo "Bootable ISO created!"
echo ""
echo "To run in QEMU:"
echo "  cd \"$REPO_ROOT\" && ./scripts/run-qemu.sh"
echo ""
