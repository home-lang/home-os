# Debugging Kernel

This guide covers kernel debugging techniques for HomeOS, including built-in debugging facilities, using debuggers, analyzing crashes, and troubleshooting common issues.

## Overview

Kernel debugging in HomeOS involves:

- **Kernel Logging**: Console and serial debug output
- **Debug Assertions**: Runtime checks and panic handling
- **Memory Debugging**: KASAN, use-after-free detection
- **Hardware Debugging**: JTAG, serial console, QEMU integration
- **Crash Analysis**: Stack traces, register dumps, core dumps

## Kernel Logging

### Log Levels and Output

```home
import kernel/printk

const LogLevel = enum(u3) {
    Emergency = 0,  // System is unusable
    Alert = 1,      // Action must be taken immediately
    Critical = 2,   // Critical conditions
    Error = 3,      // Error conditions
    Warning = 4,    // Warning conditions
    Notice = 5,     // Normal but significant
    Info = 6,       // Informational
    Debug = 7       // Debug-level messages
}

// Current log level threshold
let console_loglevel: LogLevel = LogLevel.Warning
let default_message_loglevel: LogLevel = LogLevel.Warning

export fn printk(level: LogLevel, comptime fmt: []const u8, args: anytype) {
    // Format message
    var buf: [1024]u8 = undefined
    let len = format(&buf, fmt, args)

    // Add to kernel log buffer
    klog_buffer.write(level, buf[0..len])

    // Output to console if level is high enough
    if @intFromEnum(level) <= @intFromEnum(console_loglevel) {
        console_write(buf[0..len])
    }

    // Output to serial for debugging
    serial_write(buf[0..len])
}

// Convenience macros
pub fn pr_emerg(comptime fmt: []const u8, args: anytype) {
    printk(LogLevel.Emergency, fmt, args)
}

pub fn pr_err(comptime fmt: []const u8, args: anytype) {
    printk(LogLevel.Error, fmt, args)
}

pub fn pr_warn(comptime fmt: []const u8, args: anytype) {
    printk(LogLevel.Warning, fmt, args)
}

pub fn pr_info(comptime fmt: []const u8, args: anytype) {
    printk(LogLevel.Info, fmt, args)
}

pub fn pr_debug(comptime fmt: []const u8, args: anytype) {
    if DEBUG {
        printk(LogLevel.Debug, fmt, args)
    }
}

// Kernel log ring buffer
const KlogEntry = struct {
    timestamp: u64,
    level: LogLevel,
    facility: u8,
    len: u16,
    text: [512]u8
}

const KLOG_BUFFER_SIZE = 1024

let klog_buffer: struct {
    entries: [KLOG_BUFFER_SIZE]KlogEntry,
    head: u32,
    tail: u32,
    seq: u64
} = undefined

export fn dmesg(buf: []u8): isize {
    var written: usize = 0
    var idx = klog_buffer.tail

    while idx != klog_buffer.head and written < buf.len {
        let entry = &klog_buffer.entries[idx % KLOG_BUFFER_SIZE]

        // Format: [timestamp] level: message
        let line_len = format(&buf[written..],
            "[{d:>10}.{d:06}] {s}\n",
            entry.timestamp / 1000000000,
            (entry.timestamp / 1000) % 1000000,
            entry.text[0..entry.len])

        written += line_len
        idx += 1
    }

    return written
}
```

### Dynamic Debug

```home
// Enable debug output per-file or per-function
const DebugDescriptor = struct {
    filename: []const u8,
    function: []const u8,
    line: u32,
    enabled: bool
}

let debug_descriptors: ArrayList(DebugDescriptor) = undefined

pub fn dynamic_debug(comptime file: []const u8, comptime func: []const u8, line: u32, comptime fmt: []const u8, args: anytype) {
    // Check if this debug point is enabled
    for desc in debug_descriptors.items {
        if matches(desc, file, func, line) and desc.enabled {
            printk(LogLevel.Debug, "[{s}:{d}] {s}: " ++ fmt, file, line, func, args)
            return
        }
    }
}

// Control interface
export fn enable_debug(pattern: []const u8) {
    for desc in &debug_descriptors.items {
        if matches_pattern(desc, pattern) {
            desc.enabled = true
        }
    }
}

export fn disable_debug(pattern: []const u8) {
    for desc in &debug_descriptors.items {
        if matches_pattern(desc, pattern) {
            desc.enabled = false
        }
    }
}

// Usage
fn some_function() {
    dynamic_debug(@src().file, @src().fn_name, @src().line, "value = {}\n", value)
}
```

