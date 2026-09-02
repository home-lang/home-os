> **Status:** describes target behavior; see [IMPLEMENTATION_STATUS.md](../../IMPLEMENTATION_STATUS.md) for current reality.

# Raspberry Pi 5 End-to-End Test Playbook

The four Pi 5 pages (`docs/INSTALL_RPI5.md`, `docs/RASPBERRY_PI_5.md`,
`docs/PI5_HARDWARE_MATRIX.md`, `docs/QUICK_START_RPI5.md`) describe target
behaviour under a banner. **This page is the procedure.** Each stage names
the exact command, the output you should see on serial or in a capture, the
criterion that makes it a pass, and the issue that has to land before the
stage is reachable at all.

- **Tracking:** home-lang/home-os#112 · Epic #113 · Milestone MC9
- **Rig:** [`PI5_RIG.md`](PI5_RIG.md) (#48) — build this first; every stage
  from 1 onward runs on it
- **Updated:** in the PR that turns each stage's gate green, never in advance

---

## Reachability at a glance

> **Only Stage 0 has been run.** Everything from Stage 1 onward is
> **NOT YET REACHABLE**: no Home code has ever executed on a Raspberry Pi 5,
> `./scripts/build.sh rpi5` exits 1 by design because there is no aarch64
> kernel entry point, the compiler's kernel codegen is x86-only, and
> `arch/arm64/arm64.home` MMIO is a no-op. See
> [IMPLEMENTATION_STATUS.md](../../IMPLEMENTATION_STATUS.md).
>
> The stages below are written now so the procedure exists before the
> hardware does. **Do not read a stage as a report.** A stage becomes a
> measurement only when its gate goes green and this page is edited in the
> same PR — at which point its NOT YET REACHABLE marker is deleted and
> replaced with the measured output.

| Stage | What it proves | Status | Unblocked by |
|---|---|---|---|
| **0 — Host setup** | The Mac can build, talk to the Pi, serve TFTP, capture HDMI, cycle power | **Reachable today** (build half); rig half needs the BOM | — / #48 |
| **1 — Rig smoke** | The rig works, end to end, with assembly-only boot code | **NOT YET REACHABLE** | #48 + #57 |
| **2 — Home kernel on serial** | The Home kernel boots on real silicon to an interactive shell | **NOT YET REACHABLE** | #51, #52, #53, #54, #57–#61 → gate #63 |
| **3 — Storage & network** | SD, PCIe/RP1, USB and Ethernet work on hardware | **NOT YET REACHABLE** | #66, #67, #68, #69 |
| **4 — Display & audio** | First pixel, HVS planes, HDMI audio | **NOT YET REACHABLE** | #73, #74, #79 |
| **5 — Media** | Real playback from USB and NAS, within budget, over hours | **NOT YET REACHABLE** | #82–#88, #104 |
| **6 — Product** | A flashed image a stranger can use: onboarding, remote, OTA, recovery | **NOT YET REACHABLE** | #92–#100, #108, #109, #110 |

---

## Stage 0 — Host setup (macOS)

**Status: the build half is reachable today.** The rig half (serial, TFTP,
capture, power) is reachable as soon as the #48 BOM is assembled.

### 0.1 Toolchain

The Home compiler is the long pole and the thing most often set up wrong.
Three corrections to the older instructions floating around the issues:

- **The compiler repo on this machine is `~/Code/Home/lang`**, *not*
  `~/Code/home`. `CLAUDE.md` and several issues still say `~/Code/home`;
  that path does not exist here. Export `HOME_REPO` accordingly — the build
  script defaults to `<repo-root>/../home`, which is also wrong for this
  layout, so the export is mandatory rather than optional.
- **Zig is pinned at `0.17.0-dev.1441+d5181a9c9`**, matching
  `ZIG_VERSION` in `.github/workflows/ci.yml`. A different Zig will fail to
  build the compiler in ways that look like compiler bugs. (`scripts/zig-version.txt`,
  referenced by #112, does not exist in this repo yet; `ci.yml` is the pin
  of record until it does. Note that `.github/workflows/pi-hardware-test.yml`
  pins a *different*, stale version — that is one of the defects #56 fixes.)
- **The release build target is `release-safe`**, producing
  `zig-out/bin/home-release-safe` (with `zig-out/bin/home` as a symlink to
  it). `-Doptimize=ReleaseSafe` is the older invocation.

```bash
# Install the pinned Zig with the user's own package manager
pantry install ziglang.org@0.17.0-dev.1441_d5181a9c9
zig version            # → 0.17.0-dev.1441+d5181a9c9

# QEMU, for the x86-64 and aarch64 pre-hardware gates
brew install qemu

# Build the Home compiler
export HOME_REPO=~/Code/Home/lang
cd "$HOME_REPO"
zig build release-safe
ls -l zig-out/bin/home-release-safe
export HOME_COMPILER="$HOME_REPO/zig-out/bin/home-release-safe"
```

**Expected output:** `zig build release-safe` completes without error and
leaves an executable at `zig-out/bin/home-release-safe`;
`"$HOME_COMPILER" --version` prints a version and exits `0`.

**Pass criterion:** from this repo,

```bash
cd ~/Code/Home/os
./scripts/typecheck.sh          # parse/typecheck ratchet
./scripts/boot-gate.sh          # x86-64 QEMU boot gate
```

both exit `0`. That is the "the host can build HomeOS" bar, and it is the
only thing in this playbook that is currently measured — see the parse
rate and boot status on
[IMPLEMENTATION_STATUS.md](../../IMPLEMENTATION_STATUS.md).

### 0.2 Rig host tools

Full detail in [`PI5_RIG.md`](PI5_RIG.md) §4; the short form:

```bash
brew install picocom ffmpeg curl

# Debug Probe serial console
ls /dev/tty.usbmodem*
screen /dev/tty.usbmodem* 115200          # Ctrl-A k y to exit

# macOS built-in TFTP server, serving /private/tftpboot
sudo mkdir -p /private/tftpboot
sudo launchctl enable system/com.apple.tftpd
sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist
sudo lsof -nP -iUDP:69                    # confirm it is listening

# HDMI capture dongle
ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | sed -n '1,40p'
ffmpeg -hide_banner -f avfoundation -framerate 30 -video_size 1920x1080 \
       -i "0" -frames:v 1 -y /tmp/pi-frame.png

# Power control
scripts/pi/pi-power.sh state              # → power: on|off   (script per #48)
```

**Expected output:** the serial device exists; `lsof` shows a process bound
to UDP/69; `ffmpeg` lists the capture dongle by name and writes a non-empty
PNG; `pi-power.sh state` prints `power: on` or `power: off`.

**Pass criterion:** all four subsystems answer independently, before any Pi
is involved. Debugging a boot failure through an untested rig is the single
biggest time sink in hardware bring-up.

**Unblocked by:** the build half, nothing. The rig half, **#48** (BOM
assembled, `scripts/pi/` helpers implemented — they do not exist yet).

### 0.3 EEPROM: network-first boot

Per [`PI5_RIG.md`](PI5_RIG.md) §5, on a Raspberry Pi OS card, once:

```bash
sudo rpi-eeprom-update -a && sudo reboot
vcgencmd bootloader_version
sudo -E rpi-eeprom-config --edit
#   BOOT_UART=1
#   BOOT_ORDER=0xf12      # network first, SD fallback, then retry
#   TFTP_IP=<the Mac's address on the rig segment>
#   TFTP_PREFIX=0
```

**Pass criterion:** with no SD card able to boot and nothing staged in
`/private/tftpboot`, a power cycle produces bootloader chatter on serial
that names the TFTP server and reports a failed fetch. A *failing* netboot
that is visible on serial is the correct Stage 0 result — it proves the
EEPROM, the network path and the console all work.

---

## Stage 1 — Rig smoke: the assembly UART banner

> ### 🚧 NOT YET REACHABLE — blocked by #48 (rig + helper scripts) and #57 (Pi 5 `boot.s` entry)
> No assembly banner has been built or run. `./scripts/build.sh rpi5`
> currently exits 1 with "The rpi5 kernel build has no entry point yet."

**What it proves:** the rig — power, TFTP, EEPROM, serial — carries a byte
from the Mac to the Pi and back, with the smallest possible thing running
on the target. Assembly is permitted for boot code (`CLAUDE.md`); this is
the one and only place it is the *whole* payload.

```bash
cd ~/Code/Home/os
export HOME_REPO=~/Code/Home/lang

./scripts/build.sh rpi5 --profile=smoke
scripts/pi/pi-cycle-and-capture.sh \
    --boot-dir=build/rpi5/boot \
    --timeout=30 \
    --expect='HomeOS' \
    --out-dir=artifacts/pi/stage1
```

**Expected serial output** (shape, not a transcript — the exact bootloader
text depends on the EEPROM version):

```
[000.031] RPi: BOOTLOADER release VERSION:<...> DATE: <...>
[000.104] net_boot: server <mac-ip> client <pi-ip>
[000.512] Loading kernel_2712.img from <mac-ip>
[000.918] HomeOS: Raspberry Pi 5 (BCM2712) — assembly UART banner
[000.919] EL: 1   MIDR: 0x414fd0b1
```

**Expected capture:** nothing meaningful. The banner writes to UART only;
`frame.png` at this stage is the firmware's rainbow splash or a black
frame, and either is acceptable.

**Pass criterion:** `pi-cycle-and-capture.sh` exits `0`, and `serial.log`
contains the bootloader's own output *followed by* the banner line. Both
halves matter: the bootloader line proves the EEPROM path, the banner line
proves our image was fetched and executed.

**Unblocked by:** #48 (rig), #57 (BCM2712 entry, EL2→EL1, corrected
`config.txt`), #54 (a real `rpi5` build pipeline).

