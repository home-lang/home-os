# ADR MC5: Display Architecture — HVS Hardware Planes, 1080p CPU UI

**Status**: Accepted
**Date**: 2026-09-02
**Epic**: home-lang/home-os#113
**Issue**: home-lang/home-os#47
**Milestone**: MC0 — Product & decisions
**Decision Makers**: Core Team
**Tags**: `display`, `compositor`, `videocore`, `hvs`, `hdmi`, `bandwidth`

---

## Context

ADR-MC1 asks for a 60 fps UI **and** 4K video on a Raspberry Pi 5, inside a 128 MB idle footprint
and a 3 W idle power budget. The cheapest way to get there without writing a 3D GPU driver is to use
what the VideoCore VII **Hardware Video Scaler (HVS)** already does in hardware: compose several
planes with per-plane scaling, format conversion and alpha, then feed the HDMI encoder.

Linux's `vc4` driver and several bare-metal projects prove the path exists. We implement it in Home
from public register documentation and observed behaviour, **never by copying code**.

### Current state

- `kernel/src/video/compositor.home` (**2,158 lines**) presents by copying a backbuffer to a
  **hardcoded x86 address `0xFD000000`**. It is a working single-framebuffer compositor pointed at
  the wrong machine.
- `kernel/src/rpi/videocore7.home` (**1,416 lines**) and `kernel/src/rpi/rp1_hdmi.home`
  (**1,200 lines**) exist but have **never been compiled**, and their register maps are
  **unverified**.

So the display story today is 4,774 lines of plausible-looking code, none of which has produced a
pixel on a Pi 5. This ADR fixes the architecture those files must converge on, and states the
bandwidth arithmetic that makes the architecture necessary rather than merely preferable.

---

## Decision

### Plane assignment

```
   ┌──────────────────────────────────────────────────────────────────────┐
   │                         PANEL (1080p60 or 2160p60)                   │
   └──────────────────────────────────────────────────────────────────────┘
                                     ▲
                                     │  HDMI encoder (mode, RGB/YCbCr, infoframes)
                                     │
   ┌─────────────────────────────────┴────────────────────────────────────┐
   │            VideoCore VII  HVS  —  hardware compose + scale           │
   │        per-plane: scaling · format conversion · alpha blend          │
   └──────────────────────────────────────────────────────────────────────┘
        ▲                        ▲                          ▲
        │                        │                          │
   ┌────┴──────────┐      ┌──────┴──────────┐      ┌────────┴──────────┐
   │  PLANE 0      │      │  PLANE 1        │      │  PLANE 2          │
   │  VIDEO        │      │  UI             │      │  SUBTITLES / OSD  │
   │               │      │                 │      │  (optional)       │
   │ YUV, native   │      │ ARGB8888        │      │ ARGB8888          │
   │ resolution    │      │ 1920 × 1080     │      │ 1920 × 1080       │
   │ HVS-scaled    │      │ HVS-scaled to   │      │ HVS-scaled        │
   │               │      │ panel mode      │      │                   │
   │ ◄ HEVC hw     │      │ ◄ Home          │      │ ◄ subtitle/OSD    │
   │   (zero-copy) │      │   compositor,   │      │   renderer        │
   │ ◄ or NEON-    │      │   CPU, dirty    │      │                   │
   │   converted   │      │   rects, NEON   │      │                   │
   │   sw frames   │      │   blits         │      │                   │
   └───────────────┘      └─────────────────┘      └───────────────────┘
                                     ▲
                                     │ vsync: HVS end-of-frame interrupt paces the UI loop
```

**Plane 0 — video.** Decoder output in a YUV plane at native resolution, scaled by the HVS.
Zero-copy for the hardware HEVC path: the decoder writes the frame, the HVS reads it, and the CPU
never touches pixel data. Software-decoded frames (H.264 up to 1080p60 per ADR-MC1) are
NEON-converted into the same plane format.

**Plane 1 — UI.** ARGB8888 at **1920×1080**, rendered by the Home compositor on the CPU with dirty
rectangles and NEON blits. The HVS scales it to the panel mode, whether that is 1080p or 4K.
**Rendering a 4K UI on the CPU is rejected for v1** — see the bandwidth math below.

**Plane 2 — subtitles / OSD.** Optional separate ARGB plane, so a subtitle change does not force a
redraw of the whole UI plane. Subtitles update on their own cadence, often several times a second;
coupling them to the UI plane would turn a text change into a full-screen composite.

