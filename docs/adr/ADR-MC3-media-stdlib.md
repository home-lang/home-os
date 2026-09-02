# ADR MC3: Media Codecs Are Home Standard Library, Not HomeOS Source

**Status**: Accepted
**Date**: 2026-09-02
**Epic**: home-lang/home-os#113
**Issue**: home-lang/home-os#45
**Milestone**: MC0 — Product & decisions
**Decision Makers**: Core Team
**Tags**: `media`, `codecs`, `stdlib`, `language-policy`, `ffi`

---

## Context

A media center is, in the end, a program that turns compressed bytes into pictures and sound. That
means demuxers, decoders, resamplers and image codecs. Today HomeOS has none of them working.

### What the OS tree actually contains

The media code in this repository is decorative:

| File | Lines | Reality |
|---|---|---|
| `kernel/src/media/video_decoder.home` | 138 | `video_decode_h264` / `h265` / `vp8` / `vp9` each **`return 1`** |
| `kernel/src/media/audio_codec.home` | 496 | parses headers, **never decodes a frame** |
| demuxer | — | **does not exist** |
| image decoder | — | **does not exist** |
| resampler | — | **does not exist** |

Four functions that return `1` are not a video decoder. There is no path from here to a playing
film that does not involve tens of thousands of lines of codec work.

### What the compiler repo already contains

The **Home compiler repository** already holds a large, real media stack, written in Zig with Home
FFI bindings (`src/bindings/home.zig` / `home_bindings.zig`):

| Package (`~/Code/Home/lang/packages/`) | Files / lines | Contents |
|---|---|---|
| `video/` | 202 / 95,619 | h264, hevc, av1, vp8/9, mpeg2/4, prores decoders+encoders; mp4, mkv, webm, mpegts, avi, mov demux/mux; hls, dash, rtp; srt/ass/vtt/ttml/pgs, cea608/708; seeking, thumbnails, hdr, metadata |
| `audio/` | 77 / 30,164 | aac, mp3, opus, vorbis decoders; flac, wav, aiff, m4a, ogg…; fft, resampler, eq, limiter, loudness, gapless, crossfade; playlist |
| `image/` | 66 / 42,557 | png, jpeg, webp, avif, heic, gif, bmp, tiff, jxl, svg…; draw, blend, compose, colorspace |

That is 345 files and 168,340 lines of media code that already exists, already has Home bindings,
and is already shipped by the toolchain.

### The policy question

CLAUDE.md forbids Zig **in this repo**, but explicitly blesses Home's Zig-implemented kernel
packages — "Home provides these built-in kernel support modules". The kernel package
(`~/Code/Home/lang/packages/kernel/`) is Zig; we use it every day through Home, and nobody
considers that a violation, because it is the language's own runtime.

The open question this ADR settles is narrow: **do `audio` / `video` / `image` get the same status
as `kernel`?** Are they part of the Home standard library, or are they third-party code we would be
sneaking in through the compiler's back door?

---

## Options considered

| # | Option | What it means | Assessment |
|---|---|---|---|
| **1** | **Treat `{audio,video,image,media}` as Home standard library** | Shipped by the Home toolchain, linked into HomeOS userspace via the existing Home bindings; HomeOS source stays 100 % `.home` | **Chosen.** Same status as `packages/kernel/`, which is already accepted precedent |
| 2 | **Rewrite the codecs in Home first** | Port ~168K lines of codec work into `.home` before any playback | Rejected for v1 — months of work before a single frame plays, and the Home aarch64 backend would be optimising codecs before it can boot a kernel (see ADR-MC2) |
| 3 | **Vendor the Zig sources into this repo** | Copy `packages/{audio,video,image}` into `kernel/` or `apps/` | Rejected outright — puts Zig in the OS tree, breaks the language policy, and forks the code away from its upstream |
| 4 | **Use an external media library (FFmpeg or similar)** | Link a third-party C stack | Rejected — third-party userland, contrary to MASTER_PLAN D1/D4 and to the premise that the whole stack is ours |

Option 2 deserves a fair hearing because it is the philosophically pure answer, and it is where we
intend to end up. The reason it loses *for v1* is sequencing, not principle: rewriting codecs in
Home requires a Home aarch64 backend good enough to compile performance-critical DSP, and per
ADR-MC2 that backend does not yet compile a kernel. Doing codecs first would mean tuning a compiler
against `h264/idct.home` before it can emit a working exception vector. That is the wrong order.

---

## Decision

Treat `packages/{audio,video,image,media}` as **Home standard library**, shipped by the Home
toolchain and linked into HomeOS userspace through the existing Home bindings.
**HomeOS source stays 100 % `.home`; the OS repo never contains Zig.**

The decision is conditional. All four conditions are part of the decision, not aspirations attached
to it.

### Condition 1 — freestanding aarch64 build (#82)

The packages must build **freestanding for aarch64**:

- no libc
- no `std.heap.page_allocator`
- allocator **injected** by the caller
- no threads unless via a Home threading shim

A media stack that silently assumes a hosted environment is not a standard library for an operating
system; it is a Linux program. Until #82 is green, the status granted by this ADR is provisional.

### Condition 2 — truth is measured by conformance corpora, not line counts (#83)

Line counts are evidence that code exists, not that it decodes correctly. The decoder sizes are a
warning worth writing down: **AAC 446 lines, MP3 624 lines, Opus 430 lines** — far below what
conformant decoders usually need. Expect gaps. The corpus tells us which gaps.

