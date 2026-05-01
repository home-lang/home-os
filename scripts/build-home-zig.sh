#!/bin/bash
# Build home-os kernel using Home compiler + Zig assembler/linker
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

echo "=== Building home-os Kernel with Home Compiler ==="
echo ""

# Check for Home compiler
if [ ! -f "$HOME_COMPILER" ]; then
    echo "Error: Home compiler not found at: $HOME_COMPILER"
    echo "Set HOME_COMPILER or HOME_REPO env vars, or build the Home compiler:"
    echo "  cd \"$HOME_REPO\" && zig build"
    exit 1
fi

# Create build directories
mkdir -p "$BUILD_DIR"
mkdir -p "$ISO_DIR/boot/grub"

cd "$KERNEL_DIR"

echo "Step 1: Compiling kernel_simple.home with Home compiler..."
"$HOME_COMPILER" build src/kernel_simple.home --kernel -o "$BUILD_DIR/kernel_main.s"
echo "✅ Home compilation complete!"
echo ""

echo "Step 2: Building kernel with Zig (assembling boot.s + kernel_main.s)..."
zig build-exe \
    src/boot.s \
    "$BUILD_DIR/kernel_main.s" \
    -target x86_64-freestanding \
    -O ReleaseSafe \
    -T linker.ld \
    --name home-kernel \
    -femit-bin="$BUILD_DIR/home-kernel.elf"

echo "✅ Kernel assembled and linked!"
ls -lh "$BUILD_DIR/home-kernel.elf"
echo ""

# Copy to ISO directory
cp "$BUILD_DIR/home-kernel.elf" "$ISO_DIR/boot/"

echo "Step 3: Creating bootable ISO..."
GRUB_MKRESCUE=""
if command -v i686-elf-grub-mkrescue &> /dev/null; then
    GRUB_MKRESCUE="i686-elf-grub-mkrescue"
elif command -v grub-mkrescue &> /dev/null; then
    GRUB_MKRESCUE="grub-mkrescue"
elif [ -f "/opt/homebrew/bin/i686-elf-grub-mkrescue" ]; then
    GRUB_MKRESCUE="/opt/homebrew/bin/i686-elf-grub-mkrescue"
else
    echo "Warning: grub-mkrescue not found"
    exit 1
fi

$GRUB_MKRESCUE -o "$BUILD_DIR/home-os.iso" "$ISO_DIR" 2>&1 | grep -v "warning:" || true

echo "✅ ISO created: $BUILD_DIR/home-os.iso"
ls -lh "$BUILD_DIR/home-os.iso"
echo ""

echo "=== Build Complete! ==="
echo ""
echo "🎉 Successfully built kernel with Home compiler!"
echo ""
echo "To run: cd \"$REPO_ROOT\" && ./scripts/run-qemu.sh"