## Debug Assertions

### Kernel Assertions

```home
// Assert with message
pub fn assert(condition: bool, comptime msg: []const u8) {
    if !condition {
        kernel_panic("Assertion failed: " ++ msg)
    }
}

pub fn assert_fmt(condition: bool, comptime fmt: []const u8, args: anytype) {
    if !condition {
        var buf: [256]u8 = undefined
        let len = format(&buf, fmt, args)
        kernel_panic_msg(&buf[0..len])
    }
}

// Debug-only assertions (compiled out in release)
pub fn debug_assert(condition: bool, comptime msg: []const u8) {
    if (DEBUG) {
        assert(condition, msg)
    }
}

// BUG() - for impossible conditions
pub fn BUG() noreturn {
    kernel_panic("BUG: impossible condition reached")
}

pub fn BUG_ON(condition: bool) {
    if (condition) {
        BUG()
    }
}

// WARN() - print warning but continue
pub fn WARN(comptime msg: []const u8) {
    pr_warn("WARNING: " ++ msg ++ "\n")
    dump_stack()
}

pub fn WARN_ON(condition: bool) {
    if (condition) {
        WARN("condition triggered")
    }
}

pub fn WARN_ON_ONCE(condition: bool) {
    const warned = struct {
        var value: bool = false
    }

    if (condition and !warned.value) {
        warned.value = true
        WARN("condition triggered (once)")
    }
}
```

### Panic Handling

```home
const PanicInfo = struct {
    message: []const u8,
    file: []const u8,
    line: u32,
    registers: RegisterContext,
    stack_trace: [32]usize
}

let panic_cpu: i32 = -1
let panic_info: PanicInfo = undefined

export fn kernel_panic(comptime msg: []const u8) noreturn {
    // Disable interrupts
    cpu.cli()

    // Prevent recursive panics
    let cpu_id = get_current_cpu()
    if @atomicRmw(i32, &panic_cpu, .Xchg, cpu_id, .SeqCst) != -1 {
        // Another CPU is panicking
        loop {
            cpu.hlt()
        }
    }

    // Save panic info
    panic_info.message = msg
    panic_info.file = @src().file
    panic_info.line = @src().line

    // Save registers
    save_registers(&panic_info.registers)

    // Capture stack trace
    capture_stack_trace(&panic_info.stack_trace)

    // Print panic message
    console_force_unlock()
    serial_force_unlock()

    pr_emerg("\n")
    pr_emerg("================================================================================\n")
    pr_emerg("KERNEL PANIC: {s}\n", msg)
    pr_emerg("================================================================================\n")
    pr_emerg("\n")

    // Print register state
    print_registers(&panic_info.registers)

    // Print stack trace
    pr_emerg("\nStack trace:\n")
    print_stack_trace(&panic_info.stack_trace)

    // Print loaded modules
    pr_emerg("\nLoaded modules:\n")
    print_modules()

    // Stop other CPUs
    smp_send_stop()

    // Wait for debugger or reboot
    if debugger_connected() {
        pr_emerg("\nDropping to debugger...\n")
        debugger_break()
    } else {
        pr_emerg("\nSystem halted. Press reset to reboot.\n")
    }

    loop {
        cpu.hlt()
    }
}

fn capture_stack_trace(trace: *[32]usize) {
    var frame_ptr: usize = undefined
    asm volatile ("mov %%rbp, %[fp]" : [fp] "=r" (frame_ptr))

    var i: usize = 0
    while i < 32 and frame_ptr != 0 and frame_ptr < KERNEL_STACK_TOP {
        let return_addr: *usize = @ptrFromInt(frame_ptr + 8)
        trace[i] = return_addr.*

        let next_frame: *usize = @ptrFromInt(frame_ptr)
        frame_ptr = next_frame.*
        i += 1
    }

    while i < 32 {
        trace[i] = 0
        i += 1
    }
}

fn print_stack_trace(trace: *[32]usize) {
    for i in 0..32 {
        if trace[i] == 0 {
            break
        }

        let sym = lookup_symbol(trace[i])
        if sym != null {
            pr_emerg("  [{x:016}] {s}+{x}\n", trace[i], sym.name, trace[i] - sym.addr)
        } else {
            pr_emerg("  [{x:016}] ???\n", trace[i])
        }
    }
}

fn print_registers(regs: *RegisterContext) {
    pr_emerg("Registers:\n")
    pr_emerg("  RAX: {x:016}  RBX: {x:016}  RCX: {x:016}\n", regs.rax, regs.rbx, regs.rcx)
    pr_emerg("  RDX: {x:016}  RSI: {x:016}  RDI: {x:016}\n", regs.rdx, regs.rsi, regs.rdi)
    pr_emerg("  RBP: {x:016}  RSP: {x:016}  R8:  {x:016}\n", regs.rbp, regs.rsp, regs.r8)
    pr_emerg("  R9:  {x:016}  R10: {x:016}  R11: {x:016}\n", regs.r9, regs.r10, regs.r11)
    pr_emerg("  R12: {x:016}  R13: {x:016}  R14: {x:016}\n", regs.r12, regs.r13, regs.r14)
    pr_emerg("  R15: {x:016}  RIP: {x:016}  RFLAGS: {x:016}\n", regs.r15, regs.rip, regs.rflags)
    pr_emerg("  CR2: {x:016}  CR3: {x:016}\n", cpu.read_cr2(), cpu.read_cr3())
}
```

