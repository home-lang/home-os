#!/usr/bin/env bash
# Build and run the host-side regression harness.
#
# The kernel .home files type-check with the Home compiler but have no
# runnable codegen target today, so the algorithms are mirrored in C
# and executed here to validate the fix logic.

set -euo pipefail
cd "$(dirname "$0")"

ZIG="${ZIG:-/opt/homebrew/bin/zig}"
"$ZIG" cc runner.c -o runner -target native-macos -O2 -Wall -Wextra
./runner
