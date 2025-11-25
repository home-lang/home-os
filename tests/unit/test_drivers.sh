#!/bin/bash
# Unit tests for driver subsystem

set -e

TEST_NAME="Driver Subsystem Tests"
KERNEL_SRC="$(git rev-parse --show-toplevel)/kernel/src"

echo "Running $TEST_NAME..."

# Test 1: Parallel driver initialization
echo "[1/8] Checking parallel driver init..."
if [ ! -f "$KERNEL_SRC/core/driver_init.home" ]; then
  echo "FAIL: Driver initialization module not found"
  exit 1
fi

if ! grep -q "driver_init_parallel" "$KERNEL_SRC/core/driver_init.home"; then
  echo "FAIL: Parallel initialization function not found"
  exit 1
fi
echo "PASS: Parallel driver init exists"

# Test 2: RP1 southbridge driver (Pi 5)
echo "[2/8] Checking RP1 driver..."
if [ ! -f "$KERNEL_SRC/rpi/rp1.home" ]; then
  echo "FAIL: RP1 driver not found"
  exit 1
fi

if ! grep -q "rp1_init" "$KERNEL_SRC/rpi/rp1.home"; then
  echo "FAIL: RP1 initialization function not found"
  exit 1
fi
echo "PASS: RP1 driver exists"

# Test 3: GIC-600 interrupt controller (Pi 5)
echo "[3/8] Checking GIC-600 driver..."
if [ ! -f "$KERNEL_SRC/arch/arm64/gic600.home" ]; then
  echo "FAIL: GIC-600 driver not found"
  exit 1
fi

if ! grep -q "gic600_init" "$KERNEL_SRC/arch/arm64/gic600.home"; then
  echo "FAIL: GIC-600 initialization function not found"
  exit 1
fi
echo "PASS: GIC-600 driver exists"

# Test 4: GIC-400 interrupt controller (Pi 4)
echo "[4/8] Checking GIC-400 driver..."
if [ ! -f "$KERNEL_SRC/arch/arm64/gic400.home" ]; then
  echo "FAIL: GIC-400 driver not found"
  exit 1
fi

if ! grep -q "gic400_init" "$KERNEL_SRC/arch/arm64/gic400.home"; then
  echo "FAIL: GIC-400 initialization function not found"
  exit 1
fi
echo "PASS: GIC-400 driver exists"

# Test 5: BCM EMMC driver
echo "[5/8] Checking BCM EMMC driver..."
if [ ! -f "$KERNEL_SRC/drivers/bcm_emmc.home" ]; then
  echo "FAIL: BCM EMMC driver not found"
  exit 1
fi

if ! grep -q "emmc2_init" "$KERNEL_SRC/drivers/bcm_emmc.home"; then
  echo "FAIL: EMMC initialization function not found"
  exit 1
fi
echo "PASS: BCM EMMC driver exists"

# Test 6: CYW43455 WiFi/BT driver
echo "[6/8] Checking CYW43455 driver..."
if [ ! -f "$KERNEL_SRC/drivers/cyw43455.home" ]; then
  echo "FAIL: CYW43455 driver not found"
  exit 1
fi

if ! grep -q "wifi_connect" "$KERNEL_SRC/drivers/cyw43455.home"; then
  echo "FAIL: WiFi connect function not found"
  exit 1
fi
echo "PASS: CYW43455 driver exists"

# Test 7: xHCI USB driver
echo "[7/8] Checking xHCI driver..."
if [ ! -f "$KERNEL_SRC/drivers/usb_xhci.home" ]; then
  echo "FAIL: xHCI driver not found"
  exit 1
fi

if ! grep -q "xhci_init" "$KERNEL_SRC/drivers/usb_xhci.home"; then
  echo "FAIL: xHCI initialization function not found"
  exit 1
fi
echo "PASS: xHCI driver exists"

# Test 8: SD/MMC driver with DMA
echo "[8/8] Checking SD/MMC driver..."
if [ ! -f "$KERNEL_SRC/drivers/sdmmc.home" ]; then
  echo "FAIL: SD/MMC driver not found"
  exit 1
fi

if ! grep -q "sdmmc_dma_transfer" "$KERNEL_SRC/drivers/sdmmc.home"; then
  echo "FAIL: DMA transfer function not found"
  exit 1
fi
echo "PASS: SD/MMC driver exists"

echo "All driver tests passed!"
