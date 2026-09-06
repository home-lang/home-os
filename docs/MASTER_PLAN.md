# HomeOS Master Plan

> **The open-source macOS — built entirely in Home, one language from kernel to desktop, and better than Omarchy everywhere.**

- **Version:** 1.1
- **Date:** 2026-08-24 (revised 2026-08-25 at the Phase 0 gate)
- **Supersedes:** the "Canonical Strategic TODO" section of `TODO.md` (Nov 2025)
- **Standing rule:** every claim of completion in this document must be CI-verifiable, or it must be labeled **ASPIRATION**. No exceptions.

## Table of Contents

1. [Mission & Thesis](#1-mission--thesis)
2. [Honest Baseline](#2-honest-baseline)
3. [Strategic Decisions Register](#3-strategic-decisions-register)
4. [The Phase Map](#4-the-phase-map)
5. [Phases in Detail](#5-phases-in-detail)
6. [Workstream A — Home Compiler & Toolchain](#6-workstream-a--home-compiler--toolchain)
7. [Workstream B — Kernel & Stub-Burndown Register](#7-workstream-b--kernel--stub-burndown-register)
8. [Workstream C — Userspace & POSIX](#8-workstream-c--userspace--posix)
9. [Workstreams D & E — GUI and Distribution](#9-workstreams-d--e--gui-and-distribution)
10. [Feature-Parity Matrix vs Omarchy 4.0](#10-feature-parity-matrix-vs-omarchy-40)
11. [Beyond-Parity Differentiators](#11-beyond-parity-differentiators)
12. [Testing & Verification Strategy](#12-testing--verification-strategy)
13. [Documentation Realignment](#13-documentation-realignment)
14. [Governance, Cadence & Releases](#14-governance-cadence--releases)
15. [Risk Register](#15-risk-register)
16. [Sizing & Parallelism](#16-sizing--parallelism)
- [Appendix A — Minimum Viable Kernel file-set](#appendix-a--minimum-viable-kernel-file-set)

---

## 1. Mission & Thesis

**"Open-source macOS"** means, concretely:

- One coherent design language across every surface — a published HIG with a type scale, spacing grid, and motion vocabulary.
- Hardware that just works on a certified list: sleep/resume, external displays, audio, Wi-Fi, battery — zero configuration.
- An integrated first-party app suite that shares one look, one keymap, and one data layer.
- Polish and animation as functional feedback, not decoration.
- A GUI path for every setting — discoverability, not "embrace the config file."
- Install-and-forget updates with reliable, boot-selectable rollback.
- Curation: a small set of excellent defaults rather than a package catalog.

**"Beats Omarchy everywhere"** means: for every capability in Omarchy 4.0 there is a HomeOS answer that is *concretely better* (§10), plus differentiators Omarchy structurally cannot match (§11). The deepest one: HomeOS is **one language top to bottom** — kernel, drivers, compositor, apps, build tool, and CLI are all Home. That makes it the first **agent-legible OS**: an AI agent (or a human) can trace a bug from a button click to the scheduler in a single grammar. Omarchy markets AI-agent friendliness as its frontier, but it can only wrap Linux in scripts; we *are* the artifact.

**Strategy (binding): kernel-first purist.** No Linux-hosted stopgap, no shipping our desktop on someone else's kernel. We compete on our own boot chain or not at all. The honest consequence: Omarchy parity arrives at Phase 5, not next quarter. The payoff: a moat no distro can copy, and every hour of work compounds into our own stack instead of glue.

---

## 2. Honest Baseline

The repository contains a very large body of Home source: roughly **409 kernel `.home` files (~180k lines)** under `kernel/src/`, **125 userspace files** under `apps/`, and a **12-module libc** under `libs/libc/`. The breadth runs from a TCP stack to a compositor, and much of it is written with real care — these are not throwaway sketches.

**What genuinely exists (written, never executed):**

| File | Lines | What it is |
|------|-------|------------|
| `kernel/src/net/tcp.home` | 1,589 | RFC-793-grade TCP: sequence accounting, retransmit queue |
| `kernel/src/sys/syscall.home` | 1,866 | The syscall layer |
| `kernel/src/video/compositor.home` | 2,158 | Window compositor: dirty regions, layers, animations |
| `kernel/src/sched/cfs.home` | 1,068 | CFS scheduler |
| `kernel/src/mm/buddy.home` | 625 | Buddy allocator |
| `kernel/src/gui/window_manager.home` | 565 | Tiling WM: 5 layouts + floating |
| `apps/shell_parser.home` | — | Hardened shell parser: quoting, pipelines, redirection |
| `apps/utils/` | 80+ files | Coreutils: ls, cat, grep, sed, awk, tar, ps, mount… |
| `installer/installer.home` | 1,026 | OS installer |

**The frontier.** **410 of 410 kernel files parse (100%)** — milestone A1 is done. As of the Phase 0 gate, one Home-compiled kernel **executes**: `kernel/src/mvk_poc.home` compiles through the Home compiler, links via `kernel/linker.ld`, boots in QEMU, and prints `HomeOS v0.1: kernel_main reached` on the serial console. That is the entirety of what runs. The Home compiler is developed in [`home-lang/home`](https://github.com/home-lang/home); every HomeOS release pins a version of it (§6).

Two facts keep that achievement in proportion. First, `mvk_poc.home` is written inside the *current* kernel-codegen subset — integer literals, local calls, and simple-form inline assembly — so the proof-of-life message is spelled out through `putc()` calls rather than printed from a string. Widening that subset to the Appendix A file-set is the bulk of Phase 1. Second, parsing is not compiling: 410/410 says the parser accepts these files, not that any of them typecheck or generate code.

**Load-bearing stubs** sit at exactly the seams where software meets hardware — see the Stub-Burndown Register in §7. Each now carries a `// STUB(Sn)` marker enforced by CI against that register.

**Build, CI, and test truth.** All three lied, and all three were fixed at the Phase 0 gate. `scripts/build.sh` had four silent fallbacks — a default path compiling a nonexistent `kernel/src/kernel.zig`, an `rpi5` path around a nonexistent `rpi5_main.zig`, an hlt-loop stub substituted for a missing compiler in the `unified` path, and a toolchain check that downgraded a missing Home compiler to a warning. Every one now exits nonzero naming its real blocker. CI had never built the kernel; it now compiles, links, and boots it on every commit. The grep-scripts under `tests/` were renamed to `static-checks/`, because they assert that files exist and that symbol names appear, and execute nothing.

The frontier is now **widening codegen** — from a single hand-shaped file to the Appendix A file-set — not feature breadth. This section is regenerated at every release and is the credibility anchor of the project: if it is ever flattering but wrong, nothing else in this plan can be trusted.

---

## 3. Strategic Decisions Register

New decisions of this magnitude get an ADR in `docs/adr/`; this register indexes them.

| ID | Decision | Rationale | Revisit trigger |
|----|----------|-----------|-----------------|
| D1 | Kernel-first purist; no hosted-on-Linux stopgap | The one-language moat *is* the product; a Linux-hosted shell would fork effort and dilute the claim | Owner review if the Phase 0 gate stalls beyond budget |
| D2 | Home compiler work is in scope of this plan | The compiler is the critical path (~40% of effort through Phase 2); sequencing must live in one document | Compiler reaches self-hosting (A7) |
| D3 | Hardware order: QEMU → x86-64 → Pi 5 → Apple Silicon | QEMU gives CI-checkable truth; x86-64 is where Omarchy lives; Pi 5 is the fixed-SKU "just works" story; Apple Silicon is the narrative endgame | Each wave's gate |
| D4 | All OS code in Home; extend Home first (per CLAUDE.md) | The rule that makes D1 worth having | Never |
| D5 | Feature-breadth freeze: `kernel/src/iot/`, `kernel/src/ml/`, `kernel/src/industrial/`, gaming, and the container orchestrator receive zero work until Phase 3 exit | Breadth without a booting kernel is dead weight; the freeze is the honestly-paid cost of D1 | Phase 3 exit |

---

## 4. The Phase Map

| Phase | Name | Exit gate (one line) | Release tag |
|-------|------|----------------------|-------------|
| 0 | Truth & Toolchain | Home-compiled Minimum Viable Kernel boots in QEMU under CI; build system and docs stop lying | v0.1 |
| 1 | Kernel Bring-up | Kernel reaches an interactive userspace shell over serial, scripted in CI | v0.2 |
| 2 | Subsystem Realization | Real storage, real networking, real console — the load-bearing stubs burn down | v0.3 |
| 3 | Userspace & POSIX | libc, shell, and 40+ coreutils pass *executed* test suites; pantry installs a package in-VM | v0.4 |
| 4 | Craft & GUI Foundation | Craft v1 frozen; compositor + tiling WM + terminal usable at 60fps in QEMU | v0.5 |
| 5 | Desktop Experience Parity | Every parity row of §10 demoable; ISO installs to desktop in <5 min in CI | **v1.0** |
| 6 | Beyond Omarchy | Snapshot rollback, agent-native CLI, first-party suite, capability security, published HIG | v1.x |
| 7a | x86-64 metal | Boots and suspends on ≥2 real machines incl. one laptop; weekly hardware-in-loop CI | per-wave |
| 7b | Raspberry Pi 5 | Serial boot → desktop on real Pi 5 hardware | per-wave |
| 7c | Apple Silicon (**ASPIRATION**) | m1n1-chainload proof-of-life; research only, no dates | — |

**The ratchet rule:** a phase exits only when its named CI jobs are green on the default branch. Gate jobs are never removed afterward — they accumulate into a permanent regression wall.

---

## 5. Phases in Detail

### Phase 0 — Truth & Toolchain

- **Entry state:** today (§2).
- **Workstreams:** A (A1, A8, A2, A3, A4), B (S1), docs (§13).
- **Deliverables:** the last 9 files parsing; syntax-modernized tree; MVK compile pipeline; honest `build.sh`; CI boot job; docs realignment; auto-generated `IMPLEMENTATION_STATUS.md`.
- **Exit gate:**
  - ✅ CI job **`parse-rate`**: 410/410 kernel files parse, published as a README badge.
  - ✅ CI job **`boot-qemu-x86_64`**: a Home-compiled kernel boots in QEMU (`-serial stdio -display none`) and prints `HomeOS <version>: kernel_main reached` on serial within 30 seconds; fails red otherwise; runs on every commit.
  - ✅ CI job **`stub-register`**: `scripts/stub-check.sh` enforces §7 against `// STUB(Sn)` markers in both directions.
  - ✅ `scripts/build.sh` has zero silent fallbacks: the generated hlt-stub `kernel_stub.s` path and the dead references to `kernel/src/kernel.zig` and `kernel/src/rpi5_main.zig` are removed; a missing compiler or failed compile exits nonzero.
  - ✅ All §13 documentation-realignment items merged; `IMPLEMENTATION_STATUS.md` is generated by measurement.
  - ✅ CI ratchet **`typecheck`**: 39/39 Appendix A files have zero type errors (A2).
  - ✅ CI ratchet **`mvk-compiles`**: 39/39 Appendix A files reach x86-64 codegen with no unlowered constructs, verified by the assembler.
  - ⬜ **The remaining gate item:** *linking* the whole Appendix A set into one multiboot2 ELF and booting it. Each file compiles individually; they have not yet been linked together, which is where duplicate symbols, missing definitions, and section-placement conflicts surface. This is the Phase 0 → Phase 1 boundary.

### Phase 0.5 — Codegen widening (the gap between one file and forty-one)

Recorded as its own stretch because the original plan collapsed it into a single Phase 0 bullet, and it turned out to be the largest remaining piece of Phase 0. The MVK boots, but only a file written to the codegen's current shape. The distance from there to Appendix A is measured, not guessed, by a per-feature ratchet:

- **A ladder of proof-of-life kernels.** Each step adds exactly one language feature to `mvk_poc.home`'s successor and must still boot and print. In order, because each depends on the last: string literals in `.rodata` → arrays and indexing → structs and field access → `while`/`for` over data → function pointers → imports across files → `const`/`comptime` evaluation → volatile MMIO loads and stores (A3).
- **A per-file compile ratchet.** A CI job `mvk-compiles` records how many of the 41 Appendix A files reach codegen. The number may never fall. This replaces "does the tree compile" — an all-or-nothing question that stays "no" for months and tells nobody anything — with a number that moves every week.
- **Diagnostics are a deliverable, not a side effect.** Every file that fails to compile must fail with `file:line:col`, expected/found types, and a suggested fix (A2's bar). The compile ratchet is only useful if its failures are actionable.
- **Consolidate the two serial implementations** (`kernel/src/serial.home` and `kernel/src/drivers/serial.home`) before either is a compile target, per the Appendix A note.

### Phase 1 — Kernel Bring-up (MVK boots to shell)

- **Entry:** Phase 0 gates green.
- **Workstreams:** A (A5), B, C (init + shell glue).
- **Deliverables:** GDT/IDT/paging/PMM/heap/scheduler initialization; initramfs loading; syscall path; serial shell; `home build` (A5) as the build entry.
- **Exit gate — CI job `boot-to-shell`:** ✅ green, enforced by `scripts/boot-gate.sh` against `scripts/boot-milestones.txt`.
  - ✅ Kernel initializes GDT, IDT, paging, PMM, heap, and the scheduler, then loads an initramfs. The GDT carries a TSS so ring 3 has a kernel stack; the initramfs arrives as a Multiboot boot module and is unpacked into the VFS.
  - ✅ A userspace `hello` binary runs via real `write`/`exit` syscalls. `userland/hello.s` is a flat binary entered at ring 3 through `iretq`; its `int $0x80` reaches `sys/syscall.home`'s table. The ELF loader is Phase 2.
  - ✅ The interactive serial shell executes scripted commands (`echo`, `ls`, `cat`, `ps`, `uname`, plus `irq` and `run`). `scripts/boot-commands.txt` is fed over the serial line and the milestones are each command's output.
  - ✅ Timer and keyboard IRQs demonstrably fire. The gate presses a key through QEMU's monitor — with `-display none` nothing else would — and asserts the shell reports both lines live.

### Phase 2 — Subsystem Realization (stub burndown: storage + net + console)

- **Entry:** Phase 1 green.
- **Workstreams:** B (S2, S3, S4-design), A (codegen widening beyond MVK, per-directory compile ratchets).
- **Exit gates:**
  - ✅ **`storage-roundtrip`**: an ext2 filesystem survives write → unmount → remount → `fsck`. Enforced in `scripts/boot-gate.sh`: the kernel creates a file on disk, `remount` discards the superblock, group descriptors and every cached block before reading it back, and `tools/mkext2.py check` verifies the image from outside — including that the free-block count still matches the bitmap. The block driver is ATA PIO rather than virtio-blk, which QEMU serves equally well; virtio-blk is worth having for throughput, not correctness, and is not what the gate turns on.
  - ✅ **`net-echo`**: the kernel obtains a DHCP lease and completes a TCP echo against QEMU user-mode networking, in both directions. `scripts/boot-gate.sh` attaches an e1000, runs an echo server on the host's loopback, and forwards a host port into the guest. The kernel ARPs for the gateway, obtains 10.0.2.15/255.255.255.0 via a real DISCOVER/OFFER/REQUEST/ACK exchange (none of those numbers chosen here), connects out and requires its 32 bytes back unchanged, then listens and echoes a connection made from the host — which the harness verifies from outside the guest, since that is the half the kernel cannot assert about itself.
  - ✅ **`fb-boot-log`**: `fb_console` renders the boot log with a real PSF font. `kernel/src/drivers/bochs_vbe.home` programs the display directly, since QEMU's `-kernel` loader ignores the Multiboot video request; the gate captures the framebuffer through QEMU's monitor and rejects a single flat colour.
  - 🟡 ELF loader runs coreutils from disk. `kernel/src/loader/elf.home` maps a real ELF64 image's segments and runs it at ring 3 (`exec /bin/hello_elf` in the gate); the coreutils themselves are not written yet.

### Phase 3 — Userspace & POSIX Solidity

- **Entry:** Phase 2 green.
- **Workstreams:** C, B (S5 for pantry signing), E (pantry local mode).
- **Exit gates:**
  - **`libc-suite`**: an executed (not grepped) libc test subset passes ≥90% in-VM.
  - **`shell-suite`**: scripted shell test suite passes (pipelines, redirection, quoting, `&&`/`||`, variables — the features `apps/shell_parser.home` already claims).
  - **`coreutils-suite`**: ≥40 coreutils runtime-tested.
  - Pipes, signals, fork/exec, and job control demonstrated in tests.
  - **`pantry-local-install`**: pantry installs a signed package from a local repository inside the VM (signing requires S5).

### Phase 4 — Craft & GUI Foundation

- **Entry:** Phase 3 green.
- **Workstreams:** D, A (compiler perf work as needed for 60fps).
- **Exit gates:**
  - virtio-gpu driver up; the compositor (`kernel/src/video/compositor.home`) renders.
  - **Craft API frozen at v1**: written spec plus conformance tests. No app-suite work begins before this freeze (Risk R7).
  - **`craft-demo`**: a Craft demo app draws, receives keyboard and mouse input, and animates at 60fps in QEMU with frame timing asserted.
  - **`wm-layouts`**: the tiling WM's 5 layouts (`kernel/src/gui/window_manager.home`) driven by keyboard in CI screenshot tests.
  - A terminal emulator is usable inside the GUI.
  - A real font stack lands (TrueType rasterization in Home) — fonts are a named weak point today.

### Phase 5 — Desktop Experience Parity (the Omarchy fight)

- **Entry:** Phase 4 green.
- **Workstreams:** D, E (installer + ISO).
- **Exit gates:**
  - **`iso-install`**: installer ISO → installed, booting desktop in under 5 minutes inside CI (`installer/installer.home` finally executes for real).
  - **`desktop-parity-suite`**: theming engine with ≥10 whole-system themes and theme validation (themes are data, never code); app launcher (Super+Space); keybinding browser; notification center with persistent, replayable history; control panels for audio, network, display, and power; capture suite (screenshot, region picker, screen recording, color picker); lock screen.
  - Every row of §10 marked "Phase ≤5" is demoable in QEMU.
- **Release: v1.0-desktop.**

### Phase 6 — Beyond Omarchy (differentiators land)

- **Entry:** Phase 5 shipped.
- **Exit gates:**
  - **`snapshot-rollback`**: homefs CoW snapshots power boot-selectable rollback of a pantry update in CI: install update → snapshot → reboot to boot menu → roll back → assert prior state.
  - **`agent-cli-suite`**: unified `home os` CLI with typed `--json` output on every subcommand.
  - First-party app suite v1: Files, Editor, Settings, Terminal, Browser-lite — sharing HIG, keymap, and data layer.
  - Capability-based security default-on for apps, surfaced in Settings.
  - The HomeOS HIG published, with motion and type-scale tokens enforced by Craft at compile time.

### Phase 7 — Hardware Waves

- **7a — x86-64 metal** (may start once Phase 3 exits): boots on ≥2 real machines (at least one laptop) with AHCI/NVMe storage, e1000 plus one named Intel Wi-Fi part, XHCI USB, and ACPI S3 suspend/resume; weekly hardware-in-loop CI (§12 Tier 3). Requires S6, S7.
- **7b — Raspberry Pi 5** (requires compiler milestone A6): `arm64.home` MMIO de-stubbed (S8); serial boot → desktop on a real Pi 5.
- **7c — Apple Silicon (ASPIRATION):** m1n1-chainload proof-of-life only. Research tier: no dates, no budget commitments, and no other gate depends on it (Risk R3).

---

## 6. Workstream A — Home Compiler & Toolchain (`home-lang/home`)

**The compiler is the critical path. Roughly 40% of total effort through Phase 2 lands here. Nothing in this plan ships until A-milestones land.** HomeOS is the compiler's most demanding customer, and the kernel tree becomes the compiler's permanent regression corpus.

- **A1 — Parse-100** *(Phase 0)* — ✅ **done**: 410/410 kernel files parse. The kernel tree is added to the compiler's CI as a parser-regression corpus; parser fuzzing is seeded from it.
- **A8 — Syntax modernization** *(Phase 0; deliberately ordered after A1, before A2)*: a one-time mechanical migration of the ~180k-line tree to current Home idiom — the TypeScript-flavored surface: `let`, `fn name(a: int): int`, `loop`, minimal semicolons — executed by a `home fmt --fix`-style tool so the diff is machine-generated and reviewable. Zig-era leftovers (`@import("x.zig")` path forms, `kernel/build.home` containing literal Zig) are replaced wherever current Home defines the replacement. Typechecking then targets modern syntax exactly once.
- **A2 — Typecheck** *(Phase 0)* — ✅ **done. 39/39 Appendix A files typecheck with zero errors**, gated by `scripts/typecheck.sh` on every commit. The Home compiler already ships a type checker meeting the diagnostics bar below (`home check`, with `file:line:col` and a caret). Nothing in this repository had ever run it. The Home compiler already shipped a checker meeting the diagnostics bar below (`home check`), and nothing in this repository had ever run it — the first measurement was 35/39. Closing the last four took three fixes in the compiler, each of which had been silently mis-shaping programs rather than merely failing to check them (§6, A10). Same lesson as the build fallbacks and the stub register: the gap was not capability, it was measurement.: the full type system checks the MVK file-set with zero escape-hatch holes. Diagnostics quality bar: `file:line:col`, expected/found types, and a suggested fix.
- **A3 — Codegen, x86-64 freestanding** *(Phase 0)*: no libc, no red zone, kernel code model. An intrinsics or inline-assembly story for port I/O, MSRs, control registers, and `cli`/`sti`/`hlt` — the operations the project previously leaned on the Home repo's `packages/kernel/src/asm.zig` for. **Volatile MMIO load/store semantics are defined in the language specification** — the prerequisite for ever un-stubbing `arm64.home` (S8) honestly.
- **A4 — Link** *(Phase 0)*: linker-script consumption (or lld emission) honoring `kernel/linker.ld`; section-placement attributes (e.g. `.boot`, per-CPU data) expressible from Home source.
- **A5 — `home build`** *(Phase 1)*: manifest-driven whole-kernel builds from `kernel/home.toml` — targets, incremental compilation, cross-compilation. Replaces `scripts/compile_home_kernel.zig`; `scripts/build.sh` becomes a thin wrapper.
- **A6 — arm64 backend** *(gates Phase 7b)*.
- **A7 — Self-hosting** *(Phase 6+)*: `home` compiles itself; endgame, HomeOS builds itself on HomeOS — "the OS is its own SDK," a headline no distro can print.
- **A10 — Systems types in the TypeScript-derived checker** *(Phase 0.5; added at the Phase 0 gate)*: Home's type system descends from a TypeScript implementation (roughly 445k lines of Zig across the `ts_*` packages: parser, checker, resolver, LSP, and a `tsc`-compatible driver). That inheritance is an asset — the checker is mature, the diagnostics are good, and the surface syntax is already TypeScript-flavored — but a JavaScript type system has no vocabulary for the things a kernel is made of. Closing that gap is its own milestone, distinct from codegen:
  - ✅ **Arbitrary-width integers** (`u4`, `u6`, `u40`, `u63`). A page table entry is a `u40` address beside a `u3` of available bits. Took the typecheck ratchet from 35/39 to 37/39.
  - ✅ **Pointer slicing** — `ptr[0..len]`, how a kernel turns a syscall's raw address into something carrying a length. A JavaScript type system has no reason to allow it, having no pointers; without it the only way to pass such data on was a bare pointer to a parameter that would read `.len` off it.
  - ⬜ **Layout as a type property** — `packed`, backing types, and field bit ranges are known to the codegen but invisible to the checker, so nothing verifies that a bitfield's declared widths actually fit its backing integer.
  - ⬜ **Pointer provenance and volatility** — `*T`, `[*]T`, `[]T`, and `volatile` are parsed as type-name text rather than modelled, so nothing catches indexing a pointer that carries no length.
  - ⬜ **Address-space and alignment constraints** — `align(N)` is a placement note today; a checker that understood it could reject a misaligned MMIO access at compile time.
  - ⬜ **Integer overflow and truncation** at assignment and cast sites, which is where a kernel silently corrupts state.

- **A9 — Kernel-codegen feature ladder** *(Phase 0.5)* — ✅ **done: 39/39.**: the ordered list in §5 Phase 0.5, driven by the `mvk-compiles` ratchet. Split out from A3 because A3 as written ("x86-64 freestanding codegen") reads as one task and is in practice a dozen, each independently demonstrable by a kernel that still boots. The kernel tree is the compiler's regression corpus; this ladder is how the corpus gets consumed in an order that keeps a booting artifact at every step.

### Compiler-interface contract

| OS phase | Consumes | Pinning policy |
|----------|----------|----------------|
| 0 | A1, A8, A2, A3, A4 | Every HomeOS release pins one compiler version; both repos' CI cross-trigger on the shared kernel corpus |
| 1 | A5 | ″ |
| 2–5 | codegen widening + perf | ″ |
| 6 | A7 | ″ |
| 7b | A6 | ″ |

---

## 7. Workstream B — Kernel & Stub-Burndown Register

Bring-up order (each stage proven over serial before the next): serial-first debugging → GDT/IDT → paging + PMM/VMM/heap → scheduler + context switch → syscalls → initramfs + ELF loading → block + VFS → network. The tree already contains detailed source for most of these; Workstream B's job is making it *execute*, subsystem by subsystem, behind per-directory "compiles" CI ratchets.

### Stub-Burndown Register

| # | Stub | File | Priority | Blocks gate |
|---|------|------|----------|-------------|
| S1 | **CLOSED** — silent hlt-stub fallback + dead `.zig` references | `scripts/build.sh` | P0 | Phase 0 (truth) |
| S3 | **CLOSED** — the RX path parses Ethernet, demuxes on ethertype, validates IPv4 and dispatches to arp/icmp/udp | `kernel/src/net/netdev.home` | P1 | Phase 2 `net-echo` |
| S4 | **CLOSED** — steps 1–6 of `docs/design/homefs.md` §9: on-disk structures with blake2s checksums, a block device, copy-on-write B-trees, the commit protocol, snapshots with rollback, objects (files, directories and extent trees), removal, ownership and mode, `fsck`, free-space reclamation, and VFS routing — a volume mounts at a path and `open`/`read`/`write`/`lseek`/`readdir`/`mkdir`/`rmdir` reach it, with permissions checked against the object's own mode and owner. A volume survives a reboot, `scripts/crash-gate.sh` kills QEMU mid-commit and remounts to prove it, and the boot gate runs 18 checks over the object layer plus an end-to-end round trip through /homefs | `kernel/src/fs/homefs.home` | P2 (CoW implementation) | Phase 2 storage; Phase 6 `snapshot-rollback` |
| S5 | **CLOSED** — chacha20, poly1305, blake2s and curve25519 are implemented and checked against the vectors in RFC 8439, RFC 7693 and RFC 7748 | `kernel/src/crypto/` | P2 | Phase 3 `pantry-local-install` (signing); later WireGuard |
| S6 | **CLOSED** — the xHCI host controller, USB mass storage and USB HID. Enumeration walks every port and dispatches on interface class; Bulk-Only Transport carries INQUIRY, READ CAPACITY(10), READ(10) and WRITE(10); the disk is registered as `/dev/usb0` so paths reach it through the VFS; and HID runs in boot protocol with both the mouse and keyboard report layouts decoded. The boot gate reads a known block, writes another and checks the host image (a device accepting a write is not the same as the write reaching the media), reads that block back through `vfs_pread`, moves an emulated mouse and reads the movement off the interrupt endpoint, and — in a second run, because a usb-kbd takes keystrokes away from the PS/2 controller — presses a key and reads the keycode back | `kernel/src/drivers/usb.home` | P2 | Phase 7a (keyboards, storage on metal) |
| S7 | **CLOSED** — ACPI table discovery, the AML namespace and an interpreter, and S3 suspend/resume. The DSDT is parsed to the byte and shutdown takes its SLP_TYP from `\_S5_` instead of assuming 5; methods run within a stated integer subset and refuse anything outside it rather than guessing (15 of the 100 QEMU declares fall inside); and the machine suspends to RAM and comes back through a real-mode trampoline planted in the FACS waking vector. The boot gate requires the parser to reject a truncated and a corrupted DSDT, runs the interpreter against a hand-assembled method with exact expected values, and — in a run of its own, since suspending ends a run — suspends the machine, confirms from outside the guest that QEMU really slept, wakes it, and requires the kernel to report coming back | `kernel/src/drivers/acpi.home` | P2 | Phase 7a (power, S3 suspend) |
| S8 | **CLOSED** — `mmio_read32`/`mmio_write32` were inert, so every ARM64/Pi driver was too | `kernel/src/arch/arm64/arm64.home` | P3 | Phase 7b entirely |
| S9 | Port-I/O wrappers halt the machine on ARM64 — the architecture has no I/O address space, so calling one is always a bug | `kernel/src/core/foundation.home` | P3 | Phase 7b (only reachable from ARM64 code paths) |
| S10 | **CLOSED** — SMAP's ARM64 counterpart (the PAN bit in PSTATE) is set up, so `asm_stac`/`asm_clac` move a real bit on both architectures | `kernel/src/core/foundation.home` | P3 | Phase 7b hardening |

| S11 | **CLOSED** — `tcp_input()` validates a segment and hands it to the state machine, and netdev dispatches to it | `kernel/src/net/netdev.home` | P1 | Phase 2 `net-echo` for TCP |

**Register rules:**
1. A stub may not be closed without a runtime test exercising it.
2. Every new stub must be added to this register and carry a `// STUB(Sn)` marker in the source it describes, where `Sn` is its register ID.
3. The `stub-register` CI gate (`scripts/stub-check.sh`) parses this table as the single source of truth and enforces it in both directions: no marker may name an unregistered ID or sit outside the file the register names, and no open entry may lack a marker. A bare `// STUB` with no ID is a red build.
4. Closing an entry means marking it **CLOSED** in this table *and* deleting its markers in the same commit — the gate fails otherwise, so the register cannot drift from the code.

---

## 8. Workstream C — Userspace & POSIX

The userspace inventory is already broad: a shell with a hardened parser (`apps/shell.home`, `apps/shell_parser.home` — quoting, pipelines, redirection, `&&`/`||`, variable expansion, with 25 tests in `tests/shell/test_parser.home`), more than 80 coreutils in `apps/utils/`, a structured init (`apps/init/init.home` — runlevels, services, mounts), and a 12-module libc in `libs/libc/`. The honest caveat applies to all of it: none of this code has ever executed.

The path from written to running is fixed: everything compiles under the Phase 1 syscall ABI, then executes under the Phase 3 CI suites (`libc-suite`, `shell-suite`, `coreutils-suite`). libc grows against an *executed* test subset — never grep checks — so its coverage number means what it says.

One correction to the historical record: `TODO.md` history claims an `init_enhanced.home` with supervision and exponential backoff. That file does not exist in the tree. Supervision is re-implemented directly in `apps/init/init.home` rather than hunting for the phantom file.

---

## 9. Workstreams D & E — GUI and Distribution

### D — Craft, GUI & Desktop

The GUI stack is a strict layering, each layer first-party:

1. virtio-gpu / framebuffer drivers
2. Compositor — `kernel/src/video/compositor.home`
3. Craft toolkit — API frozen at v1 at the Phase 4 gate
4. Window manager — 5 tiling layouts + floating, `kernel/src/gui/window_manager.home`
5. Desktop shell — panel, launcher, notifications as **one long-running Craft process** (deliberately the architecture Omarchy 4.0 proved out with Quickshell, but first-party all the way down)
6. First-party apps

Fonts are today's named weak point: PSF fonts for the console land with S2; a TrueType rasterizer written in Home is a Phase 4 deliverable.

### E — Distribution & Updates

The distribution pipeline runs: installer (`installer/installer.home`, 1,026 lines, never yet run) → ISO pipeline (`scripts/build.sh` already stages GRUB) → pantry as the package and update channel (`pantry.jsonc`, `pantry.lock` at repo root) with signed indexes (needs S5) → homefs CoW snapshots as the rollback substrate (S4) → factory reset as a preserved pristine snapshot — matching Omarchy's `@factory` reset, but native to the filesystem rather than bolted on.

---

## 10. Feature-Parity Matrix vs Omarchy 4.0

Rules: every row names a concrete edge — "same as Omarchy" is not an allowed answer. Each row is proven by the CI gate of its phase (§5). Unproven rows say **planned**; there are no checkmarks in this table until gates are green.

| Omarchy 4.0 capability | HomeOS answer | Phase | Why better |
|---|---|---|---|
| **Install & update** | | | |
| Bootable ISO, sub-minute install | Installer ISO, <5-min installed desktop in CI | 5 | No distro underneath: installer, FS, and OS are one codebase, so install can't drift from the OS |
| Dual-boot installer | Dual-boot support in installer | 7a | planned; same UX bar, fewer moving parts |
| btrfs/snapper snapshots, boot-selectable rollback | homefs CoW snapshots + boot-menu rollback | 6 | FS and updater are co-designed in one language: rollback covers *whole-OS state*, not just packages |
| Factory reset (`@factory` snapshot) | Factory reset as a preserved pristine homefs snapshot | 6 | Native to the FS, not layered tooling |
| 4 release channels (stable/RC/edge/dev) | pantry channels: stable/rc/edge/dev | 6 | Snapshot-guarded upgrades make `edge` actually safe to run |
| Curated Arch mirror, ~1 month behind | pantry is the source of truth | 6 | Nothing to lag behind — HomeOS *is* upstream |
| ALPM guard blocking raw `pacman -Syu` | pantry is the only updater | 6 | No foot-gun to guard against in the first place |
| Firmware updates (fwupd/LVFS) | Firmware update integration | 7a | planned |
| **Shell & UX** | | | |
| Single Quickshell process (<300MB) replacing 7 daemons | Craft-native desktop shell: one process | 5 | Compositor, toolkit, and shell are ONE first-party stack — no Hyprland/Quickshell seam, one animation vocabulary, lower memory floor |
| 22 whole-system themes, 24-color palette, carousel switcher, theme validation | Theming engine, ≥10 themes at v1.0, themes-are-data validation | 5 | Theme tokens also constrain *first-party apps*, not just re-skinned third-party ones |
| Keyboard-first everything + Super+K binding browser | Same keyboard-first grammar + binding browser | 5 | Plus a GUI path for every setting — macOS-grade discoverability instead of "embrace the config file" |
| Hyprland tiling: dwindle + scrolling layouts, grouping, scratchpad | 5 tiling layouts + floating (already in-tree) | 4–5 | Layout engine is first-party and themable; no compositor/WM version-breakage treadmill (Omarchy 3.4 existed to clean up a Hyprland release) |
| Native launcher (fuzzy + acronym matching) | Craft launcher | 5 | planned; same bar |
| Native notifications with replayable history | Notification center with persistent history | 5 | planned; same bar, first-party |
| **System control** | | | |
| Control panels: audio/BT/network/display/power incl. speedtest, Wi-Fi QR, 802.1X | Settings app panels | 5 | Every panel is also scriptable via `home os --json` — GUI and automation are the same surface |
| Fingerprint + PAM lock | Lock screen (5); fingerprint on certified hardware (7a) | 5/7a | Backed by capability-based auth, not PAM stack archaeology |
| Night light, DND | Night light, DND | 5 | planned |
| Screensaver with ~1ms startup | In-process shell screensaver | 5 | Zero exec, zero startup — it's a state, not a program |
| **Capture** | | | |
| Screenshot/region/recording + webcam overlay, OCR, QR, color picker | First-party Capture app: screenshot, region, recording, color picker (5); OCR (6) | 5–6 | Zero-copy path through our own compositor — no PipeWire/portal seam |
| **Developer & AI** | | | |
| Unified `omarchy` CLI (437 scripts) framed for AI agents | `home os` CLI, typed `--json` on every subcommand | 6 | The whole OS is one grammar an agent can read and patch — agent-legibility is an OS property, not a script collection |
| mise-managed runtimes; Docker + Compose; local DB setup | pantry toolchains; container subsystem (`kernel/src/container/`) | 6 | planned, honestly labeled: containers reach parity later; toolchains ship curated like everything else |
| lazygit/lazydocker/btop TUIs | Equivalent first-party TUIs on our terminal | 6 | Terminal, shell, and TUIs share one input/keymap grammar |
| AI integration: default-agent picker, usage/spend widget, crash-to-agent | Same, plus kernel-level structured crash dumps (`kernel/src/debug/panic.home`) consumable by an agent | 6 | A distro can hand an agent logs; we hand it the kernel's own structured state |
| Dotfiles discipline (`~/.config` everything) | Typed Home settings with GUI + file + CLI parity | 5–6 | Settings are data with one schema across all three surfaces |
| **Apps & media** | | | |
| Re-themed third-party apps + first-party Omawrite/Omacalc/Omacut | Integrated first-party suite: Files, Editor, Settings, Terminal, Browser-lite — one HIG, keymap, data layer | 6 | Coherence a distro structurally cannot have |
| Web apps as frameless Chromium windows | Web-app windows | post-1.0 | **conceded short-term** — depends on browser-engine strategy (Risk R8) |
| LibreOffice, Kdenlive, OBS, media breadth | Curated small set | post-1.0 | **conceded** — curation-over-catalog is the macOS play |
| Gaming: Steam, RetroArch, Lutris, controllers | — | post-1.0 | **conceded** |
| **Hardware** | | | |
| Broad tree: NVIDIA incl. legacy, T2 Macs, Framework, Surface, Asus | Narrow certified list that fully just-works (sleep, displays, audio, Wi-Fi) | 7a | **conceded on breadth**; the counter is certification — Omarchy's NVIDIA pain is the cautionary tale we design around |
| **macOS-ideal rows (no Omarchy equivalent)** | | | |
| — | Published HIG: type scale, spacing, motion tokens, machine-enforced by Craft | 6 | Conformance is compile-time, not code-review-time |
| — | Polish-as-feedback animation standards | 4–6 | Motion has a spec, not vibes |
| — | Integrated data layer across first-party apps | 6 | Files/Editor/Settings share typed data, not ad-hoc formats |
| — | Install-and-forget updates | 6 | Atomic image + snapshot rollback + zero prompts |

---

## 11. Beyond-Parity Differentiators

### 11.1 One language, whole stack — the agent-legible OS

Every layer of HomeOS — kernel, drivers, compositor, apps, build tool, CLI — is written in Home. That is not an aesthetic choice; it is a capability. A developer, or an AI agent, can follow a defect from a button click in a Craft app, through the compositor, into the scheduler, without switching grammars, build systems, or mental models. Omarchy's own positioning proves the demand: it ships a unified CLI explicitly framed for AI agents and integrates agent tooling throughout. But a distro can only wrap Linux in scripts. HomeOS *is* the artifact: the deliverables are the `home os` CLI with typed `--json` output on every subcommand, full source on every installed device, and — with milestone A7 — an OS that compiles itself, making "the OS is its own SDK" literally true.

### 11.2 homefs + pantry: a time machine for the whole OS

Omarchy's rollback story is snapper on btrfs — good, and bolted on. HomeOS co-designs the filesystem and the updater in one language: homefs CoW snapshots underneath, pantry on top. Every update is snapshot-guarded; every snapshot is boot-selectable; factory reset is a preserved pristine snapshot; per-app data snapshots become possible because the FS and the app data layer share types. The named deliverable that unlocks all of this is `docs/design/homefs.md` — the CoW model, extent layout, and snapshot trees — written *before* implementation, because homefs is currently a 28-line stub (S4) and deserves a real design, not an improvisation.

### 11.3 The memory-safety story

Home's safety semantics apply inside the kernel, not just in apps. The tree already carries the beginnings of this discipline — `scripts/migrate-ptr-safety.sh` and `kernel/src/security/ptr_safety.home` — and the plan makes it measurable: every release publishes an **unsafe-block census**, the count and location of every escape hatch in the kernel, tracked release-over-release like a benchmark. A memory-safe kernel is a claim; a falling census is evidence.

### 11.4 Capability-based security

Apps hold capabilities, not ambient authority. The kernel side exists in early form (`kernel/src/security/caps.home`); the differentiating move is the surface: the Settings app shows, and lets the user edit, exactly which capabilities each app holds. That beats Linux's ambient-authority model outright, and it beats macOS too — TCC grants exist but are opaque and scattered; HomeOS makes the security model a first-class, legible UI.

### 11.5 The first-party Craft app suite

Files, Editor, Settings, Terminal, and Browser-lite, all built on Craft, all sharing one HIG, one keymap, and one typed data layer. Omarchy's 4.0 direction (Omawrite, Omacalc, Omacut) shows it knows re-themed third-party apps aren't enough — but a distro assembling other people's applications can never reach suite-level coherence. This is the heart of the macOS claim.

### 11.6 The HomeOS HIG

A published, versioned Human Interface Guidelines document: type scale, spacing grid, motion durations and curves, and a keyboard grammar. The enforcement mechanism is the differentiator: HIG tokens are Craft compile-time constraints, so conformance is checked by the compiler, not by code review. Omarchy has strong taste; HomeOS has taste as a spec.

---

## 12. Testing & Verification Strategy

**Principle: every grep-test is replaced by an executed test.** The existing bash suites under `tests/` check file existence and grep for symbols; they are renamed to `static-checks/` immediately so nobody mistakes them for tests, and each is deleted the moment its runtime equivalent lands.

**Boot-protocol note (learned at the Phase 0 gate).** QEMU's `-kernel` loader implements Multiboot1 only, and its ELF path refuses 64-bit images. The kernel therefore ships two headers: Multiboot2 for GRUB — the real install path, used by the ISO — and Multiboot1 with the a.out kludge for QEMU, which is handed an objcopy'd flat image. This keeps every Tier-1 boot gate free of GRUB, `xorriso`, and ISO mastering, which matters because those tools are the least portable part of the toolchain (`grub-mkrescue` has no usable darwin build in the pantry registry today). The ISO path is exercised by `iso-install` at Phase 5, where it is the thing under test rather than a dependency of unrelated gates.

- **Tier 1 — every commit:** the QEMU boot matrix. Serial-console expect harness, per-phase scenario scripts, deterministic, under 10 minutes. The Tier-1 job names ARE the phase gates: `parse-rate`, `stub-register`, `boot-qemu-x86_64`, `mvk-compiles`, `boot-to-shell`, `storage-roundtrip`, `net-echo`, `fb-boot-log`, `libc-suite`, `shell-suite`, `coreutils-suite`, `pantry-local-install`, `craft-demo`, `wm-layouts`, `iso-install`, `desktop-parity-suite`, `snapshot-rollback`, `agent-cli-suite`.
- **Tier 2 — nightly:** syscall fuzzing; filesystem crash-consistency (kill QEMU mid-write → remount → verify); soak and leak runs.
- **Tier 3 — weekly, from Phase 7a:** hardware-in-loop. Self-hosted runners: one NUC-class x86-64 box and one Raspberry Pi 5 on a network power relay; boot + smoke suite.
- **Compiler CI (`home-lang/home`):** the kernel tree is the compiler's regression corpus; every HomeOS release pins one compiler version; the two repos' CI cross-trigger.

---

## 13. Documentation Realignment (Phase 0 tasks)

1. **README.md**: remove the overclaiming header; replace with an honest baseline paragraph plus `parse-rate` and boot-status badges; fix the project-structure diagram (it references a nonexistent `kernel/src/boot.zig` and wrong doc paths).
2. **Create `IMPLEMENTATION_STATUS.md` as an auto-generated page** (parse %, boot status, stub-register excerpt, per-subsystem compile ratchet) so it can never drift. README's currently-dangling link then resolves.
3. **`HOME_KERNEL_FEATURES.md`** (referenced by `CLAUDE.md` and `docs/adr/0001-*` but missing): fold its intent into `IMPLEMENTATION_STATUS.md` and update the referring documents.
4. **Aspirational guides** (`docs/USER_MANUAL.md`, `docs/INSTALL_RPI5.md`, and peers): add a standard banner — "Status: describes target behavior; see `IMPLEMENTATION_STATUS.md` for current reality." — rather than rewriting them.
5. **CHANGELOG.md / RELEASE_NOTES.md**: reset to reality at the first Phase-0 tag (v0.1).

---

## 14. Governance, Cadence & Releases

- **Versioning:** 0.x until the Phase 5 exit, which is **1.0**. A tag at every phase-gate exit (v0.1 = Phase 0 … v0.5 = Phase 4).
- **Channels (Phase 6):** `stable` / `rc` / `edge` / `dev`, delivered through pantry with signed indexes (requires S5) and snapshot-guarded upgrades. Rollback is what makes `edge` safe to actually run — that is the beat over Omarchy's channel model.
- **Cadence:** monthly dev snapshots from Phase 1 onward. Changelog discipline is CI-enforced: every merged PR updates `CHANGELOG.md` under Unreleased.
- **Decision records:** `docs/adr/` continues; §3 indexes strategic decisions.
- **Plan maintenance:** this document is reviewed at every phase exit; §2 (Honest Baseline) is regenerated at every release.
- **Contribution:** `CONTRIBUTING.md` gains a "how an AI agent contributes" section — agent-legibility (§11.1) is also the contributor-scaling strategy (Risk R4).

---

## 15. Risk Register

| ID | Risk | Mitigation |
|----|------|------------|
| R1 | Codegen for a 180k-line tree is intractable early; a whole-tree compile requirement would stall Phase 0 forever | **The MVK strategy** (Appendix A): only the ~30–50-file set is the Phase 0–1 compile target; the rest of the tree is staged in per-subsystem behind per-directory "compiles" CI ratchets; breadth directories are frozen (D5) |
| R2 | Wi-Fi/GPU driver cliff on real hardware | virtio-everything through Phase 5; Phase 7a certifies a narrow, named device list before any breadth; USB-Ethernet is the documented fallback |
| R3 | Apple Silicon becomes a scope black hole | Quarantined as ASPIRATION (7c): no dates, no budget, no dependent gates |
| R4 | Single-maintainer bus factor | CI-encoded gates make project state legible to any newcomer; the MVK gives contributors a small true core; agent-friendly contribution docs scale the contributor pool |
| R5 | Documentation-credibility debt poisons adoption | Phase 0 realignment (§13) + the auto-generated status page + the "CI-verifiable or ASPIRATION" standing rule |
| R6 | Compiler and OS repos deadlock on each other | Pinned compiler versions per release; the kernel corpus doubles as the compiler's test suite; cross-repo CI triggers; compiler milestones live inside this plan (§6) so sequencing is one document |
| R7 | Craft API instability churns 125 app files | Craft v1 is frozen with conformance tests at the Phase 4 gate, before any app-suite investment |
| R8 | A web/browser engine in Home is out of reach short-term | Browser-lite is scoped to a document viewer first; the full web-app story is deferred post-1.0 and gets its own ADR when chosen |

---

## 16. Sizing & Parallelism

Relative effort (T-shirt): P0 = M · P1 = L · P2 = XL · P3 = L · P4 = XL · P5 = XL · P6 = L–XL · P7a = XL · P7b = L (after A6) · P7c = research/unbounded. **The compiler workstream is roughly 40% of all effort through Phase 2** — said out loud so nobody plans around it.

- **Strictly serial spine:** A1 → A8 → A2 → A3/A4 → Phase 0 gate → P1 → P2 → P3 → P4 → P5.
- **Parallel-safe at any time:** documentation realignment (§13); the homefs design doc; the HIG spec; Craft API spec drafting (during P2–P3); theme and design assets (P3–P4); Phase 7a from the P3 exit; Phase 7b after A6.
- **Frozen until the Phase 3 exit (D5):** `kernel/src/iot/`, `kernel/src/ml/`, `kernel/src/industrial/`, gaming, and the container orchestrator. This freeze is the honestly-paid cost of the kernel-first decision.

---

## Appendix A — Minimum Viable Kernel file-set

This list is the ONLY compile target for Phases 0–1. A file may be added only with a note of which gate needs it. Every path below exists in-tree. The entry point is `kernel/src/main.home` (the lean unified entry, 21 imports) — **not** `kernel/src/kernel_main.home`, which imports ~130 modules and is out of MVK scope by design.

**Boot / entry (5)**
- `kernel/src/boot.s`
- `kernel/src/idt_stubs.s`
- `kernel/src/main.home`
- `kernel/src/multiboot2.home`
- `kernel/src/boot/initramfs.home`

**Console (1)**
- `kernel/src/console/serial_shell.home` — needed by `boot-to-shell`: the interactive serial console. Runs in the kernel and calls the subsystems directly; `apps/shell.home` is the userspace shell and needs an ELF loader and syscall path that do not exist yet.

**Storage (2)**
- `kernel/src/drivers/ata.home` — needed by `storage-roundtrip`: ATA PIO, with the capacity read out of the drive's IDENTIFY response.
- `kernel/src/fs/ext2.home` — needed by `storage-roundtrip`: mounts an ext2 filesystem from disk 0 and reads from it. `tools/mkext2.py` builds the images and checks them independently.

**Display (1)**
- `kernel/src/drivers/bochs_vbe.home` — needed by `fb-boot-log`: programs the Bochs/std-VGA adapter directly and finds its linear framebuffer through PCI. QEMU's `-kernel` loader ignores the Multiboot video request, so a kernel booted that way has no framebuffer unless it sets one up itself.

**Userspace (2)**
- `kernel/src/arch/x86_64/usermode.home` — needed by `boot-to-shell`: the ring-3 transition and the `int $0x80` system call path (`write`, `exit`).
- `kernel/src/loader/elf.home` — needed by Phase 2 (ELF loader runs coreutils from disk): maps an ELF64 image's PT_LOAD segments where they ask to live, with user permissions.

**Interrupts (2)**
- `kernel/src/arch/x86_64/interrupts.home` — needed by `boot-to-shell`: builds and loads the IDT, remaps the PIC to vectors 32-47, and dispatches. Before it, `kernel_main` called `sti()` with IDTR still zero and triple-faulted on the first timer tick.
- `kernel/src/idt.home` — superseded by the above and no longer reached; its `init()` is called from nowhere. Remove once nothing references it.

**Memory (6)**
- `kernel/src/pmm.home`
- `kernel/src/vmm.home`
- `kernel/src/heap.home`
- `kernel/src/core/memory.home`
- `kernel/src/mm/mm_integration.home`
- `kernel/src/mm/buddy.home`

**Core init / process / VFS minimum (7)**
- `kernel/src/core/kernel_init.home`
- `kernel/src/core/foundation.home`
- `kernel/src/core/process.home`
- `kernel/src/core/filesystem.home`
- `kernel/src/core/vfs_block_io.home`
- `kernel/src/core/vfs_mmap_integration.home`
- `kernel/src/core/vfs_path.home`

**Scheduling & sync (4)**
- `kernel/src/sched/scheduler.home`
- `kernel/src/sync/spinlock.home`
- `kernel/src/os/cpu.home`
- `kernel/src/mm/slab.home`

**Console / serial / video-text (4)**
- `kernel/src/serial.home`
- `kernel/src/drivers/serial.home`
- `kernel/src/vga.home`
- `kernel/src/drivers/fb_console.home`

**Syscalls & security minimum (5)**
- `kernel/src/sys/syscall.home` *(MVK subset: write, read, exit, fork, exec, open, close)*
- `kernel/src/sys/signal.home`
- `kernel/src/lib/shell_syscall.home`
- `kernel/src/security/caps.home`
- `kernel/src/security/seccomp.home`

**Drivers minimum (4)**
- `kernel/src/drivers/keyboard.home`
- `kernel/src/drivers/timer.home`
- `kernel/src/drivers/framebuffer.home`
- `kernel/src/drivers/ramdisk.home`

**Import-closure additions (15)** — the set was not import-closed ([#41]): these
modules are called from files already in the list, so each is added with the
gate that needs it. Every one reaches clean codegen today.

**Boot timing (1)** — Phase 0 link (kernel_init phase instrumentation):
- `kernel/src/perf/boot_opt.home`

**Security depth (4)** — Phase 0 link (init path calls each):
- `kernel/src/security/aslr.home`
- `kernel/src/security/smep_smap.home`
- `kernel/src/security/audit.home`
- `kernel/src/core/vfs_permissions.home`

**Block devices (2)** — Phase 2 `storage-roundtrip` (vfs_block_io dispatches here):
- `kernel/src/drivers/ata.home`
- `kernel/src/drivers/nvme.home`

**Pseudo-filesystems (4)** — Phase 2 storage (kernel_init mounts them at boot):
- `kernel/src/fs/devfs.home`
- `kernel/src/fs/procfs.home`
- `kernel/src/fs/sysfs.home`
- `kernel/src/fs/tmpfs.home`

**Async I/O (1)** — Phase 2 storage (io path completion processing):
- `kernel/src/perf/async_io.home`

**Network resolution (2)** — Phase 2 `net-echo`. DHCP lands now; DNS stays
out until its 26 type-checker diagnostics are resolved (it returns with
`net-echo`, same terms as tcp/udp):
- `kernel/src/net/dhcp.home`

**Shell library (1)** — Phase 1 boot-to-shell (shell_syscall boots the den shell):
- `kernel/src/lib/den_lib.home`

**Timer (1)**
- `kernel/src/time/clocksource.home`

**Import closure — added because MVK files call into them (12)**

These were referenced by files already in the set and were not listed, which is how the set came to have 188 unresolved symbols at its first whole-set link. Each compiles and typechecks clean; they were added once that was true, not before.

- `kernel/src/security/ptr_safety.home`
- `kernel/src/security/capabilities.home`
- `kernel/src/security/audit.home`
- `kernel/src/core/vfs_permissions.home`
- `kernel/src/mm/memcg.home`
- `kernel/src/perf/boot_opt.home`
- `kernel/src/perf/async_io.home`
- `kernel/src/drivers/timer.home`
- `kernel/src/drivers/ata.home`
- `kernel/src/drivers/nvme.home`
- `kernel/src/net/udp.home`
- `kernel/src/net/dns.home`
- `kernel/src/drivers/pci.home`
- `kernel/src/drivers/e1000.home`
- `kernel/src/mm/swap.home`
- `kernel/src/security/random.home`
- `kernel/src/block/io_scheduler.home`
- `kernel/src/block/request_merge.home`
- `kernel/src/core/driver_init.home`
- `kernel/src/net/socket.home`
- `kernel/src/net/tcp.home`
- `kernel/src/net/arp.home`
- `kernel/src/net/icmp.home`
- `kernel/src/net/netdev.home`
- `kernel/src/net/link.home`
- `kernel/src/crypto/chacha20.home`
- `kernel/src/crypto/poly1305.home`
- `kernel/src/crypto/crypto_selftest.home`
- `kernel/src/crypto/blake2s.home`
- `kernel/src/crypto/sha256.home`
- `kernel/src/crypto/curve25519.home`
- `kernel/src/drivers/acpi.home`
- `kernel/src/drivers/aml.home`
- `kernel/src/fs/homefs.home`
- `kernel/src/drivers/usb.home`

**Link script**
- `kernel/linker.ld`

Total: **74 source files + 1 linker script.**

**Deliberately excluded — networking.** `net/socket.home`, `net/tcp.home`, and `net/udp.home` were in this list only because `main.home` imported them, and the simplification this section already recommended — shrink the entry's imports — was taken. `tcp` and `udp` were imported and never used; `socket` was used once, in an IRQ branch for interrupts a kernel with no NIC driver cannot receive. Servicing it dragged `drivers/e1000` in behind it. They return with the Phase 2 `net-echo` gate.

**Deliberately excluded — libraries.** `kernel/src/integration.home`, which initializes the package manager (`lib/pantry_lib.home`), the den shell (`lib/den_lib.home`), and the Craft GUI toolkit (`lib/craft_lib.home`). Those are Phase 3 and Phase 4 concerns. It was in this list until the set was first linked, where it contributed 61 of 188 unresolved symbols — a *minimum* viable kernel does not reach into the package manager or the GUI toolkit. The call to it was removed from `main.home` in the same change.

**Known gaps:** this list was described as having none. That was wrong, and per-file compilation could not show it — linking the set together did. Two problems surfaced (see [#41](https://github.com/home-lang/home-os/issues/41)):

1. **The set is not import-closed.** It imports modules it does not contain — `drivers/ata`, `drivers/nvme`, `drivers/e1000`, `mm/memcg`, `mm/swap`, `net/dhcp`, `net/dns`, `block_io/scheduler`, `perf/async_io`. Each needs a decision: add it, or cut the call.
2. **Some imports resolve to functions that were never written.** `core/foundation.home` is called for `atomic_add_u64`, `cpu_halt`, `cpu_reboot`, `get_ticks`, and `get_lapic_id`, and defines none of them.

The `mvk-links` ratchet tracks the remaining count so this cannot drift back. Two serial implementations exist (`kernel/src/serial.home` and `kernel/src/drivers/serial.home`); MVK bring-up should consolidate on one and delete or fold in the other, noted here so the duplication is not silently carried forward.
