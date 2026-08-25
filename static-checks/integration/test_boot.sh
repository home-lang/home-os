#!/bin/bash
# Integration test for boot sequence

set -e

TEST_NAME="Boot Sequence Integration Test"
KERNEL_BUILD="$(git rev-parse --show-toplevel)/kernel/build"

echo "Running $TEST_NAME..."

# Test 1: Kernel binary exists
echo "[1/4] Checking kernel binary..."
if [ ! -f "$KERNEL_BUILD/home-kernel.elf" ]; then
  echo "FAIL: Kernel binary not found (run build first)"
  exit 1
fi
echo "PASS: Kernel binary exists"

# Test 2: Kernel is ARM64
echo "[2/4] Verifying architecture..."
if ! file "$KERNEL_BUILD/home-kernel.elf" | grep -q "aarch64"; then
  echo "FAIL: Kernel is not ARM64"
  exit 1
fi
echo "PASS: Kernel is ARM64"

# Test 3: Kernel has required sections
echo "[3/4] Checking ELF sections..."
required_sections=(".text" ".rodata" ".data" ".bss")

for section in "${required_sections[@]}"; do
  if ! readelf -S "$KERNEL_BUILD/home-kernel.elf" | grep -q "$section"; then
    echo "FAIL: Missing section: $section"
    exit 1
  fi
done
echo "PASS: All required sections present"

# Test 4: Kernel entry point is valid
echo "[4/4] Checking entry point..."
entry_point=$(readelf -h "$KERNEL_BUILD/home-kernel.elf" | grep "Entry point" | awk '{print $4}')

if [ "$entry_point" == "0x0" ]; then
  echo "FAIL: Invalid entry point (0x0)"
  exit 1
fi
echo "PASS: Entry point is valid: $entry_point"

echo "All boot integration tests passed!"
