> **Status:** describes target behavior; see [IMPLEMENTATION_STATUS.md](../../IMPLEMENTATION_STATUS.md) for current reality.

# The HomeOS 10-Foot HIG — TV Addendum

> **Status: v0 draft.** An addendum to [`docs/design/hig.md`](hig.md) v0.2,
> not a replacement. Everything in the base HIG still applies unless a
> section here overrides it explicitly. Like the base document, these
> tokens become Craft compile-time constraints at the Phase 4 freeze, so
> conformance is checked by the compiler, not code review. This document
> defines the `tv` profile tokens; `docs/design/hig-tokens.home` holds
> their machine-readable form and `docs/design/craft.md` §7 defines their
> consumption.

- **Version:** 0.1 (draft)
- **Date:** 2026-09-02
- **Owner:** Workstream D
- **Extends:** `docs/design/hig.md` v0.2 (desktop profile)
- **Tracking:** home-lang/home-os#50 · Epic #113 · Milestone MC0
- **Supersedes:** nothing; first publication

---

## 0. Thesis

The base HIG describes a **pointer-and-keyboard** system read from 60 cm.
This addendum describes the same system read from **three metres with a
five-button remote in the dark**. The two share one motion vocabulary, one
colour model and one enforcement ladder; they differ in every measurement
that depends on angular size, and in one structural way:

**On a TV there is no hover, no scrollbar, no pointer and no second
chance.** The user cannot point at a thing to ask what it is. The only
question the interface ever has to answer is *where am I, and what happens
if I press this*. Focus is therefore not an accent — it is the primary
content of every frame.

Three rules follow, and the rest of this document is their consequences:

1. **Exactly one element is focused, always, everywhere.**
2. **Every key press produces visible motion within 150 ms.**
3. **Nothing is smaller, dimmer or thinner than the 10-foot floor**, and
   the floor is enforced numerically, not by eye.

## 1. Principles (deltas from base §1)

The base principles hold. These replace or sharpen them for the `tv`
profile:

1. **Remote-first, keyboard-equal, pointer-absent.** Every action is
   reachable from the eight-key grammar in §7. A USB keyboard is a
   convenience for development and text entry, never a requirement. There
   is no pointer; nothing may depend on hover.
2. **One focused element.** Base §1.4 says focus is always visible; here
   it is stronger — focus is *singular*, *never lost*, and never merely a
   ring (§5).
3. **Directional navigation is predictable before it is optimal.** A press
   of Right must move to the thing that visually sits to the right. A
   "smart" jump that a user cannot predict is a bug, even if it saves a
   press.
4. **No chrome the remote cannot reach.** No scrollbars, no close buttons,
   no tooltips, no drag targets, no right-click affordances.
5. **Legible at three metres, in the dark, from off-axis.** Type scale
   §2, safe areas §3 and contrast §4 are floors, not suggestions.
6. **One full-plane redraw per key press, at most.** The frame budget in
   #49 is a design constraint, not just an implementation one: a screen
   whose wireframe cannot be updated within one composited plane update
   per key press is rejected at design review (§10).

## 2. Type Scale (`tv` profile)

