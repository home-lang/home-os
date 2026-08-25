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
# Usage: scripts/mvk-compiles.sh [--list] [--floor N]
#   --list     print per-file PASS/FAIL
#   --floor N  exit 1 if fewer than N files compile (the ratchet; CI passes the
#              committed floor from scripts/mvk-floor.txt)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN="$REPO_ROOT/docs/MASTER_PLAN.md"
FLOOR_FILE="$REPO_ROOT/scripts/mvk-floor.txt"

LIST=0
FLOOR=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list)  LIST=1; shift ;;
        --floor) FLOOR="$2"; shift 2 ;;
        --floor=*) FLOOR="${1#*=}"; shift ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
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
[ -f "$PLAN" ] || { echo "error: $PLAN not found" >&2; exit 2; }

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
    if "$HOME_COMPILER" build "$abs" --kernel -o "$tmpdir/out.s" >/dev/null 2>&1 \
       && [ -s "$tmpdir/out.s" ]; then
        ok=$((ok + 1))
        [ "$LIST" = 1 ] && echo "PASS $rel"
    else
        failed="${failed}FAIL $rel"$'\n'
        [ "$LIST" = 1 ] && echo "FAIL $rel"
    fi
done <<< "$files"

echo "mvk-compiles: $ok/$total Appendix A files reach codegen"

if [ -z "$FLOOR" ] && [ -f "$FLOOR_FILE" ]; then
    FLOOR="$(grep -vE '^\s*#' "$FLOOR_FILE" | tr -dc '0-9')"
fi

if [ -n "$FLOOR" ]; then
    if [ "$ok" -lt "$FLOOR" ]; then
        echo "" >&2
        echo "RATCHET BROKEN: $ok files compile, floor is $FLOOR." >&2
        echo "The count may never fall. Fix the regression, or if a file was" >&2
        echo "deliberately removed from Appendix A, lower $FLOOR_FILE in the" >&2
        echo "same commit as the plan edit." >&2
        [ "$LIST" = 0 ] && printf '%s' "$failed" >&2
        exit 1
    fi
    if [ "$ok" -gt "$FLOOR" ]; then
        echo "Ratchet advanced: $ok > floor $FLOOR. Raise $FLOOR_FILE to $ok."
    fi
fi
exit 0
