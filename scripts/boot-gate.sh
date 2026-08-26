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

# A port for QEMU's monitor. Derived from the pid so two runs on one machine
# do not collide.
MONITOR_PORT=$(( 24000 + ($$ % 1000) ))

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

# Build the initramfs the kernel is handed as a boot module. Its contents are
# what `ls` and `cat` are asserted against, so they live in the repo rather
# than being invented here.
# Assemble the userspace programs into the initramfs before packing it. They
# are flat binaries — the kernel's loader reads an image and jumps to offset
# zero — so they are linked against userland/flat.ld rather than the kernel's
# script.
if [ -d "$REPO_ROOT/userland" ]; then
    mkdir -p "$REPO_ROOT/initramfs/bin"
    for src in "$REPO_ROOT"/userland/*.s; do
        [ -e "$src" ] || continue
        name="$(basename "$src" .s)"
        "$ZIG" cc -c -x assembler -target x86_64-freestanding "$src" \
            -o "$workdir/$name.o" >/dev/null 2>&1 || {
            echo "error: could not assemble $src" >&2; exit 2; }
        "$ZIG" build-exe "$workdir/$name.o" -target x86_64-freestanding \
            -O ReleaseSmall -T "$REPO_ROOT/userland/flat.ld" \
            --name "$name" -femit-bin="$workdir/$name.elf" >/dev/null 2>&1 || {
            echo "error: could not link $src" >&2; exit 2; }
        "$ZIG" objcopy -O binary "$workdir/$name.elf" "$REPO_ROOT/initramfs/bin/$name"
    done
fi

initrd=""
if [ -d "$REPO_ROOT/initramfs" ] && command -v cpio >/dev/null 2>&1; then
    ( cd "$REPO_ROOT/initramfs" && find . -print0 | cpio --null -o --format=newc ) \
        > "$workdir/initrd.cpio" 2>/dev/null
    if [ -s "$workdir/initrd.cpio" ]; then
        initrd="$workdir/initrd.cpio"
        echo "boot-gate: initramfs $(wc -c < "$initrd" | tr -d ' ') bytes"
    fi
fi
if [ -z "$initrd" ]; then
    echo "error: could not build the initramfs (need cpio and $REPO_ROOT/initramfs)" >&2
    exit 2
fi

# The kernel drops out of init and idles rather than powering off, so QEMU is
# given a deadline instead of being waited on.
#
# The console is driven rather than only read: the serial line carries the
# scripted commands in, so the shell milestones prove the shell *runs* a
# command, not merely that it printed a banner. Commands are fed one at a
# time — the 16550 receive FIFO is 16 bytes, and a burst of them is dropped
# on the floor.
log="$workdir/serial.log"
{
    sleep 4
    while IFS= read -r cmd; do
        case "$cmd" in ''|\#*) continue ;; esac
        printf '%s\n' "$cmd"
        sleep 2
    done < "$SCRIPT_DIR/boot-commands.txt"
    sleep "${BOOT_TIMEOUT:-45}"
} | "$QEMU" -kernel "$workdir/boot-gate.bin" -initrd "$initrd" -serial stdio \
    -monitor "telnet:127.0.0.1:$MONITOR_PORT,server,nowait" \
    -display none -no-reboot -m 256M > "$log" 2>&1 &
qemu_pid=$!

# Press a key on the emulated PS/2 keyboard.
#
# The gate asserts that the keyboard line fires, and with -display none
# nothing else will ever press one. sendkey goes through QEMU's monitor,
# reached over a loopback socket because bash can open one without any extra
# tool being installed.
(
    sleep 6
    exec 3<>"/dev/tcp/127.0.0.1/$MONITOR_PORT" 2>/dev/null || exit 0
    printf 'sendkey a\n' >&3
    sleep 1
    printf 'sendkey b\n' >&3
    # Hold the connection until the run is over. QEMU treats the monitor
    # closing as a reason to exit, which cut every run short at the moment
    # the keys had been delivered.
    sleep "${BOOT_TIMEOUT:-45}"
) &
keypress_pid=$!
# Stop as soon as the final milestone appears, rather than always waiting out
# the deadline. "Final" means the last real entry — taking the file's last
# line would pick up a blank or a comment, and grep for an empty string
# matches immediately, which ends the run before the kernel has done anything.
last_milestone="$(grep -vE '^\s*(#|$)' "$MILESTONES" | tail -n 1 | sed 's/^ *//; s/ *$//')"
[ -n "$last_milestone" ] || { echo "error: $MILESTONES has no entries" >&2; exit 2; }

deadline=$(( $(date +%s) + ${BOOT_TIMEOUT:-45} ))
while kill -0 "$qemu_pid" 2>/dev/null && [ "$(date +%s)" -lt "$deadline" ]; do
    if [ -s "$log" ] && grep -qF "$last_milestone" "$log" 2>/dev/null; then
        break
    fi
    sleep 1
done
kill "$qemu_pid" 2>/dev/null
wait "$qemu_pid" 2>/dev/null
kill "$keypress_pid" 2>/dev/null

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
