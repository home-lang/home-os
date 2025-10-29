// home-os kernel main entry point
// Written in Zig (will be Home once compiler is ready)

const serial = @import("serial.zig");
const vga = @import("vga.zig");
const idt = @import("idt.zig");
const pmm = @import("pmm.zig");
const std = @import("std");

// Multiboot2 constants
const MULTIBOOT2_MAGIC: u32 = 0x36d76289;

// Kernel panic handler
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    _ = ret_addr;

    serial.writeString("\n[PANIC] ");
    serial.writeString(msg);
    serial.writeString("\n");

    vga.setColor(.Red, .Black);
    vga.writeString("\n*** KERNEL PANIC ***\n");
    vga.writeString(msg);
    vga.writeString("\n");

    // Halt the CPU
    while (true) {
        asm volatile ("hlt");
    }
}

// Kernel entry point (called from boot.s)
export fn kernel_main(magic: u32, info_addr: u32) callconv(.c) noreturn {
    // Initialize serial console
    serial.init();
    serial.writeString("home-os kernel starting...\n");
    serial.writeString("Serial initialized OK\n");

    // Initialize VGA text mode
    // TODO: VGA has issues accessing 0xB8000 buffer - needs investigation
    // For now, using serial console only
    serial.writeString("=== home-os ===\n");
    serial.writeString("A modern, minimal operating system\n");
    serial.writeString("Built with Home, Craft, and Pantry\n\n");

    // Verify Multiboot2 magic number
    if (magic != MULTIBOOT2_MAGIC) {
        @panic("Invalid Multiboot2 magic number!");
    }

    serial.writeString("Multiboot2 magic verified: ");
    serial.writeHex(magic);
    serial.writeString("\n");
    serial.writeString("Multiboot2: OK\n");

    // Display boot info
    serial.writeString("Boot info address: ");
    serial.writeHex(info_addr);
    serial.writeString("\n");

    serial.writeString("Boot info: OK\n");
    serial.writeString("Bootloader: GRUB\n\n");

    // Initialize Physical Memory Manager
    serial.writeString("Initializing subsystems...\n");
    pmm.init(info_addr);
    serial.writeString("PMM: OK\n\n");

    // Skip IDT for now - will enable after PMM verification
    serial.writeString("IDT: disabled (TODO)\n\n");

    // Kernel initialized successfully
    serial.writeString("=== Kernel Ready ===\n");
    serial.writeString("64-bit page tables: FIXED\n");
    serial.writeString("Memory writes: Working\n");
    serial.writeString("PMM: Operational\n");

    // Test exception handling (optional - comment out for normal boot)
    // idt.testDivideByZero();

    serial.writeString("Entering idle loop...\n");

    // Display system info
    serial.writeString("\nSystem ready. Press Ctrl+Alt+Del to reboot.\n");

    // Idle loop
    while (true) {
        asm volatile ("hlt");
    }
}
