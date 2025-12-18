# Changelog

All notable changes to home-os are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2025-12-18

### Added

#### Kernel
- Microkernel architecture with capability-based security
- Preemptive multitasking scheduler with priority levels
- Virtual memory management with demand paging
- Slab and SLUB memory allocators
- Kernel Samepage Merging (KSM) for memory deduplication
- IPC via message passing and shared memory
- Signal handling (POSIX-compatible)
- Futex implementation for userspace synchronization

#### Filesystems
- Virtual Filesystem (VFS) abstraction layer
- HomeFS native filesystem with journaling
- ext4 filesystem support (read/write)
- FAT32 filesystem for EFI partition
- tmpfs for temporary storage
- procfs for process information
- devfs for device nodes

#### Drivers
- AHCI/SATA controller driver
- NVMe SSD driver
- USB 2.0/3.0 host controller (EHCI, xHCI)
- USB HID (keyboard, mouse)
- PS/2 keyboard and mouse
- VGA/VESA framebuffer
- Intel HD Graphics (basic)
- AMD Radeon (basic)
- Realtek RTL8139/RTL8169 network
- Intel e1000/e1000e network
- Virtio (block, network, console)

#### Networking
- TCP/IP stack (IPv4 and IPv6)
- TCP with Reno/CUBIC congestion control
- UDP protocol
- ICMP and ICMPv6
- ARP and NDP
- DHCP client
- DNS resolver with caching
- NTP client
- Stateful firewall (iptables-like)
- WireGuard VPN protocol
- SSH-2.0 server and client
- XDP (eXpress Data Path) for fast packet processing

#### Graphics
- Wayland-inspired compositor
- Hardware-accelerated rendering (OpenGL ES 2.0)
- Window management (floating and tiling)
- Multiple workspace support
- Theming engine (light, dark, custom)
- Font rendering with FreeType
- Multi-monitor support

#### Applications
- File Manager with VFS integration
- Terminal emulator (VT100/ANSI)
- Text Editor with syntax highlighting
- Web Browser (HTML5/CSS3/JS)
- Calculator (basic/scientific/programmer)
- System Monitor
- Settings application
- Media Player with codec support

#### Security
- Capability-based access control
- Mandatory Access Control (MAC)
- Application sandboxing
- seccomp syscall filtering
- Namespace isolation
- Audit logging framework
- Cryptographic library (AES, ChaCha20, SHA, Ed25519)
- UEFI Secure Boot support
- Disk encryption support

#### Accessibility
- Screen reader with text-to-speech
- Screen magnifier (100-1000% zoom)
- High contrast themes (4 variants)
- Keyboard accessibility (sticky, slow, bounce keys)
- Mouse keys (numpad control)

#### Internationalization
- 14 language locales
- Unicode support (UTF-8)
- Timezone database
- Regional format settings
- Input method framework

#### Raspberry Pi Support
- BCM2711 SoC driver (Pi 4)
- BCM2712 SoC driver (Pi 5)
- ARM64 boot sequence
- Mini UART and PL011 drivers
- GPIO controller
- VideoCore mailbox interface
- EMMC/SD card driver
- GIC-400 interrupt controller
- Device Tree parsing

#### Performance
- Lock-free data structures (stack, queue, skip list)
- RCU (Read-Copy-Update) synchronization
- io_uring async I/O interface
- Memory-mapped I/O optimizations
- CPU frequency scaling
- Power management

#### Installation
- Graphical installer
- Disk partitioning (GPT)
- Filesystem formatting
- User account creation
- Bootloader installation (UEFI/BIOS)
- Package selection

#### Documentation
- User Manual
- Installation Guide
- Troubleshooting Guide
- FAQ
- API documentation

---

## [0.9.0] - 2025-11-15 (Beta)

### Added
- Complete desktop environment
- All essential applications
- Raspberry Pi 5 support
- WireGuard VPN
- SSH server/client

