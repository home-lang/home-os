# Getting Started with home-os

Welcome to home-os! This guide will help you build and run the operating system.

## Prerequisites

### Required Tools

1. **Home Compiler** (from `~/Code/home`)
   - Status: In development, using Zig for now
   - Will switch to pure Home once compiler is ready

2. **Zig** (temporary, until Home compiler is complete)
   ```bash
   brew install zig  # macOS
   # or
   sudo apt install zig  # Ubuntu/Debian
   ```

3. **QEMU** (for testing)
   ```bash
   brew install qemu  # macOS
   # or
   sudo apt install qemu-system-x86  # Ubuntu/Debian
   ```

4. **GRUB Tools** (for bootable ISO)
   ```bash
   brew install grub xorriso  # macOS
   # or
   sudo apt install grub-pc-bin xorriso  # Ubuntu/Debian
   ```

## Building

### Quick Build

```bash
cd /Users/chrisbreuer/Code/home-os
./scripts/build.sh
```

This will:
1. Compile the kernel (boot.s + kernel.home)
2. Create a bootable ISO image
3. Place everything in `kernel/build/`

### Expected Output

```
=== Building home-os kernel ===
Compiling kernel...
Kernel compiled successfully!
Creating bootable ISO...
ISO created: kernel/build/home-os.iso

=== Build complete! ===
```

## Running

### QEMU (Standard)

```bash
./scripts/run-qemu.sh
```

### QEMU with KVM (Faster)

```bash
./scripts/run-qemu.sh --kvm
```

### QEMU with GDB Debugging

Terminal 1:
```bash
./scripts/run-qemu.sh --debug
```

Terminal 2:
```bash
gdb kernel/build/home-kernel.elf
(gdb) target remote localhost:1234
(gdb) break kernel_main
(gdb) continue
```

## Expected Boot Sequence

When you run home-os, you should see:

1. **GRUB Menu** (5 second timeout)
   ```
   home-os
   home-os (debug mode)
   home-os (safe mode)
   ```

2. **Boot Messages** (serial console)
   ```
   home-os kernel starting...
   Multiboot2 magic verified: 0x36d76289
   Boot info address: 0x...
   Bootloader: GRUB 2.xx
   
   Memory map:
     0x0000000000000000 - 0x000000000009fc00 (639 KB) - Available
     ...
   Total usable memory: XXX MB
   
   Kernel initialized successfully!
   Entering idle loop...
   ```

3. **VGA Display**
   ```
   === home-os ===
   A modern, minimal operating system
   Built with Home, Craft, and Pantry
   
   Multiboot2: OK
   Bootloader: GRUB 2.xx
   Memory map:
     Total usable: XXX MB
   
   Kernel initialized successfully!
   
   System ready. Press Ctrl+Alt+Del to reboot.
   ```

## Troubleshooting

### "Error: Home compiler not found!"

The Home compiler is still in development. For now, we're using Zig directly.
This message is informational only - the build will continue with Zig.

### "Error: QEMU not found!"

Install QEMU:
```bash
# macOS
brew install qemu

# Ubuntu/Debian
sudo apt install qemu-system-x86

# Arch Linux
sudo pacman -S qemu
```

### "grub-mkrescue: command not found"

Install GRUB tools:
```bash
# macOS
brew install grub xorriso

# Ubuntu/Debian
sudo apt install grub-pc-bin xorriso

# Arch Linux
sudo pacman -S grub xorriso
```

### Kernel panics immediately

Check serial output for the panic message:
```bash
./scripts/run-qemu.sh 2>&1 | grep PANIC
```

Common causes:
- Invalid Multiboot2 magic (should be 0x36d76289)
- Memory map parsing error
- GDT/IDT setup issue

### No output on screen

1. Check if serial output is working
2. Verify VGA initialization in kernel.home
3. Check QEMU framebuffer settings

## Development Workflow

### 1. Make Changes

Edit files in `kernel/src/`:
- `kernel.home` - Main kernel logic
- `serial.home` - Serial driver
- `vga.home` - VGA driver
- `boot.s` - Boot assembly

### 2. Build

```bash
./scripts/build.sh
```

### 3. Test

```bash
./scripts/run-qemu.sh
```

### 4. Debug

```bash
# Terminal 1
./scripts/run-qemu.sh --debug

# Terminal 2
gdb kernel/build/home-kernel.elf
(gdb) target remote localhost:1234
(gdb) break kernel_main
(gdb) continue
(gdb) step
```

## File Structure

```
home-os/
├── kernel/
│   ├── src/
│   │   ├── kernel.home    # Main kernel
│   │   ├── serial.home    # Serial driver
│   │   ├── vga.home       # VGA driver
│   │   └── boot.s         # Boot assembly
│   ├── build/             # Build artifacts
│   │   ├── home-kernel.elf
│   │   └── home-os.iso
│   └── iso/
│       └── boot/grub/
│           └── grub.cfg   # GRUB config
└── scripts/
    ├── build.sh           # Build script
    └── run-qemu.sh        # Run script
```

## Next Steps

Once you have the kernel booting:

1. **Add Interrupt Handling** (Phase 1.3)
   - Set up IDT
   - Add timer interrupt
   - Add keyboard interrupt

2. **Memory Management** (Phase 2)
   - Physical memory allocator
   - Virtual memory manager
   - Heap allocator

3. **Process Management** (Phase 2)
   - Process creation
   - Scheduler
   - Context switching

See [TODO.md](TODO.md) for the complete roadmap!

## Resources

- **Project Docs**: See `docs/` directory
- **TODO List**: [TODO.md](TODO.md)
- **Progress**: [PROGRESS.md](PROGRESS.md)
- **Home Language**: `~/Code/home`
- **OSDev Wiki**: https://wiki.osdev.org/

## Getting Help

If you encounter issues:

1. Check [PROGRESS.md](PROGRESS.md) for known limitations
2. Review serial console output
3. Enable debug mode: `./scripts/run-qemu.sh --debug`
4. Check memory map in boot output
5. Verify GRUB is finding the Multiboot2 header

---

Happy hacking! 🚀
