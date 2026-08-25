#!/bin/bash
# boot-test.sh — the boot-qemu-x86_64 phase gate (MASTER_PLAN Phase 0, #26).
#
# Boots the Home-compiled kernel ELF in QEMU with the serial port on stdio and
# asserts the proof-of-life string appears within a timeout. This is the first
# gate that proves Home-generated machine code executes.
#
# Exit codes: 0 = proof-of-life seen, 1 = not seen / timed out, 2 = setup error.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# The flat image, not the ELF: see the a.out-kludge note in kernel/src/boot.s.
KERNEL="${KERNEL:-$REPO_ROOT/kernel/build/home-kernel.bin}"
EXPECT="${EXPECT:-HomeOS v0.1: kernel_main reached}"
TIMEOUT="${TIMEOUT:-30}"
LOG="${LOG:-$REPO_ROOT/kernel/build/boot-test.log}"

usage() {
    cat <<USAGE
Usage: scripts/boot-test.sh [--kernel PATH] [--expect STRING] [--timeout SECS]

Environment overrides: KERNEL, EXPECT, TIMEOUT, LOG, QEMU
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --kernel)  KERNEL="$2"; shift 2 ;;
        --expect)  EXPECT="$2"; shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --log)     LOG="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

# Resolve QEMU: $QEMU, PATH, then the pantry-installed toolchain declared in
# this repo's deps.yaml (pantry install).
QEMU="${QEMU:-}"
if [ -z "$QEMU" ]; then
    if command -v qemu-system-x86_64 >/dev/null 2>&1; then
        QEMU="qemu-system-x86_64"
    elif [ -x "$REPO_ROOT/pantry/.bin/qemu-system-x86_64" ]; then
        QEMU="$REPO_ROOT/pantry/.bin/qemu-system-x86_64"
    else
        echo "error: qemu-system-x86_64 not found." >&2
        echo "  Install it with:  pantry install qemu.org" >&2
        exit 2
    fi
fi

if [ ! -f "$KERNEL" ]; then
    echo "error: kernel not found: $KERNEL" >&2
    echo "  Build it with:  ./scripts/build.sh mvk" >&2
    exit 2
fi

mkdir -p "$(dirname "$LOG")"
: > "$LOG"

echo "boot-test: $QEMU"
echo "  kernel:  $KERNEL"
echo "  expect:  $EXPECT"
echo "  timeout: ${TIMEOUT}s"
echo ""

# -kernel takes the multiboot2 ELF directly; -display none keeps CI headless;
# -no-reboot makes a triple fault terminate instead of looping forever.
"$QEMU" \
    -kernel "$KERNEL" \
    -serial stdio \
    -display none \
    -no-reboot \
    -m 128M \
    > "$LOG" 2>&1 &
qemu_pid=$!

deadline=$(( SECONDS + TIMEOUT ))
found=1
while [ "$SECONDS" -lt "$deadline" ]; do
    if grep -qF "$EXPECT" "$LOG" 2>/dev/null; then
        found=0
        break
    fi
    if ! kill -0 "$qemu_pid" 2>/dev/null; then
        # QEMU exited; give the log one last look.
        grep -qF "$EXPECT" "$LOG" 2>/dev/null && found=0
        break
    fi
    sleep 0.25
done

kill "$qemu_pid" 2>/dev/null
wait "$qemu_pid" 2>/dev/null

echo "--- serial output ---"
cat "$LOG"
echo "---------------------"

if [ "$found" -eq 0 ]; then
    echo ""
    echo "PASS: proof-of-life string found on serial."
    exit 0
fi

echo "" >&2
echo "FAIL: '$EXPECT' did not appear on serial within ${TIMEOUT}s." >&2
exit 1
