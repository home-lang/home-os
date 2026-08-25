#!/bin/bash
# typecheck.sh — the typecheck gate (MASTER_PLAN milestone A2, Phase 0.5).
#
# Runs the Home type checker over the Minimum Viable Kernel file set from
# MASTER_PLAN Appendix A and counts files with zero type errors.
#
# This is a separate axis from mvk-compiles. That one asks "can the backend
# lower this file to assembly"; this one asks "does the file typecheck". A
# file can do one without the other, and both are required before the MVK
# builds end to end.
#
# `home check` reports diagnostics but exits 0, so this counts them itself
# rather than trusting the exit status.
#
# Usage: scripts/typecheck.sh [--list] [--floor N] [--all]
#   --list     print per-file error counts
#   --floor N  exit 1 if fewer than N files are clean (default: scripts/typecheck-floor.txt)
#   --all      check every kernel .home file, not just the Appendix A set
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN="$REPO_ROOT/docs/MASTER_PLAN.md"
FLOOR_FILE="$REPO_ROOT/scripts/typecheck-floor.txt"

LIST=0
ALL=0
FLOOR=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list)  LIST=1; shift ;;
        --all)   ALL=1; shift ;;
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

if [ "$ALL" = 1 ]; then
    files="$(cd "$REPO_ROOT" && find kernel -name '*.home' | sort)"
else
    [ -f "$PLAN" ] || { echo "error: $PLAN not found" >&2; exit 2; }
    files="$(awk '
        /^## Appendix A/ { inapp = 1 }
        inapp && /^- `kernel\/.*\.home`/ {
            match($0, /`[^`]+`/)
            print substr($0, RSTART + 1, RLENGTH - 2)
        }
    ' "$PLAN" | sort -u)"
fi
[ -n "$files" ] || { echo "error: no files to check" >&2; exit 2; }

cd "$REPO_ROOT"
total=0
clean=0
detail=""

while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    total=$((total + 1))
    if [ ! -f "$rel" ]; then
        detail="${detail}MISSING $rel"$'\n'
        continue
    fi
    # Count diagnostics, not the exit status: `home check` exits 0 either way.
    #
    # Match the checker's diagnostic form exactly: "error:" optionally wrapped
    # in colour codes. The compiler's debug allocator also writes lines
    # beginning "error(DebugAllocator):", and a looser pattern counts those —
    # which is how an earlier version of this script reported every file as
    # having hundreds of type errors.
    n="$("$HOME_COMPILER" check "$rel" 2>&1 \
        | grep -cE $'^(\x1b\\[[0-9;]*m)?error(\x1b\\[[0-9;]*m)?:' || true)"
    if [ "${n:-0}" -eq 0 ]; then
        clean=$((clean + 1))
        [ "$LIST" = 1 ] && echo "CLEAN $rel"
    else
        detail="${detail}${n} $rel"$'\n'
        [ "$LIST" = 1 ] && echo "ERRORS $n $rel"
    fi
done <<< "$files"

echo "typecheck: $clean/$total files have zero type errors"

if [ -z "$FLOOR" ] && [ -f "$FLOOR_FILE" ] && [ "$ALL" = 0 ]; then
    FLOOR="$(grep -vE '^\s*#' "$FLOOR_FILE" | tr -dc '0-9')"
fi

if [ -n "$FLOOR" ]; then
    if [ "$clean" -lt "$FLOOR" ]; then
        echo "" >&2
        echo "RATCHET BROKEN: $clean files typecheck clean, floor is $FLOOR." >&2
        printf '%s' "$detail" | sort -rn >&2
        exit 1
    fi
    if [ "$clean" -gt "$FLOOR" ]; then
        echo "Ratchet advanced: $clean > floor $FLOOR. Raise $FLOOR_FILE to $clean."
    fi
fi
exit 0
