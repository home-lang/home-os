# Multi-Architecture Support

HomeOS is designed to run on multiple CPU architectures, including x86-64, ARM64 (AArch64), and RISC-V. This guide covers the architecture abstraction layer and how to write portable kernel code.

## Overview

Multi-architecture support in HomeOS involves:

- **Architecture Abstraction**: Common interfaces for architecture-specific code
- **Boot Process**: Platform-specific initialization
- **Memory Management**: Architecture-specific paging and memory layout
- **Interrupt Handling**: Different interrupt controllers and handlers
- **Device Support**: Platform-specific device trees and drivers

## Architecture Abstraction Layer

### Common Interfaces

```home
// arch/mod.home - Architecture abstraction module
const arch = switch (builtin.cpu.arch) {
    .x86_64 => @import("x86_64/mod.home"),
    .aarch64 => @import("aarch64/mod.home"),
    .riscv64 => @import("riscv64/mod.home"),
    else => @compileError("Unsupported architecture")
}

// Re-export architecture-specific implementations
pub const cpu = arch.cpu
pub const mmu = arch.mmu
pub const interrupt = arch.interrupt
pub const timer = arch.timer
pub const early_console = arch.early_console

// Common CPU interface that all architectures must implement
pub const CpuInterface = struct {
    // Interrupt control
    enable_interrupts: fn () void,
    disable_interrupts: fn () void,
    interrupts_enabled: fn () bool,

    // CPU identification
    get_cpu_id: fn () u32,
    get_cpu_count: fn () u32,

    // Halt and wait
    halt: fn () void,
    wait_for_interrupt: fn () void,

    // Memory barriers
    memory_barrier: fn () void,
    instruction_barrier: fn () void,

    // Cache operations
    flush_cache: fn (usize, usize) void,
    invalidate_cache: fn (usize, usize) void
}

// Common MMU interface
pub const MmuInterface = struct {
    // Page table operations
    create_page_table: fn () ?*PageTable,
    destroy_page_table: fn (*PageTable) void,
    map_page: fn (*PageTable, usize, usize, u64) i32,
    unmap_page: fn (*PageTable, usize) void,

    // TLB operations
    flush_tlb: fn () void,
    flush_tlb_page: fn (usize) void,

    // Address space switching
    switch_address_space: fn (*PageTable) void,
    get_current_page_table: fn () *PageTable
}
```

### Platform Detection

```home
// Detect platform at runtime
const Platform = enum {
    // x86-64 platforms
    PC,

    // ARM64 platforms
    RaspberryPi4,
    RaspberryPi5,
    QEMU_Virt,

    // RISC-V platforms
    QEMU_Virt_RiscV,
    SiFive_U
}

let current_platform: Platform = undefined

fn detect_platform() {
    switch (builtin.cpu.arch) {
        .x86_64 => {
            current_platform = Platform.PC
        },
        .aarch64 => {
            // Read device tree to identify platform
            let dt = get_device_tree()
            let compatible = dt.get_property("/", "compatible")

            if mem_contains(compatible, "raspberrypi,5") {
                current_platform = Platform.RaspberryPi5
            } else if mem_contains(compatible, "raspberrypi,4") {
                current_platform = Platform.RaspberryPi4
            } else {
                current_platform = Platform.QEMU_Virt
            }
        },
        .riscv64 => {
            let dt = get_device_tree()
            let compatible = dt.get_property("/", "compatible")

            if mem_contains(compatible, "sifive") {
                current_platform = Platform.SiFive_U
            } else {
                current_platform = Platform.QEMU_Virt_RiscV
            }
        },
        else => unreachable
    }
}
```

## x86-64 Architecture

### CPU Operations

