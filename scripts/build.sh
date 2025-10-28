#!/bin/bash
# Build script for home-os kernel

set -e

KERNEL_DIR="/Users/chrisbreuer/Code/home-os/kernel"
ISO_DIR="$KERNEL_DIR/iso"
BUILD_DIR="$KERNEL_DIR/build"

echo "=== Building home-os kernel ==="

# Check for Home compiler
if ! command -v home &> /dev/null; then
    echo "Error: Home compiler not found!"
    echo "Please build Home compiler first from ~/Code/home"
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"
mkdir -p "$ISO_DIR/boot/grub"

# Build kernel
cd "$KERNEL_DIR"
echo "Compiling kernel..."

# For now, use zig directly since Home compiler is still in development
# Once Home compiler is ready, switch to: home build
zig build-exe \
    src/boot.s \
    src/kernel.home \
    src/serial.home \
    src/vga.home \
    -target x86_64-freestanding \
    -O ReleaseSafe \
    --script linker.ld \
    --name home-kernel \
    -femit-bin="$BUILD_DIR/home-kernel.elf" \
    -I ../home/packages/kernel/src \
    -I ../home/packages/ffi/src \
    -I ../home/packages/basics/src

echo "Kernel compiled successfully!"

# Copy kernel to ISO directory
cp "$BUILD_DIR/home-kernel.elf" "$ISO_DIR/boot/"

# Check kernel file
ls -lh "$ISO_DIR/boot/home-kernel.elf"

# Create ISO
echo "Creating bootable ISO..."
if ! command -v grub-mkrescue &> /dev/null; then
    echo "Warning: grub-mkrescue not found. Install with:"
    echo "  macOS: brew install grub xorriso"
    echo "  Linux: sudo apt install grub-pc-bin xorriso"
    exit 1
fi

grub-mkrescue -o "$BUILD_DIR/home-os.iso" "$ISO_DIR"

echo "ISO created: $BUILD_DIR/home-os.iso"
ls -lh "$BUILD_DIR/home-os.iso"

echo ""
echo "=== Build complete! ==="
echo ""
echo "To run in QEMU:"
echo "  ./scripts/run-qemu.sh"
echo ""
echo "To run with KVM acceleration:"
echo "  ./scripts/run-qemu.sh --kvm"
echo ""
echo "To debug with GDB:"
echo "  ./scripts/run-qemu.sh --debug"
