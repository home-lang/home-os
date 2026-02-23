#!/bin/bash
# Build home-os kernel using Home language
set -e

# Use environment or auto-detect paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
KERNEL_DIR="$PROJECT_DIR/kernel"
ISO_DIR="$KERNEL_DIR/iso"
BUILD_DIR="$KERNEL_DIR/build"

# Auto-detect Home compiler location
if [ -n "$HOME_COMPILER_DIR" ]; then
    HOME_DIR="$HOME_COMPILER_DIR"
elif [ -d "$HOME/Code/home" ]; then
    HOME_DIR="$HOME/Code/home"
elif [ -d "$HOME/Documents/Projects/home" ]; then
    HOME_DIR="$HOME/Documents/Projects/home"
else
    HOME_DIR="$HOME/Code/home"
fi
HOME_COMPILER="$HOME_DIR/zig-out/bin/home"

# Determine the kernel entry point
KERNEL_ENTRY=""
if [ -f "$KERNEL_DIR/src/main.home" ]; then
    KERNEL_ENTRY="src/main.home"
elif [ -f "$KERNEL_DIR/src/kernel_main.home" ]; then
    KERNEL_ENTRY="src/kernel_main.home"
elif [ -f "$KERNEL_DIR/src/kernel.home" ]; then
    KERNEL_ENTRY="src/kernel.home"
else
    echo "Error: No kernel entry point found (main.home, kernel_main.home, or kernel.home)"
    exit 1
fi

echo "=== Building home-os Kernel ==="
echo ""

# Check for Home compiler
if [ ! -f "$HOME_COMPILER" ]; then
    echo "Error: Home compiler not found at $HOME_COMPILER"
    echo "Please build the Home compiler first:"
    echo "  cd $HOME_DIR && zig build"
    exit 1
fi

# Create build directories
mkdir -p "$BUILD_DIR"
mkdir -p "$ISO_DIR/boot/grub"

cd "$KERNEL_DIR"

echo "Step 1: Compiling $KERNEL_ENTRY with Home compiler..."
"$HOME_COMPILER" build "$KERNEL_ENTRY" --kernel -o "$BUILD_DIR/kernel_main.s"
if [ $? -ne 0 ]; then
    echo "Home compilation failed!"
    exit 1
fi
echo "Home compilation complete!"
echo ""

echo "Generated assembly:"
head -n 50 "$BUILD_DIR/kernel_main.s"
echo "..."
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

if [ $? -ne 0 ]; then
    echo "Kernel assembly/linking failed!"
    exit 1
fi

echo "Kernel assembled and linked!"
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
    echo "Warning: grub-mkrescue not found, skipping ISO creation"
    echo "Kernel ELF file is available at: $BUILD_DIR/home-kernel.elf"
    exit 0
fi

$GRUB_MKRESCUE -o "$BUILD_DIR/home-os.iso" "$ISO_DIR" 2>&1 | grep -v "warning:" || true

echo "ISO created: $BUILD_DIR/home-os.iso"
ls -lh "$BUILD_DIR/home-os.iso"
echo ""

echo "=== Build Complete! ==="
echo ""
echo "Successfully built kernel with Home compiler!"
echo ""
echo "Kernel binary: $BUILD_DIR/home-kernel.elf"
echo "Bootable ISO:  $BUILD_DIR/home-os.iso"
echo ""
echo "To run in QEMU:"
echo "  cd $PROJECT_DIR && ./scripts/run-qemu.sh"
echo ""
