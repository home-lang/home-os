# Home OS - Strategic TODO Updates

> **Mission**: Build the most performant, developer-friendly operating system that runs beautifully on everything from Raspberry Pis to high-end workstations.

**Last Updated**: November 24, 2025  
**Status**: Codebase Analysis Complete - Strategic Roadmap Defined

---

## Executive Summary

After comprehensive codebase analysis, Home OS has an impressive foundation:

- **210+ kernel modules** written in Home language
- **57 hardware drivers** (storage, input, network, USB, video, etc.)
- **17 networking protocols** (TCP/IP, HTTP, TLS, WebSocket, MQTT, etc.)
- **11 file systems** (FAT32, ext2, NTFS, Btrfs, tmpfs, procfs, etc.)
- **87 userspace utilities** (ls, grep, cat, ps, etc.)
- **13 security modules** (ASLR, firewall, encryption, capabilities, etc.)
- **12 performance modules** (async I/O, RCU, zero-copy, etc.)

However, the existing TODO.md (1858 lines, 18 phases) is **aspirational documentation** rather than a reflection of actual implementation state. Many items marked "complete" are **stub implementations** that need real functionality.

---

## 🎯 Priority 1: Performance Foundation (Critical for Low-End Devices)

### P1.1 Memory Efficiency (Target: <128MB RAM for headless, <256MB for GUI)

**Current State**: Basic PMM/VMM implemented, but not optimized for constrained environments.

- [ ] **Implement ZRAM** - Compressed swap in RAM (critical for Pi 3 with 1GB)
  - Location: `kernel/src/mm/zram.home`
  - Target: 2:1 compression ratio
  - Priority: **CRITICAL**

- [ ] **Optimize Kernel Memory Footprint**
  - Audit all static allocations in `kernel/src/`
  - Remove unused drivers from default build
  - Implement lazy module loading
  - Target: <50MB kernel memory usage
  - Priority: **HIGH**

- [ ] **Implement Memory Pools**
  - Pre-allocated pools for common object sizes
  - Reduce fragmentation on long-running systems
  - Location: `kernel/src/mm/pool.home`
  - Priority: **HIGH**

- [ ] **Slab Allocator Optimization**
  - Current: `kernel/src/mm/slab.home` exists but basic
  - Need: Per-CPU caches, magazine layer
  - Priority: **MEDIUM**

### P1.2 Boot Time Optimization (Target: <3s to shell on Pi 4/5)

**Current State**: Sequential initialization, no parallelization.

- [ ] **Parallel Driver Initialization**
  - Identify independent drivers in `kernel/src/drivers/`
  - Implement async init with dependency graph
  - Priority: **HIGH**

- [ ] **Lazy Service Loading**
  - Don't load GUI components for headless boot
  - Defer non-essential drivers
  - Priority: **HIGH**

- [ ] **Boot Time Profiling**
  - Add timestamps to each init phase
  - Create boot chart visualization
  - Location: `kernel/src/perf/boot_opt.home` (exists, needs enhancement)
  - Priority: **MEDIUM**

- [ ] **Initramfs Optimization**
  - Minimal initramfs for fast boot
  - Compressed kernel modules
  - Priority: **MEDIUM**

### P1.3 I/O Performance (Critical for SD Card Performance)

**Current State**: Basic ATA driver, no async I/O.

- [ ] **Implement io_uring-style Async I/O**
  - Current: `kernel/src/perf/async_io.home` exists but incomplete
  - Need: Ring buffer submission/completion queues
  - Priority: **CRITICAL** (SD cards are slow, async is essential)

- [ ] **SD/MMC Driver Optimization**
  - Current: No dedicated SD driver
  - Need: DMA support, multi-block transfers
  - Location: `kernel/src/drivers/sdmmc.home` (create new)
  - Priority: **CRITICAL** for Raspberry Pi

- [ ] **Block Layer Request Merging**
  - Combine adjacent I/O requests
  - Reduce SD card wear
  - Priority: **HIGH**

- [ ] **Read-Ahead Cache**
  - Predictive file reading
  - Critical for sequential workloads
  - Priority: **MEDIUM**

---

## 🎯 Priority 2: Raspberry Pi First-Class Support

### P2.1 Hardware Bring-Up (Currently Partial)

**Current State**: `rpi5_main.home` exists with basic UART and GPIO, but most hardware unsupported.