## Memory Debugging

### KASAN (Kernel Address Sanitizer)

```home
// KASAN shadow memory layout
// For each 8 bytes of memory, 1 byte of shadow memory
const KASAN_SHADOW_SCALE = 3  // 8 bytes per shadow byte
const KASAN_SHADOW_OFFSET = 0xDFFF800000000000

fn kasan_mem_to_shadow(addr: usize): *u8 {
    return @ptrFromInt((addr >> KASAN_SHADOW_SCALE) + KASAN_SHADOW_OFFSET)
}

// Shadow values
const KASAN_SHADOW_VALID = 0
const KASAN_SHADOW_PARTIAL = 1..7  // Valid bytes in 8-byte region
const KASAN_SHADOW_FREED = 0xFA
const KASAN_SHADOW_REDZONE = 0xFC
const KASAN_SHADOW_STACK_LEFT = 0xF1
const KASAN_SHADOW_STACK_RIGHT = 0xF3

// Check memory access
export fn __asan_load8(addr: usize) {
    kasan_check_access(addr, 8, false)
}

export fn __asan_store8(addr: usize) {
    kasan_check_access(addr, 8, true)
}

fn kasan_check_access(addr: usize, size: usize, is_write: bool) {
    if !kasan_enabled {
        return
    }

    let shadow = kasan_mem_to_shadow(addr)
    let shadow_val = shadow.*

    if shadow_val == KASAN_SHADOW_VALID {
        return  // Access OK
    }

    // Check partial validity
    if shadow_val >= 1 and shadow_val <= 7 {
        let last_byte = (addr & 7) + size - 1
        if last_byte < shadow_val {
            return  // Access OK
        }
    }

    // Invalid access
    kasan_report(addr, size, is_write, shadow_val)
}

fn kasan_report(addr: usize, size: usize, is_write: bool, shadow_val: u8) {
    pr_err("================================================================================\n")
    pr_err("KASAN: {s} of size {d} at addr {x:016}\n",
        if is_write { "write" } else { "read" },
        size, addr)

    let bug_type = switch shadow_val {
        KASAN_SHADOW_FREED => "use-after-free",
        KASAN_SHADOW_REDZONE => "heap-buffer-overflow",
        KASAN_SHADOW_STACK_LEFT, KASAN_SHADOW_STACK_RIGHT => "stack-buffer-overflow",
        else => "invalid-access"
    }
    pr_err("Bug type: {s}\n", bug_type)

    // Print allocation info if available
    if let alloc_info = kasan_get_alloc_info(addr) {
        pr_err("\nAllocated by:\n")
        print_stack_trace(&alloc_info.alloc_stack)

        if shadow_val == KASAN_SHADOW_FREED {
            pr_err("\nFreed by:\n")
            print_stack_trace(&alloc_info.free_stack)
        }
    }

    pr_err("\nCurrent stack:\n")
    dump_stack()

    pr_err("================================================================================\n")

    if KASAN_PANIC_ON_ERROR {
        kernel_panic("KASAN detected memory corruption")
    }
}

// Poison/unpoison memory
export fn kasan_poison_memory(addr: usize, size: usize, value: u8) {
    let shadow_start = kasan_mem_to_shadow(addr)
    let shadow_size = (size + 7) >> KASAN_SHADOW_SCALE
    @memset(shadow_start, value, shadow_size)
}

export fn kasan_unpoison_memory(addr: usize, size: usize) {
    let shadow_start = kasan_mem_to_shadow(addr)
    let full_bytes = size >> KASAN_SHADOW_SCALE
    let remainder = size & 7

    @memset(shadow_start, 0, full_bytes)

    if remainder > 0 {
        shadow_start[full_bytes] = @truncate(remainder)
    }
}
```