### Changed
- Improved memory allocator performance
- Enhanced compositor stability
- Better hardware detection

### Fixed
- Network stack race conditions
- File manager crash on large directories
- Terminal escape sequence handling

---

## [0.8.0] - 2025-10-01 (Alpha)

### Added
- Networking stack (TCP/IP)
- DHCP and DNS clients
- Firewall implementation
- Initial SSH support

### Changed
- Refactored VFS layer
- Improved scheduler fairness
- Enhanced driver model

### Fixed
- Memory leaks in filesystem code
- Deadlock in mutex implementation
- USB enumeration issues

---

## [0.7.0] - 2025-08-15

### Added
- USB 3.0 support (xHCI)
- NVMe driver
- ext4 filesystem
- Multi-monitor support

### Changed
- Migrated to new build system
- Reorganized kernel source tree
- Updated memory allocator

---

## [0.6.0] - 2025-07-01

### Added
- Wayland-inspired compositor
- Window management
- Basic applications (terminal, file manager)
- Font rendering

### Changed
- Rewrote graphics subsystem
- Improved input handling
- Enhanced IPC performance

---

## [0.5.0] - 2025-05-15

### Added
- Raspberry Pi 4 support
- ARM64 architecture port
- Device Tree parsing
- GPIO and UART drivers

### Changed
- Made kernel architecture-agnostic
- Abstracted hardware interfaces
- Improved boot sequence

---

## [0.4.0] - 2025-04-01

### Added
- Virtual Filesystem (VFS)
- HomeFS native filesystem
- FAT32 support
- Block device layer

### Changed
- Reorganized driver model
- Enhanced memory management
- Improved process lifecycle

---

## [0.3.0] - 2025-02-15

### Added
- USB 2.0 stack (EHCI)
- HID drivers (keyboard, mouse)
- AHCI/SATA driver
- Interrupt handling framework

### Changed
- Rewrote interrupt dispatcher
- Improved PCI enumeration
- Enhanced DMA support

---

## [0.2.0] - 2025-01-01

### Added
- Process management
- Virtual memory
- Basic scheduler
- System call interface

### Changed
- Transitioned to microkernel design
- Implemented capability system
- Added memory protection

---

## [0.1.0] - 2024-10-15

### Added
- Initial kernel bootstrap
- GDT/IDT setup
- Basic memory detection
- Serial console output
- Simple shell

---

## Version History Summary

| Version | Date | Milestone |
|---------|------|-----------|
| 1.0.0 | 2025-12-18 | Initial stable release |
| 0.9.0 | 2025-11-15 | Beta release |
| 0.8.0 | 2025-10-01 | Alpha release |
| 0.7.0 | 2025-08-15 | Storage & display |
| 0.6.0 | 2025-07-01 | Desktop environment |
| 0.5.0 | 2025-05-15 | ARM64 support |
| 0.4.0 | 2025-04-01 | Filesystem layer |
| 0.3.0 | 2025-02-15 | Device drivers |
| 0.2.0 | 2025-01-01 | Process management |
| 0.1.0 | 2024-10-15 | Initial bootstrap |

---

[1.0.0]: https://github.com/home-os/home-os/releases/tag/v1.0.0
[0.9.0]: https://github.com/home-os/home-os/releases/tag/v0.9.0
[0.8.0]: https://github.com/home-os/home-os/releases/tag/v0.8.0
[0.7.0]: https://github.com/home-os/home-os/releases/tag/v0.7.0
[0.6.0]: https://github.com/home-os/home-os/releases/tag/v0.6.0
[0.5.0]: https://github.com/home-os/home-os/releases/tag/v0.5.0
[0.4.0]: https://github.com/home-os/home-os/releases/tag/v0.4.0
[0.3.0]: https://github.com/home-os/home-os/releases/tag/v0.3.0
[0.2.0]: https://github.com/home-os/home-os/releases/tag/v0.2.0
[0.1.0]: https://github.com/home-os/home-os/releases/tag/v0.1.0