**Mode setting** via the HDMI block: read EDID, select 1080p60 or 2160p60, choose RGB or YCbCr,
emit infoframes.

**Vsync** comes from the **HVS end-of-frame interrupt**, which paces the UI loop. This is the
mechanism behind ADR-MC1's p99 ≤ 16.6 ms frame-time gate: without a real vsync source, frame pacing
is guesswork and p99 is unmeasurable.

**HDR10** is **passthrough infoframes only**, and a stretch goal at that. No tone-mapping (ADR-MC1
lists it as a non-goal).

**Fallback:** a mailbox-allocated single framebuffer (**#73**), so the first pixel on screen does
not wait for a complete HVS driver. Bring-up gets a picture early; the plane architecture lands
behind it.

**V3D** (OpenGL / Vulkan) is out of scope for v1. `kernel/src/video/opengl.home` and
`kernel/src/video/vulkan.home` are **frozen**.

---

## Bandwidth math

This is the arithmetic that decides the architecture. All figures are computed from the pixel
dimensions; nothing here is measured on hardware.

### Per-frame bytes

| Surface | Dimensions | Format | Bytes per pixel | **Bytes per frame** |
|---|---|---|---|---|
| UI plane (chosen) | 1920 × 1080 = 2,073,600 px | ARGB8888 | 4 | **8,294,400 B** (7.91 MiB) |
| UI plane (4K, rejected) | 3840 × 2160 = 8,294,400 px | ARGB8888 | 4 | **33,177,600 B** (31.64 MiB) |
| Video plane, 1080p | 1920 × 1080 | NV12 (8-bit 4:2:0) | 1.5 | 3,110,400 B (2.97 MiB) |
| Video plane, 4K | 3840 × 2160 | NV12 (8-bit 4:2:0) | 1.5 | 12,441,600 B (11.87 MiB) |
| Video plane, 4K 10-bit | 3840 × 2160 | P010 (10-bit 4:2:0) | 3 | 24,883,200 B (23.73 MiB) |
| OSD plane | 1920 × 1080 | ARGB8888 | 4 | 8,294,400 B (7.91 MiB) |

### At 60 fps

| Surface | Bytes per frame | × 60 fps | Rate |
|---|---|---|---|
| **UI plane 1080p ARGB8888** | 8,294,400 | **497,664,000 B/s** | ≈ **0.50 GB/s** (0.46 GiB/s) |
| **UI plane 4K ARGB8888** | 33,177,600 | **1,990,656,000 B/s** | ≈ **1.99 GB/s** (1.85 GiB/s) |
| Video plane 4K NV12 | 12,441,600 | 746,496,000 B/s | ≈ 0.75 GB/s |
| Video plane 4K P010 | 24,883,200 | 1,492,992,000 B/s | ≈ 1.49 GB/s |
| Video plane 1080p NV12 | 3,110,400 | 186,624,000 B/s | ≈ 0.19 GB/s |
| OSD plane 1080p | 8,294,400 | 497,664,000 B/s | ≈ 0.50 GB/s |

**1,990,656,000 B/s is the ≈2 GB/s figure that rejects a CPU-rendered 4K UI**, and it is only the
*write* side. The HVS must then *read* every plane it composites, once per frame.

### DRAM traffic, write + read

Each plane is written by its producer and read by the HVS, so a fully-redrawn plane costs roughly
twice its write rate in DRAM traffic.

| Configuration | UI write | UI read (HVS) | Video write | Video read (HVS) | OSD read | **Total** |
|---|---|---|---|---|---|---|
| **Chosen: 1080p UI + 4K NV12 video + OSD** (full UI redraw, worst case) | 0.50 | 0.50 | 0.75 | 0.75 | 0.50 | **≈ 3.00 GB/s** |
| **Chosen, typical** (≈10 % dirty-rect UI redraw, static OSD) | ≈0.05 | 0.50 | 0.75 | 0.75 | 0.50 | **≈ 2.55 GB/s** |
| Rejected: 4K CPU UI + 4K NV12 video + OSD | 1.99 | 1.99 | 0.75 | 0.75 | 0.50 | **≈ 5.98 GB/s** |
| Chosen, 1080p panel, 1080p video, no OSD | 0.50 | 0.50 | 0.19 | 0.19 | — | **≈ 1.38 GB/s** |

### The DRAM budget implication

The Pi 5's LPDDR4X memory system has a theoretical peak of roughly **17 GB/s** (4267 MT/s on a
32-bit bus). That figure is datasheet arithmetic, not something we have measured; **achievable**
sustained bandwidth on real access patterns is typically a fraction of peak, and measuring it on
BCM2712 is an open task, not a known number.

