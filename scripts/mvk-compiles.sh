#!/bin/bash
# mvk-compiles.sh — the codegen ratchet (MASTER_PLAN §5 Phase 0.5, issue #38).
#
# "Does the tree compile?" is a question that answers "no" for months and tells
# nobody anything. This asks a better one: how many of the 41 Minimum Viable
# Kernel files in MASTER_PLAN Appendix A reach codegen today? That number moves
# every week, and it may never fall.
#
# The Appendix A list is parsed out of the plan, so there is one source of truth
# and adding a file to the MVK means editing the plan.
#
# Usage: scripts/mvk-compiles.sh [--list] [--floor N] [--arch ARCH]
#   --list     print per-file PASS/FAIL
#   --floor N  exit 1 if fewer than N files compile (the ratchet; CI passes the
#              committed floor from scripts/mvk-floor.txt)
#   --arch A   x86_64 (default) or aarch64. Each architecture keeps its own
#              floor file, because they advance independently: a file can lower
#              on one and not the other, and averaging the two would hide it.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN="$REPO_ROOT/docs/MASTER_PLAN.md"
LIST=0
FLOOR=""
ARCH="x86_64"
while [ $# -gt 0 ]; do
    case "$1" in
        --list)  LIST=1; shift ;;
        --floor) FLOOR="$2"; shift 2 ;;
        --floor=*) FLOOR="${1#*=}"; shift ;;
        --arch)  ARCH="$2"; shift 2 ;;
        --arch=*) ARCH="${1#*=}"; shift ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

case "$ARCH" in
    x86_64|x86-64)
        ARCH="x86_64"
        FLOOR_FILE="$REPO_ROOT/scripts/mvk-floor.txt"
        # No --target: x86-64 is this path's default, and passing it would
        # make the invocation differ from the one build.sh uses.
        COMPILER_TARGET_ARGS=""
        ;;
    aarch64|arm64)
        ARCH="aarch64"
        FLOOR_FILE="$REPO_ROOT/scripts/mvk-floor-aarch64.txt"
        COMPILER_TARGET_ARGS="--target=aarch64-freestanding"
        ;;
    *)
        echo "error: --arch $ARCH is not a target this backend lowers for (x86_64, aarch64)" >&2
        exit 2
        ;;
esac

HOME_COMPILER="${HOME_COMPILER:-}"
if [ -z "$HOME_COMPILER" ]; then
    for root in "${HOME_REPO:-}" "$REPO_ROOT/../home" "$REPO_ROOT/../lang"; do
        [ -z "$root" ] && continue
        if [ -x "$root/zig-out/bin/home" ]; then HOME_COMPILER="$root/zig-out/bin/home"; break; fi
    done
fi
[ -x "$HOME_COMPILER" ] || { echo "error: home compiler not found (set HOME_COMPILER)" >&2; exit 2; }
[ -f "$PLAN" ] || { echo "error: $PLAN not found" >&2; exit 2; }

# Assembler for step 3. Zig is used purely as an assembler here — no kernel
# logic is written in it (CLAUDE.md). Order: $ZIG, PATH, the Home toolchain.
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
if [ -n "$ZIG" ] && command -v "$ZIG" >/dev/null 2>&1; then
    ASSEMBLER="$ZIG"
    ASSEMBLER_ARGS="cc -c -x assembler -target ${ARCH}-freestanding"
elif [ "$ARCH" = "x86_64" ] && command -v as >/dev/null 2>&1; then
    ASSEMBLER="as"
    ASSEMBLER_ARGS="-c"
else
    # The host assembler only assembles for the host. Cross-assembling needs
    # zig, so say that rather than failing later with a confusing error.
    echo "error: no assembler for $ARCH found (set ZIG to a zig binary)" >&2
    exit 2
fi

# Appendix A lists its files as bullets holding a single backticked path.
# Only .home files are compile targets; boot.s and linker.ld are inputs to the
# link step, not to codegen.
mapfile_compat() {
    awk '
        /^## Appendix A/ { inapp = 1 }
        inapp && /^- `kernel\/.*\.home`/ {
            match($0, /`[^`]+`/)
            p = substr($0, RSTART + 1, RLENGTH - 2)
            print p
        }
    ' "$PLAN" | sort -u
}

files="$(mapfile_compat)"
[ -n "$files" ] || { echo "error: no Appendix A .home files parsed from the plan" >&2; exit 2; }

total=0
ok=0
failed=""
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    total=$((total + 1))
    abs="$REPO_ROOT/$rel"
    if [ ! -f "$abs" ]; then
        failed="${failed}MISSING $rel"$'\n'
        [ "$LIST" = 1 ] && echo "MISSING $rel"
        continue
    fi
    # A file counts as compiling only when all three hold. The compiler
    # exiting 0 is not enough on its own: the kernel backend emits a marker
    # comment and carries on when it meets something it cannot lower, so an
    # exit status of 0 can accompany a file that produced nothing usable.
    #   1. the compiler exits 0 and writes a non-empty .s
    #   2. that .s carries no ERROR or unsupported marker
    #   3. the assembler accepts it
    reason=""
    if ! "$HOME_COMPILER" build "$abs" --kernel $COMPILER_TARGET_ARGS -o "$tmpdir/out.s" >/dev/null 2>&1; then
        reason="compiler exited nonzero"
    elif [ ! -s "$tmpdir/out.s" ]; then
        reason="no output"
    elif grep -qE '# (ERROR|unsupported)' "$tmpdir/out.s"; then
        n_markers="$(grep -cE '# (ERROR|unsupported)' "$tmpdir/out.s")"
        first="$(grep -oE '# (ERROR|unsupported)[^\n]*' "$tmpdir/out.s" | head -1)"
        reason="$n_markers unlowered construct(s), first: ${first}"
    elif ! "$ASSEMBLER" $ASSEMBLER_ARGS "$tmpdir/out.s" -o "$tmpdir/out.o" >"$tmpdir/as.log" 2>&1; then
        reason="assembler rejected it: $(head -1 "$tmpdir/as.log")"
    fi

    if [ -z "$reason" ]; then
        ok=$((ok + 1))
        [ "$LIST" = 1 ] && echo "PASS $rel"
    else
        failed="${failed}FAIL $rel — $reason"$'\n'
        [ "$LIST" = 1 ] && echo "FAIL $rel — $reason"
    fi
done <<< "$files"

echo "mvk-compiles ($ARCH): $ok/$total Appendix A files reach codegen"

if [ -z "$FLOOR" ] && [ -f "$FLOOR_FILE" ]; then
    FLOOR="$(grep -vE '^\s*#' "$FLOOR_FILE" | tr -dc '0-9')"
fi

if [ -n "$FLOOR" ]; then
    if [ "$ok" -lt "$FLOOR" ]; then
        echo "" >&2
        echo "RATCHET BROKEN: $ok files compile, floor is $FLOOR." >&2
        echo "The count may never fall. There are exactly three legitimate" >&2
        echo "reasons to lower $FLOOR_FILE, each requiring the reason in the" >&2
        echo "commit message:" >&2
        echo "  1. a file was deliberately removed from Appendix A" >&2
        echo "  2. this script got stricter, so the old number measured less" >&2
        echo "  3. the compiler pin moved backwards deliberately" >&2
        echo "Anything else is a regression. Fix it." >&2
        [ "$LIST" = 0 ] && printf '%s' "$failed" >&2
        exit 1
    fi
    if [ "$ok" -gt "$FLOOR" ]; then
        echo "Ratchet advanced: $ok > floor $FLOOR. Raise $FLOOR_FILE to $ok."
    fi
fi
exit 0
