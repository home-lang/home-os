# ADR MC4: TV UI Stack — Author in stx, Compile Ahead of Time to Craft

**Status**: Accepted
**Date**: 2026-09-02
**Epic**: home-lang/home-os#113
**Issue**: home-lang/home-os#46
**Milestone**: MC0 — Product & decisions
**Decision Makers**: Core Team
**Tags**: `ui`, `stx`, `craft`, `crosswind`, `10-foot`, `performance`

---

## Context

Two requirements pull against each other. "Use our own tech (stx, etc.)" says the TV shell should be
authored in the same tooling as the rest of our work. "Seamless, performant, resource cheap" on a
Raspberry Pi 5 — concretely, ADR-MC1's **128 MB idle RSS**, **60 fps with p99 frame time ≤ 16.6 ms**
and **≤ 50 ms remote-to-screen latency** — says the device must not be running a web stack.

Resolving that tension requires being precise about what each of our tools actually is, because the
names suggest capabilities that the code does not have.

### What our tools actually are

- **`~/Code/Tools/stx`** is TypeScript on Bun. It has **no renderer of its own**: its output is
  HTML strings, Web Components, or — via `packages/stx/src/craft-compiler.ts` (**1,422 lines**) —
  a **Craft native component tree**, with
  `CompilationFormat = 'zig' | 'typescript' | 'json' | 'binary'`.
  This is the crucial fact: stx is already, in part, a compiler to a native component tree. It is
  not inherently a web technology; it is an authoring format that currently has web backends.

- **`~/Code/Tools/crosswind`** (= `ts-css`) is a CSS generator with a parser and minifier and
  **no layout or paint engine**. It gives us a utility-class vocabulary, not a rendering system.

- **`~/Code/Tools/craft`** (Zig) renders through a **WebView** (`webkit2gtk` on Linux). That is not
  available on a bare-metal HomeOS and would violate the no-Linux-userland rule. Desktop Craft's
  renderer does not transfer to the television.

- **HomeOS has its own Craft, in Home**: spec `docs/design/craft.md` v0.3,
  `kernel/src/lib/craft_lib.home`, `kernel/src/gui/craft_integration.home`,
  `apps/desktop/craft_bridge.home`, plus HIG tokens in `docs/design/hig-tokens.home`. It is
  retained-mode draw-lists into the compositor — **exactly what a 10-foot UI needs**: a small,
  mostly-static scene graph, dirty-rect updates, and no per-frame layout of a document model.

- **`~/Code/Libraries/zig-js`** is a complete JS engine (**test262 100 %**) with a pinned Home ABI.
  It is a viable *runtime* — and a large one for an idle-at-128 MB budget.

So we have an authoring format that can already target a native tree, a styling vocabulary with no
engine, a desktop renderer we cannot use, a native retained-mode renderer in Home that is the right
shape, and a JS engine we would rather not pay for yet.

---

## Options considered

The estimates below are **engineering estimates, not measurements** — order-of-magnitude figures
used to compare options against the ADR-MC1 budgets. They are explicitly not the kind of measured
number this repository treats as fact, and each will be replaced by a measurement when the
corresponding path is built.

