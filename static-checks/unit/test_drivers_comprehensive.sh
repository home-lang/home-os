#!/bin/bash
# home-os Comprehensive Driver Test Suite
# Tests all driver modules: USB, storage, network, input, display, sensors, power
# Validates initialization functions, data structures, and platform support

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
KERNEL_SRC="$PROJECT_ROOT/kernel/src"
DRIVERS_DIR="$KERNEL_SRC/drivers"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Results
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Platform detection
PLATFORM="x86-64"
if [ -f /proc/device-tree/model ]; then
    MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "")
    if [[ "$MODEL" == *"Raspberry Pi 3"* ]]; then
        PLATFORM="pi3"
    elif [[ "$MODEL" == *"Raspberry Pi 4"* ]]; then
        PLATFORM="pi4"
    elif [[ "$MODEL" == *"Raspberry Pi 5"* ]]; then
        PLATFORM="pi5"
    fi
fi

echo -e "${BLUE}home-os Comprehensive Driver Test Suite${NC}"
echo "=========================================="
echo "Platform: $PLATFORM"
echo "Date: $(date)"
echo ""

# Test helper functions
test_pass() {
    local test_name="$1"
    local details="$2"
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}[PASS]${NC} $test_name"
    [ -n "$details" ] && echo -e "        $details"
}

test_fail() {
    local test_name="$1"
    local details="$2"
    ((TESTS_FAILED++))
    echo -e "  ${RED}[FAIL]${NC} $test_name"
    [ -n "$details" ] && echo -e "        $details"
}

test_skip() {
    local test_name="$1"
    local reason="$2"
    ((TESTS_SKIPPED++))
    echo -e "  ${YELLOW}[SKIP]${NC} $test_name - $reason"
}

# Verify driver file exists
verify_driver() {
    local driver="$1"
    local desc="$2"
    ((TESTS_TOTAL++))
    if [ -f "$DRIVERS_DIR/$driver" ]; then
        test_pass "$desc"
        return 0
    else
        test_fail "$desc" "File not found: $driver"
        return 1
    fi
}

# Verify function exists in driver
verify_driver_function() {
    local driver="$1"
    local func="$2"
    ((TESTS_TOTAL++))
    if grep -q "export fn $func" "$DRIVERS_DIR/$driver" 2>/dev/null; then
        test_pass "Function $func"
        return 0
    elif grep -q "fn $func" "$DRIVERS_DIR/$driver" 2>/dev/null; then
        test_pass "Function $func (internal)"
        return 0
    else
        test_fail "Function $func" "Not found in $driver"
        return 1
    fi
}

# Verify constant in driver
verify_driver_const() {
    local driver="$1"
    local const="$2"
    ((TESTS_TOTAL++))
    if grep -q "const $const" "$DRIVERS_DIR/$driver" 2>/dev/null; then
        test_pass "Constant $const"
        return 0
    else
        test_fail "Constant $const" "Not defined in $driver"
        return 1
    fi
}

# Verify struct in driver
verify_driver_struct() {
    local driver="$1"
    local struct="$2"
    ((TESTS_TOTAL++))
    if grep -q "struct $struct" "$DRIVERS_DIR/$driver" 2>/dev/null; then
        test_pass "Structure $struct"
        return 0
    else
        test_fail "Structure $struct" "Not defined in $driver"
        return 1
    fi
}

# ============================================================================
# USB DRIVERS
# ============================================================================

echo -e "\n${YELLOW}--- USB Drivers ---${NC}"

# xHCI (USB 3.0)
if verify_driver "usb_xhci.home" "xHCI USB 3.0 driver"; then
    verify_driver_function "usb_xhci.home" "xhci_init"
    verify_driver_function "usb_xhci.home" "xhci_reset"
    verify_driver_const "usb_xhci.home" "XHCI_CAP_CAPLENGTH"
    verify_driver_const "usb_xhci.home" "USBCMD_RUN"
    verify_driver_struct "usb_xhci.home" "XhciController"