```home
// arch/x86_64/cpu.home

pub fn enable_interrupts() {
    asm volatile ("sti")
}

pub fn disable_interrupts() {
    asm volatile ("cli")
}

pub fn interrupts_enabled(): bool {
    var flags: u64 = undefined
    asm volatile ("pushfq; pop %[flags]" : [flags] "=r" (flags))
    return (flags & 0x200) != 0
}

pub fn get_cpu_id(): u32 {
    // Read from APIC ID
    let apic_base = rdmsr(IA32_APIC_BASE) & ~@as(u64, 0xFFF)
    let apic: *volatile u32 = @ptrFromInt(apic_base + 0x20)
    return apic.* >> 24
}

pub fn halt() {
    asm volatile ("hlt")
}

pub fn wait_for_interrupt() {
    asm volatile ("sti; hlt; cli")
}

pub fn memory_barrier() {
    asm volatile ("mfence" ::: "memory")
}

pub fn instruction_barrier() {
    asm volatile ("" ::: "memory")
}

// MSR access
pub fn rdmsr(msr: u32): u64 {
    var low: u32 = undefined
    var high: u32 = undefined
    asm volatile ("rdmsr"
        : [low] "={eax}" (low), [high] "={edx}" (high)
        : [msr] "{ecx}" (msr)
    )
    return (@as(u64, high) << 32) | low
}

pub fn wrmsr(msr: u32, value: u64) {
    let low: u32 = @truncate(value)
    let high: u32 = @truncate(value >> 32)
    asm volatile ("wrmsr"
        :
        : [msr] "{ecx}" (msr),
          [low] "{eax}" (low),
          [high] "{edx}" (high)
    )
}

// Control registers
pub fn read_cr0(): u64 {
    var value: u64 = undefined
    asm volatile ("mov %%cr0, %[value]" : [value] "=r" (value))
    return value
}

pub fn write_cr0(value: u64) {
    asm volatile ("mov %[value], %%cr0" : : [value] "r" (value))
}

pub fn read_cr3(): u64 {
    var value: u64 = undefined
    asm volatile ("mov %%cr3, %[value]" : [value] "=r" (value))
    return value
}

pub fn write_cr3(value: u64) {
    asm volatile ("mov %[value], %%cr3" : : [value] "r" (value))
}
```

### x86-64 Paging

```home
// arch/x86_64/mmu.home

const PAGE_PRESENT = 1 << 0
const PAGE_WRITE = 1 << 1
const PAGE_USER = 1 << 2
const PAGE_PWT = 1 << 3
const PAGE_PCD = 1 << 4
const PAGE_ACCESSED = 1 << 5
const PAGE_DIRTY = 1 << 6
const PAGE_HUGE = 1 << 7
const PAGE_GLOBAL = 1 << 8
const PAGE_NX = 1 << 63

const PageTableEntry = packed struct(u64) {
    present: bool,
    writable: bool,
    user: bool,
    write_through: bool,
    cache_disable: bool,
    accessed: bool,
    dirty: bool,
    huge_page: bool,
    global: bool,
    available: u3,
    addr: u40,
    available2: u11,
    no_execute: bool
}

pub fn create_page_table(): ?*PageTable {
    let phys = pmm.allocate_frame() ?? return null
    let table: *PageTable = @ptrFromInt(phys_to_virt(phys))
    @memset(@ptrCast([*]u8, table), 0, 4096)
    return table
}

pub fn map_page(table: *PageTable, vaddr: usize, paddr: usize, flags: u64): i32 {
    let pml4_idx = (vaddr >> 39) & 0x1FF
    let pdpt_idx = (vaddr >> 30) & 0x1FF
    let pd_idx = (vaddr >> 21) & 0x1FF
    let pt_idx = (vaddr >> 12) & 0x1FF

    // Walk page tables, creating as needed
    let pdpt = get_or_create_table(&table.entries[pml4_idx]) ?? return -ENOMEM
    let pd = get_or_create_table(&pdpt.entries[pdpt_idx]) ?? return -ENOMEM
    let pt = get_or_create_table(&pd.entries[pd_idx]) ?? return -ENOMEM

    // Set the final entry
    pt.entries[pt_idx] = PageTableEntry{
        .present = true,
        .writable = (flags & PAGE_WRITE) != 0,
        .user = (flags & PAGE_USER) != 0,
        .addr = @truncate(paddr >> 12),
        .no_execute = (flags & PAGE_NX) != 0
    }

    return 0
}

pub fn flush_tlb() {
    let cr3 = read_cr3()
    write_cr3(cr3)
}

pub fn flush_tlb_page(vaddr: usize) {
    asm volatile ("invlpg (%[addr])" : : [addr] "r" (vaddr) : "memory")
}

pub fn switch_address_space(table: *PageTable) {
    let phys = virt_to_phys(@intFromPtr(table))
    write_cr3(phys)
}
```

