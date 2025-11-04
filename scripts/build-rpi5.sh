#!/bin/bash
# Build script for HomeOS on Raspberry Pi 5

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KERNEL_DIR="$PROJECT_ROOT/kernel"
RPI5_DIR="$PROJECT_ROOT/rpi5"
BUILD_DIR="$PROJECT_ROOT/build/rpi5"
HOME_COMPILER="$HOME/Code/home/zig-out/bin/home"

echo "╔════════════════════════════════════════╗"
echo "║  Building HomeOS for Raspberry Pi 5   ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check if Home compiler exists
if [ ! -f "$HOME_COMPILER" ]; then
    echo "❌ Error: Home compiler not found at $HOME_COMPILER"
    echo "   Please build the Home compiler first:"
    echo "   cd ~/Code/home && zig build"
    exit 1
fi

# Create build directory
echo "📁 Creating build directory..."
mkdir -p "$BUILD_DIR"
mkdir -p "$BUILD_DIR/boot"

# Copy ARM64 boot assembly
echo "📋 Copying ARM64 boot code..."
if [ -f "$HOME/Code/home/packages/kernel/src/arm64/boot.s" ]; then
    cp "$HOME/Code/home/packages/kernel/src/arm64/boot.s" "$BUILD_DIR/boot.s"
else
    echo "❌ Error: ARM64 boot.s not found"
    exit 1
fi

# Compile Home kernel to Zig (temporary until Home self-hosts)
echo "🏗️  Compiling Home kernel to intermediate format..."
# For now, we'll use the existing infrastructure from ~/Code/home
# In the future, this will be: $HOME_COMPILER build --target=aarch64-freestanding

# Assemble boot code
echo "🔧 Assembling ARM64 boot code..."
aarch64-linux-gnu-as "$BUILD_DIR/boot.s" -o "$BUILD_DIR/boot.o"

# For now, create a minimal kernel using the Home compiler's kernel package
echo "🔨 Building kernel with Home compiler infrastructure..."
cd "$HOME/Code/home/packages/kernel"

# Create a temporary build script for ARM64
cat > "$BUILD_DIR/build.zig" << 'EOF'
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .freestanding,
        .abi = .none,
    });

    const optimize = b.standardOptimizeOption(.{});

    // Build kernel executable
    const kernel = b.addExecutable(.{
        .name = "home-kernel.elf",
        .root_source_file = b.path("../../home-os/kernel/src/rpi5_main.zig"),
        .target = target,
        .optimize = optimize,
        .linkage = .static,
    });

    // Set linker script
    kernel.setLinkerScriptPath(b.path("../../home-os/kernel/linker-rpi5.ld"));

    // Add assembly boot code
    kernel.addAssemblyFile(b.path("src/arm64/boot.s"));

    // Install
    b.installArtifact(kernel);
}
EOF

# Build with Zig (temporary)
echo "🔨 Building kernel binary..."
zig build -Doptimize=ReleaseSmall --build-file "$BUILD_DIR/build.zig" --prefix "$BUILD_DIR"

# Create kernel image for Raspberry Pi
echo "📦 Creating kernel image..."
aarch64-linux-gnu-objcopy "$BUILD_DIR/bin/home-kernel.elf" -O binary "$BUILD_DIR/boot/home-kernel.img"

# Copy Raspberry Pi firmware files
echo "📥 Preparing Raspberry Pi 5 firmware files..."
echo "   Note: You need to download these files from:"
echo "   https://github.com/raspberrypi/firmware/tree/master/boot"
echo ""

# Check for firmware files
FIRMWARE_NEEDED=(
    "start4.elf"
    "fixup4.dat"
    "bcm2712-rpi-5-b.dtb"
)

FIRMWARE_AVAILABLE=true
for file in "${FIRMWARE_NEEDED[@]}"; do
    if [ ! -f "$RPI5_DIR/$file" ]; then
        echo "   ⚠️  Missing: $file"
        FIRMWARE_AVAILABLE=false
    else
        echo "   ✓ Found: $file"
        cp "$RPI5_DIR/$file" "$BUILD_DIR/boot/"
    fi
done

# Copy config files
echo "📋 Copying boot configuration..."
cp "$RPI5_DIR/config.txt" "$BUILD_DIR/boot/"
cp "$RPI5_DIR/cmdline.txt" "$BUILD_DIR/boot/"

# Display kernel information
echo ""
echo "📊 Kernel Information:"
aarch64-linux-gnu-size "$BUILD_DIR/bin/home-kernel.elf"

echo ""
echo "✅ Build complete!"
echo ""
echo "📂 Build output:"
echo "   $BUILD_DIR/boot/"
echo ""

if [ "$FIRMWARE_AVAILABLE" = false ]; then
    echo "⚠️  WARNING: Some firmware files are missing!"
    echo "   Download them from: https://github.com/raspberrypi/firmware/tree/master/boot"
    echo "   Required files:"
    for file in "${FIRMWARE_NEEDED[@]}"; do
        echo "     - $file"
    done
    echo "   Place them in: $RPI5_DIR/"
    echo ""
fi

echo "📋 Next steps:"
echo "   1. Download missing firmware files (if any)"
echo "   2. Format SD card with FAT32 partition"
echo "   3. Copy contents of $BUILD_DIR/boot/ to SD card"
echo "   4. Insert SD card into Raspberry Pi 5"
echo "   5. Connect USB-to-serial adapter to GPIO 14/15 (pins 8/10)"
echo "   6. Open serial console at 115200 baud"
echo "   7. Power on the Raspberry Pi 5"
echo ""
echo "For detailed instructions, see: $PROJECT_ROOT/docs/RASPBERRY_PI_5.md"
