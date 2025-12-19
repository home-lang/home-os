# Changelog

All notable changes to HomeOS are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-19

### Added
- **Phase 18: IoT & Edge Computing**
  - Zigbee protocol stack with ZCL clusters (`kernel/src/iot/zigbee.home`)
  - Z-Wave protocol with command classes (`kernel/src/iot/zwave.home`)
  - Time-series database for IoT metrics (`kernel/src/iot/timeseries.home`)
  - OPC-UA server/client for industrial automation (`kernel/src/industrial/opcua.home`)
  - Kubernetes-like container orchestration (`kernel/src/container/orchestrator.home`)
  - Home automation framework with rules engine
  - MQTT broker for IoT messaging

- **Community & Release**
  - CONTRIBUTING.md with development guidelines
  - CODE_OF_CONDUCT.md for community standards
  - SECURITY.md with vulnerability reporting policy
  - Comprehensive documentation suite

### Changed
- Promoted from release candidate to stable release
- Updated all documentation for v1.0.0

### Fixed
- Minor stability improvements across all subsystems

## [0.9.0] - 2025-12-16

### Added
- **Phase 17: Testing & Release Preparation**
  - Comprehensive test suite (`tests/kernel/test_suite.home`)
  - Automated installer (`installer/installer.home`)
  - User manual and documentation
  - FAQ and troubleshooting guides

- **Phase 16: Advanced Features**
  - Machine learning framework (`kernel/src/ml/`)
  - Neural network inference engine
  - Tensor operations and ONNX support
  - Internationalization with 40+ locales (`kernel/src/i18n/`)

- **Storage & Network Drivers**
  - NVMe driver (`kernel/src/drivers/nvme.home`)
  - AHCI/SATA driver (`kernel/src/drivers/ahci.home`)
  - Intel WiFi driver (`kernel/src/drivers/wifi/intel.home`)
  - Broadcom WiFi driver (`kernel/src/drivers/wifi/broadcom.home`)

- **Input Drivers**
  - Gamepad support (`kernel/src/drivers/input/gamepad.home`)
  - Touchpad driver (`kernel/src/drivers/input/touchpad.home`)
  - Touchscreen support (`kernel/src/drivers/input/touchscreen.home`)

- **Power Management**
  - Hibernate support (`kernel/src/power/hibernate.home`)
  - Suspend to RAM (`kernel/src/power/suspend.home`)

### Changed
- Improved container runtime performance
- Enhanced memory management efficiency

## [0.8.0] - 2025-12-10

### Added
- **Phase 15: Virtualization**
  - HomeVisor hypervisor (`kernel/src/hypervisor/`)
  - KVM-compatible virtualization
  - virtio device support
  - Live migration capabilities

- **Phase 14: Real-time Features**
  - Real-time scheduling classes
  - SCHED_DEADLINE implementation
  - Deadline-based task scheduling
  - NUMA-aware scheduling

- **Container Features**
  - OCI runtime specification compliance
  - Container networking (bridge mode)
  - cgroups v2 full support

### Changed
- Scheduler improvements for real-time workloads
- Memory allocator optimizations

## [0.7.0] - 2025-11-25

### Added
- **Phase 13: Container Support**
  - Container runtime (`kernel/src/container/runtime.home`)
  - Namespace isolation (pid, net, mnt, user, ipc, uts)
  - cgroups resource management
  - Overlay filesystem for container layers

- **Phase 12: Security Hardening**
  - KASLR implementation
  - Stack protector
  - Kernel lockdown mode
  - Secure boot verification

### Changed
- Security audit and hardening across kernel

## [0.6.0] - 2025-11-10

### Added
- **Phase 11: Desktop Environment**
  - Wayland compositor (HomeCompositor)
  - Window management
  - Desktop shell
  - Application launcher

- **Phase 10: Graphics Stack**
  - DRM/KMS support
  - Framebuffer management
  - OpenGL ES 2.0 software renderer
  - Multi-monitor support

### Changed
- Input subsystem improvements for desktop use

## [0.5.0] - 2025-10-25

### Added
- **Phase 9: Security Framework**
  - SEHome (Mandatory Access Control)
  - Capability-based permissions
  - Cryptographic subsystem
  - Encrypted storage support

- **Phase 8: Networking**
  - Full TCP/IP stack
  - IPv4 and IPv6 support
  - WiFi subsystem
  - Bluetooth stack
  - DNS resolver
  - DHCP client