The UI plane is composed at **1920×1080 logical pixels** and scaled by the
HVS to the physical mode (#74). All sizes below are logical pixels on that
1080p plane; at 2160p output the plane is scaled 2× and the effective sizes
double, so the tokens are resolution-independent by construction.

Base size 32px. Ratio ≈ 1.5, rounded to whole pixels — a deliberately
coarser ratio than the desktop's 1.2, because at 3 m the eye discriminates
far fewer steps.

| Token | Size | Weight | Line height | Use |
|---|---|---|---|---|
| `tv.type.display` | 96 | bold | 104 | Hero titles, Now Playing title, screensaver clock |
| `tv.type.title` | 64 | bold | 72 | Screen titles, detail-page movie title |
| `tv.type.heading` | 40 | semibold | 48 | Row headings, section headings, settings group labels |
| `tv.type.body` | 32 | regular | 44 | Default text: synopses, list rows, settings values |
| `tv.type.caption` | 24 | regular | 32 | Metadata line, timestamps, helper text |

Rules:

- **24px is the absolute floor.** Nothing renders below `tv.type.caption`
  anywhere in the TV shell — not in Settings, not in the OSD's codec
  overlay, not in a debug panel visible to a user. There is no "small"
  variant to reach for; if text does not fit at 24px, the layout is wrong.
- Weights collapse to the same three as base §2 (regular / medium / bold;
  "semibold" maps to medium when the font lacks it).
- **Line length ≤ 60 characters** at `tv.type.body`. Long synopses truncate
  with an ellipsis and expand on Select, they do not wrap into a wall.
- **No italics below `tv.type.heading`.** Italic stems at 24–32px on a
  scaled plane alias badly; use `fg_muted` for the same emphasis.
- Text is never rendered over unblurred artwork. Any text sitting on an
  image sits on a scrim (§4).

## 3. Safe Areas and Grid

### 3.1 Title-safe insets

Consumer TVs still overscan, and wall mounts still crop. Every element
that carries meaning lives inside the **title-safe rectangle: 5 % inset on
all four edges**.

| Token | 1080p value | Meaning |
|---|---|---|
| `tv.safe.inset_pct` | 5 % | Inset applied to all four edges |
| `tv.safe.x` | 96 px | Left/right inset at 1920 wide |
| `tv.safe.y` | 54 px | Top/bottom inset at 1080 tall |
| `tv.safe.width` | 1728 px | Usable width |
| `tv.safe.height` | 972 px | Usable height |

Rules:

- **Inside title-safe:** all text, all icons, all focusable elements, all
  focus decoration at its *grown* size (a card scaled 1.08 must still fit).
- **Outside title-safe, inside the plane:** background artwork, gradients,
  scrims, and the bleed of a row that continues off-screen. Losing any of
  it to overscan must cost the user nothing.
- A row that scrolls horizontally **bleeds to the plane edge** so the user
  can see that more content exists; the first and last *focusable* card
  still parks inside the safe rectangle.

### 3.2 Grid

The desktop's 4px grid is **doubled to 8px** for the `tv` profile. All
padding, margins and gaps are multiples of 8.

| Token | px | Use |
|---|---|---|
| `tv.space.xs` | 8 | Icon-to-label |
| `tv.space.s` | 16 | Inside controls, chip padding |
| `tv.space.m` | 32 | Card-to-card in a row, control-to-control |
| `tv.space.l` | 48 | Row-to-row, section separation |
| `tv.space.xl` | 80 | Major region separation, screen-title to content |

Corner radii: `tv.radius.s` = 8 (chips, buttons), `tv.radius.m` = 16
(cards, panels), `tv.radius.l` = 24 (sheets, dialogs). Elevation stays at
exactly two levels (`tv.elev.card`, `tv.elev.focus`) — no custom shadow
math, same rule as base §3.

**Focusable target ≥ 96×96 px** on the 1080p plane. This is the TV
analogue of the desktop's 24×24 hit target: it is not about the finger, it
is about the eye finding the focused thing in one saccade.

## 4. Colour and Contrast

The semantic token model from base §6 is unchanged — `bg`, `bg_elevated`,
`fg`, `fg_muted`, `accent`, `danger`. The TV profile changes the floors:

| Rule | Desktop (base §6) | TV (`tv` profile) |
|---|---|---|
| Body text contrast | ≥ 4.5:1 | **≥ 7:1** |
| Large text (≥ 40px) contrast | ≥ 3:1 | **≥ 4.5:1** |
| Focus indicator vs. its surroundings | ≥ 3:1 | **≥ 4.5:1**, plus a non-colour cue (§5) |

Rules:

- **Dark surfaces are the default and the only default.** There is no
  light theme for the TV shell in v1: a 1000-nit white field on a
  living-room TV at night is a usability defect, not a preference.
- **Never pure black, never pure white.** `tv.color.bg` sits a little
  above black so that OLED near-black banding and LCD backlight blooming
  do not read as artefacts; `tv.color.fg` sits a little below white so
  that large white type does not bloom. The exact values live in the theme
  files, as in base §6 — the *floors* live here.
- **Text over artwork requires a scrim.** Any text drawn over a poster,
  backdrop or video frame sits on `tv.color.scrim` (a vertical gradient to
  ~80 % opacity of `tv.color.bg` at the text end). Contrast is measured
  against the scrimmed result, not the artwork, and is validated by the
  theme validator — not by eye.
- **Colour never carries meaning alone.** Focus is scale + shadow +
  parallax (§5); state is icon + label. A user with a mis-calibrated TV in
  a bright room must still be able to read the interface.

## 5. The Focus Language

This is the section that makes the shell feel like one product. Every
screen implements it identically; #91 implements it once, in the Craft
focus engine, and screens do not get to reinterpret it.

### 5.1 What focus looks like

Exactly one element on the plane is focused. It is indicated by **three
simultaneous, non-redundant cues**:

| Cue | Token | Value |
|---|---|---|
| Scale | `tv.focus.scale` | 1.08 about the element's own centre |
| Shadow | `tv.elev.focus` | Elevated shadow, the second and last elevation level |
| Parallax | `tv.focus.parallax` | 8 px of counter-motion of the artwork inside the card |

Plus, for cards carrying artwork, the title label **fades in beneath the
focused card only** — an unfocused card in a row is artwork alone.

Rules:

- A focus **ring** is not used on the TV profile. A 2px ring at 3 m is
  invisible; scale and shadow are visible across the room and survive a
  mis-calibrated display.
- The scale is about the element's own centre, and the row's layout does
  **not** reflow to accommodate it — the focused card grows *over* its
  neighbours. A reflowing row makes every neighbour move on every key
  press, which is both ugly and a redraw the budget cannot afford.
- Parallax applies to the *content* of the card (the artwork), never to
  the card's frame, and never exceeds 8 px. It is the cheapest possible
  cue that reads as depth.
- Focus decoration at its grown size stays inside title-safe (§3.1).

### 5.2 Focus is never lost

There is no state in which nothing is focused. This is a hard invariant of
the focus engine, and it is a test, not a convention:

1. **On screen entry**, focus goes to the screen's declared default
   (named in §9 for each screen).
2. **If the focused element is removed** (a scan finishes, a row
   re-sorts, a device disconnects), focus moves — in this order — to the
   nearest surviving sibling in the same row, then to the row's first
   element, then to the previous row's remembered element, then to the
   screen default.
3. **If a screen's content is empty**, the empty-state element itself is
   focusable and focused. An empty row is never focusable and is not
   rendered at all.
4. **On return from a modal, the OSD or a child screen**, focus returns to
   the exact element that opened it.
5. **A dialog traps focus** for as long as it is open. Back dismisses it;
   directional keys cannot escape it.

### 5.3 Focus memory

- **Per row.** Each horizontal row remembers its focused index. Moving
  Down out of row A and back Up into row A returns to A's remembered card,
  not to A's first card.
- **Per screen.** Each screen remembers its focused row plus each row's
  index, for the lifetime of the back stack entry. Popping the screen off
  the back stack discards its memory; a fresh push starts at the default.
- **Per session, for the home screen only.** The home screen's memory
  survives navigation but resets on the screensaver-to-home wake and on
  boot, so a cold TV always presents the same first frame.

### 5.4 Wrap rules

| Direction | Behaviour |
|---|---|
| Left at the start of a row | **No wrap.** A nudge animation (12 px, `tv.motion.focus`, returning) says "edge". Focus does not move. |
| Right at the end of a row | **No wrap.** Same nudge. |
| Up at the top row | **No wrap.** Nudge. On screens with a top-level nav bar, Up from the first row moves *into* the nav bar — this is a move, not a wrap. |
| Down at the last row | **No wrap.** Nudge. |
| Long-press Up on a long vertical list | **Wrap to top** — the only wrap in the system, and it exists because scrolling back up 200 rows one press at a time is not a design. |
| Long-press Down on a long vertical list | Jump to the end of the list. Does not wrap to the top. |

Horizontal wrapping does not exist anywhere. A row that wraps makes
"press Right repeatedly to see everything" an infinite loop, and destroys
the user's sense of position in the row.

Long lists (> 12 items) additionally show a position indicator
(`tv.type.caption`, e.g. `14 / 212`) beside the row heading, since there is
no scrollbar.

## 6. Motion

Same vocabulary as base §5 — durations and curves are tokens only, per-app
values are compile errors — with TV durations, because motion at 3 m is
read as *transport*, not as flourish.

| Token | Duration | Curve | Use |
|---|---|---|---|
| `tv.motion.focus` | 150 ms | `ease-out-quart` | Focus moving between elements: the scale, shadow and parallax of both the leaving and the arriving element, and the row's scroll to keep the focused card in view |
| `tv.motion.page` | 250 ms | `ease-out-quart` | Screen push/pop, tab change, dialog present/dismiss |
| `tv.motion.hero` | 400 ms | `ease-out-quart` | Hero/backdrop crossfade behind a focus change, artwork load-in |
| `tv.motion.snap` | 0 ms | none | Key repeat, scrubber follow, anything that must feel instant |

Rules:

- **One curve.** `ease-out-quart` for everything that is not `snap`. A
  single curve is what makes two different screens feel like one system.
  There is no ease-in and no spring in the `tv` profile: motion starts at
  full speed because the key press has *already happened*, and decelerates
  into place.
- **Interruptible, never queued** (base §5). Holding a direction key
  produces a continuous glide, not a queue of 150 ms animations: a new
  target retargets the running animation from its current value.
- **Key repeat outruns the animation deliberately.** At repeat rates
  faster than `tv.motion.focus`, focus state updates immediately and only
  the visual catches up. Focus position is never behind the user's presses.
- **The hero crossfade is decoupled.** Focus moves at 150 ms; the backdrop
  behind it crossfades at 400 ms and is allowed to lag. Fast row traversal
  must not turn the backdrop into a strobe — the crossfade retargets to
  the latest artwork and never queues intermediate ones.
- **Reduced motion collapses every token to 0 ms.** Not "faster" — zero.
  Focus, page transitions and crossfades become instant cuts. The focus
  *cues* (scale, shadow) remain; only their animation goes. This is an
  accessibility setting in Settings → Accessibility, and it is the one
  setting that must be reachable without ever seeing an animation.
- Motion communicates *where things went* or *that they changed*, never
  decoration alone (base §5).

## 7. Remote Key Grammar

### 7.1 The grammar

Eight keys. Everything the TV shell does is reachable from these; anything
that is not is a design defect.

| Key | Short press | Long press (≥ 500 ms) |
|---|---|---|
| **Up** | Move focus up | Jump to the top of a long vertical list (the wrap in §5.4) |
| **Down** | Move focus down | Jump to the end of a long vertical list |
| **Left** | Move focus left; in the player, skip back 10 s | In the player, rewind (accelerating) while held |
| **Right** | Move focus right; in the player, skip forward 10 s | In the player, fast-forward (accelerating) while held |
| **Select** | Activate the focused element | Context menu for the focused element (mark watched, remove from Continue Watching, go to series, info) |
| **Back** | Pop the back stack; dismiss a dialog/OSD | Return to the home screen from any depth |
| **Menu** | Screen-level menu: filters and sort on a library screen, tracks and settings in the player | Settings |
| **Play/Pause** | Toggle playback; from a Detail screen, start playback directly | Stop and return to the previous screen |

Rules:

- **Back is never ambiguous.** It always removes the topmost thing: a
  dialog before an OSD, an OSD before a screen, a screen before the home
  screen. Back on the home screen does nothing (with the §5.4 nudge) — it
  never exits to a black screen, because there is nothing to exit to.
- **Long-press is always additive.** Every long-press is a shortcut for
  something the user can also reach by short presses. Nothing is
  *only* reachable by long press.
- **Long-press cancels on release before 500 ms** and fires the short
  press instead; a long press does not also fire its short press.
- Volume, mute and TV power are **not** in this grammar: on CEC they
  belong to the TV, and HomeOS passes them through rather than handling
  them (#98). The shell's own volume control lives in the player's Menu.

### 7.2 Physical key mapping

The same eight actions arrive over three transports. This table is the
single mapping; #98 (CEC), #99 (HID) and #91 (focus engine) all consume it.

| Action | CEC user-control code | HID Consumer page (0x0C) usage | HID Keyboard page (0x07) | Keyboard key (dev/USB) |
|---|---|---|---|---|
| Up | `0x01` Up | `0x0042` Menu Up | `0x52` | `Up` |
| Down | `0x02` Down | `0x0043` Menu Down | `0x51` | `Down` |
| Left | `0x03` Left | `0x0044` Menu Left | `0x50` | `Left` |
| Right | `0x04` Right | `0x0045` Menu Right | `0x4F` | `Right` |
| Select | `0x00` Select | `0x0041` Menu Pick | `0x28` Enter | `Enter` |
| Back | `0x0D` Exit | `0x0224` AC Back | `0x29` Escape | `Esc` / `Backspace` |
| Menu | `0x09` Root Menu | `0x0040` Menu | `0x76` Menu | `m` |
| Play/Pause | `0x61` Pause-Play Function | `0x00CD` Play/Pause | — | `Space` |
| Home (= long Back) | `0x0A` Setup Menu | `0x0223` AC Home | — | `h` |
| Play | `0x44` Play | `0x00B0` Play | — | — |
| Pause | `0x46` Pause | `0x00B1` Pause | — | — |
| Stop | `0x45` Stop | `0x00B7` Stop | — | — |
| Fast forward | `0x49` Fast Forward | `0x00B3` Fast Forward | — | — |
| Rewind | `0x48` Rewind | `0x00B4` Rewind | — | — |
| Next chapter | `0x4B` Forward | `0x00B5` Scan Next Track | — | — |
| Previous chapter | `0x4C` Backward | `0x00B6` Scan Previous Track | — | — |
| Info | `0x35` Display Information | `0x0209` AL Info? (device-dependent) | — | `i` |

Notes and honesty markers:

- **These codes are transcribed from the HDMI-CEC and USB HID usage-table
  specifications and have not yet been observed on hardware.** No CEC
  frame and no HID report has ever reached a HomeOS build (see
  IMPLEMENTATION_STATUS.md). Every row is verified against a real TV and a
  real remote in #98 and #99, and this table is corrected there rather
  than in a later doc.
- Remotes disagree, especially on Back and Menu. The engine therefore
  maps **transport code → action** through a per-device keymap
  (#99), and this table is the *default* keymap, not a hard-wired switch.
- Codes marked `—` have no natural equivalent on that transport; the
  action is reached through the grammar's eight keys instead.
- Unmapped codes are dropped silently. They are never forwarded to the
  focused element and never produce a beep.

### 7.3 Latency

Key-to-visible-change is budgeted at **≤ 50 ms** end to end (epic #113
budgets, gate `input-latency` in #101). The design consequence: the focus
engine must be able to move focus and start the animation without waiting
for artwork, metadata, or a decode. A screen whose focus movement depends
on an I/O result cannot meet the budget and is rejected at design review.

## 8. On-Screen Keyboards

Text entry from a remote is the worst interaction in any living-room
product, so the shell offers three routes and defaults to the least bad
one available.

1. **Phone remote (#100)** — the preferred route. When a phone is paired,
   the OSK shows a hint line: *"Type from your phone"*, and phone
   keystrokes appear in the field live.
2. **USB/Bluetooth keyboard (#99)** — if a keyboard is attached, the OSK
   still shows (so the user can see the field and the results) but is not
   focusable; typing goes straight into the field.
3. **The grid OSK below** — the fallback, and the one that must be good.

### 8.1 Grid layout (default)

Five rows of ten, D-pad traversable, no wrapping (§5.4), search results
updating live beneath it after each character.

```
 ┌──────────────────────────────────────────────────────────────┐
 │  Search                                                      │
 │  ┌────────────────────────────────────────────────────────┐  │
 │  │ blade run▌                                             │  │
 │  └────────────────────────────────────────────────────────┘  │
 │                                                              │
 │   a  b  c  d  e  f  g  h  i  j                               │
 │   k  l  m  n  o  p  q  r  s  t                               │
 │   u  v  w  x  y  z  0  1  2  3                               │
 │   4  5  6  7  8  9  -  '  :  .                               │
 │  ┌────┐ ┌───────────┐ ┌────────┐ ┌───────┐                   │
 │  │ ⇧  │ │   space   │ │   ⌫    │ │ clear │                   │
 │  └────┘ └───────────┘ └────────┘ └───────┘                   │
 └──────────────────────────────────────────────────────────────┘
```

Rules:

- **Alphabetical, not QWERTY.** QWERTY's advantage is muscle memory for
  ten fingers; with a D-pad it is only a scrambled ordering that costs
  presses. Alphabetical order is scannable at 3 m.
- Keys are `tv.type.heading` on ≥ 96×96 px targets, `tv.space.s` apart.
- Focus on a key uses the same §5 cues at `tv.motion.focus` — the OSK is
  not a special case.
- **Select** inserts. **Long-press Select** on a letter inserts its
  accented variants via a popover (`é è ê ë`), which is how diacritics are
  reachable without a second layout.
- **Long-press ⌫** clears the field. **Back** dismisses the keyboard and
  keeps the text; Back again leaves the screen.
- ⇧ toggles case for exactly one following character; long-press latches
  caps.
- Search fields do not require case or punctuation to match — the OSK is
  for the user's convenience, not the matcher's.

### 8.2 T9-style layout (numeric remotes)

Remotes with a 0–9 keypad and no full grid — including most CEC TV remotes
— get a T9 layout, where the on-screen display shows the mapping and the
physical digits do the work.

```
 ┌──────────────────────────────────────────────────────────────┐
 │  Search                                                      │
 │  ┌────────────────────────────────────────────────────────┐  │
 │  │ 2523▌   →  blade · cake · black                        │  │
 │  └────────────────────────────────────────────────────────┘  │
 │                                                              │
 │        ┌───────┐  ┌───────┐  ┌───────┐                       │
 │        │ 1  .- │  │ 2 abc │  │ 3 def │                       │
 │        ├───────┤  ├───────┤  ├───────┤                       │
 │        │ 4 ghi │  │ 5 jkl │  │ 6 mno │                       │
 │        ├───────┤  ├───────┤  ├───────┤                       │
 │        │7 pqrs │  │ 8 tuv │  │9 wxyz │                       │
 │        ├───────┤  ├───────┤  ├───────┤                       │
 │        │  ⇧    │  │ 0 ␣   │  │  ⌫    │                       │
 │        └───────┘  └───────┘  └───────┘                       │
 └──────────────────────────────────────────────────────────────┘
```

Rules:

- **Predictive, never multi-tap.** `2523` matches every library title
  whose words begin with those letter classes; results rank by watch
  history then alphabetically. Multi-tap (press `2` three times for `c`)
  is not implemented — it is unbearable at 3 m and the library is a
  closed, small corpus that prediction handles well.
- The digit-to-letter mapping is drawn on screen at all times; nobody is
  expected to remember it.
- The grid OSK (§8.1) remains reachable from a *Keyboard* button, for
  entering strings that are not library titles (network passwords, host
  names). Password fields always use the grid, never T9.

## 9. Screen Inventory

Nine screens ship in v1. Each entry gives the wireframe, the **default
focus** on entry, what **Back** does, and the **redraw** the design costs
per key press (the #49 constraint from §1.6).

Wireframes are proportional sketches on the 1728×972 title-safe rectangle,
not pixel-accurate mockups. `▓` marks the focused element.

### 9.1 Home

Default focus: the first card of *Continue Watching* if it is non-empty,
otherwise the first card of the first row. Back: nothing (nudge).
Redraw: the focused row's two cards + the hero crossfade region.

```
 ┌────────────────────────────────────────────────────────────────────────┐
 │ ░░░░░░░░░░░░░░ backdrop of the focused item, scrimmed ░░░░░░░░░░░░░░░░ │
 │ ┌────────────────────────────────────────────────────────────────────┐ │
 │ │  Movies   TV   Music   Photos   Sources          🔍   ⚙   20:14    │ │
 │ └────────────────────────────────────────────────────────────────────┘ │
 │                                                                        │
 │   BLADE RUNNER 2049                                    ← tv.type.display│
 │   2017 · 2h 44m · 4K HDR · ★ 8.0                       ← tv.type.caption│
 │   A young blade runner's discovery of a long-buried secret leads…      │
 │                                                                        │
 │   Continue Watching                                        3 / 11      │
 │   ┌────────┐ ╔══════════╗ ┌────────┐ ┌────────┐ ┌────────┐ ┌───────    │
 │   │        │ ║▓▓▓▓▓▓▓▓▓▓║ │        │ │        │ │        │ │           │
 │   │        │ ║▓▓▓▓▓▓▓▓▓▓║ │        │ │        │ │        │ │           │
 │   └────────┘ ╚══════════╝ └────────┘ └────────┘ └────────┘ └───────    │
 │   ▁▁▁▁▁▁▁▁    Blade Runner…   ▁▁▁▁▁▁▁▁                                 │
 │                                                                        │
 │   Recently Added                                                       │
 │   ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌───────      │
 │   │        │ │        │ │        │ │        │ │        │ │             │
 │   └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └───────      │
 └────────────────────────────────────────────────────────────────────────┘
```

The focused card is 1.08× and carries its title; unfocused cards are
artwork only, with a progress bar (`▁`) where one exists. The nav bar is
reached by pressing Up from the first row.

### 9.2 Library grid

Default focus: the remembered card, else the first. Back: home.
Redraw: two cards + the header count.

```
 ┌────────────────────────────────────────────────────────────────────────┐
 │  Movies                                     212 titles   ⌄ A–Z   ≡     │
 │                                                                        │
 │   ┌────────┐ ┌────────┐ ╔══════════╗ ┌────────┐ ┌────────┐ ┌────────┐  │
 │   │        │ │        │ ║▓▓▓▓▓▓▓▓▓▓║ │        │ │        │ │        │  │
 │   │        │ │        │ ║▓▓▓▓▓▓▓▓▓▓║ │        │ │        │ │        │  │
 │   └────────┘ └────────┘ ╚══════════╝ └────────┘ └────────┘ └────────┘  │
 │                          Blade Runner 2049                             │
 │   ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐    │
 │   │        │ │        │ │        │ │        │ │        │ │        │    │
 │   │        │ │        │ │        │ │        │ │        │ │        │    │
 │   └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘    │
 │                                                                        │
 │   ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐    │
 │   │        │ │        │ │        │ │        │ │        │ │        │    │
 │   └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘    │
 │                                                        row 2 of 36     │
 └────────────────────────────────────────────────────────────────────────┘
```

Six columns of 2:3 posters. Menu opens sort/filter (`⌄ A–Z`, `≡`). There
is no scrollbar; the *row n of m* caption is the position indicator
required by §5.4. Vertical movement scrolls by exactly one row and keeps
the focused row in the vertical middle third.

### 9.3 Detail

Default focus: *Play* (or *Resume* when a resume point exists). Back:
the previous screen. Redraw: the button row.

```
 ┌────────────────────────────────────────────────────────────────────────┐
 │ ░░░░░░░░░░░░░░░░░░░░░░ backdrop, scrimmed left ░░░░░░░░░░░░░░░░░░░░░░░ │
 │                                                                        │
 │   BLADE RUNNER 2049                                                    │
 │   2017 · 2h 44m · 4K HEVC · HDR10 · DTS-HD 5.1 · ★ 8.0                 │
 │                                                                        │
 │   A young blade runner's discovery of a long-buried secret leads him   │
 │   to track down former blade runner Rick Deckard, missing for thirty…  │
 │                                                                        │
 │   ╔═══════════════╗ ┌────────────┐ ┌────────────┐ ┌──────────────────┐ │
 │   ║▓ ▶ Resume 1:12║ │ ▶ From start│ │ ✓ Watched  │ │ ⋯ More           │ │
 │   ╚═══════════════╝ └────────────┘ └────────────┘ └──────────────────┘ │
 │   ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁  44 %                 │
 │                                                                        │
 │   Cast   Ryan Gosling · Harrison Ford · Ana de Armas · Robin Wright    │
 │                                                                        │
 │   More like this                                                       │
 │   ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌───────      │
 │   └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └───────      │
 └────────────────────────────────────────────────────────────────────────┘
```

### 9.4 Season / Episodes

Default focus: the next-up episode. Back: the series' Detail screen.
Redraw: two episode rows + the still/synopsis pane.

```
 ┌────────────────────────────────────────────────────────────────────────┐
 │  Severance                                          Season ⟨ 2 ⟩       │
 │                                                                        │
 │  ┌──────────────────────────────┐  ┌─────────────────────────────────┐ │
 │  │ 1  Hello, Ms. Cobel     44m ✓│  │ ░░░░░░ episode still ░░░░░░░░░░ │ │
 │  ├──────────────────────────────┤  │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │ │
 │  │╔════════════════════════════╗│  │                                 │ │
 │  │║▓2  Goodbye, Mrs. Selvig 41m║│  │ 2 · Goodbye, Mrs. Selvig        │ │
 │  │╚════════════════════════════╝│  │ 41m · aired 2026-01-24          │ │
 │  ├──────────────────────────────┤  │                                 │ │
 │  │ 3  Who Is Alive?        38m  │  │ Mark tries to convince the      │ │
 │  ├──────────────────────────────┤  │ others that what he saw on the  │ │
 │  │ 4  Woe's Hollow         52m  │  │ outside was real…               │ │
 │  ├──────────────────────────────┤  │                                 │ │
 │  │ 5  Trojan's Horse       47m  │  │ ╔═════════╗ ┌────────────────┐  │ │
 │  ├──────────────────────────────┤  │ ║ ▶ Play  ║ │ ✓ Mark watched │  │ │
 │  │ 6  Attila               45m  │  │ ╚═════════╝ └────────────────┘  │ │
 │  └──────────────────────────────┘  └─────────────────────────────────┘ │
 │                                        episode 2 of 10                 │
 └────────────────────────────────────────────────────────────────────────┘
```

The right pane is a *detail follower*: it crossfades at `tv.motion.hero`
while the list moves at `tv.motion.focus`, so fast traversal never
strobes (§6). Right from the list moves into the pane's buttons.

### 9.5 Now Playing OSD

Default focus: the scrubber. Back: hide the OSD (playback continues).
Redraw: the scrubber region only — **the video plane is never redrawn by
the UI**; the OSD lives on the HVS UI plane above it (#74).

```
 ┌────────────────────────────────────────────────────────────────────────┐
 │                                                                        │
 │                    (video plane — untouched by the OSD)                │
 │                                                                        │
 │                                                                        │
 │ ░░░░░░░░░░░░░░░░░░░░░░░░░ scrim gradient ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
 │  BLADE RUNNER 2049                                                     │
 │  Chapter 7 · The Wallace Corporation                                   │
 │                                                                        │
 │            ┌────────────┐                                              │
 │            │ ░ thumb ░░ │                                              │
 │            └────────────┘                                              │
 │  1:12:33   ▬▬▬▬▬▬▬▬▬▬▬▬▬╔▓╗▬────────────────────────────   -1:31:41    │
 │            │  │     │   ╚═╝    │        │          │                   │
 │            chapter ticks                                               │
 │                                                                        │
 │   ⏮   ⏪   ⏯   ⏩   ⏭        🔊 Audio: DTS-HD 5.1   💬 Subs: English    │
 └────────────────────────────────────────────────────────────────────────┘
```

- The OSD appears on any key press during playback and **auto-hides after
  4 s** of no input, fading at `tv.motion.page`.
- Left/Right on the scrubber skip ±10 s; long-press scrubs at an
  accelerating rate with the thumbnail following at `tv.motion.snap`.
- Down moves to the transport row, Down again to the track pickers, Up
  returns to the scrubber.
- Menu opens the full track/settings sheet; long-press Select opens the
  info overlay (codec, bitrate, dropped frames) — which still obeys the
  24px floor (§2).

### 9.6 Settings

Default focus: the first item of the remembered group, else *Display*.
Back: pop one level. Redraw: two list rows + the right pane.

```
 ┌────────────────────────────────────────────────────────────────────────┐
 │  Settings                                                              │
 │  ┌────────────────────┐  ┌──────────────────────────────────────────┐  │
 │  │ ╔════════════════╗ │  │  Display                                 │  │
 │  │ ║▓ Display       ║ │  │                                          │  │
 │  │ ╚════════════════╝ │  │  Resolution        3840×2160 @ 60 Hz  ⟩  │  │
 │  │   Audio            │  │  HDR               Auto               ⟩  │  │
 │  │   Network          │  │  Overscan          Off                ⟩  │  │
 │  │   Sources          │  │  Match frame rate  On                 ⟩  │  │
 │  │   Remotes          │  │                                          │  │
 │  │   Screensaver      │  │  Detected: LG OLED55C4 (EDID)            │  │
 │  │   Accessibility    │  │  Modes: 2160p60, 2160p50, 1080p60,       │  │
 │  │   Updates          │  │         1080p50, 720p60                  │  │
 │  │   About            │  │                                          │  │
 │  └────────────────────┘  └──────────────────────────────────────────┘  │
 │                                                                        │
 └────────────────────────────────────────────────────────────────────────┘
```

Two panes: groups left, settings right. Right/Select enters the right
pane; Left/Back returns. Every setting states its **current value on the
row** — a TV user must never enter a screen to find out what a setting is
already set to. Reduced motion lives under *Accessibility* (§6).

### 9.7 Onboarding

Default focus: the primary action of the current step. Back: previous
step (never out of onboarding). Redraw: the step body.

```
 ┌────────────────────────────────────────────────────────────────────────┐
 │                                                                        │
 │                                                                        │
 │                              HomeOS                                    │
 │                                                                        │
 │                   Let's set up your TV. Step 2 of 5.                   │
 │                                                                        │
 │                          Choose your network                           │
 │                                                                        │
 │              ╔══════════════════════════════════════════╗              │
 │              ║▓ Ethernet — connected, 1000 Mb/s         ║              │
 │              ╚══════════════════════════════════════════╝              │
 │              ┌──────────────────────────────────────────┐              │
 │              │  Set up later                            │              │
 │              └──────────────────────────────────────────┘              │
 │                                                                        │
 │                                                                        │
 │                          ●  ●  ○  ○  ○                                 │
 │                                                                        │
 │                    Press Back to go to the previous step               │
 └────────────────────────────────────────────────────────────────────────┘
```

Steps: language → network → display check (a "does this fit?" overscan
frame) → sources → remote pairing. Rules: one decision per step, every
step skippable except language, a visible step counter, and no step that
cannot be redone later from Settings.

### 9.8 Search

Default focus: the first key of the OSK (§8). Back: dismiss results, then
leave. Redraw: the results row + the field.

```
 ┌────────────────────────────────────────────────────────────────────────┐
 │  Search                                                                │
 │  ┌──────────────────────────────┐  ┌─────────────────────────────────┐ │
 │  │ blade run▌                   │  │  17 results                     │ │
 │  └──────────────────────────────┘  │                                 │ │
 │                                    │  Movies                         │ │
 │   ╔═╗ b   c   d   e   f   g   h    │  ┌──────┐┌──────┐┌──────┐┌────  │ │
 │   ║▓║                              │  │      ││      ││      ││      │ │
 │   ╚═╝ j   k   l   m   n   o   p    │  └──────┘└──────┘└──────┘└────  │ │
 │    q   r   s   t   u   v   w   x   │  Blade Runner 2049              │ │
 │    y   z   0   1   2   3   4   5   │                                 │ │
 │    6   7   8   9   -   '   :   .   │  Episodes                       │ │
 │   ┌────┐┌───────┐┌────┐┌────────┐  │  ┌──────┐┌──────┐              │ │
 │   │ ⇧  ││ space ││ ⌫  ││ clear  │  │  │      ││      │              │ │
 │   └────┘└───────┘└────┘└────────┘  │  └──────┘└──────┘              │ │
 │                                    │  People · Albums · Folders      │ │
 │                                    └─────────────────────────────────┘ │
 └────────────────────────────────────────────────────────────────────────┘
```

Results update after every character with no submit step. Right from the
OSK's last column moves into the results; Left returns to the same key.
Results grouped by kind, best-matching group first.

### 9.9 Screensaver

Default focus: none — this is the one screen with no focusable element,
and the only exception to §5.2, because there is nothing to activate. Any
key dismisses it and restores the previous screen with its focus intact.

```
 ┌────────────────────────────────────────────────────────────────────────┐
 │                                                                        │
 │ ░░░░░░░░░░░░░░░░░░░░ slow pan over library artwork ░░░░░░░░░░░░░░░░░░░ │
 │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
 │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
 │                                                                        │
 │       20:14                                                            │
 │       Tuesday 2 September                    ← tv.type.display / title │
 │                                                                        │
 │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
 │                                              Blade Runner 2049 (2017)  │
 └────────────────────────────────────────────────────────────────────────┘
```

- Enters after the idle timeout (Settings → Screensaver), never during
  playback, and never during an active download or scan that the user
  started.
- The clock and caption **drift position** every 60 s (OLED burn-in), and
  the pan is a single plane translation — not a per-frame redraw.
- After a second, longer timeout the display goes to CEC standby (#96).
  A key press wakes both.

## 10. Enforcement Ladder

Same ladder as base §8, with two TV-specific review gates:

| Stage | Mechanism |
|---|---|
| Now | This document; manual review; tokens present in `hig-tokens.home` |
| Design review, per screen | Wireframe states its default focus, its Back behaviour, and its per-key-press redraw region. A screen with no answer to all three does not proceed. |
| Craft API freeze (Phase 4) | `tv` profile tokens consumed by the focus engine (#91) and the crosswind→token resolver (#90); golden-frame tests per screen |
| Post-freeze | Compiler rejects non-token literals in `apps/tv/*`; `tv-ui-60fps` and `input-latency` gates (#101) fail the build |

A token change here requires, in the same PR: a version bump on this
document, the matching change in `hig-tokens.home`, and a
conformance-suite update — the same rule as base §8, because after the
freeze this is an API.

---

## Appendix: what is measured today

**Nothing in this document has run on hardware.** No Home code has
executed on a Raspberry Pi 5, there is no display driver, no CEC, no HID,
and no Craft renderer (see
[IMPLEMENTATION_STATUS.md](../../IMPLEMENTATION_STATUS.md) and epic #113's
"Where we start"). This is a specification of target behaviour written
before the shell, deliberately, so that the tokens exist as data before
#91 and #92 begin. Every number here is a decision, not a measurement;
the ones that turn out to be wrong are corrected in the PR that measures
them.

*Machine-readable token definitions: `docs/design/hig-tokens.home`,
`tv` profile section.*
