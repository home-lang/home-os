#!/bin/bash
# boot-gate-aarch64.sh — the ARM64 boot ratchet.
#
# Builds the ARM64 kernel through the Home compiler, links it against the
# ARM64 boot assembly, boots it on QEMU's `virt` machine, and asserts every
# line of scripts/boot-milestones-aarch64.txt appears on the serial console in
# order.
#
# QEMU has no Raspberry Pi 5 machine model — there is no RP1 — so `virt` is
# what can run on every commit. It proves the compiler, the frame layout, the
# MMIO path and the boot handoff. Only the Pi's own peripherals are left for
# the hardware gate (home-lang/home-os#63), which is the honest division: this
# script must never be described as testing a Pi.
#
# Usage: scripts/boot-gate-aarch64.sh [--keep] [--entry FILE]
#   --keep       leave the build directory and serial log in place
#   --entry F    kernel entry .home file (default kernel/src/arm64_poc.home)
#
# Environment:
#   HOME_COMPILER  path to the `home` binary
#   ZIG            path to a zig binary, used only as assembler and linker
#   QEMU           path to qemu-system-aarch64
#   BOOT_TIMEOUT   seconds to wait for the milestones (default 30)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MILESTONES="$REPO_ROOT/scripts/boot-milestones-aarch64.txt"
ENTRY="$REPO_ROOT/kernel/src/arm64_poc.home"
LINKER="$REPO_ROOT/kernel/linker-virt.ld"
BOOT_S="$REPO_ROOT/kernel/src/arch/arm64/boot.s"
KEEP=0
BOOT_TIMEOUT="${BOOT_TIMEOUT:-30}"

while [ $# -gt 0 ]; do
    case "$1" in
        --keep) KEEP=1; shift ;;
        --entry) ENTRY="$2"; shift 2 ;;
        --entry=*) ENTRY="${1#*=}"; shift ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

fail() { echo "error: $*" >&2; exit 2; }

# --- toolchain ---------------------------------------------------------------
HOME_COMPILER="${HOME_COMPILER:-}"
if [ -z "$HOME_COMPILER" ]; then
    for root in "${HOME_REPO:-}" "$REPO_ROOT/../home" "$REPO_ROOT/../lang"; do
        [ -z "$root" ] && continue
        for cand in "$root/zig-out/bin/home" "$root/zig-out/bin/home-release-safe"; do
            [ -x "$cand" ] && { HOME_COMPILER="$cand"; break 2; }
        done
    done
fi
[ -x "$HOME_COMPILER" ] || fail "home compiler not found (set HOME_COMPILER)"

ZIG="${ZIG:-}"
if [ -z "$ZIG" ]; then
    command -v zig >/dev/null 2>&1 && ZIG="zig"
fi
[ -n "$ZIG" ] && command -v "$ZIG" >/dev/null 2>&1 || \
    fail "zig not found (set ZIG); it is the cross-assembler and linker, no kernel logic is written in it"

QEMU="${QEMU:-}"
if [ -z "$QEMU" ]; then
    if command -v qemu-system-aarch64 >/dev/null 2>&1; then
        QEMU="qemu-system-aarch64"
    else
        # The repo's own pantry environment, when one has been installed.
        for cand in "$REPO_ROOT"/pantry/qemu.org/*/bin/qemu-system-aarch64; do
            [ -x "$cand" ] && { QEMU="$cand"; break; }
        done
    fi
fi
[ -n "$QEMU" ] && command -v "$QEMU" >/dev/null 2>&1 || \
    fail "qemu-system-aarch64 not found (set QEMU, or: pantry install qemu)"

[ -f "$ENTRY" ]      || fail "kernel entry $ENTRY not found"
[ -f "$BOOT_S" ]     || fail "boot assembly $BOOT_S not found"
[ -f "$LINKER" ]     || fail "linker script $LINKER not found"
[ -f "$MILESTONES" ] || fail "milestone list $MILESTONES not found"

BUILD="$REPO_ROOT/build/aarch64-virt"
mkdir -p "$BUILD"
[ "$KEEP" = 1 ] || trap 'rm -rf "$BUILD"' EXIT

# --- collect the module set ---------------------------------------------------
# An imported module's declarations are registered in the importing file, but
# its function bodies are not emitted there — so every module reached by an
# import needs compiling and linking in its own right, or the link fails on an
# undefined symbol. Walk the import graph from the entry file.
collect_modules() {
    local pending="$1"
    local seen=""
    local current dir imported rel abs
    while [ -n "$pending" ]; do
        current="${pending%%$'\n'*}"
        if [ "$pending" = "$current" ]; then pending=""; else pending="${pending#*$'\n'}"; fi
        [ -z "$current" ] && continue
        case "$seen" in *"|$current|"*) continue ;; esac
        seen="$seen|$current|"
        echo "$current"
        dir="$(cd "$(dirname "$current")" && pwd)"
        # `import "./path.home" as name` — the quoted path is relative to the
        # importing file, which is why this resolves against its directory.
        imported="$(sed -n 's/^[[:space:]]*import[[:space:]]*"\([^"]*\.home\)".*/\1/p' "$current" 2>/dev/null)"
        while IFS= read -r rel; do
            [ -z "$rel" ] && continue
            abs="$(cd "$dir" 2>/dev/null && cd "$(dirname "$rel")" 2>/dev/null && pwd)/$(basename "$rel")"
            [ -f "$abs" ] && pending="$pending"$'\n'"$abs"
        done <<< "$imported"
    done
}

