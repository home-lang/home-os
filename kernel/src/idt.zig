// IDT (Interrupt Descriptor Table) for home-os
// Handles CPU exceptions and hardware interrupts

const serial = @import("serial.zig");

// IDT Entry (Interrupt Gate Descriptor)
const IDTEntry = packed struct {
    offset_low: u16,      // Offset bits 0-15
    selector: u16,        // Code segment selector (0x08 for kernel code)
    ist: u8,              // Interrupt Stack Table offset (0 for now)
    type_attr: u8,        // Type and attributes (0x8E = present, ring 0, 64-bit interrupt gate)
    offset_mid: u16,      // Offset bits 16-31
    offset_high: u32,     // Offset bits 32-63
    reserved: u32,        // Reserved (must be 0)
};

// IDT Pointer structure for LIDT instruction
const IDTPointer = packed struct {
    limit: u16,           // Size of IDT - 1
    base: u64,            // Address of IDT
};

// IDT with 256 entries (in .bss - will be zero-initialized by boot code)
var idt: [256]IDTEntry align(4096) = undefined;

// Exception names for debugging
const exception_names = [_][]const u8{
    "Division By Zero",
    "Debug",
    "Non-Maskable Interrupt",
    "Breakpoint",
    "Overflow",
    "Bound Range Exceeded",
    "Invalid Opcode",
    "Device Not Available",
    "Double Fault",
    "Coprocessor Segment Overrun",
    "Invalid TSS",
    "Segment Not Present",
    "Stack-Segment Fault",
    "General Protection Fault",
    "Page Fault",
    "Reserved",
    "x87 Floating-Point Exception",
    "Alignment Check",
    "Machine Check",
    "SIMD Floating-Point Exception",
    "Virtualization Exception",
    "Control Protection Exception",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Hypervisor Injection Exception",
    "VMM Communication Exception",
    "Security Exception",
    "Reserved",
};

// Set an IDT entry
fn setGate(index: u8, handler: u64, selector: u16, type_attr: u8) void {
    idt[index].offset_low = @truncate(handler & 0xFFFF);
    idt[index].selector = selector;
    idt[index].ist = 0;
    idt[index].type_attr = type_attr;
    idt[index].offset_mid = @truncate((handler >> 16) & 0xFFFF);
    idt[index].offset_high = @truncate((handler >> 32) & 0xFFFFFFFF);
    idt[index].reserved = 0;
}

// Generic exception handler
export fn exceptionHandler(vector: u64, error_code: u64, rip: u64, cs: u64, rflags: u64, rsp: u64, ss: u64) callconv(.c) void {
    serial.writeString("\n\n*** EXCEPTION ***\n");
    serial.writeString("Vector: ");
    serial.writeDec(vector);

    if (vector < exception_names.len) {
        serial.writeString(" (");
        serial.writeString(exception_names[vector]);
        serial.writeString(")");
    }
    serial.writeString("\n");

    serial.writeString("Error code: ");
    serial.writeHex(error_code);
    serial.writeString("\n");

    serial.writeString("RIP: ");
    serial.writeHex(rip);
    serial.writeString("\n");

    serial.writeString("CS: ");
    serial.writeHex(cs);
    serial.writeString("\n");

    serial.writeString("RFLAGS: ");
    serial.writeHex(rflags);
    serial.writeString("\n");

    serial.writeString("RSP: ");
    serial.writeHex(rsp);
    serial.writeString("\n");

    serial.writeString("SS: ");
    serial.writeHex(ss);
    serial.writeString("\n");

    // Halt
    while (true) {
        asm volatile ("hlt");
    }
}

// ISR stubs (defined in idt_stubs.s)
extern fn isr0() void;
extern fn isr1() void;
extern fn isr2() void;
extern fn isr3() void;
extern fn isr4() void;
extern fn isr5() void;
extern fn isr6() void;
extern fn isr7() void;
extern fn isr8() void;
extern fn isr9() void;
extern fn isr10() void;
extern fn isr11() void;
extern fn isr12() void;
extern fn isr13() void;
extern fn isr14() void;
extern fn isr15() void;
extern fn isr16() void;
extern fn isr17() void;
extern fn isr18() void;
extern fn isr19() void;
extern fn isr20() void;
extern fn isr21() void;
extern fn isr30() void;
extern fn isr31() void;

