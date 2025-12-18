# home-os Release Notes

## Version 1.0.0 - Initial Release

**Release Date**: December 2025

---

## Overview

We are excited to announce the first stable release of home-os, a modern operating system built from the ground up using the Home programming language. This release represents over 18 months of development and includes a complete, functional operating system suitable for desktop, server, and embedded use.

---

## Highlights

### Modern Microkernel Architecture
- Capability-based security model
- Minimal kernel with services in userspace
- Clean separation of concerns
- Multi-architecture support (x86_64, ARM64, RISC-V)

### Complete Desktop Environment
- Native compositor with hardware acceleration
- Window management with tiling and floating modes
- Theming support (light, dark, high contrast)
- Full accessibility features

### Essential Applications
- File Manager with VFS integration
- Terminal emulator with tabs and themes
- Text editor with syntax highlighting
- Web browser with modern standards support
- System monitor and calculator

### Raspberry Pi Support
- Full support for Raspberry Pi 4 and 5
- Optimized drivers for BCM2711/BCM2712
- GPIO, I2C, SPI, and UART support
- Hardware video acceleration

### Enterprise-Ready Networking
- Complete TCP/IP stack
- SSH server and client
- WireGuard VPN
- Firewall with stateful filtering

---

## What's New in 1.0.0

### Kernel Features

**Core Subsystems**
- Microkernel with message-passing IPC
- Preemptive multitasking scheduler
- Virtual memory with demand paging
- Capability-based access control

**Memory Management**
- Slab allocator for kernel objects
- SLUB allocator for general allocations
- Kernel Samepage Merging (KSM)
- NUMA-aware allocation

**Process Management**
- POSIX-like process model
- Thread support with futexes
- Signal handling
- Process groups and sessions

**Filesystem**
- Virtual Filesystem (VFS) layer
- HomeFS native filesystem
- ext4 read/write support
- FAT32 for EFI compatibility
- tmpfs and procfs

**Device Drivers**
- AHCI/SATA controller
- NVMe SSD support
- USB 2.0/3.0 stack
- PS/2 and USB HID
- Framebuffer graphics

### Networking

**Protocols**
- IPv4 and IPv6
- TCP with congestion control
- UDP
- ICMP/ICMPv6
- ARP/NDP

**Services**
- DHCP client
- DNS resolver
- NTP time synchronization
- SSH-2.0 server/client
- WireGuard VPN

**Security**
- Stateful firewall
- Network namespaces
- Traffic shaping

### Graphics & Display

**Compositor**
- Wayland-inspired protocol
- Hardware acceleration (OpenGL ES)
- Multiple display support
- VSync and tear-free rendering

**Window Management**
- Floating and tiling modes
- Workspaces
- Window snapping
- Keyboard shortcuts

### Desktop Applications

**File Manager**
- Directory browsing
- File operations (copy, move, delete, rename)
- Search functionality
- Bookmarks and recent files
- Trash/recycle bin

**Terminal**
- VT100/ANSI escape sequences
- Scrollback buffer
- Multiple tabs
- Color themes
- URL detection

**Text Editor**
- Syntax highlighting (50+ languages)
- Line numbers
- Search and replace
- Multiple cursors
- Code folding

**Web Browser**
- HTML5/CSS3 rendering
- JavaScript support
- Tabbed browsing
- Bookmarks and history
- Private browsing mode

**System Monitor**
- CPU usage per core
- Memory and swap usage
- Process list with kill
- Network statistics
- Disk I/O

### Security Features

**Access Control**
- Capability-based security
- Mandatory Access Control (MAC)
- Role-based permissions
- Audit logging

**Sandboxing**
- Application isolation
- seccomp filtering
- Namespace separation
- Resource limits

**Cryptography**
- AES-256 encryption
- ChaCha20-Poly1305
- SHA-256/SHA-512
- Ed25519 signatures
- X25519 key exchange

**Secure Boot**
- UEFI Secure Boot support
- Measured boot
- Key enrollment

### Accessibility

**Visual**
- Screen reader with TTS
- Screen magnifier (100-1000%)
- High contrast themes
- Large text mode

**Motor**
- Sticky keys
- Slow keys
- Bounce keys
- Mouse keys (numpad)

**Input**
- On-screen keyboard
- Voice control (experimental)
- Switch access

### Internationalization

**Languages**
- 14 supported locales
- Right-to-left support
- Input method framework

**Regional**
- Date/time formats
- Number formats
- Currency display
- Timezone database

### Performance

**Optimizations**
- Lock-free data structures
- RCU for read-heavy workloads
- io_uring async I/O
- XDP for network fast path
- SIMD acceleration

**Benchmarks**
- Context switch: <2μs
- Syscall overhead: <500ns
- Memory allocation: <100ns
- Network throughput: 10Gbps+

---

## Supported Hardware

### Architectures
- x86_64 (Intel/AMD)
- ARM64 (Cortex-A53+)
- RISC-V (experimental)

### Platforms
- Standard PC/laptop
- Raspberry Pi 4/5
- QEMU/KVM virtual machines
- VMware and VirtualBox

### Minimum Requirements
- 1 GHz 64-bit CPU
- 512 MB RAM
- 2 GB storage

### Recommended
- 2 GHz dual-core CPU
- 2 GB RAM
- 20 GB SSD

---

## Known Issues

1. **NVIDIA Proprietary Driver**: Manual installation required
2. **Bluetooth Audio**: Occasional dropouts on some adapters
3. **Hibernate**: Not yet implemented
4. **Wayland Games**: Some older games may need X11 compatibility layer

---

## Upgrade Path

This is the initial release. Future versions will support in-place upgrades via:
```bash
sudo pkg upgrade --release
```

---

## Getting Started

### Download
- ISO images: https://home-os.org/download
- Raspberry Pi images: https://home-os.org/download/rpi

### Installation
See [INSTALLATION_GUIDE.md](docs/INSTALLATION_GUIDE.md) for detailed instructions.

### Documentation
- User Manual: [docs/USER_MANUAL.md](docs/USER_MANUAL.md)
- FAQ: [docs/FAQ.md](docs/FAQ.md)
- Troubleshooting: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

## Acknowledgments

Thank you to all contributors, testers, and supporters who made this release possible. Special thanks to:
- The Home language development team
- Hardware testing volunteers
- Documentation contributors
- Translation teams

---

## License

home-os is released under the MIT License. See [LICENSE](LICENSE) for details.

---

## What's Next

### Version 1.1 (Planned)
- Hibernate/suspend improvements
- Additional language translations
- Performance optimizations
- Bug fixes

### Version 2.0 (Future)
- Container runtime
- Kubernetes support
- IoT/Edge computing features
- Enhanced ML support

---

*For the full changelog, see [CHANGELOG.md](CHANGELOG.md)*