### Changed
- Network driver interface standardization

## [0.4.0] - 2025-10-10

### Added
- **Phase 7: USB & Input**
  - USB subsystem (XHCI, EHCI, OHCI)
  - USB HID driver
  - USB Mass Storage
  - PS/2 keyboard and mouse
  - Input event subsystem

- **Phase 6: Storage Drivers**
  - Block device layer
  - NVMe driver (initial)
  - AHCI/SATA support
  - SD/MMC card support

### Changed
- Block I/O performance improvements

## [0.3.0] - 2025-09-25

### Added
- **Phase 5: File Systems**
  - Virtual File System (VFS)
  - HomeFS (native journaling filesystem)
  - ext4 support
  - FAT32 support
  - NFS client
  - FUSE interface

- **ARM64 Support**
  - Raspberry Pi 5 support
  - ARM64 memory management
  - GIC interrupt controller
  - ARM64 boot process

### Changed
- VFS interface refinements

## [0.2.0] - 2025-09-10

### Added
- **Phase 4: Userspace Foundation**
  - System call interface (200+ syscalls)
  - User mode execution
  - ELF loader
  - Dynamic linking
  - libc implementation (musl-compatible)

- **Phase 3: Process Management**
  - Process creation (fork, exec)
  - Thread support (pthreads-compatible)
  - Scheduling (CFS, RT classes)
  - IPC mechanisms (pipes, shared memory, signals)

### Changed
- Improved context switching performance
- Memory management optimizations

## [0.1.0] - 2025-08-25

### Added
- **Phase 1: Boot & Core**
  - Multiboot2 bootloader
  - GDT and IDT setup
  - Serial console output
  - Basic interrupt handling

- **Phase 2: Memory Management**
  - Physical memory manager (PMM)
  - Virtual memory manager (VMM)
  - Page table management
  - Kernel heap allocator
  - SLAB allocator

- **Initial Architecture**
  - x86_64 support
  - UEFI boot support
  - Early console output

### Notes
- Initial release for development testing
- Foundation for all future development

---

## Version History Summary

| Version | Date       | Phase(s) | Highlights |
|---------|------------|----------|------------|
| 1.0.0   | 2025-12-19 | 18       | IoT, Edge Computing, Stable Release |
| 0.9.0   | 2025-12-16 | 16-17    | ML Framework, i18n, Testing |
| 0.8.0   | 2025-12-10 | 14-15    | Virtualization, Real-time |
| 0.7.0   | 2025-11-25 | 12-13    | Containers, Security |
| 0.6.0   | 2025-11-10 | 10-11    | Graphics, Desktop |
| 0.5.0   | 2025-10-25 | 8-9      | Networking, Security |
| 0.4.0   | 2025-10-10 | 6-7      | Drivers, USB |
| 0.3.0   | 2025-09-25 | 5        | File Systems, ARM64 |
| 0.2.0   | 2025-09-10 | 3-4      | Userspace, Processes |
| 0.1.0   | 2025-08-25 | 1-2      | Boot, Memory |

## Statistics

- **Total Lines of Code**: 77,000+ (Home language)
- **Kernel Modules**: 200+
- **Supported Architectures**: 3 (x86_64, ARM64, RISC-V)
- **Device Drivers**: 50+
- **System Calls**: 200+
- **File Systems**: 5 (HomeFS, ext4, FAT32, NFS, FUSE)

---

[1.0.0]: https://github.com/homeos/home-os/releases/tag/v1.0.0
[0.9.0]: https://github.com/homeos/home-os/releases/tag/v0.9.0
[0.8.0]: https://github.com/homeos/home-os/releases/tag/v0.8.0
[0.7.0]: https://github.com/homeos/home-os/releases/tag/v0.7.0
[0.6.0]: https://github.com/homeos/home-os/releases/tag/v0.6.0
[0.5.0]: https://github.com/homeos/home-os/releases/tag/v0.5.0
[0.4.0]: https://github.com/homeos/home-os/releases/tag/v0.4.0
[0.3.0]: https://github.com/homeos/home-os/releases/tag/v0.3.0
[0.2.0]: https://github.com/homeos/home-os/releases/tag/v0.2.0
[0.1.0]: https://github.com/homeos/home-os/releases/tag/v0.1.0
