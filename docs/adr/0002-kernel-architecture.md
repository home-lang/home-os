# ADR 0002: Microkernel vs Monolithic Kernel Architecture

**Status**: Accepted
**Date**: 2025-11-24
**Decision Makers**: Core Team
**Tags**: `architecture`, `kernel`, `design`

---

## Context

We need to decide on the fundamental kernel architecture for home-os. This affects system performance, security, maintainability, and development complexity.

### Options Considered

1. **Monolithic Kernel** (Linux-style)
2. **Microkernel** (Minix-style)
3. **Hybrid Kernel** (macOS/Windows-style)
4. **Exokernel** (Research OS)

---

## Decision

**We will use a pragmatic hybrid/modular monolithic kernel architecture.**

Key characteristics:
- Core kernel services run in kernel space
- Drivers can be loaded as modules
- Performance-critical code in kernel
- Optional isolation boundaries for security

---

## Rationale

### Why Hybrid/Modular Monolithic?

**Performance Requirements**
- Target: <3s boot time on Pi 4
- Need: Low IPC overhead
- Reality: Monolithic faster for embedded

**Development Velocity**
- Simpler than pure microkernel
- Easier debugging (single address space)
- Faster iteration cycles

**Flexibility**
- Can run drivers in-kernel or as modules
- Security boundaries where needed
- Not locked into pure microkernel dogma

### Architecture Details

```
┌─────────────────────────────────────┐
│         Userspace Applications      │
├─────────────────────────────────────┤
│  System Libraries & Runtime         │
├─────────────────────────────────────┤
│        System Call Interface        │
├═════════════════════════════════════┤ ← Privilege Boundary
│                                     │
│         Kernel Core                 │
│  - Process Management               │
│  - Memory Management (PMM/VMM)      │
│  - Scheduler                        │
│  - Syscall Handler                  │
│                                     │
├─────────────────────────────────────┤
│                                     │
│    Built-in Critical Drivers        │
│  - Timer                            │
│  - Interrupt Controller (GIC)      │
│  - Serial (Debug)                   │
│                                     │
├─────────────────────────────────────┤
│                                     │
│      Loadable Driver Modules        │
│  - Storage (EMMC, SD/MMC)          │
│  - Network (WiFi, Ethernet)         │
│  - USB (xHCI)                       │
│  - Display (Framebuffer)            │
│                                     │
└─────────────────────────────────────┘
```

### Comparison with Alternatives

**vs Pure Monolithic (Linux)**
- ✅ More modular (Home wins)
- ❌ Performance (Linux wins - decades of optimization)
- ✅ Simpler codebase (Home wins - smaller)
- ✅ Security (Home wins - can add isolation)

**vs Pure Microkernel (Minix)**
- ✅ Performance (Home wins - less IPC)
- ❌ Security (Minix wins - strong isolation)
- ✅ Development speed (Home wins)
- ✅ Debugging (Home wins - simpler)

**vs Hybrid (macOS/Windows)**
- ≈ Performance (tie)
- ✅ Simplicity (Home wins - cleaner design)
- ❌ Maturity (macOS/Windows win)
- ✅ Transparency (Home wins - open source)

---

## Consequences

### Positive

1. **Fast IPC**: In-kernel drivers = function calls, not message passing
2. **Easier Debugging**: Single address space, simple stack traces
3. **Better Performance**: No context switch overhead for drivers
4. **Faster Development**: Write, compile, test cycle is quick
5. **Flexibility**: Can isolate drivers later if needed

### Negative

1. **Driver Crashes**: Can crash kernel (mitigated by restart/isolation)
2. **Security**: Larger attack surface than microkernel
3. **Memory Usage**: All drivers in kernel memory

### Mitigations

**For Driver Crashes**:
- Extensive testing (unit + integration)
- Memory safety (Home language)
- Watchdog timers
- Kernel panic handler with recovery

**For Security**:
- Seccomp-BPF syscall filtering
- Stack canaries
- Kernel/user address separation (KPTI)
- Code audit tooling

**For Memory**:
- Module unloading (when not in use)
- Lazy loading (load drivers on demand)
- Memory budgets (<50MB kernel target)

---

## Implementation

### Core Kernel (Always Loaded)

**Location**: `kernel/src/core/`
- `process.home` - Process management
- `memory.home` - PMM/VMM
- `scheduler.home` - Task scheduler
- `syscall.home` - Syscall interface

### Critical Drivers (Built-in)

**Location**: `kernel/src/arch/arm64/`
- `exceptions.home` - Exception handling
- `timer.home` - ARM Generic Timer
- `gic400.home` / `gic600.home` - Interrupt controllers

### Loadable Modules

**Location**: `kernel/src/drivers/`
- Storage: `bcm_emmc.home`, `sdmmc.home`
- Network: `cyw43455.home` (WiFi/BT)
- USB: `usb_xhci.home`
- Display: `fb_console.home`

### Module Loading

```home
// Driver module structure
struct DriverModule {
  name: [64]u8
  init_fn: fn(): u32
  exit_fn: fn(): u32
  dependencies: [8]u32
  priority: u32
  loaded: u32
}

// Load driver
export fn driver_load(module: *DriverModule): u32 {
  // Check dependencies
  // Call init_fn
  // Mark as loaded
}
```

---

## Security Model

### Privilege Levels

**ARM64 Exception Levels**:
- EL0: Userspace applications (unprivileged)
- EL1: Kernel + drivers (privileged)
- EL2: Hypervisor (not used)
- EL3: Secure monitor (not used)

### Isolation Boundaries

1. **Kernel/User Separation**
   - KPTI (Kernel Page Table Isolation)
   - Separate page tables
   - Copy-to/from-user validation

2. **Driver Sandboxing** (Future)
   - Optional driver isolation domains
   - Fault recovery
   - Resource limits

---

## Performance Targets

| Metric | Target | Rationale |
|--------|--------|-----------|
| Syscall overhead | <1μs | Function call, not IPC |
| Context switch | <5μs | Simple scheduler |
| IRQ latency | <10μs | Direct handler dispatch |
| Boot time | <3s | Parallel driver init |

---

## Evolution Path

### Phase 1 (Current): Monolithic Core
- All drivers in kernel space
- Single address space
- Function call interfaces

### Phase 2 (Future): Optional Isolation
- Flag drivers as isolated
- Run in separate address spaces
- IPC for isolated drivers only

### Phase 3 (Future): Full Capability System
- Capability-based security
- Fine-grained access control
- Revocable permissions

---

## Related Decisions

- [ADR-0001](0001-use-home-language-for-os.md) - Programming language choice
- [ADR-0003](0003-memory-management.md) - Memory management design
- [ADR-0004](0004-driver-model.md) - Driver development model
- [ADR-0006](0006-security-architecture.md) - Security design

---

## References

**Papers**:
- "The Performance of μ-Kernel-Based Systems" (Liedtke, 1995)
- "Linux Kernel Development" (Love, 2010)
- "Design and Implementation of the FreeBSD Operating System" (McKusick, 2014)

**Existing Systems**:
- Linux (monolithic with modules)
- Minix 3 (microkernel)
- macOS (hybrid)

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-24 | Core Team | Initial decision |
