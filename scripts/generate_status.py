#!/usr/bin/env python3
"""Generate IMPLEMENTATION_STATUS.md from repository truth.

MASTER_PLAN §13.2 asks for a status page that *cannot* drift. That rules out
restating facts in this file: nothing here is a hardcoded claim about the
project. Every number is measured when the script runs —

  parse rate      by running the Home compiler's parser over every kernel file
  boot status     by building the MVK and booting it in QEMU
  stub register   by parsing MASTER_PLAN §7 and counting markers in source
  phase gates     from the two results above, plus the gate scripts present

If a fact cannot be measured in this run — no compiler, no QEMU — the page
says "not verified in this run" rather than repeating a previous answer.

Usage: scripts/generate_status.py [--no-boot] [--check]
  --no-boot  skip building and booting the MVK (fast; boot status unverified)
  --check    exit 1 if the generated page differs from the committed one
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLAN = os.path.join(REPO, "docs", "MASTER_PLAN.md")
OUT = os.path.join(REPO, "IMPLEMENTATION_STATUS.md")

SOURCE_DIRS = ["kernel", "apps", "libs", "installer"]


def find_compiler():
    for c in [
        os.environ.get("HOME_COMPILER", ""),
        os.path.join(REPO, "..", "home", "zig-out", "bin", "home"),
        os.path.join(REPO, "..", "lang", "zig-out", "bin", "home"),
    ]:
        if c and os.access(c, os.X_OK):
            return os.path.normpath(c)
    return None


def compiler_revision(path):
    """Best-effort: the git revision of the compiler checkout we are using."""
    repo = os.path.dirname(os.path.dirname(os.path.dirname(path)))
    try:
        r = subprocess.run(["git", "-C", repo, "rev-parse", "--short", "HEAD"],
                           capture_output=True, text=True, timeout=10)
        if r.returncode == 0:
            return r.stdout.strip()
    except Exception:
        pass
    return None


def home_files(root):
    out = []
    for d, _, files in os.walk(os.path.join(REPO, root)):
        for f in files:
            if f.endswith(".home"):
                out.append(os.path.join(d, f))
    return sorted(out)


def parse_rate(home):
    files = home_files("kernel")
    failing = []
    for f in files:
        r = subprocess.run([home, "ast", f], capture_output=True)
        if r.returncode != 0:
            failing.append(os.path.relpath(f, REPO))
    return len(files), len(files) - len(failing), failing


def source_size():
    """Files and lines of Home source per top-level area."""
    rows = []
    for d in SOURCE_DIRS:
        files = home_files(d)
        if not files:
            continue
        lines = 0
        for f in files:
            try:
                with open(f, "rb") as fh:
                    lines += fh.read().count(b"\n")
            except OSError:
                pass
        rows.append((d, len(files), lines))
    return rows


def register_entries():
    """Parse the stub register out of MASTER_PLAN §7 — the source of truth."""
    entries = []
    with open(PLAN) as fh:
        for line in fh:
            if not re.match(r"^\| S\d+ \|", line):
                continue
            cols = [c.strip() for c in line.strip().strip("|").split("|")]
            sid, desc, path = cols[0], cols[1], cols[2].strip("`")
            entries.append({
                "id": sid,
                "desc": desc.replace("**CLOSED** — ", ""),
                "path": path,
                "closed": "CLOSED" in desc,
                "gate": cols[4] if len(cols) > 4 else "",
            })
    return entries


def count_markers():
    """How many `// STUB(Sn)` markers exist in source, per register ID."""
    counts = {}
    for d in SOURCE_DIRS:
        root = os.path.join(REPO, d)
        if not os.path.isdir(root):
            continue
        for dirpath, _, files in os.walk(root):
            for f in files:
                p = os.path.join(dirpath, f)
                try:
                    with open(p, "r", errors="ignore") as fh:
                        for m in re.finditer(r"// STUB\((S\d+)\)", fh.read()):
                            counts[m.group(1)] = counts.get(m.group(1), 0) + 1
                except OSError:
                    pass
    return counts


def run_codegen_ratchet(home, arch="x86_64"):
    """Run the mvk-compiles ratchet for one architecture.

    Returns (ok, total), or None when the run produced no measurement — no
    compiler, or no cross-assembler for the requested target. The page then
    says so rather than repeating a previous answer.
    """
    env = dict(os.environ, HOME_COMPILER=home)
    cmd = [os.path.join(REPO, "scripts", "mvk-compiles.sh")]
    if arch != "x86_64":
        cmd.append("--arch=" + arch)
    r = subprocess.run(cmd, capture_output=True, text=True, env=env, cwd=REPO)
    m = re.search(r"mvk-compiles \((\S+)\): (\d+)/(\d+)", r.stdout or "")
    if not m or m.group(1) != arch:
        return None
    return int(m.group(2)), int(m.group(3))


def run_boot_gate_aarch64(home):
    """Build the ARM64 kernel and boot it on QEMU's `virt` machine.

    Returns (state, detail). This is not a Raspberry Pi: QEMU has no Pi 5
    model, so a PASS here means the compiler, the frame layout, the MMIO path
    and the boot handoff work, and says nothing about the Pi's peripherals.
    """
    env = dict(os.environ, HOME_COMPILER=home)
    r = subprocess.run([os.path.join(REPO, "scripts", "boot-gate-aarch64.sh")],
                       capture_output=True, text=True, env=env, cwd=REPO)
    out = (r.stdout or "") + (r.stderr or "")
    if r.returncode == 0:
        for line in out.splitlines():
            if line.startswith("ok  "):
                return "PASS", f"serial says `{line[4:].strip()}`"
        return "PASS", "every ARM64 boot milestone reached"
    if "qemu-system-aarch64 not found" in out or "zig not found" in out:
        return "UNVERIFIED", "no aarch64 QEMU or cross-assembler in this run"
    return "FAIL", "the ARM64 kernel did not reach its boot milestones"


# --- Phase gates ------------------------------------------------------------
#
# What enforces each Phase 1-3 gate, and the artefact a run of it leaves
# behind. This is not a reading of MASTER_PLAN §4's ticks: the plan says what
# is meant to be true, and a page that copied it would go green on an edit to
# a sentence. Each probe below names something a gate script actually prints,
# so a gate that stops holding turns red here on the next run.
#
# Three kinds:
#   boot-line  a line the boot gate itself prints, which it only prints after
#              checking the thing from outside the guest
#   milestone  a line of scripts/boot-milestones.txt. The boot gate asserts
#              every line of that file, in order, and fails if one is missing
#              — so "the gate passed and this line is in the list" means it
#              appeared. Deleting the milestone turns the gate red here too,
#              which is the point of naming it rather than the section.
#   script     a gate script of its own, run and read separately
#
# Phases 4-6 have no entries because nothing enforces them yet. That absence
# is what "not started" means on this page, and it is measured the same way:
# no probe, no claim.
PHASE_GATE_PROBES = {
    "boot-to-shell": ("boot-pass", None),
    "storage-roundtrip": ("boot-line", "fsck OK:"),
    "net-echo": ("boot-line", "net-echo both ways"),
    "fb-boot-log": ("boot-line", "boot-gate: framebuffer "),
    "libc-suite": ("milestone", "libc-suite: every check passed"),
    "shell-suite": ("script", "den-conform"),
    "coreutils-suite": ("coreutils", None),
    "pantry-local-install": ("milestone", "[pantry] REFUSED: signature does not verify"),
}


def tier1_job_names():
    """The gate names, read from MASTER_PLAN §11 rather than repeated here.

    The plan says the Tier-1 job names ARE the phase gates, so that sentence
    is the list. Reading it is what lets the table notice a gate the plan
    gained or renamed instead of quietly omitting it.
    """
    try:
        text = open(PLAN, encoding="utf-8").read()
    except OSError:
        return []
    m = re.search(r"The Tier-1 job names ARE the phase gates:(.+?)\.\s*$",
                  text, re.M | re.S)
    if not m:
        return []
    return re.findall(r"`([a-z0-9_-]+)`", m.group(1))


def milestone_lines():
    """Every asserted line of the x86 milestone list, comments dropped."""
    path = os.path.join(REPO, "scripts", "boot-milestones.txt")
    try:
        raw = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return []
    return [l for l in raw if l.strip() and not l.lstrip().startswith("#")]


def coreutils_count():
    """How many distinct programs the boot gate's command feed runs from /bin.

    Measured from the feed rather than from a count in a sentence, because the
    sentence is what drifts. This is deliberately not "the coreutils": it
    counts every program the feed execs, test programs included, because
    deciding which of them is a coreutil would be a judgement this script
    cannot make and would quietly get wrong. The row says what was counted.
    """
    path = os.path.join(REPO, "scripts", "boot-commands.txt")
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return 0
    names = set()
    for line in text.splitlines():
        if line.lstrip().startswith("#"):
            continue
        names.update(re.findall(r"/bin/([A-Za-z0-9_.-]+)", line))
    return len(names)


def phase_gate_order():
    """Which gates belong to which phase, read out of MASTER_PLAN §4.

    Derived rather than repeated so a gate the plan moves between phases, or
    adds to one, moves here too. Only phases 1-6: the Phase 0 and 0.5 rows
    have measurements of their own above, and Phase 7 is excluded by the same
    bound — it is where §11's list of every job name lives, and scanning it
    would pull the whole list into one phase.
    """
    try:
        text = open(PLAN, encoding="utf-8").read()
    except OSError:
        return []
    names = set(tier1_job_names())
    order, seen, phase = [], set(), None
    for line in text.splitlines():
        h = re.match(r"^### Phase ([0-9.]+)", line)
        if h:
            try:
                phase = float(h.group(1))
            except ValueError:
                phase = None
            continue
        if phase is None or not (1 <= phase <= 6):
            continue
        for g in re.findall(r"`([a-z0-9_-]+)`", line):
            if g in names and g not in seen:
                seen.add(g)
                order.append((int(phase), g))
    return order


def phase_gate_status(gate, full_state, boot_out, den):
    """Measure one Phase 1-3 gate. Returns (icon, text) or None if unprobed."""
    probe = PHASE_GATE_PROBES.get(gate)
    if probe is None:
        return None
    kind, needle = probe
    # Everything but `shell-suite` rests on the boot gate having passed: these
    # are assertions made during that run, and an unfinished run has not made
    # them. Saying "unverified" beats inheriting its silence as a pass.
    if kind != "script" and full_state != "PASS":
        if full_state == "UNVERIFIED":
            return "⬜", "unverified — the boot gate did not run"
        return "❌", "the boot gate did not pass"
    if kind == "boot-pass":
        return "✅", "green"
    if kind == "boot-line":
        for line in boot_out.splitlines():
            if needle in line:
                return "✅", "green — " + line.strip().replace("boot-gate: ", "")
        return "❌", f"the boot gate printed no `{needle}` line"
    if kind == "milestone":
        if needle in milestone_lines():
            return "✅", f"green — asserted as `{needle}`"
        return "❌", f"`{needle}` is no longer asserted"
    if kind == "coreutils":
        n = coreutils_count()
        if n:
            return "✅", f"green — {n} distinct programs run from /bin under the boot gate"
        return "❌", "the command feed runs nothing from /bin"
    if kind == "script":
        den_state, den_detail = den
        icon = {"PASS": "✅", "FAIL": "❌", "UNVERIFIED": "⬜"}[den_state]
        return icon, ("green — " if den_state == "PASS" else "") + den_detail
    return None


def run_stub_gate():
    """Run the stub-register gate. Returns (state, detail)."""
    r = subprocess.run([os.path.join(REPO, "scripts", "stub-check.sh")],
                       capture_output=True, text=True, cwd=REPO)
    line = (r.stdout or r.stderr).strip().splitlines()[-1:] or [""]
    return ("PASS" if r.returncode == 0 else "FAIL"), line[0]


def run_full_boot_gate(home, keep_kernel=None):
    """Boot the whole Appendix A kernel. Returns (state, detail, output).

    run_boot_gate below measures the proof-of-life kernel — one file that
    prints and halts. This measures the real one: every Appendix A file,
    linked into one image and booted, checked against the milestone list in
    scripts/boot-milestones.txt.

    The run's own output comes back with the verdict because one boot is the
    evidence for most of the Phase 1-3 gates: the ext2 round trip, the echo in
    both directions and the framebuffer capture are all lines this run prints,
    and phase_gate_rows below reads them rather than booting three more times.

    `keep_kernel` is a path the gate copies its built image to. den-conform
    runs next and wants the same kernel; building it once is both faster and
    the only way to be sure the shell it measures is the shell this booted.
    """
    env = dict(os.environ, HOME_COMPILER=home)
    if keep_kernel:
        env["BUILD_OUT"] = keep_kernel
    r = subprocess.run([os.path.join(REPO, "scripts", "boot-gate.sh")],
                       capture_output=True, text=True, env=env, cwd=REPO)
    out = (r.stdout or "") + (r.stderr or "")
    m = re.search(r"boot-gate: (\d+)/(\d+) milestones reached", out)
    if "qemu-system-x86_64 not found" in out or "home compiler not found" in out:
        return "UNVERIFIED", "QEMU not available in this run", out
    if not m:
        return "FAIL", "boot gate produced no milestone count", out
    reached, total = int(m.group(1)), int(m.group(2))
    if r.returncode == 0 and reached == total:
        return ("PASS",
                f"{reached}/{total} init milestones reached, through to the end of init",
                out)
    stopped = re.search(r"First milestone not reached: (.+)", out)
    detail = f"{reached}/{total} init milestones reached"
    if stopped:
        detail += f"; stopped before `{stopped.group(1).strip()}`"
    return "FAIL", detail, out


def run_den_conform(kernel_bin=None):
    """Run the shell conformance gate. Returns (state, detail).

    Its own run rather than a reading of the boot gate's: den-conform is what
    enforces `shell-suite`, and it asserts something the boot gate does not —
    that home-os's shell produces the same bytes as the reference den, line
    for line, rather than merely that some builtin printed something.

    It does not need its own kernel, though. Given the image the boot gate
    just built, it measures the shell that booted a moment ago instead of a
    second build of the same tree — which is both a build shorter and one
    fewer thing that can differ.
    """
    env = dict(os.environ)
    if kernel_bin and os.path.exists(kernel_bin):
        env["KERNEL_BIN"] = kernel_bin
    r = subprocess.run([os.path.join(REPO, "scripts", "den-conform.sh")],
                       capture_output=True, text=True, cwd=REPO, env=env)
    out = (r.stdout or "") + (r.stderr or "")
    m = re.search(r"den-conform: (\d+) lines identical to the reference shell"
                  r" \((\d+) script", out)
    if r.returncode == 0 and m:
        return "PASS", f"{m.group(1)} lines identical to the reference den, {m.group(2)} script(s)"
    if "kernel build failed" in out:
        return "UNVERIFIED", "the kernel would not build in this run"
    return "FAIL", "home-os's shell diverged from the reference den"


def run_boot_gate(home):
    """Build the MVK and boot it. Returns (state, detail)."""
    env = dict(os.environ, HOME_COMPILER=home)
    build = subprocess.run([os.path.join(REPO, "scripts", "build.sh"), "mvk"],
                           capture_output=True, text=True, env=env, cwd=REPO)
    if build.returncode != 0:
        tail = (build.stderr or build.stdout).strip().splitlines()[-1:] or [""]
        return "FAIL", f"MVK build failed: {tail[0]}"
    boot = subprocess.run([os.path.join(REPO, "scripts", "boot-test.sh")],
                          capture_output=True, text=True, env=env, cwd=REPO)
    if boot.returncode == 0:
        # Quote what the serial console actually said, not what we asked for:
        # only lines after the serial-output banner count.
        in_serial = False
        for line in boot.stdout.splitlines():
            if line.startswith("--- serial output"):
                in_serial = True
                continue
            if line.startswith("---------"):
                in_serial = False
            if in_serial and line.strip():
                return "PASS", f"serial says `{line.strip()}`"
        return "PASS", "proof-of-life string seen on serial"
    if boot.returncode == 2:
        return "UNVERIFIED", "QEMU not available in this run"
    return "FAIL", "kernel built but no proof-of-life string on serial"


def main():
    no_boot = "--no-boot" in sys.argv
    check = "--check" in sys.argv

    home = find_compiler()
    if not home:
        print("error: Home compiler not found (set HOME_COMPILER)", file=sys.stderr)
        return 2

    total, ok, failing = parse_rate(home)
    pct = (ok * 100 // total) if total else 0
    rev = compiler_revision(home)

    if no_boot:
        boot_state, boot_detail = "UNVERIFIED", "skipped (--no-boot)"
        full_state, full_detail = "UNVERIFIED", "skipped (--no-boot)"
        boot_out = ""
        arm_state, arm_detail = "UNVERIFIED", "skipped (--no-boot)"
        den = ("UNVERIFIED", "skipped (--no-boot)")
    else:
        boot_state, boot_detail = run_boot_gate(home)
        # One kernel for the two gates that need a whole one. den-conform
        # builds its own when handed nothing, and that build is by far the
        # longest part of it — and a second build of the same tree is one more
        # thing that can differ from what was actually booted here.
        scratch = tempfile.mkdtemp(prefix="home-os-status-")
        try:
            kernel = os.path.join(scratch, "boot-gate.bin")
            full_state, full_detail, boot_out = run_full_boot_gate(home, kernel)
            arm_state, arm_detail = run_boot_gate_aarch64(home)
            den = run_den_conform(kernel)
        finally:
            shutil.rmtree(scratch, ignore_errors=True)
    stub_state, stub_detail = run_stub_gate()
    ratchet = None if no_boot else run_codegen_ratchet(home)
    ratchet_arm = None if no_boot else run_codegen_ratchet(home, "aarch64")
    entries = register_entries()
    markers = count_markers()
    L = []
    w = L.append

    w("# Implementation Status")
    w("")
    w("> **Auto-generated by `scripts/generate_status.py`** — do not edit by hand.")
    w("> Every figure below is measured when the script runs, never restated, so")
    w("> this page cannot drift from the repository ([MASTER_PLAN §13.2](docs/MASTER_PLAN.md)).")
    w("")

    # --- The one-line answer ------------------------------------------------
    w("## Where the project actually is")
    w("")
    if full_state == "PASS":
        w("The Home-compiled kernel **boots and runs its full initialisation**: memory")
        w("management, the scheduler, the security subsystems, drivers, filesystems,")
        w("networking and system services all initialise on the serial console. The")
        w("milestones are listed in `scripts/boot-milestones.txt` and checked on every")
        w("build.")
        w("")
        w("What executes is the Appendix A set. The rest of this repository is source")
        w("that has been written and parsed, but never run.")
    elif boot_state == "PASS":
        w("A Home-compiled kernel **boots and prints on the serial console**, but the")
        w("full Appendix A kernel does not complete initialisation — see Boot status.")
        w("Everything else in this repository is source that has been written and")
        w("parsed, but never run.")
    elif boot_state == "FAIL":
        w("**No Home-compiled kernel currently boots.** The boot gate is red — see")
        w("Boot status below. Nothing in this repository executes.")
    else:
        w("Boot status could not be verified in this run, so this page will not")
        w("claim one way or the other. See Boot status below.")
    w("")

    # --- Parse rate ---------------------------------------------------------
    w("## Parse rate")
    w("")
    w(f"**{ok}/{total} kernel `.home` files parse ({pct}%)**")
    w("")
    # The compiler path is machine-specific; the revision is the fact that
    # matters and the one CI pins.
    w("- Compiler: `home-lang/home`" + (f" @ `{rev}`" if rev else " (revision unknown)"))
    if failing:
        w("- Not parsing:")
        for f in failing:
            w(f"  - `{f}`")
    else:
        w("- Every kernel file parses. This is milestone A1.")
    w("")
    w("Parsing is not compiling. A file in this count has been accepted by the")
    w("parser; it has not been typechecked, code-generated, linked, or run.")
    w("")

    # --- Boot status --------------------------------------------------------
    w("## Boot status")
    w("")
    # Named rather than reused: `icon` is reassigned for the full-kernel and
    # ARM64 lines below, and the phase-gate table further down read it back
    # long after that. It printed the ARM64 run's icon beside the x86_64 run's
    # word, which is how a page whose whole purpose is to not drift came to
    # say "⬜ pass".
    boot_icon = {"PASS": "✅", "FAIL": "❌", "UNVERIFIED": "⬜"}[boot_state]
    w(f"{boot_icon} **`boot-qemu-x86_64`: {boot_state}** — {boot_detail}")
    w("")
    w("Measured by building `kernel/src/mvk_poc.home` through the Home compiler,")
    w("linking it with `kernel/src/boot.s` via `kernel/linker.ld`, and booting the")
    w("result in QEMU with the serial console captured.")
    w("")
    icon = {"PASS": "✅", "FAIL": "❌", "UNVERIFIED": "⬜"}[full_state]
    w(f"{icon} **`boot-full-kernel`: {full_state}** — {full_detail}")
    w("")
    w("The line above measures the proof-of-life kernel: one file that prints and")
    w("halts. This one measures the real kernel — every Appendix A file linked into")
    w("one image — against the milestone list in `scripts/boot-milestones.txt`,")
    w("which names one subsystem per entry and may only ever grow.")
    w("")
    icon = {"PASS": "✅", "FAIL": "❌", "UNVERIFIED": "⬜"}[arm_state]
    w(f"{icon} **`boot-qemu-aarch64`: {arm_state}** — {arm_detail}")
    w("")
    w("Measured by building `kernel/src/arm64_poc.home` for")
    w("`aarch64-freestanding`, linking it with `kernel/src/arch/arm64/boot.s` via")
    w("`kernel/linker-virt.ld`, and booting it on QEMU's `virt` machine.")
    w("")
    w("**This is not a Raspberry Pi.** QEMU has no Pi 5 machine model — there is no")
    w("RP1 — so a pass here means the compiler, the frame layout, the MMIO path and")
    w("the boot handoff work. It says nothing about the Pi's own peripherals, which")
    w("only the hardware gate can measure.")
    w("")

    # --- Codegen ratchet ----------------------------------------------------
    w("## Codegen ratchet")
    w("")
    if ratchet:
        ok_n, total_n = ratchet
        w(f"**{ok_n}/{total_n} of the Minimum Viable Kernel file set reaches codegen.**")
        w("")
        w("This is the number to watch. The MVK set is")
        w("[MASTER_PLAN Appendix A](docs/MASTER_PLAN.md#appendix-a--minimum-viable-kernel-file-set);")
        w("a file counts only when the compiler produces assembly with no unlowered")
        w("construct in it *and* the assembler accepts that assembly. It may never")
        w("fall — `scripts/mvk-compiles.sh` fails the build if it does.")
        w("")
        w("Run `scripts/mvk-compiles.sh --list` to see what each remaining file is")
        w("waiting on; the failures name the construct, not just the count.")
        w("")
        if ratchet_arm:
            arm_ok, arm_total = ratchet_arm
            w(f"**{arm_ok}/{arm_total} of the same set reaches codegen for `aarch64`.**")
            w("")
            w("Kept as its own number rather than averaged in, because the two targets")
            w("advance independently. The gap is not a compiler gap: the files that do")
            w("not lower for ARM are the ones reached by `asm volatile` blocks written")
            w("in x86 assembly, which is emitted verbatim by definition. Making those")
            w("architecture-neutral is kernel work, not backend work.")
        else:
            w("The `aarch64` count was **not verified in this run** — no cross-assembler")
            w("or no compiler.")
    else:
        w("Not measured in this run.")
    w("")

    # --- Source inventory ---------------------------------------------------
    w("## Source inventory")
    w("")
    w("| Area | `.home` files | Lines |")
    w("|------|--------------:|------:|")
    for d, n, lines in source_size():
        w(f"| `{d}/` | {n} | {lines:,} |")
    w("")
    w("Breadth is not progress. These files are the corpus the compiler and the")
    w("bring-up work are measured against, not a list of working features.")
    w("")

    # --- Stub register ------------------------------------------------------
    w("## Stub-Burndown Register")
    w("")
    w("Parsed from [MASTER_PLAN §7](docs/MASTER_PLAN.md#7-workstream-b--kernel--stub-burndown-register),")
    w("cross-checked against `// STUB(Sn)` markers in source by the `stub-register`")
    w("CI gate (`scripts/stub-check.sh`).")
    w("")
    w("| # | Stub | File | Markers | Status |")
    w("|---|------|------|--------:|--------|")
    for e in entries:
        n = markers.get(e["id"], 0)
        status = "**CLOSED**" if e["closed"] else f"open — blocks {e['gate']}" if e["gate"] else "open"
        w(f"| {e['id']} | {e['desc']} | `{e['path']}` | {n} | {status} |")
    w("")
    n_open = sum(1 for e in entries if not e["closed"])
    w(f"{n_open} of {len(entries)} entries open.")
    w("")

    # --- Phase gates --------------------------------------------------------
    w("## Phase gates ([MASTER_PLAN §4](docs/MASTER_PLAN.md#4-the-phase-map))")
    w("")
    w("One row per Tier-1 job name in [MASTER_PLAN §11](docs/MASTER_PLAN.md),")
    w("assigned to the phase §4 lists it under. A gate is green here because")
    w("something in this run produced the evidence for it — a line the boot gate")
    w("prints after checking from outside the guest, a milestone it asserted, or")
    w("a gate script of its own — never because the plan says it should be. A")
    w("gate with no probe has nothing enforcing it yet, and that is what \"not")
    w("started\" means below.")
    w("")
    w("| Phase | Gate | Status |")
    w("|-------|------|--------|")
    w(f"| 0 | `parse-rate` | {'✅ green' if pct == 100 else f'❌ {pct}%'} |")
    stub_icon = {"PASS": "✅", "FAIL": "❌"}[stub_state]
    w(f"| 0 | `stub-register` | {stub_icon} {stub_state.lower()} — {stub_detail} |")
    w(f"| 0 | `boot-qemu-x86_64` | {boot_icon} {boot_state.lower()} |")
    if ratchet:
        ok_n, total_n = ratchet
        done = "✅ green" if ok_n == total_n else f"🟡 {ok_n}/{total_n}"
        w(f"| 0.5 | `mvk-compiles` | {done} |")
    # One row per gate, measured. This was a literal list with "⬜ not started"
    # written into every row, which had been wrong for three phases: the boot
    # gate has been round-tripping ext2, echoing TCP both ways, capturing the
    # framebuffer and running the libc, shell, coreutils and pantry suites for
    # a long time, and the page said none of it had started — while linking to
    # the plan section that ticks all seven.
    covered = set(PHASE_GATE_PROBES) | {
        "parse-rate", "stub-register", "boot-qemu-x86_64", "mvk-compiles"}
    gate_order = phase_gate_order()
    for phase, gate in gate_order:
        measured = phase_gate_status(gate, full_state, boot_out, den)
        if measured:
            icon, text = measured
        else:
            icon, text = "⬜", "not started — nothing enforces it yet"
        w(f"| {phase} | `{gate}` | {icon} {text} |")
    w("")
    # A gate the plan has and this table does not. Shown rather than dropped:
    # a gate missing from a status page is exactly the drift the page exists
    # to prevent, and it cannot report what it does not know it is missing.
    listed = {g for _, g in gate_order} | covered
    unlisted = [g for g in tier1_job_names() if g not in listed]
    if unlisted:
        w("> **Gates in [MASTER_PLAN §11](docs/MASTER_PLAN.md) that this table does")
        w("> not cover:** " + ", ".join(f"`{g}`" for g in unlisted) + ". Add them to")
        w("> MASTER_PLAN §4 under a phase heading, or give them a probe in")
        w("> `scripts/generate_status.py`.")
        w("")

    text = "\n".join(L) + "\n"

    if check:
        current = open(OUT).read() if os.path.exists(OUT) else ""
        if current != text:
            print("IMPLEMENTATION_STATUS.md is stale — regenerate it "
                  "with scripts/generate_status.py", file=sys.stderr)
            return 1
        print("IMPLEMENTATION_STATUS.md is up to date")
        return 0

    with open(OUT, "w") as fh:
        fh.write(text)
    print(f"wrote {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