// Initialize IDT
pub fn init() void {
    serial.writeString("Initializing IDT...\n");

    // Set up exception handlers (0-31)
    // 0x8E = Present, DPL=0, 64-bit interrupt gate
    serial.writeString("Setting exception handlers...\n");

    // Set gates using inline code to avoid function call overhead during early boot
    const handler0 = @intFromPtr(&isr0);
    idt[0].offset_low = @truncate(handler0 & 0xFFFF);
    idt[0].selector = 0x08;
    idt[0].ist = 0;
    idt[0].type_attr = 0x8E;
    idt[0].offset_mid = @truncate((handler0 >> 16) & 0xFFFF);
    idt[0].offset_high = @truncate((handler0 >> 32) & 0xFFFFFFFF);
    idt[0].reserved = 0;
    setGate(1, @intFromPtr(&isr1), 0x08, 0x8E);
    setGate(2, @intFromPtr(&isr2), 0x08, 0x8E);
    setGate(3, @intFromPtr(&isr3), 0x08, 0x8E);
    setGate(4, @intFromPtr(&isr4), 0x08, 0x8E);
    setGate(5, @intFromPtr(&isr5), 0x08, 0x8E);
    setGate(6, @intFromPtr(&isr6), 0x08, 0x8E);
    setGate(7, @intFromPtr(&isr7), 0x08, 0x8E);
    setGate(8, @intFromPtr(&isr8), 0x08, 0x8E);
    setGate(9, @intFromPtr(&isr9), 0x08, 0x8E);
    setGate(10, @intFromPtr(&isr10), 0x08, 0x8E);
    setGate(11, @intFromPtr(&isr11), 0x08, 0x8E);
    setGate(12, @intFromPtr(&isr12), 0x08, 0x8E);
    setGate(13, @intFromPtr(&isr13), 0x08, 0x8E);
    setGate(14, @intFromPtr(&isr14), 0x08, 0x8E);
    setGate(15, @intFromPtr(&isr15), 0x08, 0x8E);
    setGate(16, @intFromPtr(&isr16), 0x08, 0x8E);
    setGate(17, @intFromPtr(&isr17), 0x08, 0x8E);
    setGate(18, @intFromPtr(&isr18), 0x08, 0x8E);
    setGate(19, @intFromPtr(&isr19), 0x08, 0x8E);
    setGate(20, @intFromPtr(&isr20), 0x08, 0x8E);
    setGate(21, @intFromPtr(&isr21), 0x08, 0x8E);
    setGate(30, @intFromPtr(&isr30), 0x08, 0x8E);
    setGate(31, @intFromPtr(&isr31), 0x08, 0x8E);

    serial.writeString("Exception handlers set\n");

    // Create IDT pointer on stack
    const idt_ptr = IDTPointer{
        .limit = @sizeOf(@TypeOf(idt)) - 1,
        .base = @intFromPtr(&idt),
    };

    serial.writeString("IDT address: ");
    serial.writeHex(idt_ptr.base);
    serial.writeString("\n");
    serial.writeString("IDT size: ");
    serial.writeDec(idt_ptr.limit);
    serial.writeString("\n");

    // Load IDT
    serial.writeString("Loading IDT with LIDT instruction...\n");
    asm volatile ("lidt (%[idt_ptr])"
        :
        : [idt_ptr] "r" (&idt_ptr),
    );

    serial.writeString("IDT loaded successfully!\n");
}

// Test exception by dividing by zero
pub fn testDivideByZero() void {
    serial.writeString("Testing divide by zero exception...\n");
    const x: u32 = 42;
    const y: u32 = 0;
    const z: u32 = x / y;  // This will trigger exception 0
    _ = z;
}