The implication is straightforward:

- The chosen configuration spends **≈2.55–3.00 GB/s**, roughly **15–18 %** of theoretical peak,
  leaving the rest for decode, the CPU's own working set, storage and network.
- The rejected 4K-CPU-UI configuration spends **≈5.98 GB/s**, roughly **35 %** of theoretical peak
  — and does so through the CPU cores, which must *also* be running an H.264 software decoder
  within ADR-MC1's 60 %-of-four-cores budget, and the UI at p99 ≤ 16.6 ms.
- Put in per-frame terms: a 4K CPU UI requires writing **33,177,600 bytes within a 16.6 ms frame**,
  a sustained ≈2 GB/s of CPU stores that competes directly with decode for both bandwidth and cache.
  A 1080p UI writes **8,294,400 bytes** in the same window — a quarter of the traffic — and with
  dirty rectangles typically far less.

Scaling 1080p → 4K in the HVS is free in DRAM terms: it happens in the composition path, reading
the 1080p plane once. Rendering at 4K is not. That asymmetry is the whole argument.

---

## Frame pacing model

```
   HVS end-of-frame IRQ ──► compositor wakes
                              │
                              ├─ collect dirty rects from Craft draw lists
                              ├─ NEON blit dirty regions into UI plane backbuffer
                              ├─ (subtitle/OSD changes → plane 2 only)
                              ├─ swap plane 1 buffer pointer
                              └─ program HVS display list
                              │
                              ▼
                       ◄── 16.6 ms ──►   next end-of-frame IRQ
```

Three properties follow from this model:

1. **The UI loop is interrupt-paced, not polled.** Idle cost is near zero when nothing changes,
   which is what ADR-MC1's ≤ 3 % idle CPU and ≤ 3 W idle power budgets require.
2. **Video does not wait for the UI.** Plane 0 is fed by the decoder; a slow UI frame drops a UI
   update, not a video frame. This is the main structural advantage of hardware planes over
   blitting video into a single framebuffer.
3. **p99 frame time is measurable** because there is a real clock: the interval between
   end-of-frame interrupts.

---

## Options considered

| Option | Description | Why not chosen |
|---|---|---|
| **Single framebuffer, CPU composite** | What `compositor.home` does today (2,158 lines, backbuffer copy to a hardcoded x86 address `0xFD000000`) | Requires blitting video into the UI buffer every frame — CPU cost and DRAM traffic scale with panel resolution; couples video cadence to UI cadence; cannot do zero-copy hardware decode |
| **4K CPU-rendered UI plane** | Render the UI at panel resolution | ≈1.99 GB/s of writes at 60 fps, ≈3.98 GB/s with HVS reads, 33,177,600 bytes per 16.6 ms frame, competing with software H.264 decode for cores and cache |
| **V3D / GPU-composited UI** | Use OpenGL or Vulkan on VideoCore VII | Requires a 3D GPU driver we are not writing for v1; `opengl.home` and `vulkan.home` are frozen; the HVS already does composition, scaling and alpha in fixed function |
| **HVS hardware planes (chosen)** | Video / UI / OSD as separate planes composed and scaled in hardware | Matches the silicon's actual capability, keeps DRAM traffic at ≈15–18 % of theoretical peak, decouples video from UI, and enables zero-copy hardware decode |

---

## Register knowledge and risks

The HVS/HDMI register knowledge for BCM2712 has to be inventoried before #74 and #75 can be
estimated honestly. Sources available to us: public Broadcom/Raspberry Pi documentation, device-tree
compatibles and their bindings, and observed firmware state on a running board. **Code is not a
source** — the architecture is implemented in Home from documented behaviour, never by copying.

| Risk | Impact | Notes |
|---|---|---|
| `videocore7.home` (1,416 lines) register map **unverified** and never compiled | High | Must be validated against documentation and observed hardware before it is trusted at all |
| `rp1_hdmi.home` (1,200 lines) register map **unverified** and never compiled | High | Mode setting and infoframes depend on it |
| HVS display-list format on BCM2712 not fully documented publicly | High | The core mechanism of the whole ADR; may require careful observation of firmware-programmed state |
| Plane count, format and scaler capabilities on VideoCore VII vs VI | Medium | Determines whether plane 2 (OSD) is available or must fold into plane 1 |
| End-of-frame interrupt routing and latency | Medium | Frame pacing and the p99 gate depend on it |
| Zero-copy buffer sharing between the HEVC decoder and the HVS | Medium | If unavailable, the 4K video path gains a copy and ≈1.5 GB/s of traffic |
| Achievable (vs theoretical) DRAM bandwidth on BCM2712 | Medium | All headroom percentages above are against theoretical peak and need a measurement |
| EDID parsing and mode negotiation across real televisions | Medium | Classic source of "works on my monitor" failures |
| HDR10 infoframe passthrough correctness | Low | Stretch goal; failure degrades to SDR |

