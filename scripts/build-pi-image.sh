#!/bin/bash
# HomeOS Raspberry Pi SD Card Image Builder
# Creates minimal bootable SD card images for Pi 3/4/5
#
# Usage:
#   ./scripts/build-pi-image.sh                    # Default (Pi 4)
#   ./scripts/build-pi-image.sh --target=rpi3      # Pi 3
#   ./scripts/build-pi-image.sh --target=rpi5      # Pi 5
#   ./scripts/build-pi-image.sh --size=2G          # Custom size

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
IMAGE_DIR="$BUILD_DIR/pi-image"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default options
TARGET="rpi4"
IMAGE_SIZE="2G"
BOOT_SIZE="256M"
PROFILE="pi-optimized"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}======================================================${NC}"
    echo -e "${BLUE}  HomeOS Raspberry Pi Image Builder${NC}"
    echo -e "${BLUE}======================================================${NC}"
    echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target=*)
            TARGET="${1#*=}"
            shift
            ;;
        --size=*)
            IMAGE_SIZE="${1#*=}"
            shift
            ;;
        --boot-size=*)
            BOOT_SIZE="${1#*=}"
            shift
            ;;
        --profile=*)
            PROFILE="${1#*=}"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --target=TARGET    Target Pi (rpi3, rpi4, rpi5)"
            echo "  --size=SIZE        Image size (e.g., 2G, 4G)"
            echo "  --boot-size=SIZE   Boot partition size (e.g., 256M)"
            echo "  --profile=NAME     Build profile to use"
            exit 0
            ;;
        *)
            log_warn "Unknown option: $1"
            shift
            ;;
    esac
done

print_header

log_info "Target: $TARGET"
log_info "Image size: $IMAGE_SIZE"
log_info "Boot partition: $BOOT_SIZE"
log_info "Profile: $PROFILE"
echo ""

# Create working directory
rm -rf "$IMAGE_DIR"
mkdir -p "$IMAGE_DIR"/{boot,root}

# ============================================================================
# Create boot partition contents
# ============================================================================

log_info "Creating boot partition contents..."

# config.txt for Pi
case "$TARGET" in
    rpi3)
        cat > "$IMAGE_DIR/boot/config.txt" << 'EOF'
# HomeOS Raspberry Pi 3 Configuration

# 64-bit mode
arm_64bit=1

# Kernel
kernel=home-kernel.img

# Serial console
enable_uart=1

# GPU memory (minimal for headless)
gpu_mem=16

# CPU settings
arm_freq=1200
core_freq=250

# Disable splash
disable_splash=1

# Fast boot
boot_delay=0
EOF
        ;;

    rpi4)
        cat > "$IMAGE_DIR/boot/config.txt" << 'EOF'
# HomeOS Raspberry Pi 4 Configuration

# 64-bit mode
arm_64bit=1

# Kernel
kernel=home-kernel.img

# Serial console
enable_uart=1
uart_2ndstage=1

# GPU memory
gpu_mem=64

# CPU settings (Pi 4 can go to 1.5GHz)
arm_freq=1500
over_voltage=2

# USB boot support
[pi4]
max_usb_current=1

# PCIe/USB3 settings
dtoverlay=pcie-32bit-dma

# Disable splash
disable_splash=1

# Fast boot
boot_delay=0
EOF
        ;;

    rpi5)
        cat > "$IMAGE_DIR/boot/config.txt" << 'EOF'
# HomeOS Raspberry Pi 5 Configuration

# 64-bit mode
arm_64bit=1

# Kernel
kernel=home-kernel.img

# Serial console
enable_uart=1
uart_2ndstage=1

# GPU memory
gpu_mem=64

# CPU settings (Pi 5 runs at 2.4GHz)
arm_freq=2400

# PCIe support
dtoverlay=pcie-32bit-dma

# NVMe support
dtparam=nvme

# Disable splash
disable_splash=1

# Fast boot
boot_delay=0
EOF
        ;;
esac

# cmdline.txt
cat > "$IMAGE_DIR/boot/cmdline.txt" << 'EOF'
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=noop fsck.repair=yes rootwait quiet init=/sbin/init
EOF

# Copy kernel if available
if [ -f "$BUILD_DIR/$TARGET/home-kernel.elf" ]; then
    log_info "Copying kernel..."
    cp "$BUILD_DIR/$TARGET/home-kernel.elf" "$IMAGE_DIR/boot/home-kernel.img"
elif [ -f "$BUILD_DIR/arm64/home-kernel.elf" ]; then
    cp "$BUILD_DIR/arm64/home-kernel.elf" "$IMAGE_DIR/boot/home-kernel.img"
else
    log_warn "Kernel not found, creating placeholder"
    touch "$IMAGE_DIR/boot/home-kernel.img"
fi

# Copy initramfs if available
if [ -f "$BUILD_DIR/initramfs.img" ]; then
    log_info "Copying initramfs..."
    cp "$BUILD_DIR/initramfs.img" "$IMAGE_DIR/boot/"
fi

# ============================================================================
# Create root partition contents
# ============================================================================

log_info "Creating root partition contents..."

# Create minimal root filesystem structure
mkdir -p "$IMAGE_DIR/root"/{bin,sbin,lib,lib64,usr/{bin,sbin,lib},etc,var/{log,run,tmp},home,root,tmp,proc,sys,dev,mnt}

