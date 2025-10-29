#!/bin/bash
# Build home-os kernel using Home compiler + Zig assembler/linker
set -e

KERNEL_DIR="/Users/chrisbreuer/Code/home-os/kernel"
HOME_DIR="/Users/chrisbreuer/Code/home"
ISO_DIR="$KERNEL_DIR/iso"
BUILD_DIR="$KERNEL_DIR/build"
HOME_COMPILER="$HOME_DIR/zig-out/bin/home"

echo "=== Building home-os Kernel with Home Compiler ==="
echo ""

# Check for Home compiler
if [ ! -f "$HOME_COMPILER" ]; then
    echo "Error: Home compiler not found"
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
echo "To run: cd /Users/chrisbreuer/Code/home-os && ./scripts/run-qemu.sh"
