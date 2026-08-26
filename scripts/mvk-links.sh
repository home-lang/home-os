#!/bin/bash
# mvk-links.sh — the link ratchet (MASTER_PLAN Phase 0 exit gate).
#
# scripts/mvk-compiles.sh asks whether each Appendix A file reaches codegen
# *individually*. This asks the question that only appears when they are put
# together: does the whole set link into one image?
#
# Per-file compilation cannot see duplicate symbols, references to functions
# that were never written, or section-placement conflicts. All three were
# present the first time this ran.
#
# Reports two numbers, each with its own ratchet:
#   duplicate symbols  — must stay at 0
#   undefined symbols  — must not rise
#
# Usage: scripts/mvk-links.sh [--list] [--keep]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN="$REPO_ROOT/docs/MASTER_PLAN.md"
FLOOR_FILE="$REPO_ROOT/scripts/mvk-links-ceiling.txt"

LIST=0
KEEP=0
for arg in "$@"; do
    case "$arg" in
        --list) LIST=1 ;;
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
compiled=0
while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    base="$(echo "$rel" | sed 's|/|_|g; s|\.home$||')"
    if "$HOME_COMPILER" build "$rel" --kernel -o "$workdir/$base.s" >/dev/null 2>&1 \
       && [ -s "$workdir/$base.s" ] \
       && "$ZIG" cc -c -x assembler -target x86_64-freestanding \
            "$workdir/$base.s" -o "$workdir/$base.o" >/dev/null 2>&1; then
        compiled=$((compiled + 1))
    fi
done <<< "$files"

log="$workdir/link.log"
"$ZIG" build-exe "$REPO_ROOT/kernel/src/boot.s" "$workdir"/*.o \
    -target x86_64-freestanding -O ReleaseSafe \
    -T "$REPO_ROOT/kernel/linker.ld" \
    --name mvk-all -femit-bin="$workdir/mvk-all.elf" > "$log" 2>&1

dups="$(grep -oE 'duplicate symbol: [^ ]+' "$log" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
undef="$(grep -oE 'undefined symbol: [^ ]+' "$log" 2>/dev/null | sort -u | wc -l | tr -d ' ')"

echo "mvk-links: $compiled objects; $dups duplicate symbol(s), $undef undefined symbol(s)"

if [ "$LIST" = 1 ]; then
    grep -oE 'duplicate symbol: [^ ]+' "$log" 2>/dev/null | sort -u
    grep -oE 'undefined symbol: [^ ]+' "$log" 2>/dev/null | sort -u
fi

if [ -f "$workdir/mvk-all.elf" ]; then
    echo "LINKED: the whole Appendix A set produced one image."
fi

ceiling=""
[ -f "$FLOOR_FILE" ] && ceiling="$(grep -vE '^\s*#' "$FLOOR_FILE" | tr -dc '0-9')"

rc=0
if [ "$dups" -gt 0 ]; then
    echo "" >&2
    echo "RATCHET BROKEN: $dups duplicate symbol(s); the set must have none." >&2
    grep -oE 'duplicate symbol: [^ ]+' "$log" | sort -u >&2
    rc=1
fi
if [ -n "$ceiling" ] && [ "$undef" -gt "$ceiling" ]; then
    echo "" >&2
    echo "RATCHET BROKEN: $undef undefined symbols, ceiling is $ceiling." >&2
    echo "Something now references a function that was never written." >&2
    rc=1
fi
if [ -n "$ceiling" ] && [ "$undef" -lt "$ceiling" ]; then
    echo "Ratchet advanced: $undef < ceiling $ceiling. Lower $FLOOR_FILE to $undef."
fi
exit $rc
