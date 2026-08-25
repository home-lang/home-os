# static-checks — NOT a test suite

> These scripts were previously in `tests/`. They were renamed so that nobody
> mistakes them for tests. **Nothing here executes HomeOS code.**

Per [MASTER_PLAN §12](../docs/MASTER_PLAN.md#12-testing--verification-strategy):

> Every grep-test is replaced by an executed test. The existing bash suites
> under `tests/` check file existence and grep for symbols; they are renamed to
> `static-checks/` immediately so nobody mistakes them for tests, and each is
> deleted the moment its runtime equivalent lands.

## What these scripts actually do

They assert that files exist and that certain symbol names appear in the
source. A green run means "the source still contains a function called
`tcp_connect`" — it does **not** mean TCP works, or that the code compiles,
links, or has ever run.

## What the real tests are

The real verification lives in CI, where the job names *are* the phase gates
(MASTER_PLAN §12 Tier 1):

| Gate | Phase | What it proves |
|------|-------|----------------|
| `parse-rate` | 0 | Every kernel `.home` file parses |
| `stub-register` | 0 | No unregistered `// STUB` markers |
| `boot-qemu-x86_64` | 0 | A Home-compiled kernel boots and prints on serial |
| `boot-to-shell` | 1 | Interactive serial shell runs scripted commands |
| `storage-roundtrip`, `net-echo`, `fb-boot-log` | 2 | Storage, networking, console actually work |
| `libc-suite`, `shell-suite`, `coreutils-suite` | 3 | Userspace executes |
| `craft-demo`, `wm-layouts` | 4 | GUI renders and responds |
| `iso-install`, `desktop-parity-suite` | 5 | The desktop installs and works |

## Deletion policy

Each file in this directory is **deleted** when its runtime equivalent lands.
Do not add new files here. New verification goes in CI as an executed gate.

| Directory | Deleted when |
|-----------|--------------|
| `kernel/` | `boot-to-shell` is green |
| `unit/`, `integration/` | the Phase 2 gates are green |
| `shell/` | `shell-suite` is green |
| `perf/`, `stress/` | Tier 2 nightly soak jobs land |
| `hardware/` | Tier 3 hardware-in-loop CI lands (Phase 7a) |
| `system/` | `boot-qemu-x86_64` covers it |