- [ ] **Complete BCM2712 (Pi 5) Support**
  - [ ] RP1 southbridge driver (PCIe-connected I/O)
  - [ ] GIC-600 interrupt controller
  - [ ] VideoCore VII GPU mailbox
  - [ ] USB 3.0 via RP1
  - Location: `kernel/src/rpi/`
  - Priority: **CRITICAL**

- [ ] **Complete BCM2711 (Pi 4) Support**
  - [ ] GIC-400 interrupt controller
  - [ ] VideoCore VI GPU mailbox
  - [ ] USB 3.0 (VL805 controller)
  - Priority: **HIGH**

- [ ] **SD/eMMC Controller Driver**
  - EMMC2 for Pi 4/5
  - High-speed modes (SDR104)
  - Location: `kernel/src/drivers/bcm_emmc.home` (create new)
  - Priority: **CRITICAL**

- [ ] **WiFi/Bluetooth Driver**
  - Cypress CYW43455 (Pi 4) / CYW43455 (Pi 5)
  - Current: `kernel/src/drivers/wifi.home` is stub
  - Priority: **HIGH**

- [ ] **GPU Framebuffer**
  - Mailbox-based framebuffer allocation
  - Hardware cursor support
  - Priority: **HIGH**

### P2.2 ARM64 Kernel Completeness

**Current State**: Basic ARM64 boot works, but many subsystems x86-only.

- [ ] **ARM64 Exception Handling**
  - Proper EL1 exception vectors
  - Synchronous/asynchronous exception handling
  - Location: `kernel/src/arch/aarch64/` (expand)
  - Priority: **CRITICAL**

- [ ] **ARM64 Memory Management**
  - 4KB/16KB/64KB page granule support
  - ASID management
  - TLB maintenance
  - Priority: **CRITICAL**

- [ ] **ARM Generic Timer**
  - Current: Basic timer in `rpi5_main.home`
  - Need: Proper timer driver with interrupts
  - Priority: **HIGH**

- [ ] **Device Tree Parsing**
  - Current: `basics/os/dtb` imported but minimal
  - Need: Full DTB parsing for hardware discovery
  - Priority: **HIGH**

### P2.3 Thermal & Power Management

**Current State**: Not implemented.

- [ ] **CPU Frequency Scaling**
  - DVFS (Dynamic Voltage and Frequency Scaling)
  - Governor policies (performance, powersave, ondemand)
  - Location: `kernel/src/power/cpufreq.home` (create new)
  - Priority: **HIGH** (prevents thermal throttling)

- [ ] **Thermal Monitoring**
  - Read SoC temperature
  - Thermal throttling at 80°C
  - Fan control (GPIO-based)
  - Priority: **HIGH**

- [ ] **Power Management**
  - Peripheral power gating
  - USB selective suspend
  - Display blanking
  - Priority: **MEDIUM**

---

## 🎯 Priority 3: Developer Experience (DX)

### P3.1 Build System Modernization

**Current State**: Multiple build scripts, inconsistent.

- [ ] **Unified Build System**
  - Single `home build` command for all targets
  - Cross-compilation support (x86→ARM64)
  - Incremental builds
  - Location: `kernel/build.home` (enhance)
  - Priority: **HIGH**

- [ ] **Build Configuration**
  - `menuconfig`-style interface
  - Feature flags for minimal builds
  - Target-specific optimizations
  - Priority: **MEDIUM**

- [ ] **CI/CD Pipeline**
  - Automated builds for x86-64 and ARM64
  - QEMU-based testing
  - Boot time regression tracking
  - Priority: **MEDIUM**

### P3.2 Debugging & Profiling

**Current State**: Serial output only, no real debugging.

- [ ] **GDB Stub**
  - Remote debugging via serial/network
  - Breakpoints, single-stepping
  - Location: `kernel/src/debug/gdb.home` (create new)
  - Priority: **HIGH**

- [ ] **Kernel Panic Handler**
  - Stack trace on panic
  - Register dump
  - Crash dump to storage
  - Priority: **HIGH**

- [ ] **Performance Profiler**
  - Current: `kernel/src/perf/profiler.home` exists
  - Need: Integration with actual kernel, sampling
  - Priority: **MEDIUM**

- [ ] **Memory Leak Detection**
  - Track allocations/frees
  - Report leaks on shutdown
  - Priority: **MEDIUM**

### P3.3 Documentation

**Current State**: Good high-level docs, missing API docs.

- [ ] **API Documentation**
  - Auto-generate from `.home` source
  - Syscall reference
  - Driver development guide
  - Priority: **MEDIUM**