fi

# EHCI (USB 2.0)
if verify_driver "ehci.home" "EHCI USB 2.0 driver"; then
    verify_driver_function "ehci.home" "ehci_init"
fi

# UHCI (USB 1.1)
if verify_driver "uhci.home" "UHCI USB 1.1 driver"; then
    verify_driver_function "uhci.home" "uhci_init"
fi

# USB Hub
if verify_driver "usb_hub.home" "USB Hub driver"; then
    verify_driver_function "usb_hub.home" "usb_hub_init"
fi

# USB Core
if verify_driver "usb.home" "USB Core driver"; then
    verify_driver_function "usb.home" "usb_init"
fi

# ============================================================================
# STORAGE DRIVERS
# ============================================================================

echo -e "\n${YELLOW}--- Storage Drivers ---${NC}"

# NVMe
if verify_driver "nvme.home" "NVMe driver"; then
    verify_driver_function "nvme.home" "nvme_init"
    verify_driver_function "nvme.home" "nvme_read"
    verify_driver_function "nvme.home" "nvme_write"
fi

# AHCI (SATA)
if verify_driver "ahci.home" "AHCI SATA driver"; then
    verify_driver_function "ahci.home" "ahci_init"
fi

# ATA
if verify_driver "ata.home" "ATA driver"; then
    verify_driver_function "ata.home" "ata_init"
fi

# SD/MMC
if verify_driver "sdmmc.home" "SD/MMC driver"; then
    verify_driver_function "sdmmc.home" "sdmmc_init"
    verify_driver_function "sdmmc.home" "sdmmc_dma_transfer"
fi

# SD/MMC High Speed
if verify_driver "sdmmc_highspeed.home" "SD/MMC High Speed driver"; then
    verify_driver_function "sdmmc_highspeed.home" "sdmmc_enable_highspeed"
fi

# SD/MMC Tuning
if verify_driver "sdmmc_tuning.home" "SD/MMC Tuning driver"; then
    verify_driver_function "sdmmc_tuning.home" "sdmmc_tune"
fi

# BCM eMMC (Raspberry Pi)
if verify_driver "bcm_emmc.home" "BCM eMMC driver"; then
    verify_driver_function "bcm_emmc.home" "emmc2_init"
fi

# RAMDisk
if verify_driver "ramdisk.home" "RAMDisk driver"; then
    verify_driver_function "ramdisk.home" "ramdisk_init"
fi

# RAID
if verify_driver "raid.home" "RAID driver"; then
    verify_driver_function "raid.home" "raid_init"
fi

# NVDIMM
if verify_driver "nvdimm.home" "NVDIMM driver"; then
    verify_driver_function "nvdimm.home" "nvdimm_init"
fi

# ============================================================================
# NETWORK DRIVERS
# ============================================================================

echo -e "\n${YELLOW}--- Network Drivers ---${NC}"

# E1000 (Intel Gigabit)
if verify_driver "e1000.home" "E1000 Ethernet driver"; then
    verify_driver_function "e1000.home" "e1000_init"
    verify_driver_function "e1000.home" "e1000_send"
    verify_driver_function "e1000.home" "e1000_receive"
fi

# RTL8139
if verify_driver "rtl8139.home" "RTL8139 Ethernet driver"; then
    verify_driver_function "rtl8139.home" "rtl8139_init"
fi

# Virtio-net
if verify_driver "virtio_net.home" "Virtio-net driver"; then
    verify_driver_function "virtio_net.home" "virtio_net_init"
fi

# WiFi
if verify_driver "wifi.home" "WiFi driver"; then
    verify_driver_function "wifi.home" "wifi_init"
fi

# CYW43455 (Pi WiFi/BT)
if verify_driver "cyw43455.home" "CYW43455 WiFi/BT driver"; then
    verify_driver_function "cyw43455.home" "wifi_connect"
    verify_driver_function "cyw43455.home" "wifi_scan"
