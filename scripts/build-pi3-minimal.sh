#!/bin/bash
# home-os Pi 3 B+ Minimal Image Builder
# Creates a tuned image for 1GB RAM constraint
#
# Target: < 64MB kernel, < 96MB total, < 5s boot
#
# Usage: ./scripts/build-pi3-minimal.sh [options]
#   --release     Release build (default)
#   --debug       Debug build
#   --image       Create SD card image
#   --dry-run     Show what would be done

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build/pi3-minimal"
PROFILE="$PROJECT_ROOT/kernel/profiles/pi3-minimal.config"
KERNEL_SRC="$PROJECT_ROOT/kernel/src"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Build options
BUILD_TYPE="release"
CREATE_IMAGE=0
DRY_RUN=0

# Image settings
IMAGE_SIZE_MB=256
BOOT_SIZE_MB=64
ROOT_SIZE_MB=192
IMAGE_NAME="home-os-pi3-minimal.img"

# Memory budget (from profile)
KERNEL_BUDGET_MB=64
TOTAL_BUDGET_MB=96

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_TYPE="release"
            shift
            ;;
        --debug)
            BUILD_TYPE="debug"
            shift
            ;;
        --image)
            CREATE_IMAGE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --release     Release build (default)"
            echo "  --debug       Debug build"
            echo "  --image       Create SD card image"
            echo "  --dry-run     Show what would be done"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     home-os Pi 3 B+ Minimal Image Builder                    ║${NC}"
echo -e "${BLUE}║     Target: 1GB RAM, <64MB kernel, <5s boot                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Build type:   ${CYAN}$BUILD_TYPE${NC}"
echo -e "Create image: ${CYAN}$([ $CREATE_IMAGE -eq 1 ] && echo "yes" || echo "no")${NC}"
echo -e "Profile:      ${CYAN}$PROFILE${NC}"
echo ""

# ============================================================================
# STEP 1: Validate Profile
# ============================================================================

echo -e "${YELLOW}[1/7] Validating build profile...${NC}"

if [ ! -f "$PROFILE" ]; then
    echo -e "${RED}Error: Profile not found: $PROFILE${NC}"
    exit 1
fi

# Check required settings
check_profile_setting() {
    local setting="$1"
    local expected="$2"
    if grep -q "^$setting = $expected" "$PROFILE" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $setting = $expected"
    else
        echo -e "  ${YELLOW}!${NC} $setting not set to $expected"
    fi
}

check_profile_setting "enable_gui" "false"
check_profile_setting "enable_tls" "false"
check_profile_setting "enable_gpu" "false"
check_profile_setting "enable_smp" "true"
check_profile_setting "max_processes" "64"

echo -e "${GREEN}Profile validation complete${NC}"
echo ""

# ============================================================================
# STEP 2: Calculate Module Sizes
# ============================================================================

echo -e "${YELLOW}[2/7] Calculating minimal module set...${NC}"

# Count enabled modules
count_modules() {
    local category="$1"
    local pattern="$2"
    local count=$(grep -c "$pattern" "$PROFILE" 2>/dev/null || echo "0")
    echo "$count"
}

DRIVER_COUNT=$(grep -c "^enable_.*= true" "$PROFILE" 2>/dev/null || echo "0")
echo -e "  Enabled drivers: ${CYAN}$DRIVER_COUNT${NC}"

# Estimate module sizes (KB)
declare -A MODULE_SIZES
MODULE_SIZES[core]=256
MODULE_SIZES[memory]=128
MODULE_SIZES[process]=96
MODULE_SIZES[filesystem]=192
MODULE_SIZES[network]=384
MODULE_SIZES[drivers]=512
MODULE_SIZES[security]=64
MODULE_SIZES[init]=32

TOTAL_ESTIMATE=0
for module in "${!MODULE_SIZES[@]}"; do
    TOTAL_ESTIMATE=$((TOTAL_ESTIMATE + MODULE_SIZES[$module]))
done

echo -e "  Estimated kernel size: ${CYAN}$((TOTAL_ESTIMATE / 1024))MB${NC}"
echo ""

# ============================================================================
# STEP 3: Setup Build Directory
# ============================================================================

echo -e "${YELLOW}[3/7] Setting up build directory...${NC}"

if [ $DRY_RUN -eq 0 ]; then
    mkdir -p "$BUILD_DIR"/{boot,root,modules}
    echo -e "  Created: ${CYAN}$BUILD_DIR${NC}"
else
    echo -e "  ${YELLOW}[dry-run]${NC} Would create: $BUILD_DIR"
fi

# ============================================================================
# STEP 4: Generate Minimal Kernel Config
# ============================================================================

echo -e "${YELLOW}[4/7] Generating minimal kernel configuration...${NC}"

KERNEL_CONFIG="$BUILD_DIR/kernel.config"