CI runs conformance corpora; the corpus result, not the file size, is what allows a codec to be
claimed as supported against the ADR-MC1 codec floor.

### Condition 3 — a port-to-Home track under A7 (self-hosting)

A **port-to-Home** track is opened under compiler milestone **A7 (self-hosting)** so the standard
library eventually becomes Home too. This is **not a v1 requirement**. It is recorded so that
"stdlib is Zig" is understood as a stage, not an endpoint, and so that the eventual port has a home
in the plan rather than being reinvented as a surprise.

### Condition 4 — hardware decode is a kernel driver, not stdlib (#84)

Hardware HEVC decode on VideoCore VII is a **kernel driver written in Home** (#84). It is not part
of the media stdlib and does not inherit this exception. The boundary is clean: the stdlib does
software codec work in userspace; the kernel talks to silicon in Home.

---

## Language policy amendment

CLAUDE.md's "When to Use Other Languages" section is amended to name this exception precisely:
compiler-repo packages only, consumed via Home FFI bindings, never vendored into this repo. The
"extend Home first" philosophy is unchanged — the exception describes where the Home toolchain's
own standard library lives, not a licence to write Zig for HomeOS.

The three properties that make this an exception rather than a loophole:

1. **Location** — the code lives in the compiler repo
   (`~/Code/Home/lang/packages/{audio,video,image,media}`), where the rest of Home's runtime lives.
2. **Interface** — HomeOS touches it only through Home FFI bindings. No HomeOS file imports Zig, and
   no HomeOS file is Zig.
3. **Non-vendoring** — it is never copied into this repository. If it were, the OS tree would
   contain Zig and the policy would be broken in fact regardless of what any document said.

Any one of those three failing means the exception no longer applies.

---

## Consequences

### Positive

1. **Playback becomes reachable in v1.** 168,340 lines of existing media code with existing Home
   bindings is the difference between shipping a media center and shipping a plan for one.
2. **The OS tree stays pure.** Every file in this repository remains `.home` (plus the unavoidable
   boot assembly). The policy is enforceable by a grep, which is the only kind of policy that
   survives.
3. **Consistent with existing precedent.** `packages/kernel/` is already Zig and already blessed;
   this extends an accepted rule rather than inventing one.
4. **Codec quality becomes measurable.** Condition 2 replaces "we have an AAC decoder" with a
   corpus pass rate, which is what the ADR-MC1 codec floor actually needs.
5. **The end state is written down.** Condition 3 keeps self-hosting on the roadmap instead of
   letting Zig stdlib calcify by default.

### Negative

1. **The stdlib is Zig for the foreseeable future.** "HomeOS is 100 % Home" is true of the OS repo
   and not true of the whole running system. We should say so plainly rather than finesse it.
2. **The decoders are probably incomplete.** AAC at 446 lines, MP3 at 624 and Opus at 430 are small
   for conformant decoders. Condition 2 will surface real gaps and those gaps are work.
3. **Freestanding porting is unbudgeted risk.** Code written against a hosted allocator and threads
   often assumes them deeply; #82 may be larger than it looks.
4. **A dependency across repos.** HomeOS playback is now gated on the compiler repo's release
   cadence and on its aarch64 support.
5. **The exception will be cited.** Someone will eventually argue that their favourite library
   belongs in the stdlib too. The three properties above are the test; the answer is usually no.

### Mitigations

- The exception is worded narrowly in CLAUDE.md — four named packages, bindings-only, never
  vendored.
- Condition 2 makes gaps visible early and per-codec, so the ADR-MC1 codec floor can be defended
  with evidence rather than assumed from a file listing.
- Condition 3 gives the eventual Home port a tracked location under A7.

---

## Revisit trigger

Reopen this decision if:

- **#82 concludes the packages cannot be built freestanding for aarch64** without substantial
  rewriting — at which point rewriting in Home (option 2) and porting to freestanding Zig cost
  something closer to the same, and the pure option wins.
- **Conformance corpora (#83) show the codecs on the ADR-MC1 floor failing broadly**, meaning the
  stdlib is not actually saving the work we adopted it to save.
- **Any of the three exception properties breaks** — code vendored into this repo, a non-FFI
  dependency introduced, or the packages moving out of the compiler repo.
- **Compiler milestone A7 (self-hosting) lands** and Home can compile the media stack with
  acceptable performance, at which point the port-to-Home track becomes the plan of record rather
  than a background item.

---

## Related decisions

- [ADR-MC1](ADR-MC1-media-center.md) — the v1 codec floor this stack must satisfy
- [ADR-MC2](ADR-MC2-aarch64-codegen.md) — the aarch64 backend that must exist first
- [ADR-MC5](ADR-MC5-display.md) — where decoded frames go
- [ADR 0001](0001-use-home-language-for-os.md) — use the Home language for the OS

---

## References

- `kernel/src/media/video_decoder.home` (138 lines), `kernel/src/media/audio_codec.home` (496 lines)
- `~/Code/Home/lang/packages/video/` (202 files / 95,619 lines)
- `~/Code/Home/lang/packages/audio/` (77 files / 30,164 lines)
- `~/Code/Home/lang/packages/image/` (66 files / 42,557 lines)
- `src/bindings/home.zig` / `home_bindings.zig` — Home FFI bindings
- CLAUDE.md — "When to Use Other Languages"; MASTER_PLAN A7
- Issues #82 (freestanding aarch64), #83 (conformance corpora), #84 (hardware HEVC driver)

---

## Revision history

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 2026-09-02 | Core Team | Initial decision (from #45) |