`compositor.home`'s hardcoded `0xFD000000` is not a risk so much as a known defect: it is an x86
address in code that must run on aarch64, and it is the first thing #74 must remove.

---

## Consequences

### Positive

1. **4K video and 60 fps UI coexist** without a 3D driver, because the HVS does composition,
   scaling, format conversion and alpha in fixed function.
2. **DRAM traffic stays at ≈2.55–3.00 GB/s** in the target configuration rather than ≈5.98 GB/s.
3. **Zero-copy hardware decode is possible** — the CPU never touches video pixels on the HEVC path.
4. **Video and UI cadences are decoupled.** A dropped UI frame is not a dropped video frame.
5. **Subtitles are cheap.** A separate OSD plane means a caption change costs one small plane
   update, not a full-screen UI recomposite.
6. **Bring-up is unblocked** by the mailbox framebuffer fallback (#73), so display work can start
   before the HVS driver is finished.

### Negative

1. **Three unverified register maps** stand between this design and a picture. 2,616 lines of
   never-compiled Pi-specific code is a liability, not an asset, until validated.
2. **UI is capped at 1080p rendering.** On a 4K panel, UI text and vector art are hardware-upscaled
   rather than natively sharp. This is a visible quality trade and it is accepted for v1.
3. **HDR is passthrough only.** SDR panels fed HDR content depend on the television to cope.
4. **No 3D effects.** Anything requiring V3D — shader transitions, blurs, perspective — is out for
   v1, which constrains what ADR-MC4's Craft UI can express.
5. **Hardware-specific.** The plane model is VideoCore-shaped; another SoC means another compositor
   backend.
6. **`compositor.home` needs real work**, not a port: its present path is a copy to a hardcoded x86
   address and must become an HVS display-list programmer.

---

## Revisit trigger

Reopen this decision if:

- **Measured DRAM bandwidth on BCM2712 is far below the theoretical ≈17 GB/s peak**, such that even
  the chosen ≈2.55–3.00 GB/s configuration contends with decode — in which case the OSD plane is
  merged, or video plane formats are reconsidered.
- **The HVS provides fewer usable planes than the design requires**, forcing subtitles back into the
  UI plane and changing the redraw cost model.
- **Zero-copy between the HEVC decoder and the HVS proves impossible**, adding ≈1.5 GB/s to the 4K
  path and requiring the budget to be re-derived.
- **1080p-upscaled UI is judged unacceptable on 4K panels** after being seen on real hardware, at
  which point a selective 4K path for text and vector art (rather than the full plane) should be
  costed against the 33,177,600 bytes/frame figure.
- **A V3D driver becomes available** for reasons outside the TV profile, which would reopen
  GPU-composited UI as an option.

---

## Related decisions

- [ADR-MC1](ADR-MC1-media-center.md) — the 60 fps / 16.6 ms p99 / 3 W budgets this design serves
- [ADR-MC2](ADR-MC2-aarch64-codegen.md) — NEON intrinsics used by the blit path
- [ADR-MC3](ADR-MC3-media-stdlib.md) — where decoded frames come from
- [ADR-MC4](ADR-MC4-ui-stack.md) — Craft draw lists feeding the UI plane
- [ADR 0008](0008-raspberry-pi-focus.md) — Raspberry Pi first strategy

---

## References

- `kernel/src/video/compositor.home` (2,158 lines) — present path, hardcoded `0xFD000000`
- `kernel/src/rpi/videocore7.home` (1,416 lines) — never compiled, register map unverified
- `kernel/src/rpi/rp1_hdmi.home` (1,200 lines) — never compiled, register map unverified
- `kernel/src/video/opengl.home`, `kernel/src/video/vulkan.home` — frozen for v1
- Linux `vc4` driver and bare-metal VideoCore projects — evidence the path exists; **not** a source
  of code
- Issues #73 (mailbox framebuffer fallback), #74, #75, #84 (hardware HEVC driver)

---

## Revision history

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 2026-09-02 | Core Team | Initial decision (from #47) |
