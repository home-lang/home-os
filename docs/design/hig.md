# The HomeOS Human Interface Guidelines (HIG)

> **Status: v0 draft.** Published and versioned per [MASTER_PLAN §11.6].
> The differentiator is the enforcement mechanism: these tokens become
> Craft compile-time constraints at the Phase 4 freeze, so conformance is
> checked by the compiler, not code review. This document defines the
> tokens; `docs/design/craft.md` §7 defines their consumption.

- **Version:** 0.2 (draft)
- **Date:** 2026-08-25
- **Owner:** Workstream D
- **Supersedes:** nothing; first publication

---

## 0. Thesis

**Polish is functional feedback, not decoration.** Every rule below exists
because it makes the system legible: the user should be able to predict
what a control does, where focus is, and what just happened — from any
first-party app, with zero re-learning.

Three audiences, one source of truth:

1. **Designers** read this page.
2. **Craft apps** consume it as token tables (`hig.*`).
3. **The compiler** rejects non-conforming literals after the Phase 4 freeze.

## 1. Principles

1. **Keyboard-first, pointer-equal, GUI-discoverable.** Every action has a
   keybinding; every keybinding appears in the Super+K browser; every
   setting has a GUI path ([MASTER_PLAN §1]).
2. **One motion vocabulary.** The same class of change animates the same
   way everywhere, at the same speed.
3. **Curation over configuration.** Defaults are excellent; themes are
   data; there is no user stylesheet.
4. **Focus is always visible.** If something can receive keyboard input,
   its focus ring is on screen right now.
5. **Feedback within one frame.** A pressed control acknowledges in ≤16ms;
   a completed action confirms in ≤320ms.

## 2. Type Scale

Base size 15px @1x. Ratio ≈ 1.2 (minor third), rounded to whole pixels.

| Token | Size | Weight | Line height | Use |
|---|---|---|---|---|
| `type.display` | 36 | bold | 40 | Desktop-level moments (lock screen clock) |
| `type.title` | 24 | bold | 28 | Window titles, panel headers |
| `type.heading` | 18 | semibold | 22 | Section headings |
| `type.body` | 15 | regular | 20 | Default text |
| `type.callout` | 13 | medium | 18 | Secondary emphasis |
| `type.caption` | 12 | regular | 16 | Timestamps, helper text |

Rules:
- Weights collapse to three: regular / medium / bold ("semibold" maps to
  medium at render time when the font lacks it).
- Body text never renders smaller than 13px anywhere, including settings
  panels and notifications.

## 3. Spacing Grid

4px base grid. All padding/margins/gaps are multiples:

| Token | px | Use |
|---|---|---|
| `space.xs` | 4 | Icon-to-label |
| `space.s` | 8 | Inside controls, list-item gaps |
| `space.m` | 16 | Control-to-control in forms, window padding |
| `space.l` | 24 | Section separation inside a window |
| `space.xl` | 40 | Major region separation |

Corner radii: `radius.s`=4 (controls), `radius.m`=8 (panels/popovers),
`radius.l`=12 (windows). Shadows come from exactly two elevation levels
(`elev.panel`, `elev.window`) — no custom shadow math.

Hit targets ≥ 24×24px logical regardless of visual size.

## 4. Keyboard Grammar

The grammar is small and absolute:

| Binding | Action |
|---|---|
| `Super` | Launcher |
| `Super+K` | Keybinding browser |
| `Super+Space` | App switcher |
| `Alt+Tab` | Window cycle (MRU) |
| `Super+arrows` | Focus movement in the tiling layout |
| `Super+Shift+arrows` | Move focused window |
| `Super+F/B/G/M` | Layouts: floating?/binary/master/spiral → bound to the WM's five layouts (`window_manager.home`: horizontal, vertical, grid, master, spiral) |
| `Ctrl+C/Ctrl+V` etc. | Standard edit bindings everywhere, including terminals' shift-qualified variants |
| `Esc` | Dismiss/cancel, always, no exceptions |

Rules:
- Apps register **actions**, not key handlers; conflicts resolve
  global-first then window-local, and the browser shows the winner.
- A binding that appears in the browser must work; a working binding must
  appear in the browser. Conformance test asserts both directions.

## 5. Motion Vocabulary

Durations and curves are tokens only; per-app values are compile errors.

| Token | Duration | Curve | Use |
|---|---|---|---|
| `motion.fast` | 120ms | ease-out | Hover states, toggles, focus ring |
| `motion.base` | 200ms | ease-out | Windows opening/closing (matches the compositor's existing fade-in default), popovers |
| `motion.slow` | 320ms | ease-in-out | Workspace switches, large layout transitions |
| `motion.snap` | 0ms | none | State that must feel instant: key repeat, drag follow |

Rules:
- **Interruptible, never queued**: a new target retargets the running
  animation from its current value.
- **Reduced-motion** setting collapses every token to `snap`.
- Animation communicates *where things went* (spatial continuity) or
  *that they changed* (fade) — never for decoration alone.

## 6. Color and Dark/Light

- Semantic tokens only (`bg`, `bg_elevated`, `fg`, `fg_muted`, `accent`,
  `danger`, …); raw palette values live in theme files, not code.
- Every theme ships dark+light variants derived from the same semantic
  mapping; switching is instant (no animation).
- Contrast floor: body text 4.5:1, large text 3:1 against its rendered
  background — validated by the theme validator, not by eye.
- Accent is chosen by the user from a curated set; `danger` stays red in
  every theme (destructive actions must look identical system-wide).

## 7. Sound, Haptics, Notifications

- No UI sounds at v0 except: notification arrival, error. Both mutable,
  both off during screen sharing.
- Notification rules: badge without interrupt for background apps; banner
  for foreground-relevant events; critical bypasses DND only via an
  explicit capability (§11.4).
- History is persistent and replayable (Phase 5 gate requirement).

## 8. Enforcement Ladder

| Stage | Mechanism |
|---|---|
| Now | This document; manual review |
| Craft API freeze (Phase 4) | Token tables land in `theme.home`; golden-frame tests encode standard widgets |
| Post-freeze | Compiler rejects non-token literals in `craft/*` consumers; CI `craft-demo` + conformance suite gate regressions |

A token change requires: HIG version bump, theme-file migration, and a
conformance-suite update in the same PR. The HIG is versioned like an API
because, after the freeze, it is one.

---

*Machine-readable token definitions ship as `docs/design/hig-tokens.home`
when `theme.home` lands (Phase 4). Until then this page is normative.*