| Option | On-device stack | Est. idle RSS | Est. input→pixel latency | Est. cold start | Verdict |
|---|---|---|---|---|---|
| **A. WebView** (desktop Craft's model) | webkit2gtk + JS engine + DOM + CSS engine | **hundreds of MB** — far over the 128 MB whole-system budget on its own | tens of ms of DOM/layout/style work per interaction, on top of input and present | seconds | **Rejected.** Requires a Linux userland we do not ship; blows the budget before our own code loads |
| **B. zig-js runtime** (interpret stx-generated JS on device) | zig-js + a Home-side DOM/scene shim + Craft | **tens of MB** for engine, JIT-less execution and GC heap, against a 128 MB whole-system ceiling that also holds the kernel, codecs and frame buffers | GC pauses are the enemy of a p99 ≤ 16.6 ms frame time | ~1 s of engine + script init inside an 8 s boot budget | **Rejected for v1.** Technically viable, wrong cost at this budget |
| **C. Ahead-of-time compile to Home** (chosen) | Craft in Home only; no script engine, no CSS engine | **single-digit MB** for the UI layer — it is compiled Home code plus its draw-lists | bounded by input plumbing and compositing, not by interpretation | milliseconds — the UI is already machine code | **Chosen.** The only option where the UI layer is a rounding error against the budget |

Option B is the interesting rejection. zig-js is genuinely good — test262 100 % and a pinned Home
ABI is not a toy — and a JS runtime would give us dynamic third-party apps. The reason it loses is
arithmetic: ADR-MC1 budgets **128 MB for the entire system**, including the kernel, the media
stdlib's decode buffers, and the 1920×1080×4 UI plane (see ADR-MC5). Spending tens of megabytes and
a GC on a UI whose screens are known at build time is a bad trade. Nothing about the decision says
zig-js is wrong forever; it says it is wrong for the screens we already know.

---

## Decision

1. **Author** every TV screen as `.stx` single-file components — templates, props, signals,
   directives, Iconify icons. Developers write the UI in the same format used elsewhere in our
   work, with the same ergonomics.

2. **Compile ahead of time on the developer machine.** A new `home` output format in stx's
   craft-compiler emits `.home` source that builds Craft component trees plus signal bindings
   (**#89**). This extends `CompilationFormat` — which already spans `'zig' | 'typescript' | 'json'
   | 'binary'` — with the target we actually need. The emitted code is **checked in under
   `apps/tv/generated/`**: reviewable, diffable, and agent-legible. Generated code that nobody can
   read is a black box; generated code in the tree is just code with an unusual author.

3. **Style with crosswind's utility vocabulary**, but the emitter **resolves every class to HIG
   tokens at compile time** (**#90**). `docs/design/hig-tokens.home` is the palette of record.
   **No CSS parser runs on the device** — crosswind is a build-time vocabulary, not a runtime.

4. **Run as one long-running Craft process** (`apps/tv/`) — the same architecture MASTER_PLAN §9
   chose for the desktop shell, so the TV profile is a second consumer of an existing model rather
   than a parallel invention. **No JS engine ships in v1.**

5. **Post-v1**: zig-js for third-party plugins and apps, sandboxed. Not on the critical path, and
   explicitly not a v1 dependency (ADR-MC1 lists a third-party app store as a non-goal).

### Data flow

```
  developer machine                         │        Raspberry Pi 5
                                            │
  apps/tv/*.stx                             │
        │                                   │
        ▼  craft-compiler.ts (1,422 lines)  │
   format: 'home'   ──── crosswind classes ─┼──► resolved to HIG tokens at build time
        │                                   │
        ▼                                   │
  apps/tv/generated/*.home  (checked in)    │
        │                                   │
        ▼  home build (aarch64, ADR-MC2)    │
   apps/tv binary  ────────────────────────►│  one long-running Craft process
                                            │        │
                                            │        ▼  retained-mode draw lists
                                            │  Craft in Home (craft_lib.home)
                                            │        │
                                            │        ▼  dirty rects, NEON blits
                                            │  compositor ──► HVS UI plane (ADR-MC5)
```

Nothing crosses the line into the device except compiled Home code. No TypeScript, no Bun, no CSS,
no JavaScript.

### stx feature subset for v1

The emitter supports a defined subset. Anything outside it is a **compile error at build time**,
never a silent no-op or a runtime fallback — a TV shell must not discover at 60 fps that a
directive did nothing.

| stx feature | v1 status | Notes |
|---|---|---|
| Templates / single-file components | **supported** | The core authoring unit |
| Props | **supported** | Resolved statically into component constructors |
| Signals | **supported** | Emitted as Craft signal bindings; the reactivity model on device |
| Conditional directives (`if` / `else`) | **supported** | Emitted as branch in the tree builder |
| List directives (`for` / keyed lists) | **supported** | Required by every library grid and row |
| Slots | **supported** | Needed for shared screen scaffolding (row, shelf, dialog) |
| i18n | **supported** | String catalogues resolved at build time; no runtime locale loader in v1 |
| Iconify icons | **supported** | Rasterised or path-emitted at build time |
| crosswind utility classes | **supported** | Resolved to HIG tokens at compile time (#90) |
| Inline `<script>` with arbitrary TS/JS | **compile error** | There is no script engine on device |
| Dynamic `import()` / runtime component loading | **compile error** | The screen set is known at build time |
| Web Components / custom elements output | **compile error** | No DOM on device |
| Raw HTML injection | **compile error** | No HTML parser on device |
| Arbitrary runtime CSS strings | **compile error** | No CSS parser on device (#90) |
| Third-party npm UI packages | **compile error** | No third-party userland (MASTER_PLAN D1/D4) |

---

## Consequences

### Positive

1. **The UI layer costs almost nothing at runtime.** It is compiled Home code driving retained-mode
   draw lists — the option where the 128 MB budget is spent on media, not on a document engine.
2. **Frame timing is predictable.** No interpreter, no GC, no style recalculation means the p99
   16.6 ms target is bounded by our own compositor rather than by someone else's pause behaviour.
3. **Authoring ergonomics are preserved.** Developers write `.stx`, not hand-built scene graphs.
4. **Generated code is reviewable.** Checking `apps/tv/generated/` into the tree keeps the output
   diffable and legible to both humans and agents — a regression in emitted code shows up in review.
5. **It reuses an existing architecture.** One long-running Craft process is MASTER_PLAN §9's
   desktop-shell model, so the TV profile validates a decision already made.
6. **It extends our own tools rather than adopting foreign ones.** `craft-compiler.ts` already
   emits a native component tree; adding a `home` format is a new backend, not a new toolchain.

### Negative

1. **No dynamic UI in v1.** Screens are fixed at build time. Anything resembling a plugin or a
   downloadable app waits for the post-v1 sandboxed zig-js path.
2. **The emitter is now a critical build dependency.** A bug in `craft-compiler.ts`'s `home` format
   is a bug in every screen, and it is written in TypeScript on Bun — outside the Home toolchain.
3. **Two representations to keep in sync.** `.stx` sources and checked-in `.home` output can drift
   if regeneration is not enforced in CI.
4. **The stx subset is a real constraint.** Authors accustomed to full stx will hit compile errors,
   which is the intended behaviour but is still friction.
5. **crosswind's vocabulary must map onto HIG tokens.** Where a utility class has no token, either
   the token set grows or the class is rejected — a design-system negotiation, not just a compiler
   feature.

### Mitigations

- Unsupported features fail as **compile errors**, so drift between what stx can express and what
  the device can run is caught on the developer's machine, not in the living room.
- Generated output is checked in, so regressions are visible in code review.
- CI regenerates and diffs `apps/tv/generated/` to prevent the two representations diverging.

---

## Revisit trigger

Reopen this decision if:

- **The AOT-emitted UI misses the ADR-MC1 frame budget** (p99 > 16.6 ms at 1080p), which would
  indicate the cost is in Craft or the compositor rather than in the runtime choice — and would
  point at ADR-MC5, not at reinstating a script engine.
- **A dynamic-app requirement is promoted into v1 scope**, which would make the zig-js runtime a
  dependency rather than a post-v1 option and would require re-costing the memory budget.
- **The idle RSS budget is raised well above 128 MB** for unrelated reasons, changing the arithmetic
  that rejected option B.
- **`craft-compiler.ts`'s `home` format proves unable to express the v1 subset** (particularly slots
  and keyed list directives), which would force hand-written Craft screens for the affected areas.

---

## Related decisions

- [ADR-MC1](ADR-MC1-media-center.md) — the 128 MB / 60 fps / 50 ms budgets this option table is
  measured against
- [ADR-MC2](ADR-MC2-aarch64-codegen.md) — the aarch64 backend that compiles the emitted Home code
- [ADR-MC5](ADR-MC5-display.md) — the UI plane the Craft compositor draws into
- MASTER_PLAN §9 — one long-running Craft process (desktop shell)

---

## References

- `~/Code/Tools/stx` — `packages/stx/src/craft-compiler.ts` (1,422 lines);
  `CompilationFormat = 'zig' | 'typescript' | 'json' | 'binary'`
- `~/Code/Tools/crosswind` (= `ts-css`) — CSS generator, parser/minifier, no layout or paint engine
- `~/Code/Tools/craft` (Zig) — WebView renderer (`webkit2gtk` on Linux)
- `~/Code/Libraries/zig-js` — complete JS engine, test262 100 %, pinned Home ABI
- `docs/design/craft.md` v0.3; `kernel/src/lib/craft_lib.home`;
  `kernel/src/gui/craft_integration.home`; `apps/desktop/craft_bridge.home`;
  `docs/design/hig-tokens.home`
- Issues #89 (`home` output format), #90 (class → HIG token resolution), #91

---

## Revision history

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 2026-09-02 | Core Team | Initial decision (from #46) |
