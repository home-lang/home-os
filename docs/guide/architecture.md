# Kernel Architecture

HomeOS uses a **hybrid/modular monolithic kernel architecture** that balances performance with modularity. This document covers the core kernel design and internals.

## Architecture Overview

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
│  - Interrupt Controller (GIC)       │
│  - Serial (Debug)                   │
│                                     │
├─────────────────────────────────────┤
│                                     │
│      Loadable Driver Modules        │
│  - Storage (EMMC, SD/MMC)           │
│  - Network (WiFi, Ethernet)         │
│  - USB (xHCI)                       │
│  - Display (Framebuffer)            │
│                                     │
└─────────────────────────────────────┘
```

## Memory Management

HomeOS implements a multi-tier memory management system optimized for embedded systems like the Raspberry Pi.

### Physical Memory Manager (PMM)

The PMM uses a **buddy allocator** for efficient page-sized allocations.

**Features:**
- O(log n) allocation/deallocation
- Low fragmentation with coalescing
- Orders: 4KB, 8KB, 16KB, ..., 4MB

```home
const BUDDY_MIN_ORDER: u32 = 0   // 4KB
const BUDDY_MAX_ORDER: u32 = 10  // 4MB

struct BuddyAllocator {
  free_lists: [BUDDY_MAX_ORDER]FreeList
  bitmap: *u8
  total_pages: u64
  free_pages: u64
}
```

**Location:** `kernel/src/mm/pmm.home`

### Virtual Memory Manager (VMM)

The VMM uses **4-level page tables** for ARM64 with full KPTI support.

**Configuration:**
- Page size: 4KB (configurable 4KB/16KB/64KB)
- Address space: 48-bit (256TB)
- Kernel space: Upper half (0xFFFF000000000000+)
- User space: Lower half (0x0000000000000000-0x0000FFFFFFFFFFFF)

**Features:**
- KPTI (Kernel Page Table Isolation)
- ASID (Address Space Identifiers)
- TLB management with lazy shootdowns
- Identity mapping for kernel

**Location:** `kernel/src/arch/arm64/mmu.home`

### Kernel Allocators

#### Slab Allocator

For variable-sized kernel objects with per-CPU caching.

```home
struct SlabCache {
  object_size: u32
  objects_per_slab: u32
  magazines: [MAX_CPUS]SlabMagazine
  slabs_full: *Slab
  slabs_partial: *Slab
  slabs_empty: *Slab
}
```

**Common sizes:** 16, 32, 64, 128, 256, 512, 1024, 2048, 4096 bytes

**Location:** `kernel/src/mm/slab.home`

#### Memory Pools

Fixed-size object pools for fast O(1) allocation.

- 13 pre-allocated pools (16B-4KB)
- Reduced fragmentation
- Fast allocation without locks

**Location:** `kernel/src/mm/pool.home`

### ZRAM (Compressed Swap)

HomeOS uses ZRAM for swap instead of disk-based swap, perfect for SD card-based systems.

**Features:**
- 2-3x compression ratio
- No disk I/O required
- LZ4-style compression
- Max size: 512MB

**Location:** `kernel/src/mm/zram.home`

### Memory Layout (ARM64)

```
0xFFFFFFFFFFFFFFFF ┐
                   │ Kernel Space (Upper Half)
                   │ - Kernel code/data
                   │ - Driver memory
                   │ - MMIO mappings
0xFFFF000000000000 ├─ KPTI Boundary
                   │
0x0000FFFFFFFFFFFF ┐
                   │ User Space (Lower Half)
                   │ - Process memory
                   │ - Heap
                   │ - Stack