fi

# Bluetooth
if verify_driver "bluetooth.home" "Bluetooth driver"; then
    verify_driver_function "bluetooth.home" "bluetooth_init"
fi

# Bluetooth HCI
if verify_driver "bluetooth_hci.home" "Bluetooth HCI driver"; then
    verify_driver_function "bluetooth_hci.home" "hci_init"
fi

# ============================================================================
# INPUT DRIVERS
# ============================================================================

echo -e "\n${YELLOW}--- Input Drivers ---${NC}"

# Keyboard
if verify_driver "keyboard.home" "Keyboard driver"; then
    verify_driver_function "keyboard.home" "keyboard_init"
fi

# Mouse
if verify_driver "mouse.home" "Mouse driver"; then
    verify_driver_function "mouse.home" "mouse_init"
fi

# Touchpad
if verify_driver "touchpad.home" "Touchpad driver"; then
    verify_driver_function "touchpad.home" "touchpad_init"
fi

# Touchscreen
if verify_driver "touchscreen.home" "Touchscreen driver"; then
    verify_driver_function "touchscreen.home" "touchscreen_init"
fi

# Gamepad
if verify_driver "gamepad.home" "Gamepad driver"; then
    verify_driver_function "gamepad.home" "gamepad_init"
fi

# Fingerprint
if verify_driver "fingerprint.home" "Fingerprint driver"; then
    verify_driver_function "fingerprint.home" "fingerprint_init"
fi

# Smartcard
if verify_driver "smartcard.home" "Smartcard driver"; then
    verify_driver_function "smartcard.home" "smartcard_init"
fi

# ============================================================================
# DISPLAY DRIVERS
# ============================================================================

echo -e "\n${YELLOW}--- Display Drivers ---${NC}"

# Framebuffer
if verify_driver "framebuffer.home" "Framebuffer driver"; then
    verify_driver_function "framebuffer.home" "framebuffer_init"
fi

# VGA Graphics
if verify_driver "vga_graphics.home" "VGA Graphics driver"; then
    verify_driver_function "vga_graphics.home" "vga_init"
fi

# GPU
if verify_driver "gpu.home" "GPU driver"; then
    verify_driver_function "gpu.home" "gpu_init"
fi

# Framebuffer Console
if verify_driver "fb_console.home" "Framebuffer Console driver"; then
    verify_driver_function "fb_console.home" "fb_console_init"
fi

# Backlight
if verify_driver "backlight.home" "Backlight driver"; then
    verify_driver_function "backlight.home" "backlight_init"
fi

# LG Monitor
if verify_driver "lg_monitor.home" "LG Monitor driver"; then
    verify_driver_function "lg_monitor.home" "lg_monitor_init"
fi

# ============================================================================
# SENSOR DRIVERS
# ============================================================================

echo -e "\n${YELLOW}--- Sensor Drivers ---${NC}"

# Hardware Monitor
if verify_driver "hwmon.home" "Hardware Monitor driver"; then
    verify_driver_function "hwmon.home" "hwmon_init"
fi

# Sensors
if verify_driver "sensors.home" "Sensors driver"; then
    verify_driver_function "sensors.home" "sensors_init"
fi

# Camera
if verify_driver "camera.home" "Camera driver"; then
    verify_driver_function "camera.home" "camera_init"
fi

# ============================================================================
# POWER MANAGEMENT DRIVERS
# ============================================================================

echo -e "\n${YELLOW}--- Power Management Drivers ---${NC}"

# ACPI
if verify_driver "acpi.home" "ACPI driver"; then
    verify_driver_function "acpi.home" "acpi_init"
fi

# ACPI Power Management
if verify_driver "acpi_pm.home" "ACPI PM driver"; then
    verify_driver_function "acpi_pm.home" "acpi_pm_init"
fi

# Battery
if verify_driver "battery.home" "Battery driver"; then
    verify_driver_function "battery.home" "battery_init"
fi

