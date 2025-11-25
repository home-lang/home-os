#!/bin/bash
# QEMU Boot Test Script for home-os
# Tests that the kernel boots successfully in QEMU

set -e

# Default values
MACHINE="raspi3b"
KERNEL=""
TIMEOUT=60
SERIAL_LOG="/tmp/home-os-boot.log"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --machine)
      MACHINE="$2"
      shift 2
      ;;
    --kernel)
      KERNEL="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [ -z "$KERNEL" ]; then
  echo "Error: --kernel is required"
  exit 1
fi

if [ ! -f "$KERNEL" ]; then
  echo "Error: Kernel file not found: $KERNEL"
  exit 1
fi

# Map machine names to QEMU machine types
case $MACHINE in
  raspi3b)
    QEMU_MACHINE="raspi3b"
    ;;
  raspi4b)
    QEMU_MACHINE="raspi4b"
    ;;
  raspi5)
    # QEMU doesn't have raspi5 yet, use raspi4b as closest
    QEMU_MACHINE="raspi4b"
    echo "Warning: Using raspi4b machine for Pi 5 (not yet supported in QEMU)"
    ;;
  *)
    echo "Error: Unknown machine: $MACHINE"
    exit 1
    ;;
esac

echo "==================================="
echo "home-os QEMU Boot Test"
echo "==================================="
echo "Machine: $MACHINE ($QEMU_MACHINE)"
echo "Kernel: $KERNEL"
echo "Timeout: ${TIMEOUT}s"
echo "Serial log: $SERIAL_LOG"
echo ""

# Clear old log
rm -f "$SERIAL_LOG"

# Create expect script for automated testing
EXPECT_SCRIPT="/tmp/home-os-boot-expect.sh"
cat > "$EXPECT_SCRIPT" << 'EOF'
#!/usr/bin/expect -f

set timeout [lindex $argv 0]
set serial_log [lindex $argv 1]

log_file -noappend $serial_log

spawn qemu-system-aarch64 \
  -M [lindex $argv 2] \
  -m 1G \
  -kernel [lindex $argv 3] \
  -nographic \
  -serial mon:stdio

expect {
  "home-os kernel initialized" {
    send_user "\n✓ Kernel initialized successfully\n"
    exp_continue
  }
  "Init process started" {
    send_user "\n✓ Init process started\n"
    exp_continue
  }
  "hsh$" {
    send_user "\n✓ Shell prompt reached\n"
    send "help\r"
    expect "hsh$"
    send "exit\r"
    expect eof
    exit 0
  }
  "Kernel panic" {
    send_user "\n✗ Kernel panic detected\n"
    exit 1
  }
  timeout {
    send_user "\n✗ Boot timeout\n"
    exit 1
  }
  eof {
    send_user "\n✗ Unexpected EOF\n"
    exit 1
  }
}
EOF

chmod +x "$EXPECT_SCRIPT"

# Run the boot test
if command -v expect &> /dev/null; then
  # Use expect for interactive testing
  if "$EXPECT_SCRIPT" "$TIMEOUT" "$SERIAL_LOG" "$QEMU_MACHINE" "$KERNEL"; then
    echo ""
    echo "==================================="
    echo "✓ Boot test PASSED"
    echo "==================================="
    exit 0
  else
    echo ""
    echo "==================================="
    echo "✗ Boot test FAILED"
    echo "==================================="
    exit 1
  fi
else
  # Fallback to timeout-based testing
  echo "Warning: 'expect' not found, using simple timeout test"

  timeout "$TIMEOUT" qemu-system-aarch64 \
    -M "$QEMU_MACHINE" \
    -m 1G \
    -kernel "$KERNEL" \
    -nographic \
    -serial file:"$SERIAL_LOG" &

  QEMU_PID=$!

  # Wait for boot
  sleep 5

  # Check if QEMU is still running
  if ! kill -0 $QEMU_PID 2>/dev/null; then
    echo "✗ QEMU exited prematurely"
    exit 1
  fi

  # Kill QEMU
  kill $QEMU_PID 2>/dev/null || true
  wait $QEMU_PID 2>/dev/null || true

  # Check log for success markers
  if grep -q "home-os kernel initialized" "$SERIAL_LOG"; then
    echo "✓ Kernel initialized"
  else
    echo "✗ Kernel initialization not found in log"
    exit 1
  fi

  if grep -q "Kernel panic" "$SERIAL_LOG"; then
    echo "✗ Kernel panic detected"
    exit 1
  fi

  echo ""
  echo "==================================="
  echo "✓ Boot test PASSED"
  echo "==================================="
  exit 0
fi
