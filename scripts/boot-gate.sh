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

        # A program ending in _elf keeps its headers and is loaded by
        # kernel/src/loader/elf.home; everything else is flattened and
        # entered at offset zero. The two loaders are both exercised.
        case "$name" in
            *_elf) script="$REPO_ROOT/userland/elf.ld"; flatten=0 ;;
            *)     script="$REPO_ROOT/userland/flat.ld"; flatten=1 ;;
        esac

        "$ZIG" cc -c -x assembler -target x86_64-freestanding "$src" \
            -o "$workdir/$name.o" >/dev/null 2>&1 || {
            echo "error: could not assemble $src" >&2; exit 2; }
        "$ZIG" build-exe "$workdir/$name.o" -target x86_64-freestanding \
            -O ReleaseSmall -T "$script" \
            --name "$name" -femit-bin="$workdir/$name.elf" >/dev/null 2>&1 || {
            echo "error: could not link $src" >&2; exit 2; }

        if [ "$flatten" = 1 ]; then
            "$ZIG" objcopy -O binary "$workdir/$name.elf" "$REPO_ROOT/initramfs/bin/$name"
        else
            cp "$workdir/$name.elf" "$REPO_ROOT/initramfs/bin/$name"
        fi
    done
fi

# Stage the console font. It is generated by tools/make-font.py from glyphs
# authored there, and lives in the image rather than the kernel so a wrong
# pixel is a change to a reviewable file.
if [ -f "$REPO_ROOT/assets/fonts/default.psf" ]; then
    mkdir -p "$REPO_ROOT/initramfs/usr/share/fonts"
    cp "$REPO_ROOT/assets/fonts/default.psf" \
       "$REPO_ROOT/initramfs/usr/share/fonts/default.psf"
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
# A blank disk for the block layer to prove itself against. Written fresh
# each run so a round-trip cannot pass on the previous run's bytes.
# A second, tiny image behind a USB mass-storage device. It exists so the USB
# stack has a device with bulk endpoints to talk to: the hub above it
# enumerates but moves no data, and a usb-kbd would take keystrokes away from
# the PS/2 controller and silence the keyboard milestone.
usbdisk="$workdir/usbdisk.img"
# Known bytes at LBA 0, so a block read can be checked against what was
# written rather than merely against "some bytes came back". Written fresh
# each run for the same reason the ext2 image is.
python3 - "$usbdisk" <<'USBIMG'
import sys
signature = b"HOMEOS-USB-BLOCK0"
block = signature + b"\x00" * (512 - len(signature))
with open(sys.argv[1], "wb") as f:
    f.write(block)
    f.write(b"\x00" * (2 * 1024 * 1024 - 512))
USBIMG

disk="$workdir/disk.img"
if [ -x "$(command -v python3 2>/dev/null)" ] && [ -f "$REPO_ROOT/tools/mkext2.py" ]; then
    python3 "$REPO_ROOT/tools/mkext2.py" build "$disk" --size-mb 8 \
        --file 'hello.txt=ext2 read path works
' --file 'second.txt=another file
' >/dev/null 2>&1 || {
        echo "error: could not build the ext2 image" >&2; exit 2; }
else
    echo "error: python3 and tools/mkext2.py are needed to build the disk" >&2
    exit 2
fi

log="$workdir/serial.log"
SHOT="${BOOT_SCREENSHOT:-$workdir/screen.ppm}"
{
    # Wait for the shell to announce itself rather than guessing how long the
    # boot takes. It is not a fixed cost: rendering the boot log onto the
    # framebuffer adds seconds, and feeding commands before the console is
    # polling loses them — the 16550 receive FIFO is sixteen bytes deep.
    waited=0
    while [ "$waited" -lt "${BOOT_TIMEOUT:-45}" ]; do
        if [ -s "$log" ] && grep -qF '[Shell] serial console ready' "$log" 2>/dev/null; then
            break
        fi
        sleep 1
        waited=$(( waited + 1 ))
    done
    sleep 1

    while IFS= read -r cmd; do
        case "$cmd" in ''|\#*) continue ;; esac
        printf '%s\n' "$cmd"
        sleep 2
    done < "$SCRIPT_DIR/boot-commands.txt"
    sleep "${BOOT_TIMEOUT:-45}"
} | "$QEMU" -kernel "$workdir/boot-gate.bin" -initrd "$initrd" \
    -drive file="$disk",format=raw,if=ide -serial stdio \
    -device qemu-xhci,id=xhci \
    -drive file="$usbdisk",format=raw,if=none,id=usbstick \
    -device usb-storage,bus=xhci.0,drive=usbstick \
    -monitor "telnet:127.0.0.1:$MONITOR_PORT,server,nowait" \
    -display none -vga std -no-reboot -m 256M > "$log" 2>&1 &
qemu_pid=$!

# Press a key on the emulated PS/2 keyboard.
#
# The gate asserts that the keyboard line fires, and with -display none
# nothing else will ever press one. sendkey goes through QEMU's monitor,
# reached over a loopback socket because bash can open one without any extra
# tool being installed.
(
    # Wait for the shell, as the command feed does. Sending keys before the
    # kernel has enabled interrupts delivers them to a masked line, and the
    # counter the gate asserts on stays at zero.
    kwait=0
    while [ "$kwait" -lt "${BOOT_TIMEOUT:-45}" ]; do
        if [ -s "$log" ] && grep -qF '[Shell] serial console ready' "$log" 2>/dev/null; then
            break
        fi
        sleep 1
        kwait=$(( kwait + 1 ))
    done
    exec 3<>"/dev/tcp/127.0.0.1/$MONITOR_PORT" 2>/dev/null || exit 0
    printf 'sendkey a\n' >&3
    sleep 1
    printf 'sendkey b\n' >&3

    # Capture the framebuffer once the boot log has been rendered onto it.
    # A screenshot is the only way to tell a console that drew the log from
    # one that drew nothing: both leave the serial output identical.
    sleep 8
    printf 'screendump %s\n' "$SHOT" >&3

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

# The framebuffer must actually have been drawn on. A PPM of a single colour
# is what an uninitialised or unmapped framebuffer produces, and it is
# indistinguishable from a working one by serial output alone.
if [ -s "$SHOT" ]; then
    distinct="$(od -An -tx1 -v -j 15 "$SHOT" 2>/dev/null | tr -s ' ' '\n' \
                | grep -v '^$' | sort -u | wc -l | tr -d ' ')"
    if [ "${distinct:-0}" -lt 2 ]; then
        echo "" >&2
        echo "RATCHET BROKEN: the framebuffer screenshot is a single flat colour." >&2
        echo "The console reported drawing but nothing reached the display." >&2
        exit 1
    fi
    echo "boot-gate: framebuffer $(wc -c < "$SHOT" | tr -d ' ') bytes, $distinct distinct byte values"
else
    echo "" >&2
    echo "RATCHET BROKEN: no framebuffer screenshot was captured." >&2
    exit 1
fi

# Check the image with the independent implementation in tools/mkext2.py.
# The kernel grading its own filesystem work is not a check.
if ! python3 "$REPO_ROOT/tools/mkext2.py" check "$disk" \
        --expect 'hello.txt=ext2 read path works
' --expect 'written.txt=kernel wrote this
' > "$workdir/fsck.out" 2>&1; then
    echo "" >&2
    echo "RATCHET BROKEN: the disk image did not survive the run." >&2
    cat "$workdir/fsck.out" >&2
    exit 1
fi
sed 's/^/boot-gate: fsck /' "$workdir/fsck.out"

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
