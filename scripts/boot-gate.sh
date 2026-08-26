#!/bin/bash
# boot-gate.sh — the boot ratchet.
#
# scripts/mvk-links.sh asks whether the Appendix A set links into one image.
# This asks the only question that matters after that: does the image boot,
# and does it still reach as far into init as it did last time?
#
# A kernel can link cleanly and do nothing. This one did, for a long time:
# every inline-asm block with operands compiled to no instructions, so it hung
# polling a serial port it could not read. Nothing in a link check sees that.
#
# The ratchet is a list of milestone strings the boot must print, in order.
# Add to it as the kernel reaches further; never remove one to make CI pass.
#
# Usage: scripts/boot-gate.sh [--verbose] [--keep]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN="$REPO_ROOT/docs/MASTER_PLAN.md"
MILESTONES="$REPO_ROOT/scripts/boot-milestones.txt"

VERBOSE=0
KEEP=0
for arg in "$@"; do
    case "$arg" in
        --verbose) VERBOSE=1 ;;
        --keep) KEEP=1 ;;
    esac
done

HOME_COMPILER="${HOME_COMPILER:-}"
if [ -z "$HOME_COMPILER" ]; then
    for root in "${HOME_REPO:-}" "$REPO_ROOT/../home" "$REPO_ROOT/../lang"; do
        [ -z "$root" ] && continue
        if [ -x "$root/zig-out/bin/home" ]; then HOME_COMPILER="$root/zig-out/bin/home"; break; fi
    done
fi
[ -x "$HOME_COMPILER" ] || { echo "error: home compiler not found (set HOME_COMPILER)" >&2; exit 2; }

ZIG="${ZIG:-}"
if [ -z "$ZIG" ]; then
    if command -v zig >/dev/null 2>&1; then
        ZIG="zig"
    else
        for root in "${HOME_REPO:-}" "$REPO_ROOT/../home" "$REPO_ROOT/../lang"; do
            [ -z "$root" ] && continue
            if [ -x "$root/pantry/.bin/zig" ]; then ZIG="$root/pantry/.bin/zig"; break; fi
        done
    fi
fi
command -v "$ZIG" >/dev/null 2>&1 || { echo "error: no assembler/linker found (set ZIG)" >&2; exit 2; }

QEMU="${QEMU:-}"
if [ -z "$QEMU" ]; then
    if command -v qemu-system-x86_64 >/dev/null 2>&1; then
        QEMU="qemu-system-x86_64"
    elif [ -x "$REPO_ROOT/pantry/.bin/qemu-system-x86_64" ]; then
        QEMU="$REPO_ROOT/pantry/.bin/qemu-system-x86_64"
    fi
fi
command -v "$QEMU" >/dev/null 2>&1 || { echo "error: qemu-system-x86_64 not found (set QEMU)" >&2; exit 2; }

[ -f "$MILESTONES" ] || { echo "error: $MILESTONES not found" >&2; exit 2; }

files="$(awk '
    /^## Appendix A/ { inapp = 1 }
    inapp && /^- `kernel\/.*\.home`/ {
        match($0, /`[^`]+`/)
        print substr($0, RSTART + 1, RLENGTH - 2)
    }
' "$PLAN" | sort -u)"
[ -n "$files" ] || { echo "error: no Appendix A files found in $PLAN" >&2; exit 2; }

workdir="$(mktemp -d)"
cleanup() { [ "$KEEP" = 1 ] || rm -rf "$workdir"; }
trap cleanup EXIT

cd "$REPO_ROOT"
while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    base="$(echo "$rel" | sed 's|/|_|g; s|\.home$||')"
    "$HOME_COMPILER" build "$rel" --kernel -o "$workdir/$base.s" >/dev/null 2>&1 || continue
    [ -s "$workdir/$base.s" ] || continue
    "$ZIG" cc -c -x assembler -target x86_64-freestanding \
        "$workdir/$base.s" -o "$workdir/$base.o" >/dev/null 2>&1 || true
done <<< "$files"

if ! "$ZIG" build-exe "$REPO_ROOT/kernel/src/boot.s" "$REPO_ROOT/kernel/src/idt_stubs.s" "$workdir"/*.o \
        -target x86_64-freestanding -O ReleaseSafe \
        -T "$REPO_ROOT/kernel/linker.ld" \
        --name boot-gate -femit-bin="$workdir/boot-gate.elf" > "$workdir/link.log" 2>&1; then
    echo "boot-gate: link failed" >&2
    tail -20 "$workdir/link.log" >&2
    exit 1
fi
"$ZIG" objcopy -O binary "$workdir/boot-gate.elf" "$workdir/boot-gate.bin"

# The kernel drops out of init and idles rather than powering off, so QEMU is
# given a deadline instead of being waited on.
log="$workdir/serial.log"
"$QEMU" -kernel "$workdir/boot-gate.bin" -serial file:"$log" \
    -display none -no-reboot -m 256M > /dev/null 2>&1 &
qemu_pid=$!
deadline=$(( $(date +%s) + ${BOOT_TIMEOUT:-45} ))
while kill -0 "$qemu_pid" 2>/dev/null && [ "$(date +%s)" -lt "$deadline" ]; do
    if [ -s "$log" ] && grep -qF "$(tail -n 1 "$MILESTONES" | sed 's/^ *//; s/ *$//')" "$log" 2>/dev/null; then
        break
    fi
    sleep 1
done
kill "$qemu_pid" 2>/dev/null
wait "$qemu_pid" 2>/dev/null

[ -f "$log" ] || { echo "boot-gate: no serial output at all" >&2; exit 1; }

if [ "$VERBOSE" = 1 ]; then
    echo "--- serial output ---"
    cat "$log"
    echo "---------------------"
fi

total=0
reached=0
missing=""
last_pos=0
while IFS= read -r line; do
    line="$(echo "$line" | sed 's/^ *//; s/ *$//')"
    case "$line" in ''|\#*) continue ;; esac
    total=$((total + 1))
    # Milestones must appear in order, so search only past the previous one.
    pos="$(tail -c +"$((last_pos + 1))" "$log" | grep -bF -m1 "$line" 2>/dev/null | head -1 | cut -d: -f1)"
    if [ -n "$pos" ]; then
        reached=$((reached + 1))
        last_pos=$((last_pos + pos + ${#line}))
    else
        [ -z "$missing" ] && missing="$line"
    fi
done < "$MILESTONES"

echo "boot-gate: $reached/$total milestones reached"

if [ "$reached" -lt "$total" ]; then
    echo "" >&2
    echo "RATCHET BROKEN: the boot stopped short." >&2
    echo "First milestone not reached: $missing" >&2
    echo "" >&2
    echo "Last 15 lines of serial output:" >&2
    tail -15 "$log" >&2
    exit 1
fi

echo "BOOTED: the kernel reached the end of init."
