# home-os Kernel Module Index

This document is auto-generated from the kernel source tree.

## Module Organization

### accessibility (1 modules)

| Module | Description |
|--------|-------------|
| `screen_reader` | home-os Kernel - Screen Reader |

### arch (15 modules)

| Module | Description |
|--------|-------------|
| `arch_semantics` | home-os Cross-Architecture Semantics Parity |

### audio (2 modules)

| Module | Description |
|--------|-------------|
| `alsa` | home-os ALSA API |
| `mixer` | home-os Audio Mixer |

### block (3 modules)

| Module | Description |
|--------|-------------|
| `io_scheduler` | HomeOS I/O Scheduler |
| `readahead` | home-os Read-Ahead Cache |
| `request_merge` | home-os Block Layer Request Merging |

### boot (2 modules)

| Module | Description |
|--------|-------------|
| `bootloader` | home-os Bootloader Interface |
| `initramfs` | home-os InitramFS - Initial RAM Filesystem |

### container (7 modules)

| Module | Description |
|--------|-------------|
| `cgroup` | home-os Control Groups |
| `cgroups` | home-os Kernel - Cgroups (Control Groups) v2 |
| `image` | home-os Kernel - Container Image Management |
| `namespace` | home-os Namespaces |
| `namespaces` | home-os Kernel - Namespaces |
| `overlayfs` | home-os Kernel - OverlayFS |
| `runtime` | home-os Kernel - Container Runtime |

### core (23 modules)

| Module | Description |
|--------|-------------|
| `driver_init` | home-os Parallel Driver Initialization System |
| `filesystem` | home-os Kernel - File System |
| `foundation` | home-os Kernel - Phase 1: Foundation |
| `kernel_init` | home-os Kernel - Initialization Orchestrator |
| `lazy_loader` | home-os Lazy Service Loading System |
| `lockfree` | Lock-Free Data Structures |
| `memory` | home-os Kernel - Memory Management |
| `numa` | NUMA (Non-Uniform Memory Access) Support |
| `process` | home-os Kernel - Process Management |
| `smp` | SMP (Symmetric Multi-Processing) Support with Per-CPU Run Qu |
| `vfs_async_io` | home-os VFS - Asynchronous I/O |
| `vfs_block_io` | home-os Kernel - VFS Block I/O Integration |
| `vfs_buffer_cache` | home-os VFS - Buffer Cache (Page Cache) |
| `vfs_hardlinks` | home-os VFS - Hard Links |
| `vfs_inode_hash` | home-os VFS - Inode Hash Table |
| `vfs_large_files` | home-os VFS - Large File Support |
| `vfs_locking` | home-os VFS - File Locking |
| `vfs_mmap` | home-os VFS - Memory-Mapped Files (mmap) |
| `vfs_mmap_integration` | home-os Kernel - VFS mmap Integration |
| `vfs_path` | home-os VFS - Path Resolution |
| `vfs_permissions` | home-os VFS - Permission Checking System |
| `vfs_symlinks` | home-os VFS - Symbolic Links |
| `vfs_xattr` | home-os VFS - Extended Attributes (xattr) |

### crypto (3 modules)

| Module | Description |
|--------|-------------|
| `aes` | home-os AES Encryption |
| `rsa` | home-os RSA Encryption |
| `sha256` | home-os SHA-256 |

### debug (10 modules)

| Module | Description |
|--------|-------------|
| `gdb` | home-os GDB Remote Debugging Stub |
| `gdb_exception_hooks` | home-os GDB Exception Integration |
| `kdb` | home-os Kernel Debugger |
| `kdb_enhanced` | home-os Kernel - Enhanced Kernel Debugger (KDB) |
| `mem_footprint` | Memory Footprint Analysis Module for HomeOS |
| `memleak` | home-os Memory Leak Detector |
| `memory_audit` | home-os Memory Audit Tool |
| `panic` | home-os Kernel Panic Handler |
| `profiler` | home-os Kernel Profiler |
| `ptrace` | home-os Kernel - Ptrace (Process Tracing) |

### drivers (65 modules)

