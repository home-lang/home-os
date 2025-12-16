#!/bin/bash
# Unit tests for Async I/O (io_uring-like) subsystem

set -e

TEST_NAME="Async I/O Unit Tests"
KERNEL_SRC="$(git rev-parse --show-toplevel)/kernel/src"

echo "Running $TEST_NAME..."
echo "========================================"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo "PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

# Test 1: Async I/O module exists
echo "[1/10] Checking async_io module..."
if [ -f "$KERNEL_SRC/perf/async_io.home" ]; then
  pass "async_io.home exists"
else
  fail "async_io.home not found"
  exit 1
fi

# Test 2: IO operation types defined
echo "[2/10] Checking I/O operation types..."
if grep -q "IO_OP_READ" "$KERNEL_SRC/perf/async_io.home" && \
   grep -q "IO_OP_WRITE" "$KERNEL_SRC/perf/async_io.home" && \
   grep -q "IO_OP_FSYNC" "$KERNEL_SRC/perf/async_io.home"; then
  pass "I/O operation types defined (READ, WRITE, FSYNC)"
else
  fail "Missing I/O operation types"
fi

# Test 3: IORequest structure defined
echo "[3/10] Checking IORequest structure..."
if grep -q "struct IORequest" "$KERNEL_SRC/perf/async_io.home"; then
  pass "IORequest structure defined"
else
  fail "IORequest structure not found"
fi

# Test 4: IOCompletion structure defined
echo "[4/10] Checking IOCompletion structure..."
if grep -q "struct IOCompletion" "$KERNEL_SRC/perf/async_io.home"; then
  pass "IOCompletion structure defined"
else
  fail "IOCompletion structure not found"
fi

# Test 5: IOUring structure (ring buffer) defined
echo "[5/10] Checking IOUring ring buffer structure..."
if grep -q "struct IOUring" "$KERNEL_SRC/perf/async_io.home"; then
  pass "IOUring structure defined"
else
  fail "IOUring structure not found"
fi

# Test 6: Ring creation function exists
echo "[6/10] Checking ring creation API..."
if grep -q "async_io_create_ring" "$KERNEL_SRC/perf/async_io.home"; then
  pass "async_io_create_ring() exists"
else
  fail "async_io_create_ring() not found"
fi

# Test 7: Submit function exists
echo "[7/10] Checking submit API..."
if grep -q "async_io_submit" "$KERNEL_SRC/perf/async_io.home"; then
  pass "async_io_submit() exists"
else
  fail "async_io_submit() not found"
fi

# Test 8: Process function exists
echo "[8/10] Checking process API..."
if grep -q "async_io_process" "$KERNEL_SRC/perf/async_io.home"; then
  pass "async_io_process() exists"
else
  fail "async_io_process() not found"
fi

# Test 9: Reap function exists
echo "[9/10] Checking reap API..."
if grep -q "async_io_reap" "$KERNEL_SRC/perf/async_io.home"; then
  pass "async_io_reap() exists"
else
  fail "async_io_reap() not found"
fi

# Test 10: Check syscall integration
echo "[10/10] Checking syscall integration..."
if grep -q "SYS_IO_URING_SETUP\|io_uring" "$KERNEL_SRC/sys/syscall.home"; then
  pass "io_uring syscalls integrated"
else
  fail "io_uring syscalls not found in syscall.home"
fi

echo "========================================"
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

if [ $FAIL_COUNT -gt 0 ]; then
  exit 1
fi

echo "All async I/O unit tests passed!"
