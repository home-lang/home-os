#!/bin/bash
# Unit tests for memory management subsystem

set -e

TEST_NAME="Memory Management Tests"
KERNEL_SRC="$(git rev-parse --show-toplevel)/kernel/src"

echo "Running $TEST_NAME..."

# Test 1: ZRAM module exists
echo "[1/5] Checking ZRAM module..."
if [ ! -f "$KERNEL_SRC/mm/zram.home" ]; then
  echo "FAIL: ZRAM module not found"
  exit 1
fi
echo "PASS: ZRAM module exists"

# Test 2: Memory pool module exists
echo "[2/5] Checking memory pool module..."
if [ ! -f "$KERNEL_SRC/mm/pool.home" ]; then
  echo "FAIL: Memory pool module not found"
  exit 1
fi
echo "PASS: Memory pool module exists"

# Test 3: Slab allocator has magazine layer
echo "[3/5] Checking slab allocator..."
if [ ! -f "$KERNEL_SRC/mm/slab.home" ]; then
  echo "FAIL: Slab allocator not found"
  exit 1
fi

if ! grep -q "SlabMagazine" "$KERNEL_SRC/mm/slab.home"; then
  echo "FAIL: Magazine layer not found in slab allocator"
  exit 1
fi
echo "PASS: Slab allocator has magazine layer"

# Test 4: Memory leak detector exists
echo "[4/5] Checking memory leak detector..."
if [ ! -f "$KERNEL_SRC/debug/memleak.home" ]; then
  echo "FAIL: Memory leak detector not found"
  exit 1
fi

if ! grep -q "memleak_track_alloc" "$KERNEL_SRC/debug/memleak.home"; then
  echo "FAIL: Allocation tracking not found"
  exit 1
fi
echo "PASS: Memory leak detector exists"

# Test 5: Memory audit module exists
echo "[5/5] Checking memory audit..."
if [ ! -f "$KERNEL_SRC/debug/memory_audit.home" ]; then
  echo "FAIL: Memory audit module not found"
  exit 1
fi
echo "PASS: Memory audit module exists"

echo "All memory tests passed!"