| Module | Description |
|--------|-------------|
| `acpi` | home-os ACPI Driver |
| `acpi_pm` | home-os Kernel - ACPI Power Management |
| `ahci` | home-os AHCI Driver |
| `ata` | home-os Kernel - ATA/IDE Driver (PIO Mode) |
| `audio` | home-os Audio Driver |
| `backlight` | home-os Backlight Driver |
| `battery` | home-os Battery Driver |
| `bcm_emmc` | home-os BCM2711/BCM2712 EMMC2 Controller Driver |
| `bluetooth` | home-os Bluetooth Driver |
| `bluetooth_hci` | home-os Kernel - Bluetooth HCI (Host Controller Interface) |
| `buzzer` | home-os PC Speaker/Buzzer |
| `camera` | home-os Camera Driver |
| `cdrom` | home-os CD-ROM Driver |
| `cyw43455` | home-os Cypress CYW43455 WiFi/Bluetooth Driver |
| `dma` | home-os DMA Controller |
| `e1000` | home-os Kernel - Intel E1000 Network Driver |
| `ehci` | home-os EHCI Driver |
| `fb_console` | home-os Framebuffer Console with Font Rendering |
| `fingerprint` | home-os Fingerprint Scanner |
| `floppy` | home-os Floppy Disk Driver |
| `framebuffer` | home-os Enhanced Framebuffer Driver |
| `gamepad` | home-os Gamepad Driver |
| `gpio` | home-os GPIO (General Purpose Input/Output) Driver |
| `gpu` | home-os GPU Driver |
| `hwmon` | home-os Hardware Monitoring |
| `i2c` | home-os I2C (Inter-Integrated Circuit) Driver |
| `keyboard` | home-os Kernel - PS/2 Keyboard Driver |
| `led` | home-os LED Driver |
| `lg_monitor` | home-os LG Monitor Support |
| `lid` | home-os Lid Switch Driver |
| `mouse` | home-os Mouse Driver |
| `msi` | home-os MSI/MSI-X |
| `nvdimm` | home-os NVDIMM Driver |
| `nvme` | home-os NVMe Driver |
| `pci` | home-os PCI Driver |
| `pcie_extended` | home-os PCIe Extended Capabilities |
| `printer` | home-os Printer Driver |
| `pwm` | home-os PWM Driver |
| `raid` | home-os Kernel - RAID Controller Support |
| `ramdisk` | home-os RAM Disk Driver |
| `rtc` | home-os RTC (Real-Time Clock) Driver |
| `rtl8139` | home-os Realtek RTL8139 Network Driver |
| `scanner` | home-os Scanner Driver |
| `sdmmc` | home-os SD/MMC Driver with DMA Support |
| `sdmmc_highspeed` | home-os SD/MMC High-Speed Mode Verification |
| `sdmmc_tuning` | home-os SD/MMC Tuning Module |
| `sensors` | home-os Sensor Framework |
| `serial` | home-os Serial Port Driver (Extended) |
| `smartcard` | home-os Smart Card Reader |
| `sound` | home-os Sound System |
| `spi` | home-os SPI (Serial Peripheral Interface) Driver |
| `timer` | home-os Kernel - PIT (Programmable Interval Timer) Driver |
| `touchpad` | home-os Touchpad Driver |
| `touchscreen` | home-os Touchscreen Driver |
| `tpm` | home-os TPM Driver |
| `uhci` | home-os UHCI Driver |
| `usb` | home-os USB Driver (UHCI/EHCI/XHCI) |
| `usb_hub` | home-os USB Hub |
| `usb_xhci` | home-os xHCI (USB 3.0) Host Controller Driver |
| `vga_graphics` | home-os VGA Graphics Mode Driver |
| `virtio` | home-os Kernel - Virtio Drivers |
| `virtio_net` | home-os VirtIO Network Driver |
| `watchdog` | home-os Watchdog Timer Driver |
| `wifi` | home-os WiFi Driver |
| `xhci` | home-os XHCI Driver |

### fs (11 modules)

| Module | Description |
|--------|-------------|
| `btrfs` | home-os Btrfs Filesystem |
| `devfs` | home-os DevFS |
| `exfat` | home-os exFAT Filesystem |
| `ext2` | home-os EXT2 Filesystem Driver |
| `fat32` | home-os FAT32 Filesystem Driver |
| `iso9660` | home-os ISO 9660 Filesystem |
| `ntfs` | home-os NTFS Filesystem Driver |
| `procfs` | home-os Kernel - ProcFS |
| `sysfs` | home-os Kernel - SysFS |
| `tmpfs` | home-os TmpFS |
| `xfs` | home-os XFS Filesystem |

### gaming (1 modules)

| Module | Description |
|--------|-------------|
| `compatibility` | home-os Kernel - Gaming Compatibility Layer |

### gui (2 modules)

| Module | Description |
|--------|-------------|
| `craft_integration` | home-os GUI - Craft UI Integration |
| `window_manager` | home-os GUI - Advanced Window Manager |

### i18n (2 modules)

| Module | Description |
|--------|-------------|
| `locale` | home-os Kernel - Locale and Internationalization |
| `unicode` | home-os Kernel - Unicode Support |

### industrial (2 modules)