- [ ] **Architecture Decision Records**
  - Document why decisions were made
  - Location: `docs/adr/`
  - Priority: **LOW**

---

## 🎯 Priority 4: Real Implementation vs Stubs

### P4.1 Kernel Core (Audit Required)

Many "complete" modules are stubs. Priority audit:

- [ ] **Process Management** (`kernel/src/core/process.home`)
  - Current: Basic PCB, round-robin scheduler
  - Need: Verify fork/exec actually works
  - Priority: **CRITICAL**

- [ ] **File System** (`kernel/src/core/filesystem.home`)
  - Current: VFS abstraction exists
  - Need: Verify actual read/write to disk works
  - Priority: **CRITICAL**

- [ ] **System Calls** (`kernel/src/sys/syscall.home`)
  - Current: 36 syscalls defined
  - Need: Verify each syscall is actually implemented
  - Priority: **CRITICAL**

### P4.2 Driver Verification

57 drivers exist, but many are stubs:

- [ ] **Audit Critical Drivers**
  - `drivers/ata.home` - Verify disk I/O works
  - `drivers/keyboard.home` - Verify input works
  - `drivers/timer.home` - Verify interrupts fire
  - `drivers/e1000.home` - Verify network packets flow
  - Priority: **HIGH**

- [ ] **Create Driver Test Suite**
  - Unit tests for each driver
  - Hardware-in-the-loop tests on real Pi
  - Priority: **MEDIUM**

### P4.3 Network Stack Verification

17 protocols defined, likely stubs:

- [ ] **Verify TCP/IP Stack**
  - Can we actually ping?
  - Can we make HTTP requests?
  - Location: `kernel/src/net/`
  - Priority: **HIGH**

- [ ] **Verify DHCP Client**
  - Can we get an IP address?
  - Location: `kernel/src/net/dhcp.home`
  - Priority: **HIGH**

---

## 🎯 Priority 5: Essential Applications

### P5.1 Shell (Critical for Usability)

**Current State**: `apps/shell.home` exists (2169 bytes), likely minimal.

- [ ] **Implement Real Shell**
  - Command parsing and execution
  - Pipes and redirections
  - Environment variables
  - Tab completion
  - History
  - Priority: **CRITICAL**

- [ ] **Ghostty Integration**
  - As noted in TODO.md, use Ghostty as terminal
  - Requires: Working PTY subsystem
  - Priority: **HIGH**

### P5.2 Init System

**Current State**: Kernel support exists, no userspace init.

- [ ] **Implement Init Process**
  - PID 1 responsibilities
  - Service supervision
  - Dependency resolution
  - Location: `apps/init/` (create new)
  - Priority: **CRITICAL**

### P5.3 Core Utilities Verification

87 utilities in `apps/utils/`, need verification:

- [ ] **Verify Critical Utilities**
  - `ls.home` (7392 bytes - largest, likely most complete)
  - `cat.home`, `cp.home`, `mv.home`, `rm.home`
  - `ps.home`, `top.home`, `kill.home`
  - Priority: **HIGH**

---

## 🎯 Priority 6: Security Hardening

### P6.1 Memory Safety (Leverage Home Language)

**Current State**: Home provides memory safety, but kernel may bypass.

- [ ] **Audit Unsafe Code**
  - Find all raw pointer usage
  - Ensure bounds checking
  - Priority: **HIGH**

- [ ] **Stack Protection**
  - Current: `kernel/src/security/stack_protection.home` exists
  - Need: Verify it's actually enabled
  - Priority: **HIGH**

### P6.2 Process Isolation

- [ ] **Verify Address Space Separation**
  - User/kernel mode separation
  - SMEP/SMAP on x86, PAN/PXN on ARM
  - Priority: **HIGH**

- [ ] **Implement Seccomp-BPF**
  - Current: `kernel/src/security/seccomp.home` exists
  - Need: Verify syscall filtering works
  - Priority: **MEDIUM**

---

## 🎯 Priority 7: GUI (Lower Priority Until Kernel Stable)

### P7.1 Framebuffer Console

**Current State**: VGA text mode on x86, basic framebuffer on Pi.

- [ ] **Implement Framebuffer Console**
  - Font rendering
  - Color support
  - Scrolling
  - Priority: **MEDIUM**

### P7.2 Craft UI Integration

**Current State**: `kernel/src/lib/craft_lib.home` exists with window management stubs.

- [ ] **Verify Craft Integration**
  - Can we create windows?
  - Can we render widgets?
  - Priority: **LOW** (until kernel stable)

