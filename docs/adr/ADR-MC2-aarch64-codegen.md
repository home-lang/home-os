# ADR MC2: aarch64 Kernel Codegen — Extend the Direct Emitter

**Status**: Accepted
**Date**: 2026-09-02
**Epic**: home-lang/home-os#113
**Issue**: home-lang/home-os#44
**Milestone**: MC0 — Product & decisions
**Decision Makers**: Core Team
**Tags**: `compiler`, `codegen`, `aarch64`, `toolchain`, `raspberry-pi`

---

## Context

Phase 7b — the Raspberry Pi 5 bring-up that the entire TV profile sits on — is gated on compiler
milestone **A6 (arm64 backend)**. MASTER_PLAN currently lists A6 as a single bullet with no
breakdown, which is how a multi-thousand-line compiler effort disappears into a checkbox.

This ADR breaks A6 open, records what actually exists in the compiler today, and chooses the
strategy for getting a Home kernel to compile for aarch64.

### Measured state of the compiler

Measured in `~/Code/Home/lang`:

| Path | Lines | arm64 refs |
|---|---|---|
| `packages/codegen/src/home_kernel_codegen.zig` (the `--kernel` path that boots HomeOS on x86) | 4,204 | **0** |
| `packages/codegen/src/native_codegen.zig` (x86-64 userspace) | 10,854 | — |
| `packages/codegen/src/aarch64_native_codegen.zig` (userspace, "Path B-lite") | 1,461 | toy subset: no pointers, methods, slices, struct args |
| `packages/codegen/src/arm64.zig` (assembler) | 518 | — |
| `packages/codegen/src/llvm_codegen.zig` / `llvm_backend.zig` | 622 / 715 | used by the JS/TS launcher only |

Two structural facts matter as much as the line counts:

1. **The kernel codegen has zero arm64 references.** `home_kernel_codegen.zig` is 4,204 lines of
   x86 lowering. The path that actually boots HomeOS today knows nothing about ARM. There is no
   partially-finished arm64 kernel emitter to complete — there is a blank sheet next to a working
   x86 reference implementation.
2. **Backend selection is by host architecture** (`src/main.zig` ~L3649), **not by a target flag.**
   There is no cross-compilation from a macOS host to `aarch64-freestanding`. Even a perfect
   aarch64 emitter would be unreachable from the machines the work happens on until target
   selection is decoupled from the host.

The existing `aarch64_native_codegen.zig` (1,461 lines) is a userspace "Path B-lite" emitter
covering a toy subset: **no pointers, no methods, no slices, no struct arguments**. A kernel is
approximately nothing but pointers, methods, slices and struct arguments, so this file is a
starting structure and an assembler consumer, not a head start on semantics.

`arm64.zig` (518 lines) is the instruction assembler. It is the one asset that transfers directly:
encoding ARM instructions is a solved, mechanical problem and that file is where the solution
lives.

The LLVM path (`llvm_codegen.zig` 622 lines, `llvm_backend.zig` 715 lines) exists but is used by
the JS/TS launcher only. The Home AST → LLVM IR lowering is in progress, not finished.

---

## Options considered

| # | Option | Approach | Pros | Cons |
|---|---|---|---|---|
| **1** | **Extend the direct emitter** | Add an aarch64 lowering to the kernel codegen, ratcheted file-by-file exactly like `mvk-compiles` | Proven approach — it is how the x86 kernel path was built; keeps the "one toolchain, no LLVM" story; NEON exposed directly as intrinsics; every step is measurable by the ratchet | ~4K lines of x86 lowering to mirror; all of it is our own work with no upstream help |
| **2** | **Finish the LLVM backend** | Complete Home AST → LLVM IR and let LLVM cover all non-x86 targets | Broader long-term reach (RISC-V and others come nearly free); world-class optimiser; register allocation is someone else's problem | The Home→LLVM lowering is "in progress", not done; pulls a ~100 MB dependency into the kernel build; hides the codegen from the ratchet culture the project relies on; optimiser behaviour on freestanding kernel code is a new class of debugging |
| **3** | **Hybrid** | Direct emitter for the kernel subset now, LLVM later for userspace optimisation | Gets the kernel moving without foreclosing LLVM; matches where each toolchain is strongest | Two backends to maintain and two sets of bugs; only worth paying for once the kernel path is actually green |

### Why the ratchet matters

The x86 kernel path did not arrive as a grand rewrite. It arrived file by file, with a script that
counts how many of the Appendix-A files compile, and a rule that the count never goes down. That
count is currently **70/70**. The whole culture of the project — small verified increments, a
number that can only go up — is built on the codegen being ours and being observable.

Handing lowering to LLVM does not just change a dependency; it removes the surface the ratchet
measures. That is the real cost of option 2, and it is larger than the 100 MB.

---

## Decision

**Option 1 — extend the direct emitter.** Add an aarch64 lowering to the kernel codegen, ratcheted
file-by-file exactly as `mvk-compiles` did for x86.

### Rationale

- **The method is proven on this exact problem.** The x86 kernel path reached **70/70** files by
  precisely this technique. We are not betting on an untried process; we are running a process that
  already produced a booting kernel once.