### Use-After-Free Detection

```home
// Quarantine for freed objects
const QUARANTINE_SIZE = 4096

const QuarantineEntry = struct {
    addr: usize,
    size: usize,
    free_stack: [8]usize
}

let quarantine: RingBuffer(QuarantineEntry) = undefined

fn quarantine_put(addr: usize, size: usize) {
    // Poison the memory
    kasan_poison_memory(addr, size, KASAN_SHADOW_FREED)

    // Fill with pattern to detect use-after-free writes
    @memset(@ptrFromInt(addr), 0xDE, size)

    // Add to quarantine
    let entry = QuarantineEntry{
        .addr = addr,
        .size = size,
        .free_stack = undefined
    }
    capture_stack_trace(&entry.free_stack)

    // If quarantine is full, actually free oldest entry
    if quarantine.is_full() {
        let old = quarantine.read()
        // Verify memory wasn't modified
        if !verify_poison_pattern(old.addr, old.size) {
            pr_err("Use-after-free write detected!\n")
            print_stack_trace(&old.free_stack)
        }
        kasan_unpoison_memory(old.addr, old.size)
        actual_free(old.addr, old.size)
    }

    quarantine.write(entry)
}

fn verify_poison_pattern(addr: usize, size: usize): bool {
    let ptr: [*]u8 = @ptrFromInt(addr)
    for i in 0..size {
        if ptr[i] != 0xDE {
            return false
        }
    }
    return true
}
```

## Hardware Debugging

### Serial Console

```home
const SERIAL_PORT = 0x3F8  // COM1

export fn serial_init() {
    // Disable interrupts
    cpu.outb(SERIAL_PORT + 1, 0x00)

    // Set baud rate to 115200
    cpu.outb(SERIAL_PORT + 3, 0x80)  // Enable DLAB
    cpu.outb(SERIAL_PORT + 0, 0x01)  // Divisor low byte
    cpu.outb(SERIAL_PORT + 1, 0x00)  // Divisor high byte

    // 8 bits, no parity, 1 stop bit
    cpu.outb(SERIAL_PORT + 3, 0x03)

    // Enable FIFO
    cpu.outb(SERIAL_PORT + 2, 0xC7)

    // Enable IRQs, RTS/DSR set
    cpu.outb(SERIAL_PORT + 4, 0x0B)
}

fn serial_write_byte(byte: u8) {
    // Wait for transmit buffer empty
    while (cpu.inb(SERIAL_PORT + 5) & 0x20) == 0 {}

    cpu.outb(SERIAL_PORT, byte)
}

export fn serial_write(data: []const u8) {
    for byte in data {
        if byte == '\n' {
            serial_write_byte('\r')
        }
        serial_write_byte(byte)
    }
}

// GDB stub for serial debugging
const GdbState = struct {
    registers: [17]u64,
    signal: u8,
    single_step: bool
}

let gdb_state: GdbState = undefined

fn gdb_handle_packet(packet: []const u8): []u8 {
    switch packet[0] {
        'g' => return gdb_read_registers(),
        'G' => return gdb_write_registers(packet[1..]),
        'm' => return gdb_read_memory(packet[1..]),
        'M' => return gdb_write_memory(packet[1..]),
        's' => return gdb_single_step(),
        'c' => return gdb_continue(),
        'Z' => return gdb_set_breakpoint(packet[1..]),
        'z' => return gdb_clear_breakpoint(packet[1..]),
        '?' => return gdb_stop_reason(),
        else => return ""
    }
}
```

