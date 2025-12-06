#!/bin/bash
# HomeOS Initramfs Builder
# Creates minimal initramfs for fast boot
#
# Usage:
#   ./scripts/build-initramfs.sh                    # Default (desktop profile)
#   ./scripts/build-initramfs.sh --profile=minimal  # Minimal profile
#   ./scripts/build-initramfs.sh --target=rpi4      # Pi 4 specific

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/initramfs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default options
PROFILE="desktop"
TARGET="x86-64"
COMPRESS="lz4"
STRIP_SYMBOLS=true
INCLUDE_MODULES=true

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}======================================================${NC}"
    echo -e "${BLUE}  HomeOS Initramfs Builder${NC}"
    echo -e "${BLUE}======================================================${NC}"
    echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile=*)
            PROFILE="${1#*=}"
            shift
            ;;
        --target=*)
            TARGET="${1#*=}"
            shift
            ;;
        --compress=*)
            COMPRESS="${1#*=}"
            shift
            ;;
        --no-strip)
            STRIP_SYMBOLS=false
            shift
            ;;
        --no-modules)
            INCLUDE_MODULES=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --profile=NAME    Build profile (minimal, server, desktop, pi)"
            echo "  --target=ARCH     Target architecture (x86-64, rpi3, rpi4, rpi5)"
            echo "  --compress=TYPE   Compression (none, gzip, lz4, xz)"
            echo "  --no-strip        Don't strip debug symbols"
            echo "  --no-modules      Don't include kernel modules"
            exit 0
            ;;
        *)
            log_warn "Unknown option: $1"
            shift
            ;;
    esac
done

print_header

log_info "Profile: $PROFILE"
log_info "Target: $TARGET"
log_info "Compression: $COMPRESS"
log_info "Strip symbols: $STRIP_SYMBOLS"
log_info "Include modules: $INCLUDE_MODULES"
echo ""

# Create build directory structure
log_info "Creating initramfs structure..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"/{bin,sbin,lib,dev,proc,sys,etc,tmp,var/run}
mkdir -p "$BUILD_DIR"/lib/modules
mkdir -p "$BUILD_DIR"/lib/firmware

# Create essential device nodes
log_info "Creating device nodes..."
cd "$BUILD_DIR/dev"
# These would normally require root, so we create placeholder files
touch null zero console tty tty0 tty1

# Create init script based on profile
log_info "Creating init script..."

case "$PROFILE" in
    minimal)
        cat > "$BUILD_DIR/init" << 'INITEOF'
#!/bin/sh
# Minimal init - just mount filesystems and exec real init

# Mount essential filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true

# Print boot message
echo "HomeOS minimal init"

# Try to find and mount root filesystem
ROOT_DEV=""
for dev in /dev/mmcblk0p2 /dev/sda2 /dev/vda2; do
    if [ -b "$dev" ]; then
        ROOT_DEV="$dev"
        break
    fi
done

if [ -n "$ROOT_DEV" ]; then
    mkdir -p /newroot
    mount -t ext4 "$ROOT_DEV" /newroot

    # Switch root
    exec switch_root /newroot /sbin/init
else
    echo "No root device found, dropping to shell"
    exec /bin/sh
fi
INITEOF
        ;;

    server|desktop)
        cat > "$BUILD_DIR/init" << 'INITEOF'
#!/bin/sh
# Standard init - with module loading and device detection

# Mount essential filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || mknod /dev/console c 5 1

# Set up kernel parameters
echo "0" > /proc/sys/kernel/printk 2>/dev/null || true

# Print boot message
echo ""
echo "HomeOS init starting..."
echo ""

