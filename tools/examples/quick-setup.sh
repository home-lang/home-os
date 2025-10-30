#!/usr/bin/env bash
#
# Quick Setup Example for HomeOS on Raspberry Pi 5
# This script demonstrates the most common setup workflow
#

set -e

echo "HomeOS Raspberry Pi 5 - Quick Setup Example"
echo "==========================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo"
   exit 1
fi

# Step 1: List available devices
echo "Step 1: Available storage devices"
echo "----------------------------------"
lsblk -d -o NAME,SIZE,TYPE,VENDOR,MODEL | grep -E "disk|mmc"
echo ""

# Step 2: Get device from user
read -p "Enter the target device (e.g., /dev/sdb): " DEVICE

if [[ ! -b "$DEVICE" ]]; then
    echo "Error: $DEVICE is not a valid block device"
    exit 1
fi

echo ""
echo "Step 2: Device information"
echo "--------------------------"
lsblk "$DEVICE" -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
echo ""

# Step 3: Confirm
echo "⚠️  WARNING: All data on $DEVICE will be destroyed!"
read -p "Type 'yes' to continue: " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Setup cancelled"
    exit 0
fi

# Step 4: Download setup tool if not present
SETUP_TOOL="./home-os-setup"
if [[ ! -f "$SETUP_TOOL" ]]; then
    echo ""
    echo "Step 3: Downloading setup tool"
    echo "-------------------------------"
    curl -LO https://raw.githubusercontent.com/home-os/home-os/main/tools/home-os-setup
    chmod +x home-os-setup
fi

# Step 5: Flash and configure
echo ""
echo "Step 4: Flashing HomeOS to $DEVICE"
echo "-----------------------------------"
echo "This will take several minutes..."
echo ""

$SETUP_TOOL flash -d "$DEVICE" --auto-configure

# Step 6: Done
echo ""
echo "✅ Setup Complete!"
echo "=================="
echo ""
echo "Next steps:"
echo "1. Safely remove the SD card"
echo "2. Insert into Raspberry Pi 5"
echo "3. Connect power and peripherals"
echo "4. Boot and enjoy HomeOS!"
echo ""
echo "For troubleshooting, see: https://docs.home-os.dev/install/rpi5"