# Lid
if verify_driver "lid.home" "Lid driver"; then
    verify_driver_function "lid.home" "lid_init"
fi

# Watchdog
if verify_driver "watchdog.home" "Watchdog driver"; then
    verify_driver_function "watchdog.home" "watchdog_init"
fi

# ============================================================================
# BUS DRIVERS
# ============================================================================

echo -e "\n${YELLOW}--- Bus Drivers ---${NC}"

# PCI
if verify_driver "pci.home" "PCI driver"; then
    verify_driver_function "pci.home" "pci_init"
    verify_driver_function "pci.home" "pci_scan"
fi

# PCIe Extended
if verify_driver "pcie_extended.home" "PCIe Extended driver"; then
    verify_driver_function "pcie_extended.home" "pcie_init"
fi

# I2C
if verify_driver "i2c.home" "I2C driver"; then
    verify_driver_function "i2c.home" "i2c_init"
fi

# SPI
if verify_driver "spi.home" "SPI driver"; then
    verify_driver_function "spi.home" "spi_init"
fi

# GPIO
if verify_driver "gpio.home" "GPIO driver"; then
    verify_driver_function "gpio.home" "gpio_init"
fi

# DMA
if verify_driver "dma.home" "DMA driver"; then
    verify_driver_function "dma.home" "dma_init"
fi

# PWM
if verify_driver "pwm.home" "PWM driver"; then
    verify_driver_function "pwm.home" "pwm_init"
fi

# MSI
if verify_driver "msi.home" "MSI driver"; then
    verify_driver_function "msi.home" "msi_init"
fi

# Virtio
if verify_driver "virtio.home" "Virtio driver"; then
    verify_driver_function "virtio.home" "virtio_init"
fi

# ============================================================================
# PERIPHERAL DRIVERS
# ============================================================================

echo -e "\n${YELLOW}--- Peripheral Drivers ---${NC}"

# Serial
if verify_driver "serial.home" "Serial driver"; then
    verify_driver_function "serial.home" "serial_init"
fi

# Printer
if verify_driver "printer.home" "Printer driver"; then
    verify_driver_function "printer.home" "printer_init"
fi

# Scanner
if verify_driver "scanner.home" "Scanner driver"; then
    verify_driver_function "scanner.home" "scanner_init"
fi

# Audio
if verify_driver "audio.home" "Audio driver"; then
    verify_driver_function "audio.home" "audio_init"
fi

# Sound
if verify_driver "sound.home" "Sound driver"; then
    verify_driver_function "sound.home" "sound_init"
fi

# Timer
if verify_driver "timer.home" "Timer driver"; then
    verify_driver_function "timer.home" "timer_init"
fi

# RTC
if verify_driver "rtc.home" "RTC driver"; then
    verify_driver_function "rtc.home" "rtc_init"
fi

# TPM
if verify_driver "tpm.home" "TPM driver"; then
    verify_driver_function "tpm.home" "tpm_init"
fi

# CD-ROM
if verify_driver "cdrom.home" "CD-ROM driver"; then
    verify_driver_function "cdrom.home" "cdrom_init"
fi

# Floppy
if verify_driver "floppy.home" "Floppy driver"; then
    verify_driver_function "floppy.home" "floppy_init"
fi

# LED
if verify_driver "led.home" "LED driver"; then
    verify_driver_function "led.home" "led_init"
fi

# Buzzer
if verify_driver "buzzer.home" "Buzzer driver"; then
    verify_driver_function "buzzer.home" "buzzer_init"
fi

# ============================================================================
# RASPBERRY PI SPECIFIC
# ============================================================================

echo -e "\n${YELLOW}--- Raspberry Pi Drivers ---${NC}"

# RP1 Southbridge (Pi 5)
RPI_DIR="$KERNEL_SRC/rpi"
((TESTS_TOTAL++))
if [ -f "$RPI_DIR/rp1.home" ]; then
    test_pass "RP1 Southbridge driver"
    ((TESTS_TOTAL++))
    if grep -q "export fn rp1_init" "$RPI_DIR/rp1.home" 2>/dev/null; then
        test_pass "Function rp1_init"
    else
        test_fail "Function rp1_init" "Not found in rp1.home"
    fi
