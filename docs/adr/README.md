# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records for home-os.

## What is an ADR?

An Architecture Decision Record (ADR) captures an important architectural decision made along with its context and consequences.

## Format

Each ADR follows this structure:
- **Title**: Short, descriptive name
- **Status**: Proposed | Accepted | Deprecated | Superseded
- **Context**: The problem and why we need to make a decision
- **Decision**: What we decided to do
- **Consequences**: What happens as a result (positive and negative)

## Index of ADRs

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [0001](0001-use-home-language-for-os.md) | Use Home Programming Language | Accepted | 2025-11-24 |
| [0002](0002-kernel-architecture.md) | Hybrid/Modular Monolithic Kernel | Accepted | 2025-11-24 |
| [0003](0003-memory-management.md) | Memory Management Strategy | Accepted | 2025-11-24 |
| [0004](0004-driver-model.md) | Driver Development Model | Accepted | 2025-11-24 |
| [0005](0005-build-system.md) | Build System Design | Accepted | 2025-11-24 |
| [0006](0006-security-architecture.md) | Security Architecture | Accepted | 2025-11-24 |
| [0007](0007-performance-targets.md) | Performance Targets | Accepted | 2025-11-24 |
| [0008](0008-raspberry-pi-focus.md) | Raspberry Pi First Strategy | Accepted | 2025-11-24 |

### MC series — Media Center / TV profile

Epic: [home-lang/home-os#113](https://github.com/home-lang/home-os/issues/113) · Milestone MC0 — Product & decisions.

| ADR | Title | Status | Date | Issue |
|-----|-------|--------|------|-------|
| [MC1](ADR-MC1-media-center.md) | HomeOS TV Profile — Scope of the Media Center | Accepted | 2026-09-02 | #43 |
| [MC2](ADR-MC2-aarch64-codegen.md) | aarch64 Kernel Codegen — Extend the Direct Emitter | Accepted | 2026-09-02 | #44 |
| [MC3](ADR-MC3-media-stdlib.md) | Media Codecs Are Home Standard Library, Not HomeOS Source | Accepted | 2026-09-02 | #45 |
| [MC4](ADR-MC4-ui-stack.md) | TV UI Stack — Author in stx, Compile Ahead of Time to Craft | Accepted | 2026-09-02 | #46 |
| [MC5](ADR-MC5-display.md) | Display Architecture — HVS Hardware Planes, 1080p CPU UI | Accepted | 2026-09-02 | #47 |

**Summaries**

- **MC1** — Defines the TV profile: a single full-screen shell on a Pi 5, its v1 feature set, codec floor (H.264 1080p60 software, HEVC 4Kp60 hardware), explicit non-goals, and the seven budgets that become CI gates.
- **MC2** — Chooses to extend the direct kernel emitter with an aarch64 lowering, ratcheted file-by-file, rather than finishing the LLVM backend; switch to LLVM if the ratchet is below 35/70 after the planned effort.
- **MC3** — Grants `packages/{audio,video,image,media}` Home standard library status, consumed via FFI bindings and never vendored, so HomeOS source stays 100 % `.home`.
- **MC4** — Authors TV screens as `.stx`, compiles them ahead of time to `.home` Craft component trees with crosswind classes resolved to HIG tokens; no JS engine and no CSS parser ship in v1.
- **MC5** — Composes video, UI and OSD as separate VideoCore VII HVS hardware planes, with the UI rendered on the CPU at 1080p and hardware-scaled, keeping DRAM traffic at roughly 2.55–3.00 GB/s.

## Creating a New ADR

1. Copy the template:
```bash
cp docs/adr/template.md docs/adr/NNNN-short-title.md
```

2. Fill in the sections:
   - Context: Why are we making this decision?
   - Decision: What did we decide?
   - Consequences: What are the trade-offs?

3. Get review from team

4. Update this README index

## Superseding an ADR

When an ADR is superseded:
1. Mark old ADR status as "Superseded by ADR-XXXX"
2. Create new ADR explaining the change
3. Link them together
4. Update this index

## Related Documentation

- `/CLAUDE.md` - Development guidelines
- `/TODO.md` - Development roadmap
- `/TODO-UPDATES.md` - Priority implementation tasks
- `/docs/architecture/` - Detailed architecture docs

## Questions?

For questions about ADRs or to propose new ones, see the team wiki or file an issue.
