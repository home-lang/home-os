# Changelog

All notable changes to HomeOS are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Note:** previous contents of this file claimed a "v1.0.0" release from
> December 2025. That release never existed — no HomeOS kernel has ever been
> compiled end-to-end, let alone released. The log was reset to reality at
> the start of Phase 0 ([MASTER_PLAN §13.5](docs/MASTER_PLAN.md)).

## [Unreleased]

### Added
- **A Home-compiled kernel boots.** `kernel/src/mvk_poc.home` compiles through
  the Home compiler, links via `kernel/linker.ld`, boots in QEMU, and prints
  `HomeOS v0.1: kernel_main reached` on the serial console (#26). This is the
  first time Home-generated machine code has executed.
- `scripts/build.sh mvk` — the Minimum Viable Kernel build, now the default
  subcommand and the only end-to-end Home build path
- `scripts/boot-test.sh` — the `boot-qemu-x86_64` gate: boots the kernel and
  asserts the proof-of-life string on serial
- `scripts/stub-check.sh` — the `stub-register` gate, enforcing MASTER_PLAN §7
  against `// STUB(Sn)` markers in source, in both directions
- `scripts/parse-rate.sh` — the `parse-rate` gate
- `scripts/generate_status.py` — generates IMPLEMENTATION_STATUS.md by
  measurement (re-parses, rebuilds, reboots) so the status page cannot drift
- Multiboot1 a.out-kludge header alongside Multiboot2 in `kernel/src/boot.s`,
  so QEMU's `-kernel` loader can boot the image without GRUB or an ISO
- `deps.yaml` declaring the QEMU toolchain, installable with `pantry install`
- MASTER_PLAN.md adopted as the canonical roadmap (supersedes the TODO.md
  strategy section)

### Fixed
- A1 (#23): the last 9 non-parsing kernel files — **410/410 (100%)**
- S1 (#24): every silent fallback removed from `scripts/build.sh`. The dead
  `kernel.zig` / `rpi5_main.zig` paths, the generated hlt-stub substituted for
  a missing compiler, and the "fall back to Zig" toolchain warning all now
  exit nonzero with a message naming the real blocker.
- Home compiler (home-lang/home): kernel codegen emitted every assembly line
  without a terminator, so nothing it produced could be assembled

### Changed
- CI replaced with the phase gates (#25). Job names are the gates; every one
  is blocking. The old workflow built nonexistent targets and had never built
  the real kernel.
- The grep-based suites under `tests/` renamed to `static-checks/` — they
  assert that files exist and that symbol names appear, and execute nothing
- §13 docs realignment (#27): honest README baseline with gate table;
  aspirational guides carry a status banner; CHANGELOG and RELEASE_NOTES reset
  to reality
