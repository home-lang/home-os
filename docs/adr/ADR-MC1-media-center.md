# ADR MC1: HomeOS TV Profile — Scope of the Media Center

**Status**: Accepted
**Date**: 2026-09-02
**Epic**: home-lang/home-os#113
**Issue**: home-lang/home-os#43
**Milestone**: MC0 — Product & decisions
**Decision Makers**: Core Team
**Tags**: `product`, `media-center`, `tv-profile`, `raspberry-pi`, `scope`

---

## Context

Before a single driver or UI screen is written, one document has to say what "an Apple TV built
from our own stack" concretely means. Without it, every downstream issue negotiates its own scope,
every gate invents its own number, and the project drifts into a general-purpose desktop that
happens to play video.

Today the repository has no living-room concept at all. Grepping the tree for `10-foot`,
`leanback`, `media center`, `AirPlay` and `DLNA` returns nothing. There is a kernel, a compositor,
storage, and a desktop shell plan — but no statement of what the television product is, what it
refuses to be, and what numbers it must hit to be called finished.

This ADR fixes that target. Everything in milestones MC1–MC9 is measured against the feature set,
the codec floor, the non-goals and the budgets recorded here. When a later issue wants to add
something that is not in this document, the honest move is to amend this ADR rather than to widen
scope quietly.

### Constraints inherited from existing decisions

- **CLAUDE.md**: all OS code is written in Home. No third-party userland is imported to make a
  feature appear faster.
- **MASTER_PLAN D1/D4**: no Linux userland, no vendored application stacks. Kodi and Plex are
  reference points for *feature scope only* — we read their feature lists, not their source.
- **Hardware**: Raspberry Pi 5 (BCM2712). The SoC has a hardware **HEVC** decoder and **no**
  H.264 and **no** AV1 hardware decoder. That single hardware fact drives the entire codec floor
  below and is not negotiable by wishing.

---

## Personas and usage

The TV profile is designed for one physical situation: a person on a sofa, three metres from a
television, holding a remote, with a NAS somewhere in the house. Everything else is a distraction.

### Persona A — "The household viewer"

Sits down, presses one button, expects a picture. Does not know or care what a codec is. Navigates
with a five-way d-pad plus play/pause and back. Never types if it can be avoided; when a search box
is unavoidable, an on-screen keyboard driven by the d-pad is the interaction, so search must be
rare and forgiving. This persona defines the **cold boot ≤ 8 s** budget and the **≤ 50 ms
remote-to-screen latency** budget: both are the difference between "an appliance" and "a computer
that shows films".

### Persona B — "The librarian"

Owns the media. Rips discs, downloads, tags, and files everything onto a NAS exported over SMB or
NFS. Cares that artwork resolves, that a TV show is grouped by season, that "continue watching"
survives a reboot, and that a new file appears in the library without a manual rescan ritual. This
persona defines the source list (USB / NVMe / SMB / NFS / HTTP(S) / HLS) and the library model.

### Persona C — "The operator"

Usually the same human as B, wearing a different hat: the person who has to update the box. Wants
updates that apply themselves overnight and that cannot brick the television. This persona defines
**OTA updates with rollback** as a v1 feature rather than a nicety — an appliance that can be
bricked by an update is not an appliance.

### The usage loop

```
  power on ──► boot (≤ 8 s) ──► home screen
                                    │
              ┌─────────────────────┼─────────────────────┐
              ▼                     ▼                     ▼
        continue watching      browse library         settings
              │                     │                     │
              └────────► player (OSD, subtitles) ◄────────┘
                                    │
                              idle ──► screensaver ──► (≤ 3 W)
```

Notice what is absent: no window management, no file manager, no terminal, no multitasking model
beyond "one player, one shell". The TV profile is a single full-screen application that owns the
display.

---

## Decision

### Product definition

**HomeOS TV profile** is a boot target for the Raspberry Pi 5 that starts straight into a single
full-screen TV shell — no desktop, no window manager — driven by a remote, playing local and
network media. It reuses the Phase 7b Pi 5 bring-up and adds a parallel "MC" milestone track; it
does not move any existing phase gate.

Kodi and Plex are the reference for feature scope only. **No third-party userland ships**, in line
with CLAUDE.md and MASTER_PLAN D1/D4.

### v1 feature set

| Area | v1 content |
|---|---|
| Home screen | Top shelf, app row, "continue watching" |
| Libraries | Movies, TV Shows, Music, Photos — each with artwork |
| Player | Full-screen video with OSD, subtitles |
| System | Settings, screensaver |
| Input | CEC (TV remote), Bluetooth remote, phone remote |
| Sources | USB, NVMe, SMB, NFS, HTTP(S), HLS |
| Lifecycle | OTA updates with rollback |

### v1 codec floor

