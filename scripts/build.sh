#!/bin/bash
# Build script for home-os kernel

set -e

KERNEL_DIR="/Users/chrisbreuer/Code/home-os/kernel"
ISO_DIR="$KERNEL_DIR/iso"
BUILD_DIR="$KERNEL_DIR/build"

echo "=== Building home-os kernel ==="

# Check for Zig (temporary, until Home compiler is ready)
if ! command -v zig &> /dev/null; then
    echo "Error: Zig compiler not found!"
    echo "Install with: brew install zig (macOS) or sudo apt install zig (Linux)"
    exit 1
fi

# Note: Using Zig for now, will switch to Home compiler once it's ready
echo "Using Zig compiler (Home compiler in development)"

# Create build directory
mkdir -p "$BUILD_DIR"
mkdir -p "$ISO_DIR/boot/grub"

# Build kernel
cd "$KERNEL_DIR"
echo "Compiling kernel..."

# For now, use zig directly since Home compiler is still in development
# Once Home compiler is ready, switch to: home build
# Note: Using .zig extension temporarily until Home compiler supports .home files
zig build-exe \
    src/boot.s \
    src/kernel.zig \
    -target x86_64-freestanding \
    -O ReleaseSafe \
    -T linker.ld \
    --name home-kernel \
    -femit-bin="$BUILD_DIR/home-kernel.elf"

echo "Kernel compiled successfully!"

# Copy kernel to ISO directory
cp "$BUILD_DIR/home-kernel.elf" "$ISO_DIR/boot/"

# Check kernel file
ls -lh "$ISO_DIR/boot/home-kernel.elf"

# Create ISO
echo "Creating bootable ISO..."

# Find grub-mkrescue (check brew installation first)
# Note: Use i686-elf-grub for BIOS-bootable ISOs (x86_64-elf creates ELF binaries only)
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
$GRUB_MKRESCUE -o "$BUILD_DIR/home-os.iso" "$ISO_DIR"

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
