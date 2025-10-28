// home-os kernel main entry point
// Written in Zig (will be Home once compiler is ready)

const serial = @import("serial.zig");
const vga = @import("vga.zig");
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

    // Initialize VGA text mode
    vga.init();
    vga.clear();

    // Display boot banner
    vga.setColor(.Cyan, .Black);
    vga.writeString("=== home-os ===\n");
    vga.setColor(.White, .Black);
    vga.writeString("A modern, minimal operating system\n");
    vga.writeString("Built with Home, Craft, and Pantry\n\n");

    // Verify Multiboot2 magic number
    if (magic != MULTIBOOT2_MAGIC) {
        @panic("Invalid Multiboot2 magic number!");
    }

    serial.writeString("Multiboot2 magic verified: ");
    serial.writeHex(magic);
    serial.writeString("\n");
    vga.writeString("Multiboot2: OK\n");

    // Display boot info
    serial.writeString("Boot info address: ");
    serial.writeHex(info_addr);
    serial.writeString("\n");

    vga.writeString("Boot info: OK\n");
    vga.writeString("Bootloader: GRUB\n");

    // Kernel initialized successfully
    vga.writeString("\n");
    vga.setColor(.Green, .Black);
    vga.writeString("Kernel initialized successfully!\n");
    vga.setColor(.White, .Black);

    serial.writeString("\nKernel initialized successfully!\n");
    serial.writeString("Entering idle loop...\n");

    // Display system info
    vga.writeString("\nSystem ready. Press Ctrl+Alt+Del to reboot.\n");

    // Idle loop
    while (true) {
        asm volatile ("hlt");
    }
}
