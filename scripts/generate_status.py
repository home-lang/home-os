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
import subprocess
import sys

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


def run_codegen_ratchet(home):
    """Run the mvk-compiles ratchet. Returns (ok, total) or None."""
    env = dict(os.environ, HOME_COMPILER=home)
    r = subprocess.run([os.path.join(REPO, "scripts", "mvk-compiles.sh")],
                       capture_output=True, text=True, env=env, cwd=REPO)
    m = re.search(r"mvk-compiles: (\d+)/(\d+)", r.stdout or "")
    if not m:
        return None
    return int(m.group(1)), int(m.group(2))


def run_stub_gate():
    """Run the stub-register gate. Returns (state, detail)."""
    r = subprocess.run([os.path.join(REPO, "scripts", "stub-check.sh")],
                       capture_output=True, text=True, cwd=REPO)
    line = (r.stdout or r.stderr).strip().splitlines()[-1:] or [""]
    return ("PASS" if r.returncode == 0 else "FAIL"), line[0]


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
    else:
        boot_state, boot_detail = run_boot_gate(home)

    stub_state, stub_detail = run_stub_gate()
    ratchet = None if no_boot else run_codegen_ratchet(home)
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
    if boot_state == "PASS":
        w("A Home-compiled kernel **boots and prints on the serial console**. That is")
        w("the whole of what executes today: everything else in this repository is")
        w("source that has been written and parsed, but never run.")
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
    icon = {"PASS": "✅", "FAIL": "❌", "UNVERIFIED": "⬜"}[boot_state]
    w(f"{icon} **`boot-qemu-x86_64`: {boot_state}** — {boot_detail}")
    w("")
    w("Measured by building `kernel/src/mvk_poc.home` through the Home compiler,")
    w("linking it with `kernel/src/boot.s` via `kernel/linker.ld`, and booting the")
    w("result in QEMU with the serial console captured.")
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
    w("A gate is green only when its CI job passes on `main`. Gates below the")
    w("first red one are blocked by definition — they are not being worked yet.")
    w("")
    w("| Phase | Gate | Status |")
    w("|-------|------|--------|")
    w(f"| 0 | `parse-rate` | {'✅ green' if pct == 100 else f'❌ {pct}%'} |")
    stub_icon = {"PASS": "✅", "FAIL": "❌"}[stub_state]
    w(f"| 0 | `stub-register` | {stub_icon} {stub_state.lower()} — {stub_detail} |")
    w(f"| 0 | `boot-qemu-x86_64` | {icon} {boot_state.lower()} |")
    if ratchet:
        ok_n, total_n = ratchet
        done = "✅ green" if ok_n == total_n else f"🟡 {ok_n}/{total_n}"
        w(f"| 0.5 | `mvk-compiles` | {done} |")
    for phase, gate in [
        (1, "`boot-to-shell`"),
        (2, "`storage-roundtrip` / `net-echo` / `fb-boot-log`"),
        (3, "`libc-suite` / `shell-suite` / `coreutils-suite` / `pantry-local-install`"),
        (4, "`craft-demo` / `wm-layouts`"),
        (5, "`iso-install` / `desktop-parity-suite` — **v1.0**"),
        (6, "`snapshot-rollback` / `agent-cli-suite`"),
    ]:
        w(f"| {phase} | {gate} | ⬜ not started |")
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