## ARM64 Architecture

### CPU Operations

```home
// arch/aarch64/cpu.home

pub fn enable_interrupts() {
    asm volatile ("msr daifclr, #2")  // Clear IRQ mask
}

pub fn disable_interrupts() {
    asm volatile ("msr daifset, #2")  // Set IRQ mask
}

pub fn interrupts_enabled(): bool {
    var daif: u64 = undefined
    asm volatile ("mrs %[daif], daif" : [daif] "=r" (daif))
    return (daif & 0x80) == 0
}

pub fn get_cpu_id(): u32 {
    var mpidr: u64 = undefined
    asm volatile ("mrs %[mpidr], mpidr_el1" : [mpidr] "=r" (mpidr))
    return @truncate(mpidr & 0xFF)
}

pub fn halt() {
    asm volatile ("wfi")  // Wait For Interrupt
}

pub fn wait_for_interrupt() {
    asm volatile ("wfi")
}

pub fn memory_barrier() {
    asm volatile ("dmb sy" ::: "memory")
}

pub fn instruction_barrier() {
    asm volatile ("isb" ::: "memory")
}

// System registers
pub fn read_sctlr(): u64 {
    var value: u64 = undefined
    asm volatile ("mrs %[value], sctlr_el1" : [value] "=r" (value))
    return value
}

pub fn write_sctlr(value: u64) {
    asm volatile ("msr sctlr_el1, %[value]" : : [value] "r" (value))
    instruction_barrier()
}

pub fn read_ttbr0(): u64 {
    var value: u64 = undefined
    asm volatile ("mrs %[value], ttbr0_el1" : [value] "=r" (value))
    return value
}

pub fn write_ttbr0(value: u64) {
    asm volatile ("msr ttbr0_el1, %[value]" : : [value] "r" (value))
    instruction_barrier()
}

pub fn read_ttbr1(): u64 {
    var value: u64 = undefined
    asm volatile ("mrs %[value], ttbr1_el1" : [value] "=r" (value))
    return value
}

pub fn write_ttbr1(value: u64) {
    asm volatile ("msr ttbr1_el1, %[value]" : : [value] "r" (value))
    instruction_barrier()
}
```

### ARM64 Paging

