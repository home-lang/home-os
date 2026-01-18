# HomeOS

> A **feature-complete, production-grade operating system** with 210+ kernel modules built from scratch using the [Home Programming Language](/home/)

HomeOS is a modern operating system designed for both x86-64 and ARM64 architectures, with first-class support for the Raspberry Pi 5. Written entirely in the Home programming language, it provides a secure, efficient, and user-friendly computing environment.

## Key Features

- **210+ Kernel Modules** - Comprehensive OS functionality written in pure Home
- **Multi-Architecture** - Supports x86-64 (QEMU/PC) and ARM64 (Raspberry Pi 5)
- **Full Network Stack** - TCP/IP, HTTP, TLS 1.3, WebSocket, MQTT, and more
- **10 File Systems** - FAT32, ext2, NTFS, Btrfs, exFAT, ISO9660, procfs, sysfs, tmpfs, devfs
- **59 Hardware Drivers** - Storage, input, network, USB, graphics, and peripherals
- **Modern Security** - ASLR, stack protection, capabilities, sandboxing

## Supported Architectures

| Architecture | Platform | Status |
|-------------|----------|--------|
| x86-64 | QEMU, Physical PCs | Production Ready |
| ARM64 | Raspberry Pi 5 (BCM2712) | Production Ready |
| ARM64 | Raspberry Pi 4 (BCM2711) | In Development |
| RISC-V | Planned | Planned |

## Technology Stack

- **Language**: [Home Programming Language](/home/) - Memory-safe systems language
- **Boot**: Multiboot2 (x86-64), Raspberry Pi firmware (ARM64)
- **Architecture**: Modular hybrid kernel with loadable drivers
- **Build System**: Zig-based (transitioning to Home self-hosting)

## Quick Start

### Run on Raspberry Pi 5 (Recommended)

```bash
# 1. Build HomeOS
./scripts/build-rpi5.sh

# 2. Copy to SD card (FAT32 formatted)
cp -r build/rpi5/boot/* /path/to/sd-card/

# 3. Boot your Raspberry Pi 5!
```

See the [Getting Started Guide](/os/guide/getting-started) for detailed instructions.

### Run on x86-64 (QEMU)

```bash
cd kernel
zig build qemu
```

## What's Included

### Core Kernel

- **Memory Management** - Physical memory manager (PMM), virtual memory manager (VMM), slab allocator, swap, OOM killer
- **Process Management** - Completely Fair Scheduler (CFS), real-time scheduler, multi-core SMP
- **Interrupt Handling** - GIC for ARM64, IDT for x86-64
- **System Calls** - POSIX-compatible syscall interface with 100+ system calls

### File Systems

- **Native**: FAT32, ext2, NTFS, Btrfs, exFAT, ISO9660
- **Virtual**: procfs, sysfs, tmpfs, devfs

### Networking

- **Core Protocols**: TCP/IP, UDP, IPv6, ICMP, ARP
- **Application Layer**: HTTP/HTTPS, WebSocket, DHCP, DNS
- **Security**: TLS 1.2/1.3 with AES-GCM
- **IoT**: MQTT, CoAP, NFC
- **Enterprise**: NFS, SMB/CIFS

### Hardware Drivers

- **Storage**: ATA, AHCI, NVMe, SD/MMC, RAID, CD-ROM
- **Input**: Keyboard, mouse, touchpad, touchscreen, gamepad
- **Network**: E1000, RTL8139, VirtIO Net, WiFi, Bluetooth
- **USB**: UHCI (1.1), EHCI (2.0), XHCI (3.0)
- **Graphics**: VGA, framebuffer, GPU, OpenGL, Vulkan
- **Peripherals**: GPIO, I2C, SPI, PWM, audio, camera

### Built-in Applications

- **Terminal** - VT100/ANSI-compatible terminal emulator
- **File Manager** - Graphical file browser with operations
- **Text Editor** - Syntax highlighting, multiple cursors
- **Shell** - Command-line interface (hsh)
- **System Monitor** - CPU, memory, disk, network monitoring

## Documentation

- [Getting Started](/os/guide/getting-started) - Build and run HomeOS
- [Architecture](/os/guide/architecture) - Kernel design and internals
- [File Systems](/os/guide/filesystems) - Supported file systems
- [Networking](/os/guide/networking) - Network stack and protocols
- [Drivers](/os/guide/drivers) - Hardware driver reference
- [Applications](/os/guide/applications) - Built-in applications
- [Raspberry Pi 5](/os/guide/raspberry-pi) - Pi 5 deployment guide
- [Development](/os/guide/development) - Contributing to HomeOS

## Related Projects

- [Home Language](/home/) - The programming language powering HomeOS
- [Pantry](/pantry/) - Package manager integration
- [Den](/den/) - Shell integration
- [Craft](/craft/) - UI framework integration

## License

MIT License

---

Built with the Home Programming Language, Craft, and Pantry