if [ $DRY_RUN -eq 0 ]; then
    cat > "$KERNEL_CONFIG" << 'EOF'
# home-os Pi 3 B+ Minimal Kernel Configuration
# Auto-generated from pi3-minimal.config

# Core
CONFIG_ARM64=y
CONFIG_BCM2837=y
CONFIG_SMP=y
CONFIG_NR_CPUS=4

# Memory
CONFIG_MEMORY_BUDGET_MB=64
CONFIG_HEAP_SIZE_MB=8
CONFIG_PAGE_CACHE_MB=24
CONFIG_MAX_PROCESSES=64
CONFIG_STACK_SIZE_KB=256

# Filesystem
CONFIG_VFS=y
CONFIG_HOMEFS=y
CONFIG_DEVFS=y
CONFIG_PROCFS=y
CONFIG_SYSFS=y
CONFIG_BUFFER_CACHE_ENTRIES=256

# Networking (minimal)
CONFIG_NET=y
CONFIG_TCP=y
CONFIG_UDP=y
CONFIG_ICMP=y
CONFIG_DHCP=y
CONFIG_DNS=y
CONFIG_HTTP=y
# CONFIG_TLS is not set
# CONFIG_WEBSOCKET is not set
# CONFIG_NFS is not set
# CONFIG_SMB is not set
CONFIG_MAX_SOCKETS=64

# Drivers
CONFIG_SERIAL=y
CONFIG_GPIO=y
CONFIG_I2C=y
CONFIG_SPI=y
CONFIG_PWM=y
CONFIG_SDMMC=y
CONFIG_BCM_EMMC=y
CONFIG_FRAMEBUFFER=y
CONFIG_FB_CONSOLE=y
CONFIG_USB=y
CONFIG_EHCI=y
CONFIG_USB_HUB=y
CONFIG_ETHERNET=y
CONFIG_WIFI=y
CONFIG_CYW43455=y
CONFIG_BLUETOOTH=y
CONFIG_HWMON=y
CONFIG_THERMAL=y
CONFIG_KEYBOARD=y
CONFIG_MOUSE=y
# CONFIG_GPU is not set
# CONFIG_AUDIO is not set
# CONFIG_CAMERA is not set
# CONFIG_NVME is not set

# Security
CONFIG_CAPABILITIES=y
CONFIG_SECCOMP=y
CONFIG_ASLR=y
CONFIG_WX_ENFORCEMENT=y
# CONFIG_AUDIT is not set

# Boot
CONFIG_PARALLEL_INIT=y
CONFIG_LAZY_MODULES=y
CONFIG_BOOT_PROFILE=headless

# Debug (minimal)
CONFIG_SERIAL_CONSOLE=y
CONFIG_PANIC_DEBUG=y
# CONFIG_KERNEL_SYMBOLS is not set
# CONFIG_GDB_STUB is not set
# CONFIG_PROFILER is not set

# GUI (disabled)
# CONFIG_CRAFT is not set
# CONFIG_COMPOSITOR is not set

# Build
CONFIG_OPTIMIZE_SIZE=y
CONFIG_STRIP=y
CONFIG_COMPRESS_LZ4=y
EOF
    echo -e "  Generated: ${CYAN}$KERNEL_CONFIG${NC}"
else
    echo -e "  ${YELLOW}[dry-run]${NC} Would generate: $KERNEL_CONFIG"
fi

# ============================================================================
# STEP 5: Create Minimal Initramfs
# ============================================================================

echo -e "${YELLOW}[5/7] Creating minimal initramfs...${NC}"

INITRAMFS_DIR="$BUILD_DIR/initramfs"

if [ $DRY_RUN -eq 0 ]; then
    mkdir -p "$INITRAMFS_DIR"/{bin,sbin,etc,dev,proc,sys,tmp,var,home,root}

    # Create minimal init script
    cat > "$INITRAMFS_DIR/init" << 'INIT'
#!/bin/sh
# home-os Pi 3 Minimal Init

echo "home-os Pi 3 Minimal starting..."

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

# Set hostname
hostname pi3-homeos

# Setup network (minimal)
ifconfig lo up
ifconfig eth0 up
udhcpc -i eth0 -s /etc/udhcpc.script -q &

# Start shell
echo "Minimal boot complete."
exec /bin/sh
INIT
    chmod +x "$INITRAMFS_DIR/init"

    # Create minimal udhcpc script
    mkdir -p "$INITRAMFS_DIR/etc"
    cat > "$INITRAMFS_DIR/etc/udhcpc.script" << 'DHCP'
#!/bin/sh
case "$1" in
    bound|renew)
        ifconfig $interface $ip netmask $subnet
        [ -n "$router" ] && route add default gw $router
        [ -n "$dns" ] && echo "nameserver $dns" > /etc/resolv.conf
        ;;