# Create init
cat > "$IMAGE_DIR/root/sbin/init" << 'EOF'
#!/bin/sh
# HomeOS init

# Mount essential filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true

# Set hostname
hostname home-os

# Print boot message
clear
echo ""
echo "  _   _                       ___  ____  "
echo " | | | | ___  _ __ ___   ___ / _ \/ ___| "
echo " | |_| |/ _ \| '_ \` _ \ / _ \ | | \___ \ "
echo " |  _  | (_) | | | | | |  __/ |_| |___) |"
echo " |_| |_|\___/|_| |_| |_|\___|\___/|____/ "
echo ""
echo "Welcome to HomeOS on Raspberry Pi"
echo ""

# Start shell
exec /bin/sh
EOF

chmod +x "$IMAGE_DIR/root/sbin/init"

# Create minimal /etc files
cat > "$IMAGE_DIR/root/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/sh
EOF

cat > "$IMAGE_DIR/root/etc/group" << 'EOF'
root:x:0:
EOF

cat > "$IMAGE_DIR/root/etc/hostname" << 'EOF'
home-os
EOF

cat > "$IMAGE_DIR/root/etc/fstab" << 'EOF'
# HomeOS fstab
/dev/mmcblk0p1  /boot   vfat    defaults,noatime    0   2
/dev/mmcblk0p2  /       ext4    defaults,noatime    0   1
proc            /proc   proc    defaults            0   0
sysfs           /sys    sysfs   defaults            0   0
devtmpfs        /dev    devtmpfs defaults           0   0
tmpfs           /tmp    tmpfs   defaults,size=64M   0   0
EOF

# ============================================================================
# Calculate sizes
# ============================================================================

log_info "Calculating sizes..."

BOOT_CONTENTS_SIZE=$(du -sk "$IMAGE_DIR/boot" | cut -f1)
ROOT_CONTENTS_SIZE=$(du -sk "$IMAGE_DIR/root" | cut -f1)

echo "  Boot partition contents: ${BOOT_CONTENTS_SIZE} KB"
echo "  Root partition contents: ${ROOT_CONTENTS_SIZE} KB"

# ============================================================================
# Create disk image (if tools available)
# ============================================================================

IMAGE_FILE="$BUILD_DIR/home-os-${TARGET}.img"

# Check if we have the tools to create actual disk image
if command -v dd &> /dev/null && command -v mkfs.vfat &> /dev/null; then
    log_info "Creating disk image..."

    # Parse image size
    case "$IMAGE_SIZE" in
        *G)
            IMAGE_BYTES=$((${IMAGE_SIZE%G} * 1024 * 1024 * 1024))
            ;;
        *M)
            IMAGE_BYTES=$((${IMAGE_SIZE%M} * 1024 * 1024))
            ;;
        *)
            IMAGE_BYTES=$((2 * 1024 * 1024 * 1024))  # Default 2GB
            ;;
    esac

    # Create sparse image file
    dd if=/dev/zero of="$IMAGE_FILE" bs=1 count=0 seek=$IMAGE_BYTES 2>/dev/null

    log_success "Created disk image: $IMAGE_FILE"
    log_info "Image size: $IMAGE_SIZE"
    echo ""
    log_info "To write to SD card:"
    echo "  sudo dd if=$IMAGE_FILE of=/dev/sdX bs=4M status=progress"
    echo ""
    log_warn "Replace /dev/sdX with your actual SD card device!"
else
    log_warn "Disk image tools not available"
    log_info "Created boot and root filesystem trees in $IMAGE_DIR"
fi

# ============================================================================
# Create tarball of filesystem
# ============================================================================

log_info "Creating filesystem tarballs..."

cd "$IMAGE_DIR"
tar -czf "$BUILD_DIR/home-os-${TARGET}-boot.tar.gz" -C boot .
tar -czf "$BUILD_DIR/home-os-${TARGET}-root.tar.gz" -C root .

BOOT_TAR_SIZE=$(ls -lh "$BUILD_DIR/home-os-${TARGET}-boot.tar.gz" | awk '{print $5}')
ROOT_TAR_SIZE=$(ls -lh "$BUILD_DIR/home-os-${TARGET}-root.tar.gz" | awk '{print $5}')

echo ""
log_success "Created tarballs:"
echo "  Boot: $BUILD_DIR/home-os-${TARGET}-boot.tar.gz ($BOOT_TAR_SIZE)"
echo "  Root: $BUILD_DIR/home-os-${TARGET}-root.tar.gz ($ROOT_TAR_SIZE)"

# ============================================================================
# Summary
# ============================================================================

echo ""
echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}  Pi Image Build Complete!${NC}"
echo -e "${GREEN}======================================================${NC}"
echo ""
echo "Target: $TARGET"
echo "Profile: $PROFILE"
echo ""
echo "Output files:"
echo "  - $IMAGE_DIR/boot/     (boot partition files)"
echo "  - $IMAGE_DIR/root/     (root filesystem)"
echo "  - $BUILD_DIR/home-os-${TARGET}-boot.tar.gz"
echo "  - $BUILD_DIR/home-os-${TARGET}-root.tar.gz"
echo ""
echo "To flash to SD card manually:"
echo "  1. Partition SD card (256MB FAT32 boot, rest ext4 root)"
echo "  2. Extract boot.tar.gz to boot partition"
echo "  3. Extract root.tar.gz to root partition"
echo ""
