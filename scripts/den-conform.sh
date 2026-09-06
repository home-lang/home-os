#!/bin/bash
# den-conform.sh — the shell conformance gate (MASTER_PLAN Phase 3, shell-suite).
#
# home-os's shell is den. The reference implementation lives at ~/Code/Tools/den
# and this gate is what makes "den" mean something: it runs the same script
# through the reference shell and through home-os's, and requires the two to
# produce identical bytes.
#
# Without this, "home-os runs den" is a claim about a name. With it, it is a
# claim anyone can check, and a claim that fails the moment the two diverge.
#
# CI has no den binary, so the reference output is recorded into a golden file
# beside each script (tests/den/NAME.expected) and CI compares against that.
# `--record` regenerates the goldens from the real den, which is the only thing
# that may write them: a golden edited by hand is a test that asserts whatever
# the code already does.
#
# Usage: scripts/den-conform.sh [--verbose] [--keep] [--record] [test.den ...]
#   With no arguments, every tests/den/*.den runs.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-120}"

VERBOSE=0
KEEP=0
RECORD=0
tests=()
for arg in "$@"; do
    case "$arg" in
        --verbose) VERBOSE=1 ;;
        --keep) KEEP=1 ;;
        --record) RECORD=1 ;;
        -*) echo "unknown option: $arg" >&2; exit 2 ;;
        *) tests+=("$arg") ;;
    esac
