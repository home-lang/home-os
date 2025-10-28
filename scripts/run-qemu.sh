#!/bin/bash
# Run home-os in QEMU

set -e

BUILD_DIR="/Users/chrisbreuer/Code/home-os/kernel/build"
ISO="$BUILD_DIR/home-os.iso"

# Check if ISO exists
if [ ! -f "$ISO" ]; then
    echo "ISO not found. Building first..."
    ./scripts/build.sh
fi

# Check for QEMU
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "Error: QEMU not found!"
    echo "Install with:"
    echo "  macOS: brew install qemu"
    echo "  Linux: sudo apt install qemu-system-x86"
    exit 1
fi

# Parse arguments
KVM=""
DEBUG=""
MEMORY="512M"

while [[ $# -gt 0 ]]; do
    case $1 in
        --kvm)
            KVM="-enable-kvm"
            shift
            ;;
        --debug)
            DEBUG="-s -S"
            echo "GDB server listening on localhost:1234"
            echo "Connect with: gdb $BUILD_DIR/home-kernel.elf"
            echo "Then in GDB: target remote localhost:1234"
            shift
            ;;
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--kvm] [--debug] [--memory SIZE]"
            exit 1
            ;;
    esac
done

echo "=== Running home-os in QEMU ==="
echo "ISO: $ISO"
echo "Memory: $MEMORY"
[ -n "$KVM" ] && echo "KVM: Enabled"
[ -n "$DEBUG" ] && echo "Debug: Enabled (waiting for GDB)"

# Run QEMU
qemu-system-x86_64 \
    -cdrom "$ISO" \
    -serial stdio \
    -m "$MEMORY" \
    $KVM \
    $DEBUG
