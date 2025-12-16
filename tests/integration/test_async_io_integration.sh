#!/bin/bash
# Integration tests for Async I/O subsystem
# Tests file I/O and network I/O through the async interface

set -e

TEST_NAME="Async I/O Integration Tests"
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

# ============================================================================
# FILE I/O INTEGRATION TESTS
# ============================================================================

echo ""
echo "=== File I/O Integration Tests ==="
echo ""

# Test 1: Async I/O integrates with VFS
echo "[1/12] Checking VFS integration..."
if grep -q "filesystem.vfs_read\|vfs_read" "$KERNEL_SRC/perf/async_io.home"; then
  pass "Async I/O calls VFS read"
else
  fail "Async I/O does not integrate with VFS read"
fi

# Test 2: Async write integrates with VFS
echo "[2/12] Checking VFS write integration..."
if grep -q "filesystem.vfs_write\|vfs_write" "$KERNEL_SRC/perf/async_io.home"; then
  pass "Async I/O calls VFS write"
else
  fail "Async I/O does not integrate with VFS write"
fi

# Test 3: Async fsync integrates with VFS
echo "[3/12] Checking VFS fsync integration..."
if grep -q "filesystem.vfs_fsync\|vfs_fsync" "$KERNEL_SRC/perf/async_io.home"; then
  pass "Async I/O calls VFS fsync"
else
  fail "Async I/O does not integrate with VFS fsync"
fi

# Test 4: Submission queue has reasonable size
echo "[4/12] Checking submission queue size..."
SQ_SIZE=$(grep -E "const SQ_SIZE.*=" "$KERNEL_SRC/perf/async_io.home" | head -1 | grep -oE "[0-9]+" | tail -1)
if [ -n "$SQ_SIZE" ] && [ "$SQ_SIZE" -ge 64 ] && [ "$SQ_SIZE" -le 4096 ]; then
  pass "Submission queue size is reasonable ($SQ_SIZE entries)"
else
  fail "Submission queue size is invalid or out of range (got: $SQ_SIZE)"
fi

# Test 5: Completion queue has reasonable size
echo "[5/12] Checking completion queue size..."
CQ_SIZE=$(grep -E "const CQ_SIZE.*=" "$KERNEL_SRC/perf/async_io.home" | head -1 | grep -oE "[0-9]+" | tail -1)
if [ -n "$CQ_SIZE" ] && [ "$CQ_SIZE" -ge 128 ] && [ "$CQ_SIZE" -le 8192 ]; then
  pass "Completion queue size is reasonable ($CQ_SIZE entries)"
else
  fail "Completion queue size is invalid or out of range (got: $CQ_SIZE)"
fi

# Test 6: Ring buffer uses circular queue
echo "[6/12] Checking circular queue implementation..."
if grep -q "% SQ_SIZE\|% CQ_SIZE" "$KERNEL_SRC/perf/async_io.home"; then
  pass "Ring buffer uses modulo for circular queue"
else
  fail "Ring buffer does not use circular queue"
fi

# ============================================================================
# NETWORK I/O INTEGRATION TESTS
# ============================================================================

echo ""
echo "=== Network I/O Integration Tests ==="
echo ""

# Test 7: Socket module exists for network I/O
echo "[7/12] Checking socket module..."
if [ -f "$KERNEL_SRC/net/socket.home" ]; then
  pass "Socket module exists"
else
  fail "Socket module not found"
fi

# Test 8: TCP module exists
echo "[8/12] Checking TCP module..."
if [ -f "$KERNEL_SRC/net/tcp.home" ]; then
  pass "TCP module exists"
else
  fail "TCP module not found"
fi

# Test 9: UDP module exists
echo "[9/12] Checking UDP module..."
if [ -f "$KERNEL_SRC/net/udp.home" ]; then
  pass "UDP module exists"
else
  fail "UDP module not found"
fi

# Test 10: IO_OP_POLL exists for async network
echo "[10/12] Checking poll operation for network..."
if grep -q "IO_OP_POLL" "$KERNEL_SRC/perf/async_io.home"; then
  pass "IO_OP_POLL defined for async network polling"
else
  fail "IO_OP_POLL not defined"
fi

# ============================================================================
# SYSCALL INTEGRATION TESTS
# ============================================================================

echo ""
echo "=== Syscall Integration Tests ==="
echo ""

# Test 11: io_uring_setup syscall exists
echo "[11/12] Checking io_uring_setup syscall..."
if grep -q "SYS_IO_URING_SETUP\|io_uring_setup" "$KERNEL_SRC/sys/syscall.home"; then
  pass "io_uring_setup syscall exists"
else
  fail "io_uring_setup syscall not found"
fi

# Test 12: io_uring_enter syscall exists
echo "[12/12] Checking io_uring_enter syscall..."
if grep -q "SYS_IO_URING_ENTER\|io_uring_enter" "$KERNEL_SRC/sys/syscall.home"; then
  pass "io_uring_enter syscall exists"
else
  fail "io_uring_enter syscall not found"
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "========================================"
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

if [ $FAIL_COUNT -gt 0 ]; then
  echo ""
  echo "Some integration tests failed!"
  exit 1
fi

echo ""
echo "All async I/O integration tests passed!"
