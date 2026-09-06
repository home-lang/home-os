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

# How long a run may take before it is treated as hung. This is a *timeout*,
# not a schedule: the wait loop below exits the moment the last milestone
# appears, so a healthy run never spends it and raising it costs nothing.
# It was 45s, which the boot had quietly grown up against — the deadline
# started firing while the serial shell still had commands queued, and the
# gate reported the *symptom* ("written.txt not present") rather than "the run
# was cut short", which is a much harder thing to read.
BOOT_TIMEOUT="${BOOT_TIMEOUT:-120}"

VERBOSE=0
KEEP=0
BUILD_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --verbose) VERBOSE=1 ;;
        --keep) KEEP=1 ;;
        # Build the kernel and stop. scripts/crash-gate.sh uses this so both
        # gates test the same image rather than two builds that drifted apart.
        --build-only) BUILD_ONLY=1 ;;
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
cleanup() {
    [ -n "${echo_srv_pid:-}" ] && kill "$echo_srv_pid" 2>/dev/null
    [ -n "${echo_client_pid:-}" ] && kill "$echo_client_pid" 2>/dev/null
    [ "$KEEP" = 1 ] || rm -rf "$workdir"
}
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

if ! "$ZIG" build-exe "$REPO_ROOT/kernel/src/boot.s" "$REPO_ROOT/kernel/src/idt_stubs.s" \
        "$REPO_ROOT/kernel/src/arch/x86_64/s3.s" "$workdir"/*.o \
        -target x86_64-freestanding -O ReleaseSafe \
        -T "$REPO_ROOT/kernel/linker.ld" \
        --name boot-gate -femit-bin="$workdir/boot-gate.elf" > "$workdir/link.log" 2>&1; then
    echo "boot-gate: link failed" >&2
    tail -20 "$workdir/link.log" >&2
    exit 1
fi
"$ZIG" objcopy -O binary "$workdir/boot-gate.elf" "$workdir/boot-gate.bin"

if [ "$BUILD_ONLY" = 1 ]; then
    cp "$workdir/boot-gate.bin" "${BUILD_OUT:-$workdir/boot-gate.bin}"
    echo "boot-gate: built ${BUILD_OUT:-$workdir/boot-gate.bin}"
    exit 0
fi

# Build the initramfs the kernel is handed as a boot module. Its contents are
# what `ls` and `cat` are asserted against, so they live in the repo rather
# than being invented here.
# Assemble the userspace programs into the initramfs before packing it. They
# are flat binaries — the kernel's loader reads an image and jumps to offset
# zero — so they are linked against userland/flat.ld rather than the kernel's
# script.
# Userspace programs written in Home. These are the real ones — the assembly
# below is two hand-written proofs that the loaders work, and everything a
# user would actually run is compiled from .home like the rest of the tree.
#
# Each is compiled to freestanding assembly, assembled, and linked as an ELF64
# at the address userland/elf.ld names, which is where the kernel's loader
# maps it. The whole set is linked together so a program can import the libc
# beside it.
if [ -d "$REPO_ROOT/userland/bin" ]; then
    mkdir -p "$REPO_ROOT/initramfs/bin"

    # The library objects every program links against, compiled once.
    user_lib_objs=""
    for lib in "$REPO_ROOT"/userland/lib/*.home; do
        [ -e "$lib" ] || continue
        libname="$(basename "$lib" .home)"
        "$HOME_COMPILER" build "$lib" --kernel -o "$workdir/ul_$libname.s" >/dev/null 2>&1 || {
            echo "error: could not compile $lib" >&2; exit 2; }
        if grep -qE '# (ERROR|unsupported)' "$workdir/ul_$libname.s"; then
            echo "error: $lib did not fully lower:" >&2
            grep -m3 -E '# (ERROR|unsupported)' "$workdir/ul_$libname.s" >&2
            exit 2
        fi
        "$ZIG" cc -c -x assembler -target x86_64-freestanding \
            "$workdir/ul_$libname.s" -o "$workdir/ul_$libname.o" >/dev/null 2>&1 || {
            echo "error: could not assemble $lib" >&2; exit 2; }
        user_lib_objs="$user_lib_objs $workdir/ul_$libname.o"
    done

    for src in "$REPO_ROOT"/userland/bin/*.home; do
        [ -e "$src" ] || continue
        name="$(basename "$src" .home)"
        "$HOME_COMPILER" build "$src" --kernel -o "$workdir/ub_$name.s" >/dev/null 2>&1 || {
            echo "error: could not compile $src" >&2; exit 2; }
        if grep -qE '# (ERROR|unsupported)' "$workdir/ub_$name.s"; then
            echo "error: $src did not fully lower:" >&2
            grep -m3 -E '# (ERROR|unsupported)' "$workdir/ub_$name.s" >&2
            exit 2
        fi
        "$ZIG" cc -c -x assembler -target x86_64-freestanding \
            "$workdir/ub_$name.s" -o "$workdir/ub_$name.o" >/dev/null 2>&1 || {
            echo "error: could not assemble $src" >&2; exit 2; }
        "$ZIG" build-exe "$workdir/ub_$name.o" $user_lib_objs \
            -target x86_64-freestanding -O ReleaseSmall \
            -T "$REPO_ROOT/userland/elf.ld" \
            --name "$name" -femit-bin="$REPO_ROOT/initramfs/bin/$name" >/dev/null 2>&1 || {
            echo "error: could not link $src" >&2; exit 2; }
    done
fi

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
# the PS/2 controller and silence the keyboard milestone — measured, not
# assumed: attaching one drops `keyboard=` to 0 while the PS/2 line is what
# the IRQ milestone counts. The HID driver is therefore exercised against a
# usb-mouse, which QEMU drives from the monitor's `mouse_move` and which
# leaves the keyboard alone.
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

# A blank second drive for homefs. The first stays ext2, so the two
# filesystems are tested against the same machine without sharing a disk.
fsdisk="$workdir/homefs.img"
dd if=/dev/zero of="$fsdisk" bs=1048576 count=16 >/dev/null 2>&1

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

# Ports for the net-echo gate. Derived from the pid like the monitor port, so
# two runs on one machine do not collide.
ECHO_HOST_PORT=7001
ECHO_FWD_PORT=$(( 27000 + ($$ % 1000) ))

# An echo server on the host's loopback. The guest reaches it at 10.0.2.2,
# which is what QEMU's user-mode networking maps the host to — so the
# kernel's outbound connection is to a real service, not to QEMU itself.
python3 - "$ECHO_HOST_PORT" > "$workdir/echo-server.log" 2>&1 <<'ECHOSRV' &
import socket, sys
srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", int(sys.argv[1])))
srv.listen(4)
# Long enough to outlast the whole command feed, not a round number that was
# generous once. The guest reaches `netc` near the end of the list, and that
# list has grown from around thirty commands to a hundred-odd — at two seconds
# each the server was timing out and exiting before the kernel ever dialled,
# which the gate then reported as the kernel failing to connect. The server is
# killed at cleanup either way; this bound only exists so a stray process
# cannot outlive a crashed run.
srv.settimeout(1800)
try:
    while True:
        conn, _ = srv.accept()
        conn.settimeout(30)
        try:
            data = conn.recv(4096)
            if data:
                conn.sendall(data)
        finally:
            conn.close()
except Exception:
    pass
ECHOSRV
echo_srv_pid=$!

log="$workdir/serial.log"
SHOT="${BOOT_SCREENSHOT:-$workdir/screen.ppm}"
{
    # Wait for the shell to announce itself rather than guessing how long the
    # boot takes. It is not a fixed cost: rendering the boot log onto the
    # framebuffer adds seconds, and feeding commands before the console is
    # polling loses them — the 16550 receive FIFO is sixteen bytes deep.
    waited=0
    while [ "$waited" -lt "$BOOT_TIMEOUT" ]; do
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
    sleep "$BOOT_TIMEOUT"
} | "$QEMU" -kernel "$workdir/boot-gate.bin" -initrd "$initrd" \
    -drive file="$disk",format=raw,if=ide,index=0 \
    -drive file="$fsdisk",format=raw,if=ide,index=1,cache=writethrough \
    -serial stdio \
    -device qemu-xhci,id=xhci \
    -drive file="$usbdisk",format=raw,if=none,id=usbstick,cache=writethrough \
    -device usb-storage,bus=xhci.0,drive=usbstick \
    -device usb-mouse,bus=xhci.0 \
    -netdev user,id=n0,hostfwd=tcp:127.0.0.1:$ECHO_FWD_PORT-:7002 \
    -device e1000,netdev=n0 \
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
    while [ "$kwait" -lt "$BOOT_TIMEOUT" ]; do
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

    # Move the emulated mouse so the HID device has something to report. A
    # HID endpoint NAKs until something changes, so without this the `hid`
    # command below would correctly find nothing and the milestone would be
    # asserting on the harness rather than on the driver. Several moves,
    # because the shell command feed runs on its own clock and only needs one
    # of them to land before it.
    # Capture the framebuffer once the boot log has been rendered onto it.
    # A screenshot is the only way to tell a console that drew the log from
    # one that drew nothing: both leave the serial output identical.
    sleep 8
    printf 'screendump %s\n' "$SHOT" >&3

    # Keep the mouse moving until the shell's `hid` command has reported, or
    # the feed has had time to finish.
    #
    # Six moves in the first six seconds used to be enough, because `hid` was
    # near the front of the command list. It is now near the back — the list
    # has grown from around thirty commands to eighty-odd — so by the time the
    # shell polled, the last move was minutes old and the endpoint correctly
    # had nothing to report. Moving until the report appears makes this
    # independent of how long the command list gets.
    moves=0
    while [ "$moves" -lt 200 ]; do
        if grep -qaF '[HID] mouse report:' "$log" 2>/dev/null; then break; fi
        printf 'mouse_move 24 16\n' >&3
        sleep 2
        moves=$(( moves + 1 ))
    done

    # Hold the connection until the run is over. QEMU treats the monitor
    # closing as a reason to exit, which cut every run short at the moment
    # the keys had been delivered.
    sleep "$BOOT_TIMEOUT"
) &
keypress_pid=$!

# The client half of the server test: once the kernel says it is listening,
# connect in through QEMU's port forward, send the pattern, and read the echo
# back. Run as a watcher rather than on a timer, because the kernel only
# starts listening when the shell reaches the `nets` command.
(
    nwait=0
    while [ "$nwait" -lt "$BOOT_TIMEOUT" ]; do
        if [ -s "$log" ] && grep -qF '[NET] listening on 7002' "$log" 2>/dev/null; then
            break
        fi
        sleep 1
        nwait=$(( nwait + 1 ))
    done
    python3 - "$ECHO_FWD_PORT" > "$workdir/echo-client.log" 2>&1 <<'ECHOCLI'
import socket, sys, time
# The same pattern the kernel builds: 'A' + (i * 7) % 26, 32 bytes.
payload = bytes((65 + (i * 7) % 26) for i in range(32))
deadline = time.time() + 60
while time.time() < deadline:
    try:
        c = socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=5)
    except OSError:
        time.sleep(1)
        continue
    try:
        c.settimeout(20)
        c.sendall(payload)
        got = b""
        while len(got) < len(payload):
            chunk = c.recv(len(payload) - len(got))
            if not chunk:
                break
            got += chunk
        if got == payload:
            print("echo-client: %d bytes returned unchanged" % len(got))
        else:
            print("echo-client: mismatch, got %r" % got)
        break
    except OSError as exc:
        print("echo-client: %s" % exc)
        break
    finally:
        c.close()
ECHOCLI
) &
echo_client_pid=$!
# Stop as soon as the final milestone appears, rather than always waiting out
# the deadline. "Final" means the last real entry — taking the file's last
# line would pick up a blank or a comment, and grep for an empty string
# matches immediately, which ends the run before the kernel has done anything.
last_milestone="$(grep -vE '^\s*(#|$)' "$MILESTONES" | tail -n 1 | sed 's/^ *//; s/ *$//')"
[ -n "$last_milestone" ] || { echo "error: $MILESTONES has no entries" >&2; exit 2; }