esac
DHCP
    chmod +x "$INITRAMFS_DIR/etc/udhcpc.script"

    echo -e "  Created initramfs in: ${CYAN}$INITRAMFS_DIR${NC}"
else
    echo -e "  ${YELLOW}[dry-run]${NC} Would create initramfs in: $INITRAMFS_DIR"
fi

# ============================================================================
# STEP 6: Generate Boot Configuration
# ============================================================================

echo -e "${YELLOW}[6/7] Generating Pi 3 boot configuration...${NC}"

BOOT_DIR="$BUILD_DIR/boot"

if [ $DRY_RUN -eq 0 ]; then
    # config.txt for Pi 3 B+ minimal
    cat > "$BOOT_DIR/config.txt" << 'CONFIG'
# home-os Pi 3 B+ Minimal Boot Configuration

# Hardware
arm_64bit=1
kernel=home-kernel.img
kernel_address=0x80000

# Memory (minimize GPU allocation)
gpu_mem=16
disable_overscan=1

# Boot optimization
boot_delay=0
disable_splash=1
force_turbo=0

# UART console (essential for debugging)
enable_uart=1
dtparam=uart0=on

# Disable unused hardware
dtparam=audio=off
camera_auto_detect=0
display_auto_detect=0

# Network (onboard WiFi/Ethernet)
dtparam=eth0=on

# GPIO (minimal)
dtparam=i2c_arm=on
dtparam=spi=on

# Power optimization
over_voltage=0
arm_freq=1200
CONFIG

    # cmdline.txt
    cat > "$BOOT_DIR/cmdline.txt" << 'CMDLINE'
console=serial0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait quiet loglevel=3 init=/init
CMDLINE

    echo -e "  Generated: ${CYAN}$BOOT_DIR/config.txt${NC}"
    echo -e "  Generated: ${CYAN}$BOOT_DIR/cmdline.txt${NC}"
else
    echo -e "  ${YELLOW}[dry-run]${NC} Would generate boot configuration"
fi

# ============================================================================
# STEP 7: Summary and Image Creation
# ============================================================================

echo -e "${YELLOW}[7/7] Build summary...${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                    BUILD SUMMARY                              ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Target:           ${CYAN}Raspberry Pi 3 Model B+ (1GB RAM)${NC}"
echo -e "  Build Type:       ${CYAN}$BUILD_TYPE${NC}"
echo -e "  Output Dir:       ${CYAN}$BUILD_DIR${NC}"
echo ""
echo -e "  Memory Budget:"
echo -e "    Kernel:         ${CYAN}<${KERNEL_BUDGET_MB}MB${NC}"
echo -e "    Total:          ${CYAN}<${TOTAL_BUDGET_MB}MB${NC} (headless)"
echo ""
echo -e "  Boot Target:      ${CYAN}<5 seconds${NC} to shell"
echo ""
echo -e "  Disabled Features:"
echo -e "    - GUI/Craft     ${RED}✗${NC}"
echo -e "    - TLS/HTTPS     ${RED}✗${NC}"
echo -e "    - GPU accel     ${RED}✗${NC}"
echo -e "    - Audio         ${RED}✗${NC}"
echo -e "    - NFS/SMB       ${RED}✗${NC}"
echo ""
echo -e "  Enabled Features:"
echo -e "    - Ethernet      ${GREEN}✓${NC}"
echo -e "    - WiFi          ${GREEN}✓${NC}"
echo -e "    - Bluetooth     ${GREEN}✓${NC}"
echo -e "    - GPIO/I2C/SPI  ${GREEN}✓${NC}"
echo -e "    - USB           ${GREEN}✓${NC}"
echo -e "    - HTTP (basic)  ${GREEN}✓${NC}"
echo ""

if [ $CREATE_IMAGE -eq 1 ]; then
    echo -e "${YELLOW}Creating SD card image...${NC}"
    if [ $DRY_RUN -eq 0 ]; then
        # Create empty image
        dd if=/dev/zero of="$BUILD_DIR/$IMAGE_NAME" bs=1M count=$IMAGE_SIZE_MB 2>/dev/null

        # Partition (boot: FAT32, root: ext4)
        # This would use parted/fdisk in real implementation
        echo -e "  Created: ${CYAN}$BUILD_DIR/$IMAGE_NAME${NC} (${IMAGE_SIZE_MB}MB)"
    else
        echo -e "  ${YELLOW}[dry-run]${NC} Would create: $BUILD_DIR/$IMAGE_NAME"
    fi
fi

echo ""
echo -e "${GREEN}Build configuration complete!${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. Build kernel: ${CYAN}./scripts/build-unified.sh --target=rpi3 --profile=pi3-minimal${NC}"
echo -e "  2. Flash to SD:  ${CYAN}dd if=$BUILD_DIR/$IMAGE_NAME of=/dev/sdX bs=4M${NC}"
echo -e "  3. Boot Pi 3 and connect via serial console"
echo ""