```home
// arch/aarch64/mmu.home

// Page table descriptors
const DESC_VALID = 1 << 0
const DESC_TABLE = 1 << 1
const DESC_PAGE = 1 << 1
const DESC_AF = 1 << 10      // Access Flag
const DESC_SH_INNER = 3 << 8  // Inner Shareable
const DESC_AP_RW = 0 << 6    // Read/Write
const DESC_AP_RO = 2 << 6    // Read Only
const DESC_AP_USER = 1 << 6  // User accessible
const DESC_UXN = 1 << 54     // User Execute Never
const DESC_PXN = 1 << 53     // Privileged Execute Never

const MAIR_DEVICE = 0x00
const MAIR_NORMAL_NC = 0x44
const MAIR_NORMAL = 0xFF

// ARM64 uses 4KB granule by default
const PAGE_SIZE = 4096
const TABLE_ENTRIES = 512

pub fn create_page_table(): ?*PageTable {
    let phys = pmm.allocate_frame() ?? return null
    let table: *PageTable = @ptrFromInt(phys_to_virt(phys))
    @memset(@ptrCast([*]u8, table), 0, PAGE_SIZE)
    return table
}

pub fn map_page(table: *PageTable, vaddr: usize, paddr: usize, flags: u64): i32 {
    // ARM64 with 4KB pages, 48-bit VA:
    // Level 0: bits 47:39
    // Level 1: bits 38:30
    // Level 2: bits 29:21
    // Level 3: bits 20:12

    let l0_idx = (vaddr >> 39) & 0x1FF
    let l1_idx = (vaddr >> 30) & 0x1FF
    let l2_idx = (vaddr >> 21) & 0x1FF
    let l3_idx = (vaddr >> 12) & 0x1FF

    let l1_table = get_or_create_table(&table.entries[l0_idx]) ?? return -ENOMEM
    let l2_table = get_or_create_table(&l1_table.entries[l1_idx]) ?? return -ENOMEM
    let l3_table = get_or_create_table(&l2_table.entries[l2_idx]) ?? return -ENOMEM

    // Create page descriptor
    var desc: u64 = DESC_VALID | DESC_PAGE | DESC_AF | DESC_SH_INNER
    desc |= (paddr & 0x0000FFFFFFFFF000)  // Physical address
    desc |= (flags & 0xFFFF000000000FFF)  // Attributes

    l3_table.entries[l3_idx] = desc

    return 0
}

pub fn flush_tlb() {
    asm volatile (
        "dsb ishst\n"
        "tlbi vmalle1is\n"
        "dsb ish\n"
        "isb"
    )
}

pub fn flush_tlb_page(vaddr: usize) {
    let shifted = vaddr >> 12
    asm volatile (
        "dsb ishst\n"
        "tlbi vaae1is, %[addr]\n"
        "dsb ish\n"
        "isb"
        : : [addr] "r" (shifted)
    )
}

pub fn switch_address_space(table: *PageTable) {
    let phys = virt_to_phys(@intFromPtr(table))
    write_ttbr0(phys)
    flush_tlb()
}
```

### GIC (Generic Interrupt Controller)

```home
// arch/aarch64/gic.home

const GIC_DIST_BASE = 0x08000000  // Platform-specific
const GIC_CPU_BASE = 0x08010000

// Distributor registers
const GICD_CTLR = 0x000
const GICD_TYPER = 0x004
const GICD_ISENABLER = 0x100
const GICD_ICENABLER = 0x180
const GICD_ISPENDR = 0x200
const GICD_ICPENDR = 0x280
const GICD_IPRIORITYR = 0x400
const GICD_ITARGETSR = 0x800
const GICD_ICFGR = 0xC00

// CPU interface registers
const GICC_CTLR = 0x000
const GICC_PMR = 0x004
const GICC_IAR = 0x00C
const GICC_EOIR = 0x010

fn gic_dist_read(offset: u32): u32 {
    let addr: *volatile u32 = @ptrFromInt(GIC_DIST_BASE + offset)
    return addr.*
}

fn gic_dist_write(offset: u32, value: u32) {
    let addr: *volatile u32 = @ptrFromInt(GIC_DIST_BASE + offset)
    addr.* = value
}

fn gic_cpu_read(offset: u32): u32 {
    let addr: *volatile u32 = @ptrFromInt(GIC_CPU_BASE + offset)
    return addr.*
}

fn gic_cpu_write(offset: u32, value: u32) {
    let addr: *volatile u32 = @ptrFromInt(GIC_CPU_BASE + offset)
    addr.* = value
}

pub fn gic_init() {
    // Disable distributor
    gic_dist_write(GICD_CTLR, 0)

    // Get number of interrupts
    let typer = gic_dist_read(GICD_TYPER)
    let num_irqs = ((typer & 0x1F) + 1) * 32

    // Disable all interrupts
    for i in 0..(num_irqs / 32) {
        gic_dist_write(GICD_ICENABLER + i * 4, 0xFFFFFFFF)
    }

    // Set all interrupts to lowest priority
    for i in 0..(num_irqs / 4) {
        gic_dist_write(GICD_IPRIORITYR + i * 4, 0xA0A0A0A0)
    }

    // Target all interrupts to CPU 0
    for i in 0..(num_irqs / 4) {
        gic_dist_write(GICD_ITARGETSR + i * 4, 0x01010101)
    }

    // Enable distributor
    gic_dist_write(GICD_CTLR, 1)

    // Configure CPU interface
    gic_cpu_write(GICC_PMR, 0xFF)  // Allow all priorities
    gic_cpu_write(GICC_CTLR, 1)    // Enable CPU interface
}

pub fn gic_enable_irq(irq: u32) {
    let reg = irq / 32
    let bit = irq % 32
    gic_dist_write(GICD_ISENABLER + reg * 4, 1 << bit)
}

pub fn gic_disable_irq(irq: u32) {
    let reg = irq / 32
    let bit = irq % 32
    gic_dist_write(GICD_ICENABLER + reg * 4, 1 << bit)
}

pub fn gic_get_irq(): u32 {
    return gic_cpu_read(GICC_IAR) & 0x3FF
}

pub fn gic_eoi(irq: u32) {
    gic_cpu_write(GICC_EOIR, irq)
}
```

