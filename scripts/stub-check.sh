#!/bin/bash
# stub-check.sh — the stub-register gate (MASTER_PLAN §7, register rule 3).
#
# The register in docs/MASTER_PLAN.md §7 is the single source of truth. This
# script parses it and enforces both directions:
#
#   1. Every `// STUB(Sn)` marker in the source names an ID that the register
#      lists, and sits in the file (or directory) that entry names.
#   2. Every open register entry has at least one marker in its source, so an
#      entry cannot linger after the code it describes is gone.
#   3. A bare `// STUB` with no ID is rejected — stubs are registered or they
#      do not exist.
#
# Usage: scripts/stub-check.sh [--list]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN="$REPO_ROOT/docs/MASTER_PLAN.md"
SEARCH_DIRS=(kernel apps libs installer)
LIST=0
[ "${1:-}" = "--list" ] && LIST=1

[ -f "$PLAN" ] || { echo "error: $PLAN not found" >&2; exit 2; }

# --- Parse the register table out of §7 -------------------------------------
# Rows look like:  | S2 | description | `path/to/file` | P1 | gate |
# CLOSED entries are marked in the description and are not expected in source.
declare -a IDS PATHS
while IFS='|' read -r _ id desc path _rest; do
    id="$(echo "$id" | tr -d ' ')"
    case "$id" in S[0-9]*) ;; *) continue ;; esac
    path="$(echo "$path" | tr -d ' `')"
    if echo "$desc" | grep -qi 'closed'; then continue; fi
    IDS+=("$id")
    PATHS+=("$path")
done < <(grep -E '^\| S[0-9]+ \|' "$PLAN")

if [ "${#IDS[@]}" -eq 0 ]; then
    echo "error: no stub-register rows parsed from $PLAN §7" >&2
    exit 2
fi

lookup_path() {
    local want="$1" i
    for i in "${!IDS[@]}"; do
        [ "${IDS[$i]}" = "$want" ] && { echo "${PATHS[$i]}"; return 0; }
    done
    return 1
}

cd "$REPO_ROOT"
existing_dirs=()
for d in "${SEARCH_DIRS[@]}"; do [ -d "$d" ] && existing_dirs+=("$d"); done

violations=0

# --- Direction 1: every marker in source is registered and correctly placed --
# bash 3.2 (macOS) has no associative arrays; a space-delimited string does.
SEEN=" "
seen() { case "$SEEN" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    file="${hit%%:*}"
    if ! echo "$hit" | grep -qE '// STUB\(S[0-9]+\)'; then
        echo "FAIL: bare '// STUB' with no register ID: $hit"
        echo "      Use '// STUB(Sn): ...' and add the entry to MASTER_PLAN §7."
        violations=$((violations + 1))
        continue
    fi
    id="$(echo "$hit" | sed -nE 's/.*\/\/ STUB\((S[0-9]+)\).*/\1/p')"
    if ! regpath="$(lookup_path "$id")"; then
        echo "FAIL: $file marks $id, which is not an open entry in MASTER_PLAN §7"
        violations=$((violations + 1))
        continue
    fi
    case "$file" in
        "$regpath"*) ;;   # exact file, or inside the registered directory
        *)
            echo "FAIL: $id is registered against '$regpath' but marked in '$file'"
            violations=$((violations + 1))
            continue
            ;;
    esac
    seen "$id" || SEEN="$SEEN$id "
    [ "$LIST" = 1 ] && echo "  $id  $file"
done < <(grep -rn '// STUB' "${existing_dirs[@]}" 2>/dev/null)

# --- Direction 2: every open register entry is marked in source --------------
for i in "${!IDS[@]}"; do
    id="${IDS[$i]}"
    if ! seen "$id"; then
        echo "FAIL: $id is open in MASTER_PLAN §7 but no '// STUB($id)' marker exists"
        echo "      Mark it in ${PATHS[$i]}, or move the entry to CLOSED."
        violations=$((violations + 1))
    fi
done

if [ "$violations" -gt 0 ]; then
    echo ""
    echo "stub-register gate FAILED: $violations violation(s)" >&2
    exit 1
fi

echo "stub-register OK — ${#IDS[@]} open entries, all marked and placed correctly"
exit 0