### QEMU Debugging

```home
// QEMU debug console (port 0xE9)
const QEMU_DEBUG_PORT = 0xE9

fn qemu_debug_write(data: []const u8) {
    for byte in data {
        cpu.outb(QEMU_DEBUG_PORT, byte)
    }
}

// QEMU monitor commands
export fn qemu_debug_dump_memory(addr: usize, size: usize) {
    var buf: [64]u8 = undefined
    let len = format(&buf, "xp/{d}xb {x}\n", size, addr)
    qemu_debug_write(buf[0..len])
}

export fn qemu_debug_print_registers() {
    qemu_debug_write("info registers\n")
}

// Detect if running in QEMU
fn is_qemu(): bool {
    // Check CPUID for hypervisor
    let result = cpuid(0x40000000)
    let sig = @ptrCast([*]u8, &result.ebx)

    return mem_equal(sig[0..12], "KVMKVMKVM\0\0\0") or
           mem_equal(sig[0..12], "TCGTCGTCGTCG")
}
```

## Debugging Tools

### Stack Unwinding

```home
const UnwindFrame = struct {
    pc: usize,
    sp: usize,
    fp: usize
}

fn unwind_frame(frame: *UnwindFrame): bool {
    if frame.fp == 0 or frame.fp < KERNEL_STACK_BOTTOM or frame.fp > KERNEL_STACK_TOP {
        return false
    }

    // Get return address and previous frame pointer
    let fp_ptr: *[2]usize = @ptrFromInt(frame.fp)

    frame.pc = fp_ptr[1]  // Return address
    frame.fp = fp_ptr[0]  // Previous frame pointer
    frame.sp = frame.fp + 16

    return true
}

export fn dump_stack() {
    pr_info("Call Trace:\n")

    var frame = UnwindFrame{
        .pc = @returnAddress(),
        .sp = undefined,
        .fp = undefined
    }

    asm volatile ("mov %%rbp, %[fp]" : [fp] "=r" (frame.fp))
    asm volatile ("mov %%rsp, %[sp]" : [sp] "=r" (frame.sp))

    while unwind_frame(&frame) {
        let sym = lookup_symbol(frame.pc)
        if sym != null {
            pr_info("  {x:016} {s}+{x}/{x}\n",
                frame.pc, sym.name, frame.pc - sym.addr, sym.size)
        } else {
            pr_info("  {x:016} ???\n", frame.pc)
        }
    }
}
```

### Symbol Table

```home
const Symbol = struct {
    name: []const u8,
    addr: usize,
    size: usize,
    type: SymbolType
}

// Embedded symbol table (generated at build time)
extern const __kallsyms_addresses: [*]usize
extern const __kallsyms_names: [*]u8
extern const __kallsyms_num_syms: usize

fn lookup_symbol(addr: usize): ?Symbol {
    // Binary search for address
    var low: usize = 0
    var high = __kallsyms_num_syms

    while low < high {
        let mid = (low + high) / 2
        let sym_addr = __kallsyms_addresses[mid]

        if addr < sym_addr {
            high = mid
        } else if mid + 1 < __kallsyms_num_syms and addr >= __kallsyms_addresses[mid + 1] {
            low = mid + 1
        } else {
            // Found it
            let name = get_symbol_name(mid)
            let size = if mid + 1 < __kallsyms_num_syms {
                __kallsyms_addresses[mid + 1] - sym_addr
            } else {
                0
            }

            return Symbol{
                .name = name,
                .addr = sym_addr,
                .size = size,
                .type = SymbolType.Function
            }
        }
    }

    return null
}

fn get_symbol_name(idx: usize): []const u8 {
    // Names are stored compressed
    var ptr = __kallsyms_names
    var i: usize = 0

    while i < idx {
        let len = ptr[0]
        ptr += 1 + len
        i += 1
    }

    let len = ptr[0]
    return ptr[1..1 + len]
}
```

