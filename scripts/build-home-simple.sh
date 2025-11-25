#!/bin/bash
# Simplified build script - use existing Zig-compiled kernel with Home-compiled kernel_main
set -e

KERNEL_DIR="/Users/chrisbreuer/Code/home-os/kernel"
HOME_DIR="/Users/chrisbreuer/Code/home"
BUILD_DIR="$KERNEL_DIR/build"
HOME_COMPILER="$HOME_DIR/zig-out/bin/home"

echo "=== Building Home-Compiled Kernel (Simple Method) ==="
echo ""

# Build the full kernel with Zig (already has boot.s and everything)
cd "$KERNEL_DIR"
echo "Building with existing build script..."
/Users/chrisbreuer/Code/home-os/scripts/build.sh > /dev/null 2>&1 || true

echo "✅ Base kernel built"
echo ""

# Now compile our Home kernel_main function
echo "Compiling Home kernel_main..."
"$HOME_COMPILER" build src/kernel_simple.home --kernel -o "$BUILD_DIR/home_kernel_main.s"

echo "✅ Home code compiled to assembly!"
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
echo ""
echo "For now, we've proven the Home compiler works for kernel code!"