---

## Stage 2 — The Home kernel on serial

> ### 🚧 NOT YET REACHABLE — blocked by #51, #52, #53, #54, #58, #59, #60, #61; gate #63
> The Home compiler's kernel codegen is x86-64 only. There is no aarch64
> lowering, no `--target=aarch64-freestanding`, and `arch/arm64/arm64.home`
> MMIO is a no-op stub. This stage is the epic's critical path and its
> longest pole.

**What it proves:** the same Home kernel that reaches 55/55 init milestones
under x86-64 QEMU reaches its milestones on real ARM silicon, and gives you
an interactive shell over the Debug Probe.

```bash
cd ~/Code/Home/os
export HOME_REPO=~/Code/Home/lang

# ARM regression wall first — never take a compiler change to hardware
# that has not passed QEMU (#55)
./scripts/mvk-compiles.sh --target=aarch64
./scripts/qemu-boot-test.sh --target=aarch64        # -M virt, PL011 serial

# Then hardware
./scripts/build.sh rpi5 --profile=serial
scripts/pi/pi-cycle-and-capture.sh \
    --boot-dir=build/rpi5/boot \
    --timeout=60 \
    --expect='home-os> ' \
    --out-dir=artifacts/pi/stage2

# Or, once the gate script exists:
./scripts/boot-pi5-serial.sh
```