### Lockdep (Lock Dependency Checking)

```home
// Track lock acquisition order to detect deadlocks
const MAX_LOCK_DEPTH = 48
const MAX_LOCK_CLASSES = 4096

const LockClass = struct {
    name: []const u8,
    key: usize,
    deps: BitSet(MAX_LOCK_CLASSES)
}

const HeldLock = struct {
    class: *LockClass,
    acquire_ip: usize,
    irq_context: bool
}

// Per-task lock chain
let current_held_locks: [MAX_LOCK_DEPTH]HeldLock = undefined
let held_lock_count: u32 = 0

export fn lock_acquire(lock: *anyopaque, ip: usize) {
    if !lockdep_enabled {
        return
    }

    let class = get_lock_class(lock)

    // Check for circular dependency
    for i in 0..held_lock_count {
        let held = &current_held_locks[i]

        if held.class == class {
            // Recursive lock - might be OK or might be deadlock
            pr_warn("Recursive lock detected: {s}\n", class.name)
            dump_held_locks()
            return
        }

        // Check if acquiring this lock creates a cycle
        if class.deps.contains(held.class.key) {
            pr_err("================================================================================\n")
            pr_err("LOCKDEP: Potential deadlock detected!\n")
            pr_err("================================================================================\n")
            pr_err("\n")
            pr_err("Trying to acquire lock: {s}\n", class.name)
            pr_err("While holding locks:\n")
            dump_held_locks()
            pr_err("\n")
            pr_err("Lock order violation:\n")
            pr_err("  {s} -> {s} (current acquisition)\n", held.class.name, class.name)
            pr_err("  {s} -> {s} (previous acquisition)\n", class.name, held.class.name)
            dump_stack()

            if LOCKDEP_PANIC_ON_DEADLOCK {
                kernel_panic("Deadlock detected by lockdep")
            }
        }

        // Add dependency
        held.class.deps.set(class.key)
    }

    // Record this lock acquisition
    current_held_locks[held_lock_count] = HeldLock{
        .class = class,
        .acquire_ip = ip,
        .irq_context = in_interrupt_context()
    }
    held_lock_count += 1
}

export fn lock_release(lock: *anyopaque) {
    if !lockdep_enabled {
        return
    }

    let class = get_lock_class(lock)

    // Find and remove from held locks
    for i in 0..held_lock_count {
        if current_held_locks[i].class == class {
            // Check for out-of-order release
            if i != held_lock_count - 1 {
                pr_warn("Lock released out of order: {s}\n", class.name)
            }

            // Remove from list
            held_lock_count -= 1
            current_held_locks[i] = current_held_locks[held_lock_count]
            return
        }
    }

    pr_err("Lock release without acquire: {s}\n", class.name)
}

fn dump_held_locks() {
    for i in 0..held_lock_count {
        let held = &current_held_locks[i]
        let sym = lookup_symbol(held.acquire_ip)
        pr_info("  #{d} {s} acquired at {s}+{x}\n",
            i, held.class.name, sym.name, held.acquire_ip - sym.addr)
    }
}
```

## Summary

Kernel debugging in HomeOS provides:

- **Logging**: Multi-level kernel logging with ring buffer
- **Assertions**: BUG(), WARN(), and panic handling with stack traces
- **KASAN**: Memory corruption detection for heap and stack
- **Hardware Debug**: Serial console and QEMU integration
- **Lockdep**: Deadlock detection through lock ordering
- **Symbols**: Full symbol resolution for stack traces

All debugging infrastructure is written in the Home programming language, providing type-safe debugging facilities integrated with the kernel.