done
if [ "${#tests[@]}" -eq 0 ]; then
    while IFS= read -r f; do tests+=("$f"); done < <(ls "$REPO_ROOT"/tests/den/*.den 2>/dev/null)
fi
[ "${#tests[@]}" -gt 0 ] || { echo "error: no test scripts found under tests/den" >&2; exit 2; }

# The reference shell. Required to record a golden; not required to check one.
DEN="${DEN:-$HOME/.local/bin/den}"
if [ "$RECORD" = 1 ] && [ ! -x "$DEN" ]; then
    echo "error: --record needs the reference den; not found at $DEN (set DEN)" >&2
    exit 2
fi

# Recording asks the reference shell what each script prints and writes it
# beside the script. Nothing else writes these files.
if [ "$RECORD" = 1 ]; then
    for t in "${tests[@]}"; do
        body="$(grep -v '^[[:space:]]*#' "$t" | grep -v '^[[:space:]]*$')"
        "$DEN" -c "$body" > "${t%.den}.expected" 2>&1
        echo "den-conform: recorded ${t%.den}.expected from $DEN"
    done
    exit 0
fi

for t in "${tests[@]}"; do
    [ -f "${t%.den}.expected" ] || {
        echo "error: no golden for $t — run scripts/den-conform.sh --record" >&2
        exit 2
    }
done

# Found the way boot-gate finds it, so both gates run the same emulator.
QEMU="${QEMU:-}"
if [ -z "$QEMU" ]; then
    if command -v qemu-system-x86_64 >/dev/null 2>&1; then
        QEMU="qemu-system-x86_64"
    else
        QEMU="$REPO_ROOT/pantry/.bin/qemu-system-x86_64"
    fi
fi
[ -x "$QEMU" ] || command -v "$QEMU" >/dev/null 2>&1 || {
    echo "error: qemu-system-x86_64 not found (set QEMU)" >&2; exit 2; }

workdir="$(mktemp -d)"
cleanup() {
    [ -n "${qemu_pid:-}" ] && kill "$qemu_pid" 2>/dev/null
    [ "$KEEP" = 1 ] || rm -rf "$workdir"
}
trap cleanup EXIT
[ "$KEEP" = 1 ] && echo "den-conform: keeping $workdir"

# One kernel, built the same way the boot gate builds it, so the shell under
# test is the shell that ships rather than a second build that drifted.
#
# KERNEL_BIN supplies one that is already built. The build is by far the
# longest part of this gate, and a caller that has just run the boot gate has
# the identical image sitting there — rebuilding it only invites the two to
# differ.
if [ -n "${KERNEL_BIN:-}" ]; then
    [ -s "$KERNEL_BIN" ] || { echo "error: KERNEL_BIN=$KERNEL_BIN is empty or missing" >&2; exit 2; }
    cp "$KERNEL_BIN" "$workdir/kernel.bin"
    echo "den-conform: using the kernel at $KERNEL_BIN"
else
    echo "den-conform: building the kernel..."
    BUILD_OUT="$workdir/kernel.bin" "$SCRIPT_DIR/boot-gate.sh" --build-only >"$workdir/build.log" 2>&1
    if [ ! -s "$workdir/kernel.bin" ]; then
        echo "den-conform: kernel build failed" >&2
        tail -20 "$workdir/build.log" >&2
        exit 1
    fi
fi

# The lines to feed. Comments and blank lines are dropped here rather than in
# the kernel: the console echoes everything it is sent, and a comment would
# add an echo with no output to pair it with.
: > "$workdir/feed.txt"
for t in "${tests[@]}"; do
    grep -v '^[[:space:]]*#' "$t" | grep -v '^[[:space:]]*$' >> "$workdir/feed.txt"
done

# What the reference shell made of the same scripts, in the same order.
: > "$workdir/expected.txt"
for t in "${tests[@]}"; do
    cat "${t%.den}.expected" >> "$workdir/expected.txt"
done

log="$workdir/serial.log"
{
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
        printf '%s\n' "$cmd"
        sleep 1
    done < "$workdir/feed.txt"
    sleep 3
} | "$QEMU" -kernel "$workdir/kernel.bin" \
    -serial stdio -display none -no-reboot -m 256M > "$log" 2>&1 &
qemu_pid=$!

# QEMU does not exit when the feeding subshell closes its stdin, so waiting on
# it waits forever. Wait for the log to go quiet instead — the feed has a
# definite end, and once the last command's output has landed nothing more is
# coming — then stop the machine.
quiet=0
elapsed=0
last_size=-1
while [ "$elapsed" -lt "$(( BOOT_TIMEOUT + 300 ))" ]; do
    size="$(wc -c < "$log" 2>/dev/null | tr -d ' ')"
    if [ "$size" = "$last_size" ]; then
        quiet=$(( quiet + 1 ))
    else
        quiet=0
        last_size="$size"
    fi
    # Quiet for six seconds, with the last command's output already in, means
    # the session is over. The feed sleeps one second between commands, so a
    # gap this long cannot be the pause between two of them.
    if [ "$quiet" -ge 6 ] && [ "${size:-0}" -gt 0 ]; then break; fi
    sleep 1
    elapsed=$(( elapsed + 1 ))
done

kill "$qemu_pid" 2>/dev/null
wait "$qemu_pid" 2>/dev/null
qemu_pid=""

# Recover what the shell printed, prompt by prompt. Each prompt is followed by
# the echo of the line that was typed and then that line's output, so dropping
# the first line of each chunk leaves exactly the output.
python3 - "$log" "$workdir/actual.txt" "$workdir/feed.txt" <<'PYX'
import re, sys

raw = open(sys.argv[1], 'rb').read().decode('utf-8', 'replace').replace('\r', '')
commands = [l for l in open(sys.argv[3]).read().split('\n') if l != '']

PROMPT = 'home-os> '

# Anchor on each command's echo rather than assuming everything after the
# "console ready" line is shell output. The kernel goes on printing driver and
# self-test diagnostics well past the first prompt, so the text between two
# prompts is not simply one command's output — it may begin with a page of
# boot log that arrived while the console sat idle.
out = []
cursor = 0
for cmd in commands:
    echo = raw.find(cmd + '\n', cursor)
    if echo < 0:
        out.append('<<den-conform: no echo found for: %s>>' % cmd)
        continue
    body_start = echo + len(cmd) + 1
    nxt = raw.find(PROMPT, body_start)
    body = raw[body_start:nxt] if nxt >= 0 else raw[body_start:]
    cursor = body_start + len(body)
    lines = body.split('\n')
    # The body ends with the newline that precedes the next prompt, so the
    # split leaves one empty element behind. A command that printed nothing
    # would otherwise contribute a blank line the reference does not have.
    if lines and lines[-1] == '':
        lines.pop()
    for line in lines:
        # Kernel diagnostics are bracketed-tag lines and arrive asynchronously;
        # they are the machine talking, not the shell. No den script prints one.
        if re.match(r'^\[[A-Za-z0-9_. -]+\] ', line):
            continue
        out.append(line)

while out and out[-1] == '':
    out.pop()
open(sys.argv[2], 'w').write('\n'.join(out) + ('\n' if out else ''))
PYX

# The reference output has no trailing blank either.
python3 - "$workdir/expected.txt" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read().replace('\r', '').split('\n')
while t and t[-1] == '':
    t.pop()
open(p, 'w').write('\n'.join(t) + ('\n' if t else ''))
PY

if [ "$VERBOSE" = 1 ]; then
    echo "--- reference ---"; cat "$workdir/expected.txt"
    echo "--- home-os ---";   cat "$workdir/actual.txt"
fi

exp_lines="$(wc -l < "$workdir/expected.txt" | tr -d ' ')"
if diff -u "$workdir/expected.txt" "$workdir/actual.txt" > "$workdir/diff.txt" 2>&1; then
    echo "den-conform: $exp_lines lines identical to the reference shell (${#tests[@]} script(s))"
    exit 0
fi

echo "" >&2
echo "RATCHET BROKEN: home-os's shell diverged from the reference den." >&2
echo "  golden recorded from: $DEN" >&2
echo "  scripts:   ${tests[*]}" >&2
echo "" >&2
head -60 "$workdir/diff.txt" >&2
echo "" >&2
echo "(-) is what den prints, (+) is what home-os printed." >&2
exit 1