else
    test_fail "RP1 Southbridge driver" "File not found: rpi/rp1.home"
fi

# GIC-600 (Pi 5)
ARCH_DIR="$KERNEL_SRC/arch/arm64"
((TESTS_TOTAL++))
if [ -f "$ARCH_DIR/gic600.home" ]; then
    test_pass "GIC-600 interrupt controller"
    ((TESTS_TOTAL++))
    if grep -q "export fn gic600_init" "$ARCH_DIR/gic600.home" 2>/dev/null; then
        test_pass "Function gic600_init"
    else
        test_fail "Function gic600_init" "Not found"
    fi
else
    test_fail "GIC-600 driver" "File not found"
fi

# GIC-400 (Pi 4)
((TESTS_TOTAL++))
if [ -f "$ARCH_DIR/gic400.home" ]; then
    test_pass "GIC-400 interrupt controller"
    ((TESTS_TOTAL++))
    if grep -q "export fn gic400_init" "$ARCH_DIR/gic400.home" 2>/dev/null; then
        test_pass "Function gic400_init"
    else
        test_fail "Function gic400_init" "Not found"
    fi
else
    test_fail "GIC-400 driver" "File not found"
fi

# ============================================================================
# DRIVER INITIALIZATION MODULE
# ============================================================================

echo -e "\n${YELLOW}--- Driver Initialization Module ---${NC}"

DRIVER_INIT="$KERNEL_SRC/core/driver_init.home"
((TESTS_TOTAL++))
if [ -f "$DRIVER_INIT" ]; then
    test_pass "Driver initialization module"

    # Check parallel init
    ((TESTS_TOTAL++))
    if grep -q "driver_init_parallel" "$DRIVER_INIT" 2>/dev/null; then
        test_pass "Parallel driver initialization"
    else
        test_fail "Parallel driver initialization" "Function not found"
    fi

    # Check driver registry
    ((TESTS_TOTAL++))
    if grep -q "struct Driver" "$DRIVER_INIT" 2>/dev/null; then
        test_pass "Driver registry structure"
    else
        test_fail "Driver registry structure" "Not defined"
    fi
else
    test_fail "Driver initialization module" "File not found"
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "=========================================="
echo -e "${BLUE}COMPREHENSIVE DRIVER TEST SUMMARY${NC}"
echo "=========================================="
echo "Platform: $PLATFORM"
echo ""
echo "Total:   $TESTS_TOTAL"
echo -e "Passed:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:  ${RED}$TESTS_FAILED${NC}"
echo -e "Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
echo ""

# Category summary
echo -e "${CYAN}Driver Categories Tested:${NC}"
echo "  - USB: xHCI, EHCI, UHCI, Hub, Core"
echo "  - Storage: NVMe, AHCI, ATA, SD/MMC, BCM eMMC, RAMDisk, RAID"
echo "  - Network: E1000, RTL8139, Virtio-net, WiFi, CYW43455, Bluetooth"
echo "  - Input: Keyboard, Mouse, Touchpad, Touchscreen, Gamepad"
echo "  - Display: Framebuffer, VGA, GPU, Backlight"
echo "  - Sensors: HWMon, Sensors, Camera"
echo "  - Power: ACPI, Battery, Watchdog"
echo "  - Bus: PCI, I2C, SPI, GPIO, DMA, PWM, Virtio"
echo "  - Peripheral: Serial, Audio, Timer, RTC, TPM"
echo "  - Raspberry Pi: RP1, GIC-600, GIC-400"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}*** ALL DRIVER TESTS PASSED ***${NC}"
    exit 0
else
    echo -e "${RED}*** SOME DRIVER TESTS FAILED ***${NC}"
    exit 1
fi
