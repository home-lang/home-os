> **Status:** describes target behavior; see [IMPLEMENTATION_STATUS.md](../../IMPLEMENTATION_STATUS.md) for current reality.

# Raspberry Pi 5 Hardware-in-the-Loop Rig

Every Pi gate in the media-centre plan is *"measured on real hardware from
the Mac"*. This page is the rig that makes that sentence true: the parts,
the wiring, the host setup, the EEPROM configuration, and the contracts of
the `scripts/pi/` helpers that every later gate calls.

- **Tracking:** home-lang/home-os#48 · Epic #113 · Milestone MC0
- **Blocks:** #63 (`boot-pi5-serial`), #111 (self-hosted HIL CI)
- **Companion:** [`PI5_E2E.md`](PI5_E2E.md) — the staged test playbook that
  runs on this rig

> **Nothing in this document has been built or measured.** No HomeOS build
> has ever executed on a Raspberry Pi 5 (see
> [IMPLEMENTATION_STATUS.md](../../IMPLEMENTATION_STATUS.md)), the
> `scripts/pi/` helpers described in §6 **do not exist yet**, and
> `.github/workflows/pi-hardware-test.yml` currently probes the runner's own
> Linux rather than a HomeOS image (#56). This page is written first, on
> purpose, so that the helpers are implemented *against a contract* instead
> of accreting one.

---

## 1. Design goals

1. **One command, from the Mac, no hands on the hardware.** The iteration
   loop is `build → copy to TFTP root → power-cycle → read serial → grab a
   frame`. No SD swapping, no cable unplugging, no button pressing.
2. **Observable before it boots.** The Debug Probe is on the Pi 5's
   dedicated debug UART connector, so it sees the *bootloader* talking —
   which is the only diagnostic available when the kernel image is wrong.
3. **Power is a script, not a person.** Every test starts from a cold
   power-on, because half of bring-up bugs are state left over from the
   previous run.
4. **Capture is evidence.** Display and audio gates produce a PNG and a WAV
   that get attached to the run, not a human saying "looks right".
5. **Unattended-capable.** The same scripts run from a terminal today and
   from the self-hosted CI runner in #111 tomorrow, with no changes.

## 2. Bill of Materials

One rig. Quantities are per rig unless noted.

| Item | Purpose | Notes |
|---|---|---|
| **Raspberry Pi 5, 8 GB** | The target | A 4 GB unit is added later as a second device to catch memory-size assumptions |
| **Official 27 W USB-C PSU** | Power | Required, not optional: third-party 5 V/3 A supplies cause the Pi 5 to cap USB/NVMe current and produce failures that look like driver bugs |
| **Raspberry Pi Debug Probe** + 3-pin JST-SH cable | UART console | Connects to the Pi 5's dedicated debug connector — no GPIO wiring, and it works while the bootloader is still running |
| **micro-HDMI → HDMI cable ×2** | TV + capture | One to the TV (HDMI0), one to the capture dongle (HDMI1) |
| **USB UVC HDMI capture dongle** (1080p60 class, with audio) | Screenshot and audio capture | Must be UVC/UAC class-compliant so macOS `avfoundation` sees it with no driver |
| **Smart plug with a local API**, or a USB relay board | Power cycling from the host | Local API only — a cloud-round-trip plug adds seconds of jitter and fails when the WAN does |
| **microSD 32 GB A2** + USB reader | Boot media / fallback | Optional but recommended: an SD mux, so the host can also present the card to itself |
| **USB 3 flash drive** with the test-media corpus | Local playback tests | Reference clips for #88 |
| **Ethernet cable** to the same switch as the Mac | TFTP netboot, NAS tests | The Pi and the Mac must be on one L2 segment; TFTP netboot is not routed |
| **CEC-capable TV**, or a USB-CEC adapter | Remote tests | #98 |
| Optional: NVMe HAT + small NVMe | #70 | Later milestone |
| Optional: Bluetooth remote | #99 | Later milestone |
| Optional: IR receiver + remote | #72 | Later milestone |

### 2.1 Inventory to record

Fill this in when the rig is assembled, and keep it current — half the
value of a rig is knowing exactly which silicon produced a result.

| Field | Value |
|---|---|
| Pi 5 serial number | _(record)_ |
| Pi 5 revision code (`/proc/cpuinfo` under Raspberry Pi OS, or the bootloader banner) | _(record)_ |
| EEPROM bootloader version (`vcgencmd bootloader_version`) | _(record)_ |
| EEPROM `BOOT_ORDER` in use | _(record)_ |
| Debug Probe firmware version | _(record)_ |
| Capture dongle vendor/product ID | _(record)_ |
| TV model + EDID summary | _(record)_ |
| Smart plug model + local endpoint | _(record)_ |
| Host Mac model, macOS version | _(record)_ |
| Photograph of the assembled rig | _(attach to #48)_ |

## 3. Wiring

```
                        ┌──────────────────────────────┐
                        │        Host Mac              │
                        │  screen / ffmpeg / curl      │
                        │  tftpd → /private/tftpboot   │
                        └──┬────────┬────────┬─────────┘
              USB          │        │ USB    │ Ethernet
       ┌─────────────────┐ │        │        │
       │  Debug Probe    │◀┘        │        │
       │  (CMSIS-DAP +   │          │        │
       │   USB-serial)   │          │        │
       └────────┬────────┘          │        │
                │ 3-pin JST-SH      │        │
                │ (UART TX/RX/GND)  │        │
                ▼                   │        ▼
      ┌───────────────────────┐     │   ┌─────────┐
      │      Raspberry Pi 5   │     │   │ Switch  │◀── same L2 segment
      │  ┌ debug UART conn.   │     │   └────┬────┘
      │  ├ micro-HDMI 0 ──────┼─────┼────────┼──────▶ TV (CEC)
      │  ├ micro-HDMI 1 ──────┼──┐  │        │
      │  ├ Ethernet ──────────┼──┼──┼────────┘
      │  ├ USB 3 ─────────────┼──┼──┼──▶ media flash drive
      │  └ USB-C power ───────┼──┼──┼──┐
      └───────────────────────┘  │  │  │
                                 │  │  │
                     ┌───────────▼──┴┐ │   ┌──────────────────┐
                     │ UVC HDMI      │ │   │ 27 W PSU         │
                     │ capture dongle│─┘   └────────┬─────────┘
                     └───────────────┘              │ mains
                                          ┌─────────▼─────────┐
                                          │ smart plug        │◀── local HTTP API
                                          │ (or USB relay)    │      from the Mac
                                          └───────────────────┘
```

Wiring notes:

- **The Debug Probe goes to the Pi 5's dedicated debug connector**, not to
  GPIO 14/15. This matters: the debug connector carries the bootloader's
  own UART, so you see the EEPROM bootloader before any kernel exists. The
  three JST-SH conductors are TX, RX and GND; the Probe is the DTE.
- **The smart plug switches the PSU's mains side**, not the USB-C side. A
  USB-C switch that leaves the PSU energised does not reliably reset the
  Pi 5's PMIC.
- **HDMI0 goes to the TV, HDMI1 to the capture dongle.** The Pi 5's
  firmware prefers HDMI0 for the boot display; keeping the TV there means
  the human view and the boot view agree. Capture on HDMI1 means unplugging
  the TV does not stop CI.
- **Do not power the capture dongle from the Pi.** It goes into the Mac.
  Backfeed through a capture dongle is a real source of half-power boots.
- **Ethernet must reach the Mac without a router hop.** TFTP netboot uses
  broadcast DHCP and a raw TFTP fetch; a routed segment breaks it.

## 4. Host setup (macOS)

Everything below runs on the Mac. Assume `~/Code/Home/os` is this repo.

### 4.1 Serial console (Debug Probe)

The Debug Probe enumerates as a USB CDC device:

```bash
ls /dev/tty.usbmodem*
# e.g. /dev/tty.usbmodem1101

screen /dev/tty.usbmodem* 115200
# exit: Ctrl-A then k, then y
```

115200 8N1, no flow control. If two USB CDC devices are present the glob
matches more than one path — name the exact device in that case, and record
it in `PI_SERIAL_DEV` (§6).

`picocom` is an acceptable alternative and behaves better under
non-interactive capture:

```bash
picocom -b 115200 /dev/tty.usbmodem1101
```

For scripted capture, `pi-serial.sh` (§6.2) uses neither — it reads the
device directly so the output can be timestamped and teed to a file.

### 4.2 TFTP server (macOS built-in)

macOS ships an inetd-style `tftpd` behind a launchd job, serving
`/private/tftpboot`. It is disabled by default.

```bash
# Prepare the root
sudo mkdir -p /private/tftpboot
sudo chmod 755 /private/tftpboot

# Enable and start the built-in service
sudo launchctl enable system/com.apple.tftpd
sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist

# Verify it is listening on UDP/69
sudo lsof -nP -iUDP:69

# Loopback smoke test
echo hello | sudo tee /private/tftpboot/hello.txt >/dev/null
tftp 127.0.0.1 <<'EOF'
get hello.txt /tmp/hello.txt
quit
EOF
cat /tmp/hello.txt      # → hello
```

To stop it again:

```bash
sudo launchctl unload -w /System/Library/LaunchDaemons/tftp.plist
sudo launchctl disable system/com.apple.tftpd
```

Notes:

- The macOS firewall must allow incoming UDP/69. System Settings →
  Network → Firewall → Options, or turn the firewall off for the duration
  of a bring-up session on a trusted LAN.
- The Pi's bootloader fetches from the **root** of the TFTP server, using
  the serial-number directory convention when one exists. `pi-deploy.sh`
  (§6.4) stages both a flat layout and a `<serial>/` layout so either
  behaviour works.
- macOS `tftpd` is read-only by default, which is what we want.

### 4.3 HDMI capture

Confirm the dongle is visible to `avfoundation`:

```bash
ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | sed -n '1,40p'
```

Grab one frame (device indices from the listing above — video 0, audio 0
here):

```bash
ffmpeg -hide_banner -f avfoundation -framerate 30 -video_size 1920x1080 \
       -i "0" -frames:v 1 -y /tmp/pi-frame.png
```

Record five seconds of the HDMI audio return:

```bash
ffmpeg -hide_banner -f avfoundation -i ":0" -t 5 -ac 2 -ar 48000 \
       -y /tmp/pi-audio.wav
```

Notes:

- The first frame after a mode change is frequently black or torn. Capture
  helpers discard a settling period (default 2 s) before grabbing.
- Many UVC dongles renumber their device index when re-enumerated. Pin the
  device by *name* where the dongle reports a stable one, and record it in
  `PI_CAPTURE_VIDEO` / `PI_CAPTURE_AUDIO` (§6).
- macOS will prompt for Camera and Microphone permission the first time.
  Grant it to the terminal application, or scripted capture silently
  produces black frames and silent audio.

### 4.4 Power control

The rig needs a plug with a **local** API. Two shapes are supported by
`pi-power.sh` (§6.1), selected by `PI_POWER_BACKEND`:

- `http` — `PI_POWER_ON_URL`, `PI_POWER_OFF_URL`, and optional
  `PI_POWER_STATE_URL` returning a body containing `on` or `off`. This
  covers Tasmota, Shelly, ESPHome and anything else with a local endpoint.
- `command` — `PI_POWER_ON_CMD`, `PI_POWER_OFF_CMD`, optional
  `PI_POWER_STATE_CMD`. This covers USB relay boards and vendor CLIs.

Credentials, if any, live in the environment or in `~/.config/homeos/pi.env`
(§6.6) — never in the repo.

### 4.5 Host prerequisites

```bash
# Debug Probe serial + capture + power control
brew install picocom ffmpeg curl
# screen and tftp ship with macOS
```

## 5. Pi 5 EEPROM: network-first boot

The point of this section is to delete SD swapping from the loop. Once the
EEPROM tries the network first, an iteration is: build on the Mac, copy
into `/private/tftpboot/`, power-cycle, read serial.

Configure the EEPROM **from a Raspberry Pi OS SD card booted on this same
Pi** (this is the one time the rig needs a Linux userland, and it is a
one-off):

```bash
# On the Pi, under Raspberry Pi OS
sudo rpi-eeprom-update -a          # take the latest stable bootloader first
sudo reboot

vcgencmd bootloader_version        # record this in §2.1
sudo -E rpi-eeprom-config --edit
```

Target configuration:

```ini
[all]
BOOT_UART=1
BOOT_ORDER=0xf12
TFTP_IP=192.168.1.10        # the Mac's address on the rig segment
TFTP_PREFIX=0               # fetch from the TFTP root, not a serial subdir
DISABLE_HDMI=0
POWER_OFF_ON_HALT=0
```

Reading `BOOT_ORDER`: the nibbles are tried **right to left**.

| Nibble | Value | Meaning |
|---|---|---|
| 1st tried | `2` | Network boot (TFTP) |
| 2nd tried | `1` | SD card |
| 3rd | `f` | Restart the sequence (loop forever) |

So `0xf12` is *network first, SD as fallback, then retry* — exactly the
iteration loop we want, with an SD card left in the slot as a rescue path.

Also required, in the boot partition's `config.txt` (staged by
`pi-deploy.sh`):

```ini
uart_2ndstage=1
enable_uart=1
kernel=kernel_2712.img
arm_64bit=1
```

`uart_2ndstage=1` is what makes the *second-stage* bootloader log to the
debug UART. Without it, a failed image load is completely silent and
indistinguishable from a dead board.

`TFTP_PREFIX=0` is a deliberate choice: the default (`1`) makes the
bootloader fetch from a directory named after the Pi's serial number, which
is useful with several Pis and a nuisance with one. `pi-deploy.sh` stages
both layouts regardless, so flipping this later costs nothing.

### 5.1 Rescue paths

Two ways back when a bad EEPROM configuration makes the Pi unbootable:

1. **SD fallback** — `0xf12`'s `1` nibble. Keep a known-good Raspberry Pi
   OS card in the slot at all times.
2. **`rpiboot` recovery** — hold the power button while applying power to
   enter the bootloader's recovery mode, then reflash the EEPROM from a
   recovery SD image written with Raspberry Pi Imager
   (Misc utility images → Bootloader).

## 6. `scripts/pi/` helper contracts

**These scripts do not exist yet.** This section is their specification;
#48 implements them against it. Every helper is a POSIX `sh`/`bash` script,
runs on the Mac, prints machine-greppable status to stdout and human
diagnostics to stderr, and communicates outcome through its exit code.

### 6.0 Common conventions

- **Configuration is environment-first**, then
  `~/.config/homeos/pi.env` (sourced if present), then built-in defaults.
  Nothing is read from the repo, so a rig's addresses never get committed.

  | Variable | Default | Meaning |
  |---|---|---|
  | `PI_SERIAL_DEV` | first match of `/dev/tty.usbmodem*` | Debug Probe device |
  | `PI_SERIAL_BAUD` | `115200` | Console baud |
  | `PI_TFTP_ROOT` | `/private/tftpboot` | TFTP server root |
  | `PI_SERIAL_NUMBER` | unset | Pi serial, for the `<serial>/` TFTP layout |
  | `PI_CAPTURE_VIDEO` | `0` | avfoundation video device index or name |
  | `PI_CAPTURE_AUDIO` | `0` | avfoundation audio device index or name |
  | `PI_CAPTURE_SETTLE` | `2` | Seconds discarded before a grab |
  | `PI_POWER_BACKEND` | `http` | `http` or `command` |
  | `PI_POWER_ON_URL` / `PI_POWER_OFF_URL` / `PI_POWER_STATE_URL` | unset | `http` backend |
  | `PI_POWER_ON_CMD` / `PI_POWER_OFF_CMD` / `PI_POWER_STATE_CMD` | unset | `command` backend |
  | `PI_POWER_SETTLE` | `3` | Seconds held off during a cycle |
  | `PI_ARTIFACT_DIR` | `./artifacts/pi` | Default output directory |

- **Exit codes are shared across all five helpers:**

  | Code | Meaning |
  |---|---|
  | `0` | Success — the contract in the script's own section was met |
  | `1` | Generic failure (an underlying tool failed) |
  | `2` | Usage error (bad arguments) |
  | `3` | Configuration error (required variable unset, backend unknown) |
  | `4` | Device not found (no serial device, no capture device, plug unreachable) |
  | `5` | Timeout — the operation ran to its deadline without meeting its success condition |

- `--help` prints usage to stdout and exits `0`. `-v`/`--verbose` adds
  trace to stderr. No helper is interactive; none prompts for input.
- Every helper is **idempotent where it can be** and leaves no background
  processes behind. A helper interrupted with SIGINT/SIGTERM cleans up its
  children and exits `1`.

### 6.1 `pi-power.sh {on|off|cycle|state}`

Controls mains power to the Pi's PSU.

| Aspect | Contract |
|---|---|
| Arguments | Exactly one of `on`, `off`, `cycle`, `state` |
| Options | `--settle=N` overrides `PI_POWER_SETTLE` for `cycle` |
| Behaviour: `on` | Energise; return once the backend confirms, or after a 10 s deadline |
| Behaviour: `off` | De-energise; same confirmation rule |
| Behaviour: `cycle` | `off`, wait `PI_POWER_SETTLE` seconds (default 3), `on` |
| Behaviour: `state` | Print `on` or `off` to stdout and exit `0`; exit `4` if the state cannot be determined |
| stdout | One line: `power: on`, `power: off`, or `power: cycled` |
| Exit | `0` on confirmed state change; `3` if the backend is unconfigured; `4` if the plug is unreachable; `5` if the state was not confirmed within the deadline |

The 3 s off period is not arbitrary: the Pi 5 PMIC holds rails briefly, and
a shorter gap produces warm restarts that hide reset bugs.

### 6.2 `pi-serial.sh [--timeout=N] [--out=FILE] [--expect=REGEX]`

Captures the Debug Probe console to a file.

| Aspect | Contract |
|---|---|
| Options | `--timeout=N` seconds (default `30`); `--out=FILE` (default `$PI_ARTIFACT_DIR/serial-<UTC timestamp>.log`); `--expect=REGEX` an early-exit success pattern; `--device=PATH`, `--baud=N` overrides; `--append` |
| Behaviour | Opens `PI_SERIAL_DEV` at `PI_SERIAL_BAUD`, reads until the timeout or, with `--expect`, until the regex matches a line |
| stdout | The captured stream, line-buffered, so it can be piped and watched live |
| Output file | The same stream, with each line prefixed `[SSS.mmm] ` — seconds since capture start. The prefix makes boot-time measurement a `grep`, not a stopwatch |
| Exit | `0` if `--expect` matched, or if no `--expect` was given and the timeout elapsed with **at least one byte** received; `4` if the device does not exist or cannot be opened; `5` if `--expect` was given and did not match before the timeout; `1` if zero bytes were received |

"Zero bytes is a failure" is deliberate: a silent console is the single
most common rig fault, and it must not be reported as a pass.

### 6.3 `pi-capture.sh [--frame=FILE] [--audio=FILE] [--seconds=N]`

Grabs evidence from the HDMI capture dongle.

| Aspect | Contract |
|---|---|
| Options | `--frame=FILE` PNG path (default `$PI_ARTIFACT_DIR/frame-<timestamp>.png`); `--audio=FILE` WAV path (default `$PI_ARTIFACT_DIR/audio-<timestamp>.wav`); `--seconds=N` audio duration (default `5`); `--settle=N` overrides `PI_CAPTURE_SETTLE`; `--no-frame`, `--no-audio` |
| Behaviour | Discards `--settle` seconds, then writes exactly one PNG at the dongle's native resolution and, unless suppressed, `N` seconds of 48 kHz stereo WAV |
| stdout | One line per artefact: `frame: <path> <width>x<height>` and `audio: <path> <seconds>s <samplerate>Hz` |
| Exit | `0` when every requested artefact was written and is non-empty; `4` if the capture device is absent or macOS permission was denied; `5` if `ffmpeg` produced nothing before its deadline; `1` otherwise |

The helper does **not** judge the content — "is the frame black?" and "does
the audio contain a 1 kHz tone?" are gate-level questions and live in the
gate scripts (#73, #79), not here. A rig helper that decides what counts as
correct is a rig helper that can lie.

### 6.4 `pi-deploy.sh <boot-dir> [--root=DIR] [--serial=NNNNNNNN] [--clean]`

Stages a built boot directory into the TFTP root.

| Aspect | Contract |
|---|---|
| Arguments | `<boot-dir>` — a directory containing at minimum `kernel_2712.img` and `config.txt`, plus any DTBs and overlays |
| Options | `--root=DIR` overrides `PI_TFTP_ROOT`; `--serial=NNNNNNNN` overrides `PI_SERIAL_NUMBER`; `--clean` removes previously staged files before copying |
| Behaviour | Validates that `<boot-dir>` exists and contains `config.txt` and the kernel named by its `kernel=` line; copies the tree to **both** `$PI_TFTP_ROOT/` and, when a serial is known, `$PI_TFTP_ROOT/<serial>/`, so the boot works with `TFTP_PREFIX` either `0` or `1`; sets modes to `644`/`755`; `sync`s |
| stdout | One line per staged file: `staged: <relative path> <bytes> <sha256 prefix>`, then `deployed: <n> files to <root>` |
| Exit | `0` when every file is present at the destination with a matching size and digest; `2` if `<boot-dir>` is missing or unreadable; `3` if the TFTP root does not exist or is not writable; `1` on a copy or verification failure |

Verifying the digest after the copy matters more than it looks: a
half-written `kernel_2712.img` in the TFTP root presents on the wire as a
kernel that hangs, and costs an afternoon.

### 6.5 `pi-cycle-and-capture.sh` — the acceptance script

This is the script #48's acceptance criterion names. It composes the other
four into the one command a human or a CI runner types.

```bash
scripts/pi/pi-cycle-and-capture.sh \
    --boot-dir=build/rpi5/boot \
    --timeout=30 \
    --expect='HomeOS' \
    --out-dir=artifacts/pi/$(date -u +%Y%m%dT%H%M%SZ)
```

| Aspect | Contract |
|---|---|
| Options | `--boot-dir=DIR` (optional — skip staging when omitted); `--timeout=N` serial capture seconds (default `30`); `--expect=REGEX` passed to `pi-serial.sh`; `--out-dir=DIR` artefact directory (default `$PI_ARTIFACT_DIR/<UTC timestamp>`); `--no-capture`; `--settle=N` |
| Sequence | 1. `pi-deploy.sh <boot-dir>` when given · 2. `pi-power.sh off` · 3. start `pi-serial.sh` capturing in the background · 4. `pi-power.sh on` · 5. wait for the serial capture to satisfy `--expect` or reach `--timeout` · 6. `pi-capture.sh --frame` · 7. write `summary.txt` |
| Ordering guarantee | The serial capture is **listening before** power is applied. Otherwise the bootloader banner — the most informative 200 ms of the whole boot — is lost every time |
| Output directory | `serial.log`, `frame.png`, `summary.txt`, and `audio.wav` when `--audio` was requested |
| `summary.txt` | Timestamp, git describe of the repo, staged file digests, serial byte count, whether `--expect` matched and at what timestamp, capture resolution, and the final exit code |
| stdout | A short human summary ending in `result: pass` or `result: fail <reason>` |
| Exit | `0` only when staging succeeded (if requested), power cycled, serial produced output satisfying `--expect` (or produced any output when no `--expect` was given), and a non-empty frame was captured. Otherwise the exit code of the first failing step |

### 6.6 `~/.config/homeos/pi.env` (example)

Not in the repo. Sourced by every helper if present, overridden by the
environment.

```sh
PI_SERIAL_DEV=/dev/tty.usbmodem1101
PI_SERIAL_NUMBER=10000000abcdef01
PI_TFTP_ROOT=/private/tftpboot
PI_CAPTURE_VIDEO="USB Capture HDMI"
PI_CAPTURE_AUDIO="USB Capture HDMI"
PI_POWER_BACKEND=http
PI_POWER_ON_URL="http://192.168.1.44/cm?cmnd=Power%20On"
PI_POWER_OFF_URL="http://192.168.1.44/cm?cmnd=Power%20Off"
PI_POWER_STATE_URL="http://192.168.1.44/cm?cmnd=Power"
PI_ARTIFACT_DIR="$HOME/Code/Home/os/artifacts/pi"
```

## 7. Bringing the rig up for the first time

The rig's own smoke test is the **assembly-only UART banner** from #57 —
the first thing that ever runs on this Pi. Assembly is permitted for boot
code (see `CLAUDE.md`); nothing else about this test involves the Home
kernel, which is the point: it isolates *rig faults* from *kernel faults*.

1. Assemble the rig per §3 and photograph it for #48.
2. Complete host setup (§4) and verify each piece independently: serial
   shows the bootloader on a cold boot, `tftp 127.0.0.1` round-trips,
   `ffmpeg` lists the dongle, `pi-power.sh state` answers.
3. Configure the EEPROM (§5) and record §2.1.
4. Build the #57 banner image and run:

   ```bash
   scripts/pi/pi-cycle-and-capture.sh --boot-dir=build/rpi5/boot \
       --timeout=30 --expect='HomeOS'
   ```

5. The rig is accepted when that command exits `0` and `serial.log`
   contains the bootloader's own output *followed by* the banner. Attach
   `serial.log` and `frame.png` to #48.

Until step 5 has actually happened, this document describes an intended
rig, and every gate that depends on it (#63, #111, and everything in
[`PI5_E2E.md`](PI5_E2E.md) beyond Stage 0) remains unreachable.
