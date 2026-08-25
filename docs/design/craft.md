# Craft — UI Toolkit API v1 (Draft Spec)

> **Status: draft for review.** Craft v1 freezes at the Phase 4 gate with
> conformance tests ([MASTER_PLAN §5 Phase 4], Risk R7). No app-suite work
> may begin before that freeze; this document is the drafting work §16 marks
> parallel-safe during Phases 2–3.
>
> Grounded in the in-tree sources this API will wrap:
> `kernel/src/gui/craft_integration.home` (widget + event enums),
> `kernel/src/gui/window_manager.home` (tiling layouts),
> `kernel/src/video/compositor.home` (animation fields),
> `apps/desktop/craft_bridge.home`.

- **Version:** 0.3 (draft)
- **Date:** 2026-08-25
- **Owner:** Workstream D
- **Blocks:** Phase 4 `craft-demo`, `wm-layouts`; the entire first-party app suite (Phase 6)

---

## 1. Design Rules

1. **One process, one event loop.** The desktop shell is a single long-running
   Craft process ([MASTER_PLAN §9 D5]) — the architecture Omarchy proved out
   with Quickshell, but first-party all the way down. Craft apps embed in it.
2. **Immediate-mode state, retained-mode rendering.** App code owns plain
   state structs; Craft diffs and submits draw lists to the compositor.
   Rationale: matches how our compositor already consumes dirty regions.
3. **HIG tokens are compile-time constraints.** Every color/spacing/duration
   literal in app code must come from `hig.*` tokens (§7). A raw hex color is
   a compile error once the freeze lands. This is §11.6's enforcement claim,
   made real here.
4. **Keyboard-first, pointer-equal.** Every action has a keybinding; every
   keybinding has a discoverable GUI path (binding browser).
5. **No allocation in the frame path.** Frame callbacks get a bump-allocated
   arena reset per frame.

## 2. Module Layout

```
craft/
├── widget.home     # Widget tree, props, lifecycle
├── event.home      # Input events, focus model
├── layout.home     # Flex/grid layout engine
├── draw.home       # Draw list primitives
├── text.home       # Text shaping + rasterization bridge (Phase 4 TrueType)
├── theme.home      # HIG token tables (§7), theme switching
├── app.home        # App trait, run loop, embedding contract
└── testing.home    # Conformance harness (headless renderer + golden frames)
```

## 3. Widget Model

Widget kinds mirror the in-tree constants (`craft_integration.home`):
`button`, `label`, `textbox`, `checkbox`, `radio`, `slider`, `listbox`,
`treeview`, `menubar`, `toolbar`, `statusbar`, `panel`, `canvas`.

```home
struct Widget {
    id: WidgetId
    kind: WidgetKind
    rect: Rectangle          // computed by layout, not set by apps
    state: WidgetState       // hover/focus/disabled — owned by Craft
    props: Props             // kind-specific, value-typed
}

trait WidgetBehavior {
    fn on_event(self: *Widget, ev: Event): Handled
    fn paint(self: *Widget, dl: *DrawList, theme: *Theme)
}
```

Rules:

- **Props are values.** No shared mutable widget state across the tree;
  re-reconciliation is structural equality on Props.
- **Focus is explicit.** One focused widget per window; the focus ring is
  painted by Craft, not by apps (consistency requirement).
- **Canvas is the escape hatch**, not the default: it exposes raw DrawList
  submission for terminal/media widgets only.

## 4. Event Model

Event enum mirrors `EVENT_*` constants: mouse move/down/up/wheel, key
down/up, window close/resize/move, widget clicked/changed, paint.

```home
struct Event {
    kind: EventKind
    target: WidgetId          // resolved by hit-testing before dispatch
    // payload union: key { code, mods }, mouse { x, y, button }, ...
}
```

Dispatch order (stops at first `Handled`):
1. Focused widget (key events)
2. Hit-tested widget (pointer events)
3. Ancestors, innermost → outermost
4. Window-level shortcuts (the keyboard grammar, §HIG 4)

**Shortcut resolution is centralized**: apps register actions
(`{id, default_keys, callback}`), never raw key handlers. This is what makes
the Super+K binding browser possible — the browser reads the action table,
so it cannot drift from reality.

## 5. Rendering Contract

Apps submit nothing directly; `paint` fills a `DrawList`:

```
DrawList ops: rect | line | glyph_run | image | clip_push/pop | opacity
```

The compositor consumes draw lists against dirty regions
(`compositor.home` already tracks per-window dirty state and animates
position/size/opacity). Frame pacing target: 60fps with vsync; missed
deadlines degrade by skipping animation frames, never input frames.

Animation: apps declare *targets* (`anim_to(widget, prop, value, token)`);
durations/curves are HIG tokens only (§7.3). There is no per-app easing
math — motion consistency is structural.

## 6. App Embedding Contract

```home
trait CraftApp {
    fn init(self: *App, ctx: *AppContext): void
    fn update(self: *App, ctx: *AppContext): void      // build widget tree
    fn shutdown(self: *App, ctx: *AppContext): void
}
```

- The desktop shell hosts first-party apps as in-process modules sharing
  one compositor connection and one data layer (§11.5).
- Third-party apps get the same interface out-of-process via the syscall
  surface (`sys/syscall.home`) — same grammar, capability-checked.

## 7. Theming and Tokens

`theme.home` exposes the token tables defined by the HIG
(`docs/design/hig.md`). Draft token sets:

| Token family | Examples |
|---|---|
| `hig.color.*` | bg, bg_elevated, fg, fg_muted, accent, danger |
| `hig.space.*` | xs=4, s=8, m=16, l=24, xl=40 (px @1x) |
| `hig.type.*` | caption/body/title/display × regular/medium/bold |
| `hig.motion.*` | fast=120ms, base=200ms, slow=320ms + standard curves |
| `hig.focus.*` | ring width, offset, color |

Themes are **data**: a theme file binds each token to a value and must
validate against the token schema (reject unknown/missing tokens). ≥10
whole-system themes ship at v1.0 (Phase 5 gate).

## 8. Conformance Testing (the freeze mechanism)

Craft v1 freezes when its conformance suite passes on the MVK-derived
QEMU image:

1. **Golden frames** — headless renderer produces checksums of draw lists
   for every widget in its states (default/hover/focus/disabled).
2. **Layout property tests** — flex/grid invariants (no overlap, no
   overflow beyond declared scroll regions).
3. **Event determinism** — scripted input streams produce identical final
   trees across two runs.
4. **Token audit** — compile an intentionally non-conforming demo app and
   assert the compiler rejects it.
5. **A11y basics** — every widget resolvable by keyboard traversal order;
   labels present (asserted structurally).

CI job `craft-demo` (Phase 4) runs the demo app under QEMU with frame
timing asserted; the conformance suite gates any change to `craft/*` after
the freeze.

## 9. Deliberate Non-Features (v1)

- No CSS/user stylesheet language. Themes are validated data files.
- No animation scripting. Targets + tokens only.
- No custom widget painting outside `canvas` (consistency over flexibility).
- No network/file access from widget code — apps use capabilities
  (§11.4); widgets stay pure.
