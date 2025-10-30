#!/usr/bin/env bash
#
# NVMe Migration Example for HomeOS on Raspberry Pi 5
# Migrates an existing SD card installation to NVMe SSD
#

set -e

echo "HomeOS Raspberry Pi 5 - NVMe Migration"
echo "======================================"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo"
   exit 1
fi

# Step 1: List available devices
echo "Step 1: Available storage devices"
echo "----------------------------------"
lsblk -d -o NAME,SIZE,TYPE,VENDOR,MODEL
echo ""

# Step 2: Get source device (SD card)
echo "Step 2: Select source device (SD card)"
echo "---------------------------------------"
read -p "Enter the source device (e.g., /dev/mmcblk0): " SOURCE

if [[ ! -b "$SOURCE" ]]; then
    echo "Error: $SOURCE is not a valid block device"
    exit 1
fi

echo ""
lsblk "$SOURCE" -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
echo ""

# Step 3: Get target device (NVMe)
echo "Step 3: Select target device (NVMe SSD)"
echo "----------------------------------------"
read -p "Enter the target device (e.g., /dev/nvme0n1): " TARGET

if [[ ! -b "$TARGET" ]]; then
    echo "Error: $TARGET is not a valid block device"
    exit 1
fi

echo ""
lsblk "$TARGET" -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
echo ""

# Step 4: Verify NVMe is detected
if [[ ! "$TARGET" =~ "nvme" ]]; then
    echo "⚠️  Warning: Target device doesn't appear to be an NVMe drive"
    read -p "Continue anyway? (yes/no): " CONTINUE
    if [[ "$CONTINUE" != "yes" ]]; then
        echo "Migration cancelled"
        exit 0
    fi
fi

# Step 5: Confirm
echo "Migration Summary"
echo "-----------------"
echo "Source: $SOURCE (SD card)"
echo "Target: $TARGET (NVMe SSD)"
echo ""
echo "⚠️  WARNING: All data on $TARGET will be destroyed!"
read -p "Type 'yes' to continue: " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Migration cancelled"
    exit 0
fi

# Step 6: Download setup tool if not present
SETUP_TOOL="../home-os-setup"
if [[ ! -f "$SETUP_TOOL" ]]; then
    echo ""
    echo "Downloading setup tool..."
    curl -LO https://raw.githubusercontent.com/home-os/home-os/main/tools/home-os-setup
    chmod +x home-os-setup
    SETUP_TOOL="./home-os-setup"
fi

# Step 7: Clone to NVMe
echo ""
echo "Step 4: Cloning to NVMe"
echo "-----------------------"
echo "This will take 10-30 minutes depending on SD card size..."
echo ""

$SETUP_TOOL clone-to-nvme -s "$SOURCE" -t "$TARGET"

# Step 8: Configure NVMe boot
echo ""
echo "Step 5: Configuring NVMe boot settings"
echo "---------------------------------------"

$SETUP_TOOL configure -d "$TARGET" --uart --pcie

# Step 9: Verify
echo ""
echo "Step 6: Verifying installation"
echo "-------------------------------"

$SETUP_TOOL verify "$TARGET"

# Step 10: Done
echo ""
echo "✅ Migration Complete!"
echo "====================="
echo ""
echo "Next steps:"
echo "1. Power off your Raspberry Pi 5"
echo "2. Remove the SD card (optional, but recommended for testing)"
echo "3. Power on - the Pi should boot from NVMe"
echo "4. Verify faster boot times and improved performance!"
echo ""
echo "Notes:"
echo "- NVMe boot is significantly faster than SD card"
echo "- You can keep the SD card as a backup"
echo "- If boot fails, re-insert SD card and check PCIe settings"
echo ""
echo "For troubleshooting, see: https://docs.home-os.dev/install/rpi5#nvme"