| Module | Description |
|--------|-------------|
| `can_bus` | home-os Kernel - CAN Bus Support |
| `modbus` | home-os Kernel - Modbus Protocol |

### iot (3 modules)

| Module | Description |
|--------|-------------|
| `home_automation` | home-os Kernel - Home Automation |
| `mqtt` | home-os Kernel - MQTT Broker |
| `sensors` | home-os Kernel - IoT Sensor Support |

### ipc (3 modules)

| Module | Description |
|--------|-------------|
| `msgqueue` | home-os Message Queue |
| `pipe` | home-os Pipe IPC |
| `shm` | home-os Shared Memory |

### lib (4 modules)

| Module | Description |
|--------|-------------|
| `craft_lib` | Craft UI Library Integration for home-os |
| `den_lib` | Den Shell Library Integration for home-os |
| `pantry_lib` | Pantry Library Integration for home-os |
| `shell_syscall` | home-os Kernel - Shell to Syscall Integration |

### loader (2 modules)

| Module | Description |
|--------|-------------|
| `elf` | home-os ELF Loader |
| `module` | home-os Kernel Module Loader |

### media (1 modules)

| Module | Description |
|--------|-------------|
| `video_decoder` | home-os Kernel - Video Decoder |

### mm (10 modules)

| Module | Description |
|--------|-------------|
| `buddy` | home-os Buddy Allocator |
| `kmem_cache` | home-os Kernel Memory Cache |
| `memcg` | HomeOS Memory Cgroups - Enhanced |
| `mm_integration` | home-os Kernel - Memory Management Integration |
| `oom` | home-os OOM Killer |
| `pool` | home-os Memory Pool Allocator |
| `slab` | home-os Slab Allocator |
| `swap` | HomeOS Swap Management - Enhanced |
| `vmalloc` | home-os Virtual Memory Allocator |
| `zram` | home-os ZRAM - Compressed RAM Block Device |

### net (20 modules)

| Module | Description |
|--------|-------------|
| `arp` | home-os ARP Protocol |
| `coap` | home-os CoAP (Constrained Application Protocol) |
| `dhcp` | home-os DHCP Client |
| `dns` | home-os DNS Client |
| `http` | home-os HTTP/1.1 Client and Server |
| `icmp` | home-os ICMP Protocol |
| `ipv6` | home-os IPv6 Protocol |
| `mqtt` | home-os MQTT (Message Queuing Telemetry Transport) Client |
| `netfilter` | home-os Netfilter |
| `netns` | home-os Network Namespaces |
| `nfc` | home-os NFC Driver |
| `nfs` | home-os NFS Client |
| `qos` | home-os QoS |
| `smb` | home-os SMB/CIFS Client |
| `socket` | home-os Kernel - Socket Layer |
| `tcp` | home-os Kernel - Full TCP/IP Stack |
| `tls` | home-os TLS 1.2/1.3 Implementation |
| `udp` | home-os UDP Protocol |
| `websocket` | home-os WebSocket Protocol (RFC 6455) |
| `wifi_bt_connectivity_test` | home-os WiFi/Bluetooth End-to-End Connectivity Tests |

### network (5 modules)

| Module | Description |
|--------|-------------|
| `qos` | home-os Kernel - Quality of Service (QoS) |
| `rdp_server` | home-os Kernel - RDP Server |
| `ssh_server` | home-os Kernel - SSH Server |
| `vpn` | home-os Kernel - VPN Support |
| `wifi_hotspot` | home-os Kernel - WiFi Hotspot Mode |

### os (1 modules)

| Module | Description |
|--------|-------------|
| `cpu` | CPU operations for OS development |

### perf (15 modules)

| Module | Description |
|--------|-------------|
| `async_io` | home-os Kernel - Async I/O (io_uring-like interface) |
| `baseline` | HomeOS Performance Baseline Module |
| `benchmark` | home-os Kernel - Benchmark Suite |
| `boot_opt` | home-os Kernel - Advanced Boot Optimization & Profiling |
| `cache_opt` | home-os Kernel - Cache Optimization |
| `flamegraph` | HomeOS Flamegraph Support Module |
| `ftrace` | home-os Function Tracer |
| `hugepages` | home-os Kernel - Huge Page Support |
| `lockfree` | home-os Kernel - Lock-Free Data Structures |
| `memory_compression` | home-os Kernel - Memory Compression (zswap-like) |
| `perf` | home-os Performance Monitoring |
| `profiler` | home-os Kernel - Enhanced Performance Profiler |
| `rcu` | home-os Kernel - RCU (Read-Copy-Update) |
| `sd_benchmark` | home-os SD Card Benchmark Suite |
| `zero_copy` | home-os Kernel - Zero-Copy Networking |