---

## Implementation Order (Recommended)

### Phase A: Bootable & Testable (Weeks 1-4)

1. Fix any boot regressions
2. Implement GDB stub for debugging
3. Verify basic syscalls work
4. Get shell running with basic commands

### Phase B: Raspberry Pi Functional (Weeks 5-12)

1. Complete SD/MMC driver
2. Complete ARM64 exception handling
3. Implement thermal management
4. Get networking working (DHCP + ping)

### Phase C: Performance Optimization (Weeks 13-20)

1. Implement ZRAM
2. Implement async I/O
3. Optimize boot time
4. Memory footprint reduction

### Phase D: Developer Experience (Weeks 21-28)

1. Unified build system
2. CI/CD pipeline
3. Documentation generation
4. Test suite

### Phase E: Applications & Polish (Weeks 29-40)

1. Complete shell
2. Init system
3. Core utilities
4. GUI (if kernel stable)

---

## Metrics & Targets

### Performance Targets

| Metric | Pi 3 B+ | Pi 4 (4GB) | Pi 5 (8GB) | x86-64 |
|--------|---------|------------|------------|--------|
| Boot to shell | <5s | <3s | <2s | <2s |
| Boot to GUI | <15s | <8s | <6s | <5s |
| Idle RAM (headless) | <96MB | <128MB | <192MB | <256MB |
| Idle RAM (GUI) | <192MB | <256MB | <384MB | <512MB |
| Kernel size | <8MB | <8MB | <8MB | <10MB |

### Stability Targets

| Metric | Target |
|--------|--------|
| Uptime | >30 days continuous |
| Kernel panics | <1 per 1000 hours |
| Memory leaks | None in 72-hour test |

### Compatibility Targets

| Platform | Status | Target |
|----------|--------|--------|
| QEMU x86-64 | ✅ Works | Maintain |
| QEMU ARM64 | 🟡 Partial | Full support |
| Pi 5 bare metal | 🟡 Basic | Full support |
| Pi 4 bare metal | ❌ Untested | Full support |
| Pi 3 B+ | ❌ Untested | Basic support |
| Real x86-64 PC | ❌ Untested | Full support |

---

## Code Quality Standards

### For New Code

1. **No stubs** - Every function must do something real
2. **Error handling** - All errors must be handled
3. **Documentation** - Public APIs must be documented
4. **Tests** - New features need tests

### For Existing Code

1. **Audit before use** - Verify stubs before depending on them
2. **Incremental improvement** - Fix issues as encountered
3. **Track technical debt** - Document known issues

---

## Files to Create

| File | Purpose | Priority |
|------|---------|----------|
| `kernel/src/drivers/bcm_emmc.home` | Pi SD card driver | CRITICAL |
| `kernel/src/drivers/sdmmc.home` | Generic SD/MMC | CRITICAL |
| `kernel/src/mm/zram.home` | Compressed swap | CRITICAL |
| `kernel/src/power/cpufreq.home` | CPU frequency scaling | HIGH |
| `kernel/src/power/thermal.home` | Thermal management | HIGH |
| `kernel/src/debug/gdb.home` | GDB remote stub | HIGH |
| `apps/init/init.home` | Init process | CRITICAL |
| `tests/boot_test.home` | Boot time tests | MEDIUM |
| `tests/driver_test.home` | Driver tests | MEDIUM |

---

## Relationship to Existing TODO.md

The existing `TODO.md` is a **78-week aspirational roadmap** with ~800 tasks across 18 phases. It's valuable for vision but:

1. **Many "complete" items are stubs** - Need verification
2. **Overly optimistic timelines** - Real OS development takes longer
3. **Missing practical priorities** - Performance/DX not emphasized enough

This `TODO-UPDATES.md` provides:

1. **Realistic assessment** of current state
2. **Prioritized action items** for making Home OS actually usable
3. **Focus on performance** for low-end devices
4. **Developer experience** improvements

**Recommendation**: Use this file for day-to-day development priorities, reference `TODO.md` for long-term vision.

---

## Quick Wins (Can Do This Week)

1. [ ] Add boot timing to `kernel_main.home` (measure each init phase)
2. [ ] Create `tests/` directory with basic smoke tests
3. [ ] Audit `kernel/src/drivers/ata.home` - verify disk I/O works
4. [ ] Test shell in QEMU - document what works/doesn't
5. [ ] Create GitHub issue templates for bug reports

---

*This document will be updated as development progresses.*