- **The structure is reusable.** An aarch64 mirror can reuse the same IR and lowering structure and
  the same ratchet scripts. The work is large but it is not novel — for each x86 lowering there is
  a corresponding aarch64 lowering, and `arm64.zig` already knows how to encode the result.
- **NEON is on the critical path.** The media-center CPU budget depends on NEON: ADR-MC1 requires
  1080p H.264 software decode within 60 % of four cores, and ADR-MC5 requires NEON blits for the UI
  plane. The direct emitter can expose NEON as intrinsics without an LLVM detour — control we would
  otherwise be negotiating with an optimiser.
- **No new heavyweight dependency in the kernel build.** The "one toolchain, no LLVM" story stays
  true for the thing that must boot.

### Supporting work implied by the decision

- **Target selection must be decoupled from host architecture.** Backend choice at
  `src/main.zig` ~L3649 is by host; it needs a target flag so that `aarch64-freestanding` can be
  produced from a macOS host. Without this, the emitter is unreachable from development machines.
- **`arm64.zig` (518 lines) is the assembler substrate** and should be extended rather than
  duplicated.
- **`aarch64_native_codegen.zig` (1,461 lines)** stays the userspace Path B-lite emitter. Its toy
  subset — no pointers, methods, slices or struct args — is not a foundation for kernel code, so
  the kernel lowering does not inherit its limitations.
- **The ratchet script is mirrored** so aarch64 has its own visible `n/70` count from day one,
  including when that count is 0/70.

---

## Revisit trigger

**If the aarch64 ratchet is below 35/70 Appendix-A files after the planned effort in #51, switch to
option 2 (finish the LLVM backend).**

The threshold is deliberately concrete and deliberately halfway. Below half of Appendix A after a
full planned effort means the per-file cost is not amortising the way it did on x86 — that the
lowering work is not, in fact, mechanical mirroring — and at that point paying LLVM's 100 MB and
its opacity is cheaper than continuing.

Secondary triggers:

- If a **second non-x86 architecture** becomes a shipping requirement, the economics of option 3
  (hybrid) improve sharply and it should be re-costed.
- If NEON intrinsics turn out to be reliably expressible through the LLVM path with the codegen
  still observable to a ratchet, the main technical argument for option 1 weakens.

---

## Consequences

### Positive

1. **A6 becomes a tracked number, not a bullet.** MASTER_PLAN A6 points at #51, #52 and #53, and
   progress is an aarch64 ratchet count anyone can read.
2. **The toolchain story stays intact.** One compiler, our lowering, no LLVM in the kernel build.
3. **NEON is available on our terms**, which is what the ADR-MC1 CPU budget and the ADR-MC5 blit
   path depend on.
4. **Failure is detectable early.** The 35/70 trigger means we find out mid-effort whether the
   approach is amortising, rather than at the end.

### Negative

1. **It is roughly 4K lines of lowering to mirror**, all of it our own work, none of it shared with
   an upstream community.
2. **No optimiser.** Code quality from a direct emitter is worse than LLVM's, which spends part of
   the media-center CPU budget on compiler output rather than algorithms.
3. **Every future architecture pays the same bill.** Option 1 does not generalise; RISC-V would be
   another mirror.
4. **Cross-compilation work is a prerequisite**, not a side quest — the host-arch backend selection
   at `src/main.zig` ~L3649 blocks everything else.

### Mitigations

- The ratchet gives continuous evidence of the amortisation rate, so the revisit trigger fires on
  data rather than on mood.
- The ADR summary is mirrored into `home-lang/home#5` as a comment so compiler contributors work
  from the same plan rather than rediscovering it.
- Option 3 (hybrid) remains available and cheap to adopt later: nothing in option 1 forecloses
  using LLVM for userspace optimisation once the kernel path is green.

---

## Related decisions

- [ADR-MC1](ADR-MC1-media-center.md) — the product whose CPU budget depends on NEON
- [ADR-MC3](ADR-MC3-media-stdlib.md) — media stdlib, which must build freestanding for aarch64
- [ADR-MC5](ADR-MC5-display.md) — NEON blits in the UI plane
- [ADR 0001](0001-use-home-language-for-os.md) — use the Home language for the OS

---

## References

- `~/Code/Home/lang/packages/codegen/src/home_kernel_codegen.zig` (4,204 lines)
- `~/Code/Home/lang/packages/codegen/src/native_codegen.zig` (10,854 lines)
- `~/Code/Home/lang/packages/codegen/src/aarch64_native_codegen.zig` (1,461 lines)
- `~/Code/Home/lang/packages/codegen/src/arm64.zig` (518 lines)
- `~/Code/Home/lang/packages/codegen/src/llvm_codegen.zig` (622) / `llvm_backend.zig` (715)
- `~/Code/Home/lang/src/main.zig` ~L3649 — host-arch backend selection
- MASTER_PLAN A6; issues #51, #52, #53; `home-lang/home#5`

---

## Revision history

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 2026-09-02 | Core Team | Initial decision (from #44) |