# Load essential modules
if [ -d /lib/modules ]; then
    for mod in /lib/modules/*.ko; do
        if [ -f "$mod" ]; then
            insmod "$mod" 2>/dev/null || true
        fi
    done
fi

# Wait for devices to settle
sleep 1

# Detect root filesystem
ROOT_DEV=""
CMDLINE=$(cat /proc/cmdline)

# Check for root= parameter
for param in $CMDLINE; do
    case "$param" in
        root=*)
            ROOT_DEV="${param#root=}"
            ;;
    esac
done

# Auto-detect if not specified
if [ -z "$ROOT_DEV" ]; then
    for dev in /dev/mmcblk0p2 /dev/sda2 /dev/vda2 /dev/nvme0n1p2; do
        if [ -b "$dev" ]; then
            ROOT_DEV="$dev"
            break
        fi
    done
fi

echo "Root device: $ROOT_DEV"

if [ -n "$ROOT_DEV" ]; then
    mkdir -p /newroot

    # Try different filesystem types
    for fs in ext4 ext2 fat32 btrfs; do
        if mount -t "$fs" "$ROOT_DEV" /newroot 2>/dev/null; then
            echo "Mounted root as $fs"
            break
        fi
    done

    if [ -f /newroot/sbin/init ]; then
        # Unmount initramfs filesystems
        umount /proc 2>/dev/null || true
        umount /sys 2>/dev/null || true

        # Switch to real root
        exec switch_root /newroot /sbin/init
    else
        echo "No init found on root filesystem"
    fi
fi

echo "Failed to boot, dropping to emergency shell"
exec /bin/sh
INITEOF
        ;;

    pi)
        cat > "$BUILD_DIR/init" << 'INITEOF'
#!/bin/sh
# Raspberry Pi optimized init

# Mount essential filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true

echo "HomeOS Pi init"

# Wait for SD card to be ready
sleep 0.5

# Load Pi-specific modules
for mod in mmc_block sdhci_iproc; do
    modprobe "$mod" 2>/dev/null || true
done

# Mount root (always mmcblk0p2 on Pi)
ROOT_DEV="/dev/mmcblk0p2"
if [ -b "$ROOT_DEV" ]; then
    mkdir -p /newroot
    mount -t ext4 "$ROOT_DEV" /newroot
    exec switch_root /newroot /sbin/init
else
    echo "SD card not found"
    exec /bin/sh
fi
INITEOF
        ;;
esac

chmod +x "$BUILD_DIR/init"

# Copy busybox or minimal utilities
log_info "Adding utilities..."

# Create minimal shell script utilities if busybox not available
cat > "$BUILD_DIR/bin/sh" << 'SHEOF'
#!/bin/true
# Placeholder - real shell would be linked here
exec /bin/busybox sh "$@"
SHEOF

# Create switch_root utility
cat > "$BUILD_DIR/sbin/switch_root" << 'SREOF'
#!/bin/sh
# Minimal switch_root implementation
NEWROOT="$1"
INIT="$2"

cd "$NEWROOT"
mount --move /dev "$NEWROOT/dev" 2>/dev/null || true
mount --move /proc "$NEWROOT/proc" 2>/dev/null || true
mount --move /sys "$NEWROOT/sys" 2>/dev/null || true

exec chroot "$NEWROOT" "$INIT"
SREOF

chmod +x "$BUILD_DIR/bin/sh"
chmod +x "$BUILD_DIR/sbin/switch_root"

# Include kernel modules based on profile
if [ "$INCLUDE_MODULES" = true ]; then
    log_info "Including kernel modules..."

    MODULES_SRC="$PROJECT_ROOT/kernel/modules"

    case "$PROFILE" in
        minimal)
            # Only essential modules
            MODULES="virtio virtio_blk virtio_net"
            ;;
        server)
            # Server modules (storage, network)
            MODULES="virtio virtio_blk virtio_net ahci nvme e1000"
            ;;
        desktop)
            # Full module set
            MODULES="virtio virtio_blk virtio_net ahci nvme e1000 usb_storage hid"
            ;;
        pi)
            # Pi-specific modules
            MODULES="mmc_block sdhci bcm2835_sdhost dwc2 usb_storage"
            ;;
    esac

    for mod in $MODULES; do
        if [ -f "$MODULES_SRC/$mod.ko" ]; then
            if [ "$STRIP_SYMBOLS" = true ]; then
                strip --strip-debug "$MODULES_SRC/$mod.ko" -o "$BUILD_DIR/lib/modules/$mod.ko"
            else
                cp "$MODULES_SRC/$mod.ko" "$BUILD_DIR/lib/modules/"
            fi
        fi
    done
fi

# Create /etc files
log_info "Creating configuration files..."

# /etc/fstab
cat > "$BUILD_DIR/etc/fstab" << 'EOF'
# HomeOS initramfs fstab
proc      /proc     proc    defaults    0 0
sysfs     /sys      sysfs   defaults    0 0
devtmpfs  /dev      devtmpfs defaults   0 0
EOF

# Build cpio archive
log_info "Creating cpio archive..."

cd "$BUILD_DIR"
find . | cpio -o -H newc > "$PROJECT_ROOT/build/initramfs.cpio" 2>/dev/null

# Compress based on setting
log_info "Compressing initramfs..."

case "$COMPRESS" in
    none)
        mv "$PROJECT_ROOT/build/initramfs.cpio" "$PROJECT_ROOT/build/initramfs.img"
        ;;
    gzip)
        gzip -9 -c "$PROJECT_ROOT/build/initramfs.cpio" > "$PROJECT_ROOT/build/initramfs.img"
        ;;
    lz4)
        if command -v lz4 &> /dev/null; then
            lz4 -9 -c "$PROJECT_ROOT/build/initramfs.cpio" > "$PROJECT_ROOT/build/initramfs.img"
        else
            log_warn "lz4 not found, falling back to gzip"
            gzip -9 -c "$PROJECT_ROOT/build/initramfs.cpio" > "$PROJECT_ROOT/build/initramfs.img"
        fi
        ;;
    xz)
        xz -9 -c "$PROJECT_ROOT/build/initramfs.cpio" > "$PROJECT_ROOT/build/initramfs.img"
        ;;
esac

rm -f "$PROJECT_ROOT/build/initramfs.cpio"

# Calculate sizes
INITRAMFS_SIZE=$(stat -f%z "$PROJECT_ROOT/build/initramfs.img" 2>/dev/null || stat -c%s "$PROJECT_ROOT/build/initramfs.img" 2>/dev/null || echo "0")
INITRAMFS_SIZE_KB=$((INITRAMFS_SIZE / 1024))

echo ""
log_success "Initramfs created: $PROJECT_ROOT/build/initramfs.img"
log_success "Size: ${INITRAMFS_SIZE_KB} KB"
echo ""

# Size targets by profile
case "$PROFILE" in
    minimal)
        TARGET_KB=512
        ;;
    server)
        TARGET_KB=2048
        ;;
    desktop)
        TARGET_KB=4096
        ;;
    pi)
        TARGET_KB=1024
        ;;
esac

if [ "$INITRAMFS_SIZE_KB" -le "$TARGET_KB" ]; then
    log_success "Within target size (${TARGET_KB} KB)"
else
    log_warn "Exceeds target size (${TARGET_KB} KB) by $((INITRAMFS_SIZE_KB - TARGET_KB)) KB"
fi