| Class | v1 requirement | Path |
|---|---|---|
| H.264 | up to **1080p60** | software, NEON |
| HEVC | up to **4Kp60** | hardware |
| Audio | AAC, MP3, FLAC, Opus, Vorbis, PCM | software |
| Containers | MP4, MKV, TS | software demux |
| Subtitles | SRT, ASS, VTT, PGS | software |

**H.264 at 4K and AV1 in any resolution are explicit non-goals for v1.** The Pi 5 has no H.264 and
no AV1 hardware decoder, and software-decoding either at 4K does not fit inside the CPU budget
below. Saying so here, once, prevents the question being relitigated in nine downstream issues.

### Non-goals for v1

- **Web browser.** Enormous, security-critical, and irrelevant to the sofa.
- **App store for third-party apps.** No third-party userland ships in v1 (see ADR-MC4 for the
  post-v1 sandboxed-plugin path).
- **Games.**
- **Wi-Fi as the only link.** Ethernet first; Wi-Fi may exist but the product is specified,
  budgeted and gated on wired networking.
- **AirPlay / Cast receivers.** Post-v1 research.
- **HDR tone-mapping.** Passthrough only (see ADR-MC5).
- **V3D / GPU 3D acceleration.** The UI is composed by the HVS, not rendered by a 3D pipeline.

### Budgets

These become CI gates in #49. Every number here is a named future gate; none of them is decorative.

| Budget | Target | Stretch |
|---|---|---|
| Cold boot to interactive home screen | ≤ **8 s** | 4 s |
| Idle RSS, whole system | ≤ **128 MB** | — |
| Idle CPU | ≤ **3 %** | — |
| UI frame rate at 1080p | **60 fps**, p99 frame time ≤ **16.6 ms** | — |
| Remote-to-screen input latency | ≤ **50 ms** | — |
| 1080p H.264 software decode | ≤ **60 %** of 4 cores | — |
| Idle power | ≤ **3 W** | — |

The budgets are interlocking, not independent. The 128 MB idle RSS ceiling is what rules out
shipping a JavaScript engine in v1 (ADR-MC4). The 60 % four-core ceiling for 1080p H.264 software
decode is what leaves headroom for a 60 fps UI on the same CPU. The 16.6 ms p99 frame time is what
forces CPU-rendered UI to stay at 1080p rather than 4K (ADR-MC5).

### Display architecture summary