MODULES="$(collect_modules "$(cd "$(dirname "$ENTRY")" && pwd)/$(basename "$ENTRY")")"
echo "==> module set:"
echo "$MODULES" | sed "s|^$REPO_ROOT/|    |"

# --- build --------------------------------------------------------------------
OBJECTS=""
while IFS= read -r module; do
    [ -z "$module" ] && continue
    name="$(echo "${module#$REPO_ROOT/}" | sed 's|/|_|g; s|\.home$||')"
    echo "==> compiling $(basename "$module") for aarch64"
    if ! "$HOME_COMPILER" build "$module" --kernel --target=aarch64-freestanding \
            -o "$BUILD/$name.s" >"$BUILD/$name.log" 2>&1; then
        echo "--- compiler output:" >&2
        cat "$BUILD/$name.log" >&2
        fail "the Home compiler could not lower $module for aarch64"
    fi
    # The kernel backend emits a marker comment and carries on when it meets
    # something it cannot lower, so exit status 0 does not mean it compiled.
    if grep -qE '# (ERROR|unsupported)' "$BUILD/$name.s"; then
        echo "--- unlowered constructs:" >&2
        grep -E '# (ERROR|unsupported)' "$BUILD/$name.s" | head -20 >&2
        fail "$module contains constructs the aarch64 backend cannot lower"
    fi
    "$ZIG" cc -c -x assembler -target aarch64-freestanding "$BUILD/$name.s" \
        -o "$BUILD/$name.o" || fail "assembler rejected the code generated from $module"
    OBJECTS="$OBJECTS $BUILD/$name.o"
done <<< "$MODULES"

echo "==> assembling boot code and linking"
"$ZIG" cc -c -x assembler -target aarch64-freestanding "$BOOT_S" \
    -o "$BUILD/boot.o" || fail "assembler rejected $BOOT_S"
# boot.o first: the linker script keeps .text.boot at the start of the image,
# and an ELF loader honours the entry symbol but a raw binary is jumped to at
# its first byte.
"$ZIG" ld.lld -T "$LINKER" -o "$BUILD/kernel.elf" "$BUILD/boot.o" $OBJECTS \
    || fail "link failed"

# --- boot --------------------------------------------------------------------
echo "==> booting on qemu virt (cortex-a76, timeout ${BOOT_TIMEOUT}s)"
LOG="$BUILD/serial.log"
: > "$LOG"
"$QEMU" -M virt -cpu cortex-a76 -m 512M -nographic \
        -kernel "$BUILD/kernel.elf" -serial mon:stdio >"$LOG" 2>&1 &
QPID=$!

# Poll rather than sleeping the whole timeout: a passing run should finish in
# well under a second, and a CI job should not pay 30s for it.
deadline=$(( $(date +%s) + BOOT_TIMEOUT ))
last_needed="$(grep -vE '^\s*(#|$)' "$MILESTONES" | tail -1)"
while [ "$(date +%s)" -lt "$deadline" ]; do
    if [ -n "$last_needed" ] && grep -qF "$last_needed" "$LOG" 2>/dev/null; then
        break
    fi
    kill -0 "$QPID" 2>/dev/null || break
    sleep 0.2
done
kill "$QPID" 2>/dev/null
wait "$QPID" 2>/dev/null

# --- assert ------------------------------------------------------------------
# Order matters: a milestone appearing before the one that must precede it means
# initialisation ran out of sequence, which is a defect even though every line
# is present.
rc=0
pos=0
missing=0
while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    found="$(grep -nF "$line" "$LOG" 2>/dev/null | head -1 | cut -d: -f1)"
    if [ -z "$found" ]; then
        echo "MISSING  $line" >&2
        missing=$((missing + 1))
        rc=1
    elif [ "$found" -lt "$pos" ]; then
        echo "OUT OF ORDER  $line (line $found, after $pos)" >&2
        rc=1
    else
        pos="$found"
        echo "ok  $line"
    fi
done < "$MILESTONES"

if [ "$rc" != 0 ]; then
    echo "" >&2
    echo "boot-aarch64: FAIL ($missing milestone(s) missing)" >&2
    echo "--- serial log:" >&2
    cat "$LOG" >&2
    exit 1
fi

echo "boot-aarch64: PASS"
exit 0