### power (4 modules)

| Module | Description |
|--------|-------------|
| `cpufreq` | home-os CPU Frequency Scaling (DVFS - Dynamic Voltage and Fr |
| `pm` | home-os Power Management |
| `power` | home-os Power Management with Peripheral Gating |
| `thermal` | home-os Thermal Monitoring and Throttling |

### realtime (1 modules)

| Module | Description |
|--------|-------------|
| `rt_scheduler` | home-os Kernel - Real-Time Scheduler |

### rpi (12 modules)

| Module | Description |
|--------|-------------|
| `bcm2711` | home-os Raspberry Pi BCM2711 Support |
| `bcm2712` | home-os Raspberry Pi BCM2712 Support |
| `bcm2835` | home-os Raspberry Pi BCM2835 Support |
| `bcm2836` | home-os Raspberry Pi BCM2836 Support |
| `bcm2837` | home-os Raspberry Pi BCM2837 Support |
| `hdmi_cec` | home-os HDMI CEC (Consumer Electronics Control) Driver |
| `mailbox_vc6` | home-os VideoCore VI GPU Mailbox Interface |
| `mailbox_vc7` | home-os VideoCore VII GPU Mailbox Interface |
| `platform` | home-os Raspberry Pi Platform Abstraction |
| `rp1` | home-os Raspberry Pi 5 RP1 Southbridge Driver |
| `rp1_hdmi` | home-os Raspberry Pi 5 HDMI Driver via RP1 |
| `videocore7` | home-os VideoCore VII GPU Driver |

### sched (3 modules)

| Module | Description |
|--------|-------------|
| `cfs` | home-os Completely Fair Scheduler (CFS) |
| `rt` | home-os Real-Time Scheduler |
| `scheduler` | home-os Kernel - Unified Scheduler |

### security (18 modules)

| Module | Description |
|--------|-------------|
| `acl` | home-os Kernel - Access Control Lists (ACLs) |
| `aslr` | home-os Kernel - ASLR (Address Space Layout Randomization) |
| `audit` | home-os Kernel - Audit Logging |
| `capabilities` | home-os Kernel - Capability-Based Security |
| `caps` | home-os Capabilities |
| `cpu_security` | home-os Kernel - CPU Security Features |
| `encryption` | home-os Kernel - File System Encryption |
| `firewall` | home-os Kernel - Integrated Firewall |
| `kernel_user_split` | home-os Kernel/User Address Space Separation |
| `ptr_safety` | HomeOS Pointer Safety Module |
| `random` | home-os Kernel - Secure Random Number Generator |
| `sandbox` | home-os Kernel - Container-like Sandbox |
| `seccomp` | home-os Kernel - Seccomp-BPF (Secure Computing with BPF) |
| `selinux` | home-os SELinux-style Security |
| `smep_smap` | home-os Kernel - SMEP/SMAP Support |
| `stack_guard` | home-os Stack Protection (Stack Canaries) |
| `stack_protection` | home-os Kernel - Stack Protection |
| `wx_enforcement` | home-os Kernel - W^X Enforcement (Write XOR Execute) |

### sync (3 modules)

| Module | Description |
|--------|-------------|
| `mutex` | home-os Mutex |
| `semaphore` | home-os Semaphore |
| `spinlock` | home-os Spinlock |

### sys (2 modules)

| Module | Description |
|--------|-------------|
| `signal` | home-os Kernel - Signal Delivery System |
| `syscall` | home-os Kernel - System Call Interface |

### system (3 modules)

| Module | Description |
|--------|-------------|
| `backup` | home-os Kernel - Backup and Restore |
| `crash_reporter` | home-os Kernel - Crash Reporter |
| `update` | home-os Kernel - System Updates |

### time (2 modules)

| Module | Description |
|--------|-------------|
| `clocksource` | home-os Clock Source |
| `hrtimer` | home-os High-Resolution Timers |

### ui (2 modules)

| Module | Description |
|--------|-------------|
| `theme_manager` | home-os Kernel - Theme Manager |
| `wallpaper` | home-os Kernel - Wallpaper Manager |

### video (3 modules)

| Module | Description |
|--------|-------------|
| `compositor` | home-os Display Compositor |
| `opengl` | home-os OpenGL 1.x Compatible Software Renderer |
| `vulkan` | home-os Vulkan 1.0 Compatible API |

### vm (2 modules)

| Module | Description |
|--------|-------------|
| `kvm` | home-os KVM |
| `virtio` | home-os VirtIO Framework |


## Statistics

- **Total Modules:** 279
- **Total Lines of Code:** 125458
- **Average Lines per Module:** 449

## Build Information

Generated on: 2025-12-16 20:37:35
