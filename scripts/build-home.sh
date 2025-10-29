#!/bin/bash
# Build script for home-os kernel using Home compiler
# This builds a minimal kernel to test the Home language compiler

set -e

KERNEL_DIR="/Users/chrisbreuer/Code/home-os/kernel"
HOME_DIR="/Users/chrisbreuer/Code/home"
ISO_DIR="$KERNEL_DIR/iso"
BUILD_DIR="$KERNEL_DIR/build"
HOME_COMPILER="$HOME_DIR/zig-out/bin/home"

echo "=== Building home-os kernel with Home Compiler ==="
echo ""

# Check for Home compiler
if [ ! -f "$HOME_COMPILER" ]; then
    echo "Error: Home compiler not found at $HOME_COMPILER"
    echo "Please build the Home compiler first:"
    echo "  cd $HOME_DIR && zig build"
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

if [ $? -ne 0 ]; then
    echo "Error: Home compiler failed!"
    exit 1
fi

echo "Home compilation successful!"
echo ""

echo "Step 2: Assembling boot.s..."
as -o "$BUILD_DIR/boot.o" src/boot.s

if [ $? -ne 0 ]; then
    echo "Error: Failed to assemble boot.s!"
    exit 1
fi

echo "boot.s assembled successfully!"
echo ""

echo "Step 3: Assembling kernel_main.s..."
as -o "$BUILD_DIR/kernel_main.o" "$BUILD_DIR/kernel_main.s"

if [ $? -ne 0 ]; then
    echo "Error: Failed to assemble kernel_main.s!"
    exit 1
fi

echo "kernel_main.s assembled successfully!"
echo ""

echo "Step 4: Linking kernel..."
ld -n -o "$BUILD_DIR/home-kernel.elf" \
    -T linker.ld \
    "$BUILD_DIR/boot.o" \
    "$BUILD_DIR/kernel_main.o"

if [ $? -ne 0 ]; then
    echo "Error: Linking failed!"
    exit 1
fi

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
echo "✅ Home compiler successfully compiled kernel!"
echo "✅ Kernel assembled and linked!"
echo "✅ Bootable ISO created!"
echo ""
echo "To run in QEMU:"
echo "  cd /Users/chrisbreuer/Code/home-os && ./scripts/run-qemu.sh"
echo ""