**Expected serial output:**

```
[000.918] HomeOS booting on BCM2712 (4x Cortex-A76)
[000.931] dtb: memory 8 GiB @ 0x0, uart @ 0x107d001000, gic @ 0x107fff9000
[000.944] mmu: 4 KiB granule, 40-bit PA, TTBR1 up
[000.961] gic-600: 256 SPIs, distributor up
[000.972] timer: generic, 54 MHz
...
[002.480] milestone 55/55: init complete
[002.481] home-os> _
```

Then, interactively over `screen`:

```
home-os> help
home-os> uname
home-os> mem
home-os> ps
```

**Pass criterion:** every milestone in `scripts/boot-milestones.txt` that
applies to ARM is printed in order, the shell prompt appears, and at least
`help`, `uname` and `mem` respond. Boot-to-prompt time is recorded from the
`pi-serial.sh` timestamps against the 8 s budget from epic #113 (that budget
is boot-to-*home-screen*, so Stage 2's number is a floor, not the gate).

**Unblocked by:** #51 (aarch64 lowering), #52 (`--target=aarch64-freestanding`),
#53 (volatile MMIO + barriers in the language), #54 (build pipeline),
#58 (PL011), #59 (DTB parsing), #60 (real MMIO), #61 (MMU/GIC/timer).
**Gate:** #63 `boot-pi5-serial`.

---

## Stage 3 — Storage and network

> ### 🚧 NOT YET REACHABLE — blocked by #66 (SDHCI), #67 (PCIe + RP1), #68 (USB/xHCI), #69 (RP1 Ethernet)
> Requires Stage 2. The ext2 round-trip currently measured is x86-64 QEMU
> against an ATA disk; none of it has touched a Pi.