## RISC-V Architecture

### CPU Operations

```home
// arch/riscv64/cpu.home

pub fn enable_interrupts() {
    // Set SIE bit in sstatus
    asm volatile ("csrsi sstatus, 2")
}

pub fn disable_interrupts() {
    // Clear SIE bit in sstatus
    asm volatile ("csrci sstatus, 2")
}

pub fn interrupts_enabled(): bool {
    var sstatus: u64 = undefined
    asm volatile ("csrr %[sstatus], sstatus" : [sstatus] "=r" (sstatus))
    return (sstatus & 2) != 0
}

pub fn get_cpu_id(): u32 {
    var hartid: u64 = undefined
    asm volatile ("csrr %[hartid], mhartid" : [hartid] "=r" (hartid))
    return @truncate(hartid)
}

pub fn halt() {
    asm volatile ("wfi")
}

pub fn wait_for_interrupt() {
    asm volatile ("wfi")
}

pub fn memory_barrier() {
    asm volatile ("fence rw, rw" ::: "memory")
}

pub fn instruction_barrier() {
    asm volatile ("fence.i" ::: "memory")
}

// CSR access
pub fn read_satp(): u64 {
    var value: u64 = undefined
    asm volatile ("csrr %[value], satp" : [value] "=r" (value))
    return value
}

pub fn write_satp(value: u64) {
    asm volatile ("csrw satp, %[value]" : : [value] "r" (value))
    asm volatile ("sfence.vma")
}

pub fn read_stvec(): u64 {
    var value: u64 = undefined
    asm volatile ("csrr %[value], stvec" : [value] "=r" (value))
    return value
}

pub fn write_stvec(value: u64) {
    asm volatile ("csrw stvec, %[value]" : : [value] "r" (value))
}

pub fn read_scause(): u64 {
    var value: u64 = undefined
    asm volatile ("csrr %[value], scause" : [value] "=r" (value))
    return value
}

pub fn read_stval(): u64 {
    var value: u64 = undefined
    asm volatile ("csrr %[value], stval" : [value] "=r" (value))
    return value
}
```

### RISC-V Paging

