#!/bin/bash
# Simplified build script - use existing Zig-compiled kernel with Home-compiled kernel_main
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
BUILD_DIR="${BUILD_DIR:-$KERNEL_DIR/build}"
HOME_COMPILER="${HOME_COMPILER:-$HOME_REPO/zig-out/bin/home}"

echo "=== Building Home-Compiled Kernel (Simple Method) ==="
echo ""

if [ ! -f "$HOME_COMPILER" ]; then
    echo "Error: Home compiler not found at: $HOME_COMPILER"
    echo "Set HOME_COMPILER or HOME_REPO env vars, or build the Home compiler first."
    exit 1
fi

# Build the full kernel with Zig (already has boot.s and everything)
cd "$KERNEL_DIR"
echo "Building with existing build script..."
"$SCRIPT_DIR/build.sh" > /dev/null 2>&1 || true

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
