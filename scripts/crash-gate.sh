#!/usr/bin/env bash
# crash-gate — homefs crash consistency (MASTER_PLAN §12, Tier 2)
#
# Kills QEMU partway through a run that is committing to a homefs volume, then
# boots again against the same disk and asserts the volume mounts and every key
# the previous boot reported as committed is still readable.
#
# The property under test is the one design doc §5 claims: after a crash the
# volume presents either the old transaction or the new one, never a mixture.
# A run that is killed at an arbitrary instant is the only way to test it —
# which is why this is a nightly job rather than a per-commit gate. It takes
# minutes and each iteration is a different arbitrary instant.
#
# Usage: scripts/crash-gate.sh [--iterations N] [--keep]
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ITERATIONS=8
KEEP=0
while [ $# -gt 0 ]; do
    case "$1" in
        --iterations) ITERATIONS="$2"; shift 2 ;;
        --iterations=*) ITERATIONS="${1#*=}"; shift ;;
        --keep) KEEP=1; shift ;;
        -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

HOME_COMPILER="${HOME_COMPILER:-}"
[ -n "$HOME_COMPILER" ] && [ -x "$HOME_COMPILER" ] || {
    echo "error: set HOME_COMPILER to the Home compiler" >&2; exit 2; }

QEMU="${QEMU:-}"
if [ -z "$QEMU" ]; then
    if command -v qemu-system-x86_64 >/dev/null 2>&1; then
        QEMU="qemu-system-x86_64"
    elif [ -x "$REPO_ROOT/pantry/.bin/qemu-system-x86_64" ]; then
        QEMU="$REPO_ROOT/pantry/.bin/qemu-system-x86_64"
    fi
fi
command -v "$QEMU" >/dev/null 2>&1 || { echo "error: qemu-system-x86_64 not found" >&2; exit 2; }

workdir="$(mktemp -d)"
cleanup() { [ "$KEEP" = 1 ] || rm -rf "$workdir"; }
trap cleanup EXIT

# The kernel is the boot gate's, built the same way. Reusing its build keeps
# the two gates testing the same image rather than two that drifted apart.
echo "==> building the kernel"
if ! BOOT_GATE_BUILD_ONLY=1 BUILD_OUT="$workdir/crash-gate.bin" \
     "$SCRIPT_DIR/boot-gate.sh" --build-only >"$workdir/build.log" 2>&1; then
    echo "error: could not build the kernel; see $workdir/build.log" >&2
    tail -20 "$workdir/build.log" >&2
    exit 2
fi

# A blank second disk for homefs. The first disk stays ext2 so the boot gate's
# own assertions keep working on the same image.
fsdisk="$workdir/homefs.img"
dd if=/dev/zero of="$fsdisk" bs=1048576 count=16 >/dev/null 2>&1

# Run QEMU for `seconds`, then SIGKILL it.
#
# QEMU's own pid is what gets signalled. Backgrounding a shell function that
# backgrounds QEMU leaves the emulator running when the function is killed,
# and the next iteration then fails to take the image's write lock — which
# looks exactly like a filesystem that would not mount.
#
# SIGKILL rather than SIGTERM throughout: a clean shutdown lets anything
# buffered reach the disk, which is the opposite of the situation under test.
#
# The homefs drive is opened cache=writethrough for the same reason and it is
# not optional. QEMU's default holds writes in the *host* page cache, so
# SIGKILL discards them — the volume then rolls back to whatever had been
# flushed, which is not a crash the guest could ever observe. Testing against
# that measures QEMU's buffering, not the commit protocol.
run_qemu() {
    local seconds="$1" log="$2"
    "$QEMU" -kernel "$workdir/crash-gate.bin" \
        -drive file="$fsdisk",format=raw,if=ide,index=1,cache=writethrough \
        -serial stdio -display none -no-reboot -m 256M >"$log" 2>&1 &
    local pid=$!
    sleep "$seconds"
    kill -9 "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    # Wait for the process to actually go before the next run opens the image.
    local settle=0
    while kill -0 "$pid" 2>/dev/null && [ "$settle" -lt 50 ]; do
        sleep 0.1
        settle=$((settle + 1))
    done
}

failures=0
iteration=1
while [ "$iteration" -le "$ITERATIONS" ]; do
    # A different instant each time. Under two seconds the kernel has not
    # reached homefs at all; past about six it has finished, and neither
    # tests anything.
    kill_after="$(awk -v i="$iteration" 'BEGIN { printf "%.2f", 2.0 + (i * 0.37) % 4.0 }')"
    log="$workdir/crash-$iteration.log"
    run_qemu "$kill_after" "$log"

    # Now boot again against the same disk and give it long enough to mount,
    # check what survived, and say so.
    verify_log="$workdir/verify-$iteration.log"
    run_qemu 14 "$verify_log"

    # A run that could not open the image proves nothing either way, and
    # reporting it as a filesystem failure would be wrong.
    if grep -qF 'Failed to get "write" lock' "$verify_log" 2>/dev/null; then
        echo "FAIL iteration $iteration: the image was still locked by the previous run"
        failures=$((failures + 1))
        iteration=$((iteration + 1))
        continue
    fi

    if grep -qF '[homefs] mount inconsistent' "$verify_log" 2>/dev/null; then
        echo "FAIL iteration $iteration (killed at ${kill_after}s): the volume mounted a mixture"
        grep -F '[homefs]' "$verify_log" | head -5
        failures=$((failures + 1))
    elif grep -qF '[homefs] volume consistent' "$verify_log" 2>/dev/null; then
        printf 'ok   iteration %d (killed at %ss): %s\n' "$iteration" "$kill_after" \
            "$(grep -F '[homefs] volume consistent' "$verify_log" | head -1)"
    else
        echo "FAIL iteration $iteration (killed at ${kill_after}s): the volume did not mount"
        grep -F '[homefs]' "$verify_log" | head -5
        failures=$((failures + 1))
    fi
    iteration=$((iteration + 1))
done

echo ""
if [ "$failures" -ne 0 ]; then
    echo "CRASH GATE BROKEN: $failures of $ITERATIONS iterations left the volume unusable." >&2
    exit 1
fi
echo "crash-gate: $ITERATIONS/$ITERATIONS iterations mounted a consistent volume."