deadline=$(( $(date +%s) + $BOOT_TIMEOUT ))
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
missing_all=""
last_pos=0
while IFS= read -r line; do
    line="$(echo "$line" | sed 's/^ *//; s/ *$//')"
    case "$line" in ''|\#*) continue ;; esac
    total=$((total + 1))
    # Milestones must appear in order, so search only past the previous one.
    # -a: the log is a serial capture, so it may legitimately contain any
    # byte. Without it grep answers "Binary file ... matches" instead of an
    # offset, and the arithmetic below then evaluates the word "file" as a
    # variable name and aborts the gate under set -u.
    pos="$(tail -c +"$((last_pos + 1))" "$log" | grep -abF -m1 "$line" 2>/dev/null | head -1 | cut -d: -f1)"
    if [ -n "$pos" ]; then
        reached=$((reached + 1))
        last_pos=$((last_pos + pos + ${#line}))
    else
        [ -z "$missing" ] && missing="$line"
        # Every one, not just the first. A run once reported 184/186 without
        # naming either, which left nothing to act on: an intermittent gate
        # that cannot say what it lost is indistinguishable from one hiding a
        # regression.
        missing_all="${missing_all}${line}"$'\n'
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

# And the USB write reached the media, not just the device. The kernel reads
# its own block back, which proves the device accepted it; only the image on
# the host says it was written. Hence cache=writethrough on that drive — with
# QEMU's default host page cache the bytes can sit in memory and the image
# below still show the block the harness laid down.
if ! python3 - "$usbdisk" <<'USBCHECK'
import sys
want = b"HOMEOS-USB-WRITE1"
with open(sys.argv[1], "rb") as f:
    f.seek(512)
    block = f.read(512)
if not block.startswith(want):
    print("usb: LBA 1 does not hold the kernel's write: %r" % block[:24])
    sys.exit(1)
# The pattern past the tag varies per byte, so a block of repeated filler
# that happened to start with the tag does not pass.
for i in range(len(want), 64):
    if block[i] != (i * 5 + 3) & 0xFF:
        print("usb: LBA 1 byte %d is %d, expected %d" % (i, block[i], (i * 5 + 3) & 0xFF))
        sys.exit(1)
print("usb: LBA 1 holds the kernel's write, 64 bytes verified")
USBCHECK
then
    echo "" >&2
    echo "RATCHET BROKEN: the USB write did not reach the disk image." >&2
    exit 1
fi | sed 's/^/boot-gate: /'

# A second run, with a USB keyboard in place of the mouse.
#
# The two cannot share a run: attaching a usb-kbd routes keystrokes to it and
# the PS/2 controller sees none, so the `[IRQ] keyboard line live` milestone
# above goes quiet — measured, not assumed. Rather than weaken that
# assertion, the keyboard path gets its own boot. It is short: the kernel is
# already built, only `hid` is fed, and the run ends as soon as the report
# appears.
#
# The boot-protocol keyboard report layout is decoded by the same driver the
# mouse uses, and this is the only test that reaches that branch.
kbdlog="$workdir/serial-kbd.log"
KBD_MONITOR_PORT=$(( MONITOR_PORT + 1 ))
{
    kwait=0
    while [ "$kwait" -lt "$BOOT_TIMEOUT" ]; do
        if [ -s "$kbdlog" ] && grep -qF '[Shell] serial console ready' "$kbdlog" 2>/dev/null; then
            break
        fi
        sleep 1
        kwait=$(( kwait + 1 ))
    done
    sleep 1
    # Press a key, then ask the kernel what the HID device reported. The key
    # has to come first: a HID endpoint NAKs until something changes, so
    # polling an idle keyboard correctly finds nothing.
    #
    # Repeated rather than sent once. A single keypress and a single poll have
    # to coincide to within the driver's polling window, and they did not
    # always: this test reported keycode 4 on one run, 5 on the next and
    # nothing on a third, which is a gate asserting on a race rather than on
    # the driver. Retrying removes the coincidence without weakening what is
    # asserted — the report still has to arrive and still has to decode.
    tries=0
    while [ "$tries" -lt 12 ]; do
        (
            exec 4<>"/dev/tcp/127.0.0.1/$KBD_MONITOR_PORT" 2>/dev/null || exit 0
            printf 'sendkey a\n' >&4
            sleep 1
            printf 'sendkey b\n' >&4
        )
        printf 'hid\n'
        sleep 2
        if grep -qaF '[HID] keyboard report:' "$kbdlog" 2>/dev/null; then break; fi
        tries=$(( tries + 1 ))
    done
    sleep 3
} | "$QEMU" -kernel "$workdir/boot-gate.bin" -initrd "$initrd" \
    -drive file="$disk",format=raw,if=ide,index=0 \
    -serial stdio \
    -device qemu-xhci,id=xhci \
    -device usb-kbd,bus=xhci.0 \
    -monitor "telnet:127.0.0.1:$KBD_MONITOR_PORT,server,nowait" \
    -display none -vga std -no-reboot -m 256M > "$kbdlog" 2>&1 &
kbd_pid=$!

kbd_deadline=$(( $(date +%s) + BOOT_TIMEOUT ))
while kill -0 "$kbd_pid" 2>/dev/null && [ "$(date +%s)" -lt "$kbd_deadline" ]; do
    if [ -s "$kbdlog" ] && grep -qF '[HID] keyboard report:' "$kbdlog" 2>/dev/null; then
        break
    fi
    sleep 1
done
kill "$kbd_pid" 2>/dev/null
wait "$kbd_pid" 2>/dev/null

kbd_report="$(grep -aF '[HID] keyboard report:' "$kbdlog" 2>/dev/null | head -1)"
if [ -z "$kbd_report" ]; then
    echo "" >&2
    echo "RATCHET BROKEN: the USB keyboard reported nothing." >&2
    echo "Last 15 lines of that run's serial output:" >&2
    tail -15 "$kbdlog" >&2
    exit 1
fi
# A report of key 0 is the device saying no key is down, which is what an
# unpressed keyboard reports and what a driver that read the wrong offset
# would also report.
kbd_key="$(printf '%s\n' "$kbd_report" | sed 's/.* key //')"
if [ "${kbd_key:-0}" = "0" ]; then
    echo "" >&2
    echo "RATCHET BROKEN: the USB keyboard reported no key down." >&2
    echo "  $kbd_report" >&2
    exit 1
fi
echo "boot-gate: usb keyboard reported keycode $kbd_key"

# A third run: suspend to RAM and come back.
#
# Its own boot, because suspending ends a run — which is exactly why the main
# gate cannot test this. The sequence is: let the kernel boot, tell it to
# suspend, confirm from *outside* the guest that the machine actually went to
# sleep, wake it, and require the kernel to say it came back.
#
# The outside confirmation matters. A kernel that printed "resumed" without
# ever suspending would pass a serial-only check; QEMU reporting the VM as
# suspended is the part the guest cannot fake.
s3log="$workdir/serial-s3.log"
S3_MONITOR_PORT=$(( MONITOR_PORT + 2 ))
{
    swait=0
    while [ "$swait" -lt "$BOOT_TIMEOUT" ]; do
        if [ -s "$s3log" ] && grep -qF '[Shell] serial console ready' "$s3log" 2>/dev/null; then
            break
        fi
        sleep 1
        swait=$(( swait + 1 ))
    done
    sleep 1
    printf 'suspend\n'
    sleep "$BOOT_TIMEOUT"
} | "$QEMU" -kernel "$workdir/boot-gate.bin" -initrd "$initrd" \
    -drive file="$disk",format=raw,if=ide,index=0 \
    -serial stdio \
    -monitor "telnet:127.0.0.1:$S3_MONITOR_PORT,server,nowait" \
    -display none -vga std -no-reboot -m 256M > "$s3log" 2>&1 &
s3_pid=$!

# Wait for the guest to say it is going down, then for QEMU to agree it has.
s3_suspended=0
s3_deadline=$(( $(date +%s) + BOOT_TIMEOUT ))
while kill -0 "$s3_pid" 2>/dev/null && [ "$(date +%s)" -lt "$s3_deadline" ]; do
    if [ -s "$s3log" ] && grep -qF '[S3] suspending' "$s3log" 2>/dev/null; then
        # `read -t` rather than a timeout(1) that macOS does not ship.
        # The monitor answers "VM status: ..." and then waits for more input,
        # so the read has to stop on that line rather than on end of stream.
        s3_status=""
        if exec 5<>"/dev/tcp/127.0.0.1/$S3_MONITOR_PORT" 2>/dev/null; then
            printf 'info status\n' >&5
            while IFS= read -r -t 2 line <&5; do
                s3_status="$s3_status $line"
                case "$line" in *"VM status"*) break ;; esac
            done
            exec 5<&-
        fi
        case "$s3_status" in
            *suspended*) s3_suspended=1; break ;;
        esac
    fi
    sleep 1
done

if [ "$s3_suspended" = 1 ]; then
    # Wake it, the way a power button or a timer would.
    (
        exec 6<>"/dev/tcp/127.0.0.1/$S3_MONITOR_PORT" 2>/dev/null || exit 0
        printf 'system_wakeup\n' >&6
        sleep 3
    )
    wake_deadline=$(( $(date +%s) + 30 ))
    while kill -0 "$s3_pid" 2>/dev/null && [ "$(date +%s)" -lt "$wake_deadline" ]; do
        if grep -qF '[S3] resumed from suspend-to-RAM' "$s3log" 2>/dev/null; then
            break
        fi
        sleep 1
    done
fi
kill "$s3_pid" 2>/dev/null
wait "$s3_pid" 2>/dev/null

if [ "$s3_suspended" != 1 ]; then
    echo "" >&2
    echo "RATCHET BROKEN: the machine did not enter S3." >&2
    echo "Last 15 lines of that run's serial output:" >&2
    tail -15 "$s3log" >&2
    exit 1
fi
if ! grep -qF '[S3] resumed from suspend-to-RAM' "$s3log" 2>/dev/null; then
    echo "" >&2
    echo "RATCHET BROKEN: the machine suspended but did not resume." >&2
    echo "Last 15 lines of that run's serial output:" >&2
    tail -15 "$s3log" >&2
    exit 1
fi
echo "boot-gate: suspended to RAM and resumed, confirmed suspended by QEMU"

# The net-echo gate, both directions.
#
# The kernel's own lines say it connected out and got its bytes back, and that
# it accepted a connection and echoed. This checks the *other* end of each:
# the host client saw its payload returned unchanged, which is the half the
# guest cannot assert about itself.
if ! grep -qF 'echo-client: 32 bytes returned unchanged' "$workdir/echo-client.log" 2>/dev/null; then
    echo "" >&2
    echo "RATCHET BROKEN: the host client did not get its bytes back from the guest." >&2
    echo "--- echo client ---" >&2
    cat "$workdir/echo-client.log" >&2 2>/dev/null
    echo "--- guest, last 15 lines ---" >&2
    tail -15 "$log" >&2
    exit 1
fi
echo "boot-gate: net-echo both ways, host client got 32 bytes back"

echo "boot-gate: $reached/$total milestones reached"

if [ "$reached" -lt "$total" ]; then
    # On stdout as well as stderr. A caller redirecting only stdout — which is
    # the ordinary way to capture a run — otherwise gets a count with no
    # explanation of it.
    echo ""
    echo "boot-gate: milestones not reached ($(( total - reached ))):"
    printf '%s' "$missing_all" | sed 's/^/  - /'
    echo "" >&2
    echo "RATCHET BROKEN: the boot stopped short." >&2
    echo "First milestone not reached: $missing" >&2
    echo "" >&2
    echo "Last 15 lines of serial output:" >&2
    tail -15 "$log" >&2
    exit 1
fi

echo "BOOTED: the kernel reached the end of init."
