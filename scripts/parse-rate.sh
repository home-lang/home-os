#!/bin/bash
# Parse-rate checker: runs the Home compiler parser over every kernel .home
# file and reports pass/fail counts plus a list of failures.
# Usage: scripts/parse-rate.sh [--list] [--strict]
#   --strict  exit 1 unless every file parses (used by the parse-rate CI gate)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STRICT=0
# Locate the Home compiler: prefer $HOME_COMPILER, then $HOME_REPO layouts
# (repo root with zig-out, or a nested lang/ checkout).
HOME_REPO="${HOME_REPO:-}"
HOME_COMPILER="${HOME_COMPILER:-}"
if [ -z "$HOME_COMPILER" ]; then
    for root in "$HOME_REPO" "$REPO_ROOT/../home" "$REPO_ROOT/../lang"; do
        [ -z "$root" ] && continue
        for cand in "$root/zig-out/bin/home" "$root/lang/zig-out/bin/home"; do
            if [ -x "$cand" ]; then HOME_COMPILER="$cand"; break 2; fi
        done
    done
fi
LIST_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --list) LIST_ONLY=1 ;;
        --strict) STRICT=1 ;;
    esac
done

if [ ! -x "$HOME_COMPILER" ]; then
    echo "error: home compiler not found at $HOME_COMPILER (set HOME_COMPILER)" >&2
    exit 2
fi

total=0
fail=0
failed=""
while IFS= read -r f; do
    total=$((total + 1))
    if ! "$HOME_COMPILER" ast "$f" >/dev/null 2>&1; then
        fail=$((fail + 1))
        failed="${failed}${f}"$'\n'
        if [ "$LIST_ONLY" = 1 ]; then
            echo "FAIL $f"
        fi
    fi
done < <(find "$REPO_ROOT/kernel" -name '*.home' | sort)

pass=$((total - fail))
echo "parse-rate: $pass/$total ($(( pass * 100 / total ))%)"
if [ "$STRICT" = 1 ] && [ "$fail" -gt 0 ]; then
    echo "parse-rate gate FAILED: $fail file(s) do not parse" >&2
    exit 1
fi
exit 0
