#!/bin/bash
# System test: Boot in QEMU Raspberry Pi 4

set -e

TEST_NAME="QEMU Raspberry Pi 4 Boot Test"
REPO_ROOT="$(git rev-parse --show-toplevel)"
KERNEL="$REPO_ROOT/kernel/build/home-kernel.elf"
SERIAL_LOG="/tmp/home-os-raspi4-test.log"

echo "Running $TEST_NAME..."

# Clean up old log
rm -f "$SERIAL_LOG"

# Run QEMU with timeout
echo "[1/3] Booting kernel in QEMU (raspi4b)..."
timeout 30s qemu-system-aarch64 \
  -M raspi4b \
  -m 1G \
  -kernel "$KERNEL" \
  -nographic \
  -serial file:"$SERIAL_LOG" &

QEMU_PID=$!

# Wait for boot
sleep 5

# Check if QEMU is still running
if ! kill -0 $QEMU_PID 2>/dev/null; then
  echo "FAIL: QEMU exited prematurely"
  cat "$SERIAL_LOG"
  exit 1
fi
echo "PASS: QEMU booted successfully"

# Kill QEMU
kill $QEMU_PID 2>/dev/null || true
wait $QEMU_PID 2>/dev/null || true

# Verify boot log
echo "[2/3] Verifying boot log..."

required_messages=(
  "home-os"
  "kernel"
)

for msg in "${required_messages[@]}"; do
  if ! grep -qi "$msg" "$SERIAL_LOG"; then
    echo "FAIL: Missing boot message: $msg"
    echo "--- Serial log ---"
    cat "$SERIAL_LOG"
    exit 1
  fi
done
echo "PASS: Boot messages present"

# Check for panics
echo "[3/3] Checking for kernel panics..."
if grep -qi "panic" "$SERIAL_LOG"; then
  echo "FAIL: Kernel panic detected"
  cat "$SERIAL_LOG"
  exit 1
fi
echo "PASS: No kernel panics"

echo "All QEMU raspi4b tests passed!"