The UI is rendered on the CPU at 1080p; video lives in a separate hardware plane; both are
composited by the VideoCore HVS and scaled to the panel's mode. Full detail, plane assignment and
bandwidth math are in **ADR-MC5** (#47).

---

## Feature matrix: HomeOS TV vs Apple TV vs Kodi

"Match" means the v1 feature set covers the same user-visible ground, not that the implementation
is equivalent.

| Feature | Apple TV | Kodi | HomeOS TV v1 | Verdict |
|---|---|---|---|---|
| Boots straight into a 10-foot shell | yes | yes (on LibreELEC) | **yes** | match |
| Home screen with top shelf / app row | yes | yes (skins) | **yes** | match |
| "Continue watching" | yes | yes | **yes** | match |
| Movies / TV / Music / Photos libraries with artwork | yes | yes | **yes** | match |
| Player OSD, seek, chapters | yes | yes | **yes** | match |
| Subtitles (SRT/ASS/VTT/PGS) | partial | yes | **yes** | match |
| Local sources (USB / internal storage) | limited | yes | **yes (USB, NVMe)** | match |
| Network shares (SMB / NFS) | no | yes | **yes** | match (Kodi parity) |
| HTTP(S) / HLS streams | yes | yes | **yes** | match |
| HEVC 4K hardware decode | yes | yes | **yes** | match |
| H.264 1080p | yes (hw) | yes (hw) | **yes (software, NEON)** | match, different path |
| H.264 4K | yes | yes | **no** | dropped — no Pi 5 hardware decoder |
| AV1 | yes (newer models) | yes | **no** | dropped — no Pi 5 hardware decoder |
| HDR10 tone-mapping | yes | yes | **passthrough only** | reduced |
| Dolby Vision / Atmos | yes | partial | **no** | dropped (licensing + scope) |
| CEC remote | yes | yes | **yes** | match |
| Bluetooth remote | yes | yes | **yes** | match |
| Phone as remote | yes | yes | **yes** | match |
| OTA updates with rollback | yes | distro-dependent | **yes** | match |
| Screensaver | yes | yes | **yes** | match |
| Third-party app store | yes | add-on repos | **no** | dropped by policy (D1/D4) |
| Web browser | limited | add-on | **no** | dropped |
| Games | yes | add-on | **no** | dropped |
| AirPlay / Cast receiver | yes (AirPlay) | add-on | **no** | post-v1 research |
| Streaming-service apps (Netflix etc.) | yes | no (DRM) | **no** | dropped — DRM, no third-party userland |
| PVR / live TV | no | yes | **no** | dropped for v1 |
| 3D GPU-accelerated UI effects | yes | yes | **no (HVS composition)** | dropped by design |
| Whole stack built from our own toolchain | no | no | **yes** | our differentiator |

The shape of the table is deliberate: we match Kodi's *library and source* story, match Apple TV's
*appliance* story (boot speed, rollback, remote, silence), and drop the two categories that both of
them get from ecosystems we do not have — DRM streaming apps and third-party app distribution.

---

## Options considered

| Option | Description | Why not chosen |
|---|---|---|
| **Desktop shell with a media app** | Ship the Phase 9 desktop and run a full-screen player inside it | A window manager, input model and app lifecycle we do not need on a sofa; blows the 128 MB and 8 s budgets on infrastructure the viewer never sees |
| **Port/adapt Kodi** | Bring an existing media center to HomeOS | Requires a Linux-shaped userland and vendored third-party code; violates CLAUDE.md and MASTER_PLAN D1/D4; abandons the "our own stack" premise that justifies the project |
| **Streaming-first box** | Netflix/YouTube-style client as the primary product | Requires DRM (Widevine/FairPlay) that cannot be implemented from our own stack, and gives us no control over the feature we can actually deliver well |
| **Dedicated TV profile (chosen)** | Single full-screen shell, local + network media, our own stack top to bottom | Fits the hardware, fits the policy, and every one of its budgets is measurable on a Pi 5 |

---

## Consequences

### Positive

1. **Every later issue has a fixed target.** MC1–MC9 can be scoped against a written feature set
   instead of an argument.
2. **Every gate has a number.** The budgets table is directly translatable into CI assertions
   (#49), so "fast enough" stops being a matter of taste.
3. **The codec floor is honest about the silicon.** Naming H.264 4K and AV1 as non-goals up front
   avoids the classic media-center failure of promising universal playback and shipping stutter.
4. **The non-goals protect the budgets.** No browser, no app store, no 3D UI means the 128 MB idle
   ceiling is achievable rather than aspirational.
5. **The product is differentiated.** A media center whose entire stack — compiler, kernel,
   drivers, UI toolkit, codecs — comes from one project is a thing that does not currently exist.

### Negative

1. **We will be compared to Apple TV and lose on breadth.** No streaming apps means many households
   cannot use this as their only box. That is accepted.
2. **Software H.264 eats CPU.** The 60 %-of-four-cores budget is tight and will constrain the UI
   thread during playback of high-bitrate 1080p content.
3. **No HDR tone-mapping** means SDR displays fed HDR content will look wrong unless the source is
   already SDR; passthrough only pushes the problem to the television.
4. **The MC track competes for attention** with the existing phase plan. It is explicitly parallel
   and must not move existing gates — which requires discipline, not just a sentence in a document.
5. **Feature creep has an obvious attack surface.** "It's just one more codec" is how codec floors
   die. The floor is a floor.

### Mitigations

- The parity matrix in MASTER_PLAN §10 gains a **living-room row group**, so TV-profile parity is
  tracked with the same rigour as the rest of the system.
- The README links this work under a clearly labelled **ASPIRATION** banner until the first
  hardware-in-the-loop gate is green. Nothing here is claimed as working software yet.
- Any addition to the v1 feature set or the codec floor requires amending this ADR, not opening a
  new issue.

---

## Revisit trigger

Reopen this decision if any of the following becomes true:

- **The budgets prove unreachable on the Pi 5** after honest optimisation — specifically if cold
  boot cannot get under 12 s or idle RSS cannot get under 192 MB — in which case the v1 feature set
  is cut, not the budgets.
- **Software H.264 at 1080p60 exceeds 60 % of four cores** with NEON in place, which would force
  either a lower resolution floor or a hardware-assisted path.
- **A target platform with an H.264 and/or AV1 hardware decoder becomes the primary device**, which
  would move both codecs from non-goal to in-scope.
- **The no-third-party-userland policy changes** in MASTER_PLAN D1/D4, which would reopen the
  app-store and streaming-app rows in the feature matrix.

---

## Related decisions

- [ADR-MC2](ADR-MC2-aarch64-codegen.md) — aarch64 kernel codegen strategy (the compiler that makes
  this bootable at all)
- [ADR-MC3](ADR-MC3-media-stdlib.md) — media codecs as Home standard library
- [ADR-MC4](ADR-MC4-ui-stack.md) — TV UI stack (stx → Craft, ahead-of-time)
- [ADR-MC5](ADR-MC5-display.md) — display and compositing architecture
- [ADR 0008](0008-raspberry-pi-focus.md) — Raspberry Pi first strategy

---

## References

- MASTER_PLAN §4 (phase plan, MC track), §9 (shell architecture), §10 (parity matrix), D1/D4
  (no third-party userland)
- CLAUDE.md — language policy
- Issue home-lang/home-os#43 (this ADR), #47 (display), #49 (CI budget gates)

---

## Revision history

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 2026-09-02 | Core Team | Initial decision (from #43) |