**What it proves:** the Pi's own peripherals — not QEMU's — read, write and
talk to the LAN.

```bash
# From the serial shell (Stage 2's prompt)
home-os> sd info
home-os> sd write-test
home-os> sd read-test
home-os> lspci
home-os> usb
home-os> dhcp
home-os> ping 192.168.1.10
```

**Expected serial output:**

```
home-os> sd info
sdhci: BCM2712 SD, 32.0 GiB, ADMA2, 50 MHz, bus width 4
home-os> sd write-test
sd: wrote 512 B to LBA 0x100000, verified
home-os> lspci
00:00.0 PCIe bridge: Broadcom BCM2712
01:00.0 System peripheral: RPi RP1
home-os> usb
xhci: 4 ports, 1 device: 0781:5583 mass storage (bulk-only)
home-os> dhcp
gem: link up, 1000 Mb/s, full duplex
dhcp: offer 192.168.1.57/24 gw 192.168.1.1 lease 86400s
home-os> ping 192.168.1.10
64 bytes from 192.168.1.10: seq=1 time=0.42 ms
```

**Pass criterion:** the SD round-trip verifies, RP1 enumerates over PCIe at
`0x1F_0000_0000`, the USB media drive enumerates, DHCP gets a real lease on
the rig LAN, and ping to the Mac replies. Gates `storage-roundtrip-pi5`
(#66) and `net-echo` (#69).

**Unblocked by:** #66, #67, #68, #69.

---

## Stage 4 — Display and audio

> ### 🚧 NOT YET REACHABLE — blocked by #73 (mailbox framebuffer), #74 (HVS + HDMI), #79 (HDMI audio)
> Requires Stage 2. `video/compositor.home` still hardcodes an x86 MMIO
> address (#75) and there is no HVS driver.

**What it proves:** pixels the capture dongle can see, and a tone a
spectrum analysis can find.

```bash
# First pixel and the console on HDMI
home-os> fb info
home-os> fb test-pattern
scripts/pi/pi-capture.sh --frame=artifacts/pi/stage4/pattern.png --no-audio

# HVS planes
home-os> hvs planes
home-os> hvs test-pattern

# Audio
home-os> tone 1000 5
scripts/pi/pi-capture.sh --no-frame --audio=artifacts/pi/stage4/tone.wav --seconds=5

# Analysis on the host: the peak must be at 1 kHz
ffmpeg -hide_banner -i artifacts/pi/stage4/tone.wav \
       -lavfi "showspectrumpic=s=1024x512" -y artifacts/pi/stage4/tone-fft.png
```

**Expected serial output:**

```
home-os> fb info
mailbox: fb 1920x1080 @32bpp, pitch 7680, base 0x3e000000
edid: LG OLED55C4 — 2160p60, 2160p50, 1080p60, 1080p50, 720p60
home-os> tone 1000 5
hdmi-audio: 48000 Hz, 2ch, S16, N=6144 CTS=148500
```

**Expected capture:** `pattern.png` is a non-black frame at the mode's
resolution containing the test pattern; `tone.wav` is five seconds of
non-silent 48 kHz stereo whose dominant frequency is 1 kHz ± 1 Hz.

**Pass criterion:** gates `fb-pi5-first-pixel` (#73), HVS 60 fps with no
tearing (#74), and `hdmi-audio-tone` (#79). Note that `pi-capture.sh` does
**not** judge these — the gate scripts do the FFT and the pixel comparison
([`PI5_RIG.md`](PI5_RIG.md) §6.3).

**Unblocked by:** #73, #74, #75, #79.

---

## Stage 5 — Media

> ### 🚧 NOT YET REACHABLE — blocked by #82 (freestanding aarch64 codec build), #83 (conformance ratchet), #84 (HEVC hardware decoder), #85 (pipeline), #88 (gates)
> Requires Stages 3 and 4. The decoders in *this* repo are stubs; the real
> codecs live in the compiler repo's stdlib and have never been built
> freestanding or for ARM.

**What it proves:** real files, from real sources, decoded within budget,
for hours.

```bash
# Local, from the USB corpus
home-os> play /usb/corpus/h264-1080p-60.mkv
home-os> stats

# From the NAS
home-os> mount smb://nas/media /nas
home-os> play /nas/corpus/hevc-2160p-main10.mkv
home-os> stats

# Gates and soak
./scripts/pi/pi-cycle-and-capture.sh --boot-dir=build/rpi5/boot \
    --timeout=120 --expect='playback: ok' --out-dir=artifacts/pi/stage5
./scripts/gates/playback-1080p-h264.sh
./scripts/gates/playback-4k-hevc.sh
./scripts/gates/soak-4h.sh
```

**Expected serial output:**

```
home-os> play /usb/corpus/h264-1080p-60.mkv
demux: matroska, video h264 1920x1080@59.94, audio aac 5.1 48kHz
decode: software (NEON), 4 threads
home-os> stats
frames 21540  dropped 0  cpu 54%  rss 96 MiB  a/v drift -1.2 ms
```

**Pass criterion:** `playback-1080p-h264` — software decode at ≤ 60 % CPU,
zero dropped frames. `playback-4k-hevc` — hardware decode, zero drops.
`soak-4h` — four hours with no leak against the RSS ceiling, no drift, no
crash. All three from epic #113's budget table.

**Unblocked by:** #82, #83, #84, #85, #86, #87, #88, #104 (NAS sources).

---

## Stage 6 — Product

> ### 🚧 NOT YET REACHABLE — blocked by #92 (TV shell), #95 (settings/onboarding), #98 (CEC), #100 (phone remote), #108 (image), #109 (OTA), #110 (recovery)
> Requires Stage 5. There is no Craft renderer and no TV shell.

**What it proves:** the thing a person receives — flashed from an image,
set up with a remote, updated over the air, and recoverable when that
fails.

```bash
# Build and flash a real image (no TFTP this time)
./scripts/build.sh pi-image --target=rpi5 --profile=tv
diskutil list                                  # identify the card
sudo diskutil unmountDisk /dev/diskN
sudo dd if=build/rpi5/home-os-rpi5-tv.img of=/dev/rdiskN bs=4m status=progress
sync

# Boot from the card and drive it with the TV's own remote
scripts/pi/pi-power.sh cycle
scripts/pi/pi-serial.sh --timeout=60 --expect='shell: home screen'
scripts/pi/pi-capture.sh --frame=artifacts/pi/stage6/home.png --no-audio

# OTA round-trip
home-os> ota check
home-os> ota install
home-os> ota status

# Recovery
home-os> recovery enter
```

**Expected serial output:**

```
[007.412] shell: home screen ready (boot 7.41 s)
[013.900] cec: TV "LG OLED55C4" logical addr 0, One Touch Play sent
[021.550] cec: user-control-pressed 0x02 (down) → focus row 2
[061.200] ota: manifest v1.0.3 signed OK, slot B written, tryboot armed
[092.700] ota: health check passed, slot B committed
```

**Expected capture:** `home.png` is the home screen from
[`../design/hig-tv.md`](../design/hig-tv.md) §9.1, at the TV's native mode,
with exactly one focused card at 1.08× (§5).

**Pass criterion:** `boot-to-home-screen` ≤ 8 s, `tv-ui-60fps` and
`input-latency` ≤ 50 ms (#101); onboarding completable with the TV remote
alone; OTA installs and commits, and a deliberately-failed health check
rolls back; recovery mode reachable and able to reflash. Gates #101, #109,
#111.

**Unblocked by:** #92–#101, #108, #109, #110.

---

## Troubleshooting

Symptoms in the order you will actually hit them.

| Symptom | Likely cause | Check | Fix |
|---|---|---|---|
| **No bootloader output on serial at all** | `BOOT_UART=0`, wrong device, wrong baud, Probe on GPIO instead of the debug connector | `ls /dev/tty.usbmodem*`; try 115200 explicitly; confirm the JST-SH cable is on the **debug** connector | Set `BOOT_UART=1` in the EEPROM config; re-seat the 3-pin cable; check TX/RX are not swapped |
| **Bootloader talks, but nothing after "Loading kernel"** | `uart_2ndstage=0`, so the second-stage loader is silent | `grep uart_2ndstage <boot-dir>/config.txt` | Add `uart_2ndstage=1` and re-deploy |
| **Rainbow splash then a blank screen** | Firmware started, our image never ran or hung before any output | Serial is authoritative here, not the TV | Verify the `kernel=` name matches the staged file; check the load address and entry in `linker-rpi5.ld` |
| **Image not loaded / TFTP timeout** | Wrong `kernel=` name, wrong `TFTP_IP`, `TFTP_PREFIX` mismatch, macOS firewall, DTB missing | `sudo lsof -nP -iUDP:69`; `tcpdump -i en0 udp port 69`; `ls -l /private/tftpboot` | Re-run `pi-deploy.sh` (it stages both the flat and `<serial>/` layouts); allow UDP/69 through the firewall; confirm the Pi and Mac are on one L2 segment |
| **Boots from SD when you wanted TFTP** | `BOOT_ORDER` nibbles read right-to-left and yours starts with `1` | `vcgencmd bootloader_config` | Set `BOOT_ORDER=0xf12` |
| **Exception immediately after the banner** | EL mismatch — entered at EL2 and never dropped to EL1, or the vector table is not installed | The banner from #57 prints `EL:`; compare with the expected `1` | Fix the EL2→EL1 drop in `boot.s` (#57); install vectors before the first `svc` |
| **Kernel hangs after the DTB line** | DTB not passed in `x0`, or the parser read a different address | Print `x0` in the banner | Firmware passes the DTB in `x0`; do not clobber it before `kernel_main` (#59) |
| **No network at all** | No link, PHY not brought up, RP1 not enumerated | Switch/Pi link LEDs; `lspci` for RP1 | RP1 comes up over PCIe first (#67); the GEM MAC and PHY after (#69) |
| **DHCP silent but link is up** | RX path not delivering (the S3 stub) | `dhcp` prints TX but never RX | #69 closes netdev RX |
| **HDMI: no signal** | EDID not read, mode not set, cable on the wrong micro-HDMI port | `fb info` should print an EDID summary; try HDMI0 | Force a known mode in `config.txt` while bringing up EDID (#74); HDMI0 is the firmware's preferred output |
| **HDMI: signal, but the capture is black** | Capture dongle grabbed before the mode settled; macOS Camera permission denied | Raise `PI_CAPTURE_SETTLE`; check System Settings → Privacy → Camera | Grant the terminal Camera and Microphone access; discard ≥ 2 s before grabbing |
| **Audio silent while the driver says it is playing** | N/CTS values wrong for the pixel clock, or the audio infoframe was never sent | Serial prints `N=` and `CTS=`; compare against the HDMI spec for the active mode | Recompute N/CTS per mode (#79); send the audio infoframe on every mode change |
| **Capture dongle vanishes or renumbers between runs** | UVC index instability after re-enumeration | `ffmpeg -f avfoundation -list_devices true -i ""` before and after | Pin `PI_CAPTURE_VIDEO`/`PI_CAPTURE_AUDIO` by device **name**, not index |
| **Pi does not come back after `pi-power.sh cycle`** | Off period too short; PMIC rails still held | `--settle=5` | Raise `PI_POWER_SETTLE`; switch mains, not the USB-C side |
| **Compiler build fails in ways that look like compiler bugs** | Wrong Zig | `zig version` | Must be `0.17.0-dev.1441+d5181a9c9`: `pantry install ziglang.org@0.17.0-dev.1441_d5181a9c9` |
| **`build.sh` cannot find the Home compiler** | The default `HOME_REPO` (`<repo-root>/../home`) does not match this machine | `echo $HOME_REPO` | `export HOME_REPO=~/Code/Home/lang` |

---

## Doc realignment (part of #112)

Once Stages 1–2 are measured, the four Pi 5 pages shrink to pointers:

| Page | Becomes |
|---|---|
| `docs/QUICK_START_RPI5.md` | A pointer to Stage 0–1 here, plus the BOM link |
| `docs/INSTALL_RPI5.md` | End-user install of a released image; keeps its banner until Stage 6 is measured |
| `docs/RASPBERRY_PI_5.md` | Architecture and driver notes only; the procedure lives here |
| `docs/PI5_HARDWARE_MATRIX.md` | A status table generated against the measured stages, not a claim list |

The ASPIRATION banner stays on every page where measurement is missing —
which, as of this writing, is all of them, and every stage of this playbook
past Stage 0.