0x0000000000000000 ┘
```

## Process Scheduling

HomeOS implements two schedulers for different workloads.

### Completely Fair Scheduler (CFS)

The default scheduler for general-purpose workloads.

**Features:**
- Virtual runtime tracking
- Red-black tree for task ordering
- Automatic load balancing
- Nice values (-20 to +19)
- Group scheduling support

**Location:** `kernel/src/sched/cfs.home`

### Real-Time Scheduler

For time-critical tasks requiring deterministic latency.

**Policies:**
- `SCHED_FIFO` - First-in, first-out
- `SCHED_RR` - Round-robin with time slices
- Priority levels: 0-99 (higher = more priority)

**Latency targets:**
- Context switch: <5us
- IRQ latency: <10us

**Location:** `kernel/src/sched/rt.home`

### Multi-Core SMP

HomeOS supports symmetric multiprocessing on all 4 cores of the Raspberry Pi 5.

**Features:**
- Per-CPU run queues
- Work stealing for load balancing
- Spinlock-based synchronization
- Core affinity support

## Interrupt Handling

### ARM64 (GIC-400/GIC-600)

HomeOS supports both GIC-400 (Pi 4) and GIC-600 (Pi 5) interrupt controllers.

**Features:**
- IRQ prioritization (256 levels)
- CPU targeting
- Software-generated interrupts (SGI)
- Per-CPU private interrupts (PPI)
- Shared peripheral interrupts (SPI)

**Location:** `kernel/src/arch/arm64/gic400.home`, `kernel/src/arch/arm64/gic600.home`

### x86-64 (IDT)

Standard interrupt descriptor table with APIC support.

**Features:**
- 256 interrupt vectors
- Exception handlers (0-31)
- IRQ handlers (32-255)
- APIC timer support

**Location:** `kernel/src/arch/x86_64/idt.home`

### Exception Levels (ARM64)

```
EL3: Secure Monitor (not used)
EL2: Hypervisor (boot only, drops to EL1)
EL1: Kernel (privileged)
EL0: Userspace (unprivileged)
```

## System Calls

HomeOS provides a POSIX-compatible syscall interface.

### Calling Convention

**ARM64:**
- Syscall number: X8
- Arguments: X0, X1, X2, X3, X4, X5
- Return value: X0
- Instruction: `svc #0`

**x86-64:**
- Syscall number: RAX
- Arguments: RDI, RSI, RDX, R10, R8, R9
- Return value: RAX
- Instruction: `syscall`

### Implemented System Calls

HomeOS implements 100+ system calls including:

| Category | System Calls |
|----------|-------------|
| Process | fork, exec, exit, wait, getpid, kill |
| File I/O | open, close, read, write, lseek, stat |
| Memory | mmap, munmap, mprotect, brk |
| Network | socket, bind, listen, accept, connect, send, recv |
| Time | gettimeofday, clock_gettime, nanosleep |
| Signals | sigaction, sigprocmask, sigsuspend |

**Full reference:** [System Call Reference](/api/syscalls)

## Boot Sequence

### ARM64 (Raspberry Pi 5)

1. **GPU Bootloader** (ROM)
   - Loads `bootcode.bin` from SD card

2. **GPU Bootloader** (stage 2)
   - Loads `start4.elf` firmware
   - Initializes hardware

3. **Firmware** (`start4.elf`)
   - Reads `config.txt`
   - Loads device tree (`bcm2712-rpi-5-b.dtb`)
   - Loads kernel (`home-kernel.img`) to 0x80000
   - Starts CPU core 0 at 0x80000 in EL2 mode

4. **Boot Assembly** (`boot.s`)
   - Drops from EL2 to EL1
   - Sets up page tables
   - Enables MMU
   - Clears BSS
   - Sets up stack
   - Calls `kernel_main(dtb_addr)`

5. **Kernel Main** (`rpi5_main.home`)
   - Initializes serial console
   - Parses device tree
   - Initializes memory management
   - Initializes interrupt controller
   - Starts scheduler
   - Launches init process

### x86-64

1. **GRUB2** loads kernel via Multiboot2
2. Kernel starts in protected mode
3. Switches to long mode (64-bit)
4. Sets up GDT, IDT, page tables
5. Initializes kernel subsystems

## Performance Targets

| Metric | Target | Rationale |
|--------|--------|-----------|
| Syscall overhead | <1us | Function call, not IPC |
| Context switch | <5us | Simple scheduler |
| IRQ latency | <10us | Direct handler dispatch |
| Boot time | <3s | Parallel driver init |

## Memory Budgets

| System | RAM | Kernel Budget | User Space |
|--------|-----|---------------|------------|
| Pi 3 B+ | 1GB | <96MB | ~900MB |
| Pi 4 (4GB) | 4GB | <128MB | ~3.9GB |
| Pi 5 (8GB) | 8GB | <192MB | ~7.8GB |

## Security Features

- **ASLR** - Address Space Layout Randomization
- **Stack Canaries** - Buffer overflow detection
- **KPTI** - Kernel Page Table Isolation
- **W^X** - Write XOR Execute enforcement
- **Capabilities** - Fine-grained privilege control
- **Seccomp-BPF** - Syscall filtering
- **Guard Pages** - Memory access protection

## Related Documentation

- [System Call Reference](/api/syscalls)
- [Driver API](/api/drivers)
- [File Systems](/guide/filesystems)