```home
// arch/riscv64/mmu.home

// Sv48 paging mode (48-bit virtual address)
const SATP_MODE_SV48 = 9 << 60

// Page table entry flags
const PTE_V = 1 << 0   // Valid
const PTE_R = 1 << 1   // Readable
const PTE_W = 1 << 2   // Writable
const PTE_X = 1 << 3   // Executable
const PTE_U = 1 << 4   // User accessible
const PTE_G = 1 << 5   // Global
const PTE_A = 1 << 6   // Accessed
const PTE_D = 1 << 7   // Dirty

const PageTableEntry = packed struct(u64) {
    flags: u10,
    rsw: u2,
    ppn0: u9,
    ppn1: u9,
    ppn2: u26,
    reserved: u8
}

pub fn create_page_table(): ?*PageTable {
    let phys = pmm.allocate_frame() ?? return null
    let table: *PageTable = @ptrFromInt(phys_to_virt(phys))
    @memset(@ptrCast([*]u8, table), 0, 4096)
    return table
}

pub fn map_page(table: *PageTable, vaddr: usize, paddr: usize, flags: u64): i32 {
    // Sv48: 4 levels
    // VPN[3]: bits 47:39
    // VPN[2]: bits 38:30
    // VPN[1]: bits 29:21
    // VPN[0]: bits 20:12

    let vpn3 = (vaddr >> 39) & 0x1FF
    let vpn2 = (vaddr >> 30) & 0x1FF
    let vpn1 = (vaddr >> 21) & 0x1FF
    let vpn0 = (vaddr >> 12) & 0x1FF

    let l2 = get_or_create_table(&table.entries[vpn3]) ?? return -ENOMEM
    let l1 = get_or_create_table(&l2.entries[vpn2]) ?? return -ENOMEM
    let l0 = get_or_create_table(&l1.entries[vpn1]) ?? return -ENOMEM

    // Create leaf PTE
    let ppn = paddr >> 12
    let pte_flags = flags | PTE_V | PTE_A | PTE_D

    l0.entries[vpn0] = @bitCast(PageTableEntry, (ppn << 10) | pte_flags)

    return 0
}

pub fn flush_tlb() {
    asm volatile ("sfence.vma")
}

pub fn flush_tlb_page(vaddr: usize) {
    asm volatile ("sfence.vma %[addr], zero" : : [addr] "r" (vaddr))
}

pub fn switch_address_space(table: *PageTable) {
    let phys = virt_to_phys(@intFromPtr(table))
    let ppn = phys >> 12
    let satp = SATP_MODE_SV48 | ppn
    write_satp(satp)
}
```

## Cross-Platform Code

### Writing Portable Code

```home
// Example: Portable spinlock implementation
const Spinlock = struct {
    locked: u32,

    pub fn init(): Spinlock {
        return Spinlock{ .locked = 0 }
    }

    pub fn lock(self: *Spinlock) {
        while (true) {
            // Use architecture-appropriate atomic
            if (@atomicRmw(u32, &self.locked, .Xchg, 1, .Acquire) == 0) {
                break
            }

            // Spin hint - architecture specific
            arch.cpu.spin_hint()
        }
    }

    pub fn unlock(self: *Spinlock) {
        @atomicStore(u32, &self.locked, 0, .Release)
    }
}

// Architecture-specific spin hints
// x86_64
pub fn spin_hint() {
    asm volatile ("pause")
}

// ARM64
pub fn spin_hint() {
    asm volatile ("yield")
}

// RISC-V (no hint instruction, just barrier)
pub fn spin_hint() {
    asm volatile ("" ::: "memory")
}
```

### Platform-Specific Drivers

```home
// Conditional compilation for platform-specific code
const serial = switch (current_platform) {
    .PC => @import("drivers/serial/ns16550.home"),
    .RaspberryPi4, .RaspberryPi5 => @import("drivers/serial/pl011.home"),
    .QEMU_Virt => @import("drivers/serial/pl011.home"),
    .QEMU_Virt_RiscV, .SiFive_U => @import("drivers/serial/ns16550.home")
}

// Generic serial interface
pub const Serial = struct {
    write: fn ([]const u8) void,
    read: fn () ?u8,
    init: fn () void
}

// Platform detection in device tree
fn probe_devices_from_dt() {
    let dt = get_device_tree()

    // Iterate compatible strings
    for node in dt.nodes() {
        let compatible = node.get_property("compatible") ?? continue

        if mem_contains(compatible, "ns16550a") {
            let base = node.get_reg_base()
            ns16550_init(base)
        } else if mem_contains(compatible, "arm,pl011") {
            let base = node.get_reg_base()
            pl011_init(base)
        }
        // ... other devices
    }
}
```

## Summary

Multi-architecture support in HomeOS provides:

- **Architecture Abstraction**: Common interfaces for CPU, MMU, and interrupts
- **x86-64**: Full support with 4-level paging and APIC
- **ARM64**: Support for Raspberry Pi and QEMU with GIC
- **RISC-V**: Sv48 paging with standard interrupt handling
- **Portable Code**: Guidelines for writing cross-platform kernel code
- **Device Trees**: Platform detection and device discovery

All architecture-specific code is written in the Home programming language, with clear separation between portable and platform-specific components.
