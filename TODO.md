# home-os TODO

> A modern, performant, minimal operating system built from scratch using Home (language), Craft (UI), and Pantry (package manager)

## Project Vision

Build a next-generation operating system that prioritizes:
- **Performance**: Sub-second boot, instant responsiveness
- **Minimal Resources**: <512MB RAM for base system (x86-64), <256MB for Raspberry Pi
- **Security**: Memory-safe language, capability-based security
- **Developer Experience**: Built-in tooling, zero-config development
- **Modern UX**: GPU-accelerated UI, beautiful design
- **Portability**: First-class support for x86-64 and ARM64 (Raspberry Pi)
- **Education**: Ideal for learning OS development and embedded systems

## Technology Stack

- **Language**: Home (memory-safe systems language, Zig-like speed, Rust-like safety)
  - Location: `~/Code/home`
  - Status: Active development, foundation phase complete
- **UI Engine**: Craft (1.4MB binary, <100ms startup, 35+ native components)
  - Location: `~/Code/craft`
  - Backends: Vulkan (primary), Metal (macOS), OpenGL (fallback)
- **Package Manager**: Pantry (multi-source package manager, sub-5ms environment switching)
  - Location: `~/Code/pantry`
  - Package Sources: pkgx.sh (10,000+ packages), npm registry, GitHub releases, custom HTTP endpoints
  - Installation Modes: Global, project-local, environment-isolated

---

## Development Milestones

### Milestone 1: "Hello World" (Week 4)
- Bootable kernel that prints "home-os" to serial console
- Runs on QEMU x86-64

### Milestone 2: "Interactive" (Week 12)
- Basic keyboard input and framebuffer output
- Simple shell that can run one built-in command

### Milestone 3: "Persistent" (Week 20)
- File system support with ability to create/read/write files
- Basic network stack (ping works)

### Milestone 4: "Visual" (Week 30)
- Craft UI displaying simple window with button
- Mouse cursor working

### Milestone 5: "Portable" (Week 48)
- Boots on real Raspberry Pi 4 hardware
- Boots on real x86-64 laptop

### Milestone 6: "Useful" (Week 60)
- Can browse the web, edit text files, compile Home code
- Package manager can install common tools

### Milestone 7: "Release" (Week 78)
- Public 1.0 release
- Documentation, installers, community ready

---

## Phase 1: Foundation & Bootloader (Weeks 1-4)

**Status**: 🚧 In Progress (Week 1)

### 1.1 Bootloader Implementation
- [x] **Week 1-2**: Create UEFI bootloader using Home
  - [x] Implement Multiboot2 header (using Home's kernel package)
  - [x] Set up memory map and paging structures (boot.s)
  - [x] Load kernel binary into memory
  - [x] Pass boot parameters to kernel (magic + info_addr)
  - [x] Support for GPT partition tables (Multiboot2)
- [x] Implement legacy BIOS bootloader (Multiboot2 + GRUB2)
  - [ ] MBR boot sector code
  - [ ] Stage 2 loader
  - [ ] A20 line activation
  - [ ] Protected mode transition
- [x] Bootloader configuration system
  - [x] Parse boot configuration file (grub.cfg)
  - [x] Support multiple boot entries (normal, debug, safe)
  - [x] Kernel parameter passing (via Multiboot2 cmdline)
  - [x] Timeout and default selection (GRUB)
- [x] Early graphics initialization
  - [x] VGA text mode (80x25)
  - [x] Set framebuffer mode (VGA)
  - [x] Display boot splash screen (banner)

### 1.2 Minimal Kernel Core
- [x] **Week 2-3**: Kernel entry point and initialization
  - [x] Switch to kernel address space (boot.s - 64-bit long mode)
  - [x] Set up GDT (Global Descriptor Table) (boot.s)
  - [ ] Set up IDT (Interrupt Descriptor Table) (TODO: causes triple fault)
  - [x] Initialize CPU features (CPUID check, PAE, long mode)
- [~] Physical memory manager (**IN PROGRESS - Oct 28, 2025**)
  - [x] Bitmap allocator for physical pages (pmm.zig, pmm.home)
  - [x] Page frame allocator (4KB pages)
  - [~] Parse Multiboot2 memory map (TODO: causes crashes, using simple layout for now)
  - [ ] Support for huge pages (2MB, 1GB) (TODO: Phase 2)
- [ ] Virtual memory manager
  - [ ] 4-level page table implementation
  - [ ] Kernel space mapping (higher half)
  - [ ] User space mapping (lower half)
  - [ ] Memory protection (NX, W^X)
  - [ ] ASLR (Address Space Layout Randomization)
- [ ] Heap allocator
  - [ ] slab allocator for kernel objects
  - [ ] General-purpose allocator (buddy system)
  - [ ] Integrate with Home's ownership system
  - [ ] Memory leak detection (debug builds)
- [ ] Interrupt handling
  - [ ] ISR (Interrupt Service Routines) setup
  - [ ] IRQ routing and handling
  - [ ] APIC (Advanced Programmable Interrupt Controller)
  - [ ] Timer interrupts (PIT/HPET)
- [ ] CPU initialization
  - [ ] Multi-core detection
  - [ ] Local APIC setup per-core
  - [ ] CPU feature detection (CPUID)
  - [ ] FPU/SSE state management

### 1.3 Device Drivers (Basic)
- [x] **Week 3-4**: Serial port driver (for early debugging)
  - [x] COM1 initialization (serial.home)
  - [x] Buffered output (writeString, writeHex, writeDec)
  - [ ] Interrupt-driven receive (TODO: needs IDT)
- [ ] Keyboard driver (TODO: Phase 2)
  - [ ] PS/2 keyboard controller
  - [ ] USB keyboard (UHCI/EHCI/XHCI)
  - [ ] Scancode to keycode translation
  - [ ] Keyboard layout support
- [x] Framebuffer driver (VGA text mode - vga.home)
  - [x] Linear framebuffer access (0xB8000)
  - [x] Mode setting (80x25 text mode)
  - [ ] Double buffering support (TODO: Phase 4)
  - [x] Software cursor (row/column tracking)
- [ ] Storage driver (basic)
  - [ ] ATA/ATAPI (IDE) support
  - [ ] AHCI (SATA) driver
  - [ ] NVMe driver (PCIe SSDs)
  - [ ] Partition table parsing (GPT, MBR)

---

## Phase 2: Process & Memory Management (Weeks 5-8)

### 2.1 Process Subsystem
- [ ] Process structure and lifecycle
  - [ ] Process Control Block (PCB) design
  - [ ] Process states (ready, running, blocked, zombie)
  - [ ] Process creation (fork/exec model)
  - [ ] Process termination and cleanup
  - [ ] Process tree hierarchy
- [ ] Thread implementation
  - [ ] Kernel threads
  - [ ] User threads (1:1 model)
  - [ ] Thread local storage (TLS)
  - [ ] Thread creation and destruction
- [ ] Scheduler
  - [ ] Completely Fair Scheduler (CFS) algorithm
  - [ ] Per-CPU run queues
  - [ ] Priority scheduling
  - [ ] Real-time scheduling classes
  - [ ] CPU affinity and pinning
  - [ ] Load balancing across cores
- [ ] Context switching
  - [ ] Save/restore CPU state
  - [ ] FPU/SSE state handling
  - [ ] TLB flushing optimization
  - [ ] Fast system call entry (SYSCALL/SYSRET)
- [ ] Process isolation
  - [ ] Address space separation
  - [ ] User/kernel mode separation
  - [ ] Memory protection
  - [ ] Capability-based security

### 2.2 Inter-Process Communication (IPC)
- [ ] Shared memory
  - [ ] Anonymous shared memory
  - [ ] Named shared memory objects
  - [ ] Copy-on-write optimization
- [ ] Message queues
  - [ ] POSIX message queues
  - [ ] Priority message handling
  - [ ] Non-blocking operations
- [ ] Pipes and FIFOs
  - [ ] Anonymous pipes
  - [ ] Named pipes (FIFOs)
  - [ ] Buffering and flow control
- [ ] Signals
  - [ ] Signal generation and delivery
  - [ ] Signal handlers
  - [ ] Real-time signals
  - [ ] Signal masking
- [ ] Unix domain sockets
  - [ ] Stream sockets (SOCK_STREAM)
  - [ ] Datagram sockets (SOCK_DGRAM)
  - [ ] File descriptor passing

### 2.3 Advanced Memory Management
- [ ] Memory mapping (mmap/munmap)
  - [ ] Anonymous mappings
  - [ ] File-backed mappings
  - [ ] Shared mappings
  - [ ] Protection flags
- [ ] Page fault handler
  - [ ] Demand paging
  - [ ] Copy-on-write
  - [ ] Page cache
  - [ ] Swap file support (optional)
- [ ] Memory allocation strategies
  - [ ] Buddy allocator refinement
  - [ ] SLUB allocator (kernel objects)
  - [ ] User-space allocator integration with Home
- [ ] Memory pressure handling
  - [ ] Page reclamation
  - [ ] LRU page eviction
  - [ ] Memory compaction
  - [ ] OOM (Out-Of-Memory) killer

---

## Phase 3: File System (Weeks 9-12)

### 3.1 Virtual File System (VFS)
- [ ] VFS architecture
  - [ ] Inode abstraction
  - [ ] Dentry (directory entry) cache
  - [ ] File operations interface
  - [ ] Superblock operations
- [ ] File descriptor table
  - [ ] Per-process FD table
  - [ ] File description sharing
  - [ ] Close-on-exec flag
- [ ] Path resolution
  - [ ] Absolute and relative paths
  - [ ] Symlink following (with loop detection)
  - [ ] Mount point traversal
  - [ ] Permission checking
- [ ] Mount system
  - [ ] Mount/umount operations
  - [ ] Mount namespace support
  - [ ] Bind mounts
  - [ ] Read-only mounts

### 3.2 Native File System Implementation
- [ ] Design home-fs (native file system)
  - [ ] Block-based architecture
  - [ ] Extent-based allocation (like ext4/XFS)
  - [ ] B-tree indexing for directories
  - [ ] Journaling for crash recovery
  - [ ] Copy-on-write support (like Btrfs)
- [ ] Implement core operations
  - [ ] File creation, deletion, rename
  - [ ] Directory operations
  - [ ] Read/write operations
  - [ ] Sparse file support
  - [ ] Large file support (>2GB)
- [ ] Advanced features
  - [ ] Extended attributes (xattrs)
  - [ ] Access control lists (ACLs)
  - [ ] File compression (transparent)
  - [ ] Encryption (per-file or per-directory)
  - [ ] Snapshots and cloning
- [ ] Performance optimizations
  - [ ] Read-ahead
  - [ ] Write-behind caching
  - [ ] Directory entry caching
  - [ ] Block group optimization

### 3.3 File System Utilities
- [ ] mkfs.home-fs (file system creation)
- [ ] fsck.home-fs (file system check and repair)
- [ ] mount/umount commands
- [ ] df (disk free space)
- [ ] du (disk usage)
- [ ] File permissions and ownership tools

### 3.4 Other File System Support
- [ ] ext4 driver (read/write)
- [ ] FAT32 driver (for USB drives, compatibility)
- [ ] exFAT driver (for large external drives)
- [ ] ISO 9660 (CD/DVD support)
- [ ] procfs (process information virtual FS)
- [ ] sysfs (kernel and device information)
- [ ] tmpfs (RAM-based temporary FS)

---

## Phase 4: Device Management & Drivers (Weeks 13-16)

### 4.1 Device Model
- [ ] Device tree structure
  - [ ] Bus hierarchy (PCI, USB, etc.)
  - [ ] Device discovery and enumeration
  - [ ] Hot-plug support
- [ ] Driver framework
  - [ ] Driver registration and probing
  - [ ] Driver lifecycle management
  - [ ] Device-driver binding
- [ ] Device files (/dev)
  - [ ] Character devices
  - [ ] Block devices
  - [ ] Major/minor numbers
  - [ ] udev-like dynamic device management

### 4.2 PCI/PCIe Support
- [ ] PCI configuration space access
- [ ] PCI device enumeration
- [ ] MSI/MSI-X interrupt support
- [ ] PCIe extended capabilities
- [ ] DMA (Direct Memory Access) support
  - [ ] DMA buffer allocation
  - [ ] IOMMU integration
  - [ ] Scatter-gather lists

### 4.3 USB Support
- [ ] USB host controller drivers
  - [ ] EHCI (USB 2.0)
  - [ ] XHCI (USB 3.0+)
- [ ] USB device enumeration
- [ ] USB hub support
- [ ] Common USB device classes
  - [ ] HID (keyboards, mice)
  - [ ] Mass storage (USB drives)
  - [ ] Audio devices
  - [ ] Network adapters

### 4.4 Network Drivers
- [ ] Ethernet controller drivers
  - [ ] Intel e1000/e1000e
  - [ ] Realtek RTL8139/RTL8169
  - [ ] Virtio-net (virtualization)
- [ ] WiFi support (basic)
  - [ ] Intel iwlwifi
  - [ ] Broadcom drivers
  - [ ] WiFi management interface
- [ ] Network device abstraction
  - [ ] TX/RX ring buffers
  - [ ] Interrupt coalescing
  - [ ] Multiqueue support

### 4.5 Graphics Drivers
- [ ] Framebuffer driver (already done in Phase 1, enhance)
- [ ] GPU drivers
  - [ ] Intel integrated graphics (i915)
  - [ ] AMD GPUs (basic AMDGPU)
  - [ ] NVIDIA (nouveau open-source)
  - [ ] Virtio-GPU (virtualization)
- [ ] DRM/KMS (Direct Rendering Manager / Kernel Mode Setting)
  - [ ] Mode setting
  - [ ] Page flipping
  - [ ] Hardware cursor
  - [ ] VBLANK synchronization
- [ ] GPU acceleration APIs
  - [ ] OpenGL support (via Craft integration)
  - [ ] Vulkan support (via Craft integration)
  - [ ] Metal support (macOS, via Craft)

### 4.6 Audio Support
- [ ] Audio driver framework
- [ ] HDA (High Definition Audio) driver
- [ ] USB audio support
- [ ] Audio mixer and routing
- [ ] ALSA-compatible API

### 4.7 Input Devices
- [ ] Enhanced keyboard support
  - [ ] Multiple keyboard layouts
  - [ ] Compose key support
  - [ ] Key repeat rate
- [ ] Mouse/touchpad drivers
  - [ ] PS/2 mouse
  - [ ] USB mouse
  - [ ] Touchpad with gestures
- [ ] Touchscreen support
- [ ] Game controller support

---

## Phase 5: Networking Stack (Weeks 17-20)

### 5.1 Network Core
- [ ] Socket abstraction layer
  - [ ] Socket creation and binding
  - [ ] Connect/listen/accept
  - [ ] Send/receive operations
  - [ ] Socket options (SO_REUSEADDR, etc.)
- [ ] Network buffer management (skbuff)
  - [ ] Buffer allocation and freeing
  - [ ] Buffer cloning and sharing
  - [ ] Header manipulation
- [ ] Network device interface
  - [ ] Packet transmission
  - [ ] Packet reception
  - [ ] Device statistics

### 5.2 Protocol Implementation
- [ ] Ethernet (Layer 2)
  - [ ] Frame parsing
  - [ ] MAC address handling
  - [ ] ARP protocol
- [ ] IPv4 (Layer 3)
  - [ ] Packet routing
  - [ ] Fragmentation and reassembly
  - [ ] ICMP (ping, traceroute)
  - [ ] IP forwarding (routing)
- [ ] IPv6 (Layer 3)
  - [ ] IPv6 addressing
  - [ ] Neighbor Discovery Protocol (NDP)
  - [ ] ICMPv6
  - [ ] Dual-stack support
- [ ] TCP (Layer 4)
  - [ ] Connection establishment (3-way handshake)
  - [ ] Reliable delivery (ACKs, retransmission)
  - [ ] Flow control (sliding window)
  - [ ] Congestion control (Cubic, BBR)
  - [ ] Connection termination
- [ ] UDP (Layer 4)
  - [ ] Connectionless datagram service
  - [ ] Checksum verification
  - [ ] Broadcast/multicast support

### 5.3 Network Utilities
- [ ] DHCP client
  - [ ] IP address acquisition
  - [ ] Lease renewal
  - [ ] Network configuration
- [ ] DNS resolver
  - [ ] Query generation
  - [ ] Response parsing
  - [ ] Caching
  - [ ] /etc/resolv.conf support
- [ ] Firewall/packet filter
  - [ ] Rule-based filtering
  - [ ] NAT support
  - [ ] Connection tracking

### 5.4 Advanced Networking
- [ ] TLS/SSL support (via Home's crypto library)
- [ ] WebSocket support
- [ ] HTTP/1.1 and HTTP/2 client/server (integrate with Home's stdlib)
- [ ] Network namespaces (for containerization)

---

## Phase 6: User Space Foundation (Weeks 21-24)

### 6.1 System Call Interface
- [ ] System call table
- [ ] System call dispatcher
- [ ] Parameter validation
- [ ] Implement POSIX-like syscalls
  - [ ] Process: fork, exec, wait, exit, getpid
  - [ ] File: open, close, read, write, lseek, stat
  - [ ] Directory: mkdir, rmdir, chdir, getcwd
  - [ ] IPC: pipe, socket, mmap, shmget
  - [ ] Signals: kill, sigaction, sigreturn
  - [ ] Time: gettimeofday, clock_gettime, nanosleep
  - [ ] User/Group: getuid, setuid, getgid, setgid

### 6.2 C Library (libc) Implementation
- [ ] Design home-libc (lightweight, Home-compatible)
  - [ ] System call wrappers
  - [ ] Standard I/O (stdio.h)
  - [ ] String operations (string.h)
  - [ ] Memory management (stdlib.h)
  - [ ] Math functions (math.h)
  - [ ] Time functions (time.h)
  - [ ] Threading (pthread-compatible)
- [ ] Dynamic linker/loader
  - [ ] ELF binary loading
  - [ ] Shared library loading (.so)
  - [ ] Symbol resolution
  - [ ] Lazy binding
  - [ ] Library search paths (LD_LIBRARY_PATH)

### 6.3 Core System Utilities (Userland)
- [ ] Shell (home-sh)
  - [ ] Command parsing and execution
  - [ ] Pipes and redirections
  - [ ] Environment variables
  - [ ] Built-in commands (cd, pwd, export, etc.)
  - [ ] Job control (fg, bg, jobs)
  - [ ] Tab completion
  - [ ] History
- [ ] Core utilities (coreutils-like)
  - [ ] File: ls, cp, mv, rm, touch, cat, head, tail, grep, find
  - [ ] Text: echo, printf, cut, sort, uniq, wc, sed, awk
  - [ ] System: ps, top, kill, uname, uptime, free, df, du
  - [ ] User: id, whoami, groups, su, sudo
  - [ ] Network: ping, ifconfig, route, netstat
- [ ] Init system
  - [ ] Process reaping (PID 1 responsibilities)
  - [ ] Service management
  - [ ] Dependency resolution
  - [ ] Parallel service startup
  - [ ] Service supervision (restart on crash)

---

## Phase 7: Pantry Package Manager Integration (Weeks 25-26)

### 7.1 Port Pantry to home-os
- [ ] Rewrite Pantry core in Home language
  - [ ] Package manifest parsing (YAML/JSON/TOML)
  - [ ] Dependency resolution algorithm
  - [ ] Version constraint handling (semver, ranges, wildcards)
  - [ ] Multi-tier cache management (in-memory, disk, CDN)
- [ ] Integrate with home-os kernel
  - [ ] System call interface for package operations
  - [ ] File system operations (extract, symlink, hardlink)
  - [ ] Process spawning (post-install scripts, hooks)
  - [ ] Sandboxed execution for untrusted packages
- [ ] Multi-source package registry integration
  - [ ] pkgx.sh registry client (primary source, 10,000+ packages)
  - [ ] npm registry client (for JavaScript/Node.js packages)
  - [ ] GitHub releases API (for downloading release artifacts)
  - [ ] Custom HTTP endpoint support (self-hosted registries)
  - [ ] Registry priority and fallback mechanism
  - [ ] Mirror support for offline/airgapped environments
- [ ] Package verification and security
  - [ ] HTTP client with connection pooling
  - [ ] TLS 1.3 support for secure downloads
  - [ ] Signature verification (GPG, minisign, cosign)
  - [ ] Checksum validation (SHA256, SHA512)
  - [ ] Metadata parsing and validation
  - [ ] Supply chain security (SBOM, provenance)

### 7.2 Package Management Features
- [ ] Package installation
  - [ ] Download from multiple sources (pkgx, npm, GitHub, custom)
  - [ ] Source selection based on package type and availability
  - [ ] Parallel downloads for multiple packages
  - [ ] Extract to package directory (versioned paths)
  - [ ] Create symlinks (version, compatibility, PKG_CONFIG)
  - [ ] Run post-install scripts (sandboxed)
  - [ ] Register in package database (SQLite)
  - [ ] Binary cache support (skip compilation)
- [ ] Package removal
  - [ ] Dependency checking (prevent breaking dependent packages)
  - [ ] Reverse dependency tracking
  - [ ] File cleanup (garbage collection)
  - [ ] Symlink removal (safe unlinking)
  - [ ] Database update (transaction-safe)
  - [ ] Orphan package detection and cleanup
- [ ] Package updates
  - [ ] Check for newer versions across all sources
  - [ ] Version comparison (respect semver constraints)
  - [ ] Download and install updates
  - [ ] Atomic updates (rollback on failure)
  - [ ] Update all vs selective update
  - [ ] Security update prioritization
- [ ] Environment management
  - [ ] Per-project environments (isolated dependency trees)
  - [ ] Environment fingerprinting (hash of dependencies)
  - [ ] Environment activation/deactivation (PATH, LD_LIBRARY_PATH)
  - [ ] Shell integration hooks (bash, zsh, fish)
  - [ ] Multi-tier environment caching (instant switching)
  - [ ] Environment inspection and debugging

### 7.3 System Integration
- [ ] Bootstrap essential packages
  - [ ] Compiler toolchain (Home compiler, LLVM, GCC)
  - [ ] Build tools (make, cmake, ninja)
  - [ ] Core utilities (coreutils, findutils)
  - [ ] Network tools (curl, wget, openssh)
  - [ ] Development tools (git, vim, tmux)
- [ ] Service management integration
  - [ ] 30+ pre-configured services (PostgreSQL, Redis, Nginx, etc.)
  - [ ] Automatic service initialization and configuration
  - [ ] Service configuration templates
  - [ ] Service health checks and monitoring
  - [ ] Service logs and debugging
  - [ ] Multi-instance support (different versions side-by-side)
- [ ] Development environment setup
  - [ ] Automatic tool installation based on project files
  - [ ] Language-specific version management (Node, Python, Go, Rust, etc.)
  - [ ] Environment isolation per project
  - [ ] IDE integration (VSCode, JetBrains)
  - [ ] Pre-configured development stacks
- [ ] Package source configuration
  - [ ] Configure custom HTTP endpoints (self-hosted, corporate)
  - [ ] npm registry authentication (npm token support)
  - [ ] GitHub releases authentication (GitHub token support)
  - [ ] Source priority configuration (prefer certain sources)
  - [ ] Proxy and mirror configuration
  - [ ] Airgapped/offline mode support

---

## Phase 8: Craft UI Integration (Weeks 27-30)

### 8.1 Port Craft to home-os
- [ ] Rewrite Craft core in Home language
  - [ ] Component system
  - [ ] Event handling
  - [ ] State management
  - [ ] Animation engine
- [ ] WebView integration
  - [ ] Port WebKit to home-os (or use lightweight alternative)
  - [ ] JavaScript bridge implementation
  - [ ] HTML/CSS renderer integration
- [ ] GPU rendering backend
  - [ ] Metal backend (if targeting macOS VMs)
  - [ ] Vulkan backend (primary for home-os)
  - [ ] OpenGL fallback
- [ ] Native component rendering
  - [ ] 35+ UI components
  - [ ] Custom styling engine
  - [ ] Theme system integration

### 8.2 Display Server
- [ ] Compositor implementation
  - [ ] Window management
  - [ ] Damage tracking
  - [ ] Buffer management
  - [ ] VSync synchronization
- [ ] Wayland protocol server (modern approach)
  - [ ] Core protocol support
  - [ ] XDG shell protocol
  - [ ] Input handling
  - [ ] Output management
- [ ] X11 compatibility layer (optional, for legacy apps)

### 8.3 Window Manager
- [ ] Window creation and destruction
- [ ] Window positioning and sizing
- [ ] Window stacking (z-order)
- [ ] Window focus management
- [ ] Window decorations (title bar, buttons)
- [ ] Tiling and floating modes
- [ ] Virtual desktops/workspaces
- [ ] Multi-monitor support

### 8.4 System UI Components
- [ ] Desktop environment
  - [ ] Desktop background/wallpaper
  - [ ] Desktop icons
  - [ ] Right-click context menu
- [ ] Panel/Taskbar
  - [ ] Application launcher
  - [ ] Window list
  - [ ] System tray
  - [ ] Clock/calendar
  - [ ] Quick settings
- [ ] Application launcher
  - [ ] Fuzzy search
  - [ ] Recently used apps
  - [ ] Favorites
- [ ] Notification system
  - [ ] Toast notifications
  - [ ] Notification center
  - [ ] Priority levels
  - [ ] Action buttons
- [ ] System settings application
  - [ ] Display settings
  - [ ] Network settings
  - [ ] User accounts
  - [ ] Appearance/themes
  - [ ] Keyboard/mouse settings
  - [ ] Power management

### 8.5 Application Framework
- [ ] Craft-based application template
  - [ ] Window creation
  - [ ] Menu bar
  - [ ] Toolbar
  - [ ] Status bar
  - [ ] Dialogs
- [ ] Application lifecycle management
  - [ ] Application launch
  - [ ] Window state preservation
  - [ ] Application termination
- [ ] Inter-application communication
  - [ ] D-Bus integration (or custom IPC)
  - [ ] Clipboard support
  - [ ] Drag-and-drop

---

## Phase 9: Essential Applications (Weeks 31-34)

### 9.1 File Manager
- [ ] File/directory browsing
- [ ] Tree view and list view
- [ ] File preview (images, text, PDFs)
- [ ] File operations (copy, move, delete, rename)
- [ ] Search functionality
- [ ] Bookmarks/favorites
- [ ] Network shares (SMB, NFS)
- [ ] Trash/recycle bin

### 9.2 Terminal Emulator
- [ ] VT100/ANSI escape sequence support
- [ ] Text rendering (with proper font support)
- [ ] Color themes
- [ ] Tabs and split panes
- [ ] Scrollback buffer
- [ ] Copy/paste
- [ ] URL detection and opening
- [ ] Configurable key bindings

### 9.3 Text Editor
- [ ] Syntax highlighting (multiple languages)
- [ ] Line numbers
- [ ] Search and replace
- [ ] Multiple tabs
- [ ] Auto-save
- [ ] Code folding
- [ ] Auto-completion
- [ ] Git integration

### 9.4 Web Browser (Basic)
- [ ] HTML/CSS/JavaScript rendering (via Craft WebView)
- [ ] Address bar with URL completion
- [ ] Tabs
- [ ] Bookmarks
- [ ] History
- [ ] Download manager
- [ ] Cookie management
- [ ] Private browsing mode

### 9.5 System Monitor
- [ ] CPU usage (per-core)
- [ ] Memory usage (RAM, swap)
- [ ] Disk I/O
- [ ] Network traffic
- [ ] Process list with details
- [ ] Kill process functionality
- [ ] System resource graphs

### 9.6 Calculator
- [ ] Basic arithmetic
- [ ] Scientific functions
- [ ] Programmer mode (hex, binary, etc.)
- [ ] History
- [ ] Keyboard shortcuts

---

## Phase 10: Security & Hardening (Weeks 35-38)

### 10.1 Language-Level Security (Home)
- [ ] Memory safety enforcement
  - [ ] Ownership checking at compile-time
  - [ ] Borrow checker
  - [ ] No null pointers (Option type)
  - [ ] Bounds checking
- [ ] Effect system
  - [ ] Track side effects (IO, memory mutation)
  - [ ] Enforce purity where needed
- [ ] Capability-based security
  - [ ] Fine-grained permissions
  - [ ] Least-privilege principle

### 10.2 Kernel Security
- [ ] Address space layout randomization (ASLR)
- [ ] Kernel stack protection (stack canaries)
- [ ] W^X (Write XOR Execute) enforcement
- [ ] SMEP/SMAP (Supervisor Mode Execution/Access Prevention)
- [ ] Secure boot integration
- [ ] Kernel module signing
- [ ] Kernel hardening options
  - [ ] KASLR (Kernel ASLR)
  - [ ] Hardened usercopy
  - [ ] Stack protector

### 10.3 Process Security
- [ ] Privilege separation
  - [ ] UID/GID management
  - [ ] Capability system (like Linux capabilities)
  - [ ] Mandatory Access Control (MAC)
- [ ] Sandboxing
  - [ ] Seccomp-BPF (syscall filtering)
  - [ ] Namespace isolation
  - [ ] Cgroups (resource limits)
- [ ] Audit logging
  - [ ] System call auditing
  - [ ] File access logging
  - [ ] Network activity logging

### 10.4 Network Security
- [ ] Firewall (integrated)
  - [ ] Packet filtering
  - [ ] Stateful inspection
  - [ ] Application-level filtering
- [ ] TLS/SSL enforcement
- [ ] Network namespace isolation
- [ ] Intrusion detection hooks

### 10.5 File System Security
- [ ] File permissions and ACLs
- [ ] Extended attributes for security labels
- [ ] Encryption at rest (full-disk or per-file)
- [ ] Integrity checking (checksums)
- [ ] Immutable files support

### 10.6 Cryptography
- [ ] Leverage Home's crypto library
- [ ] Secure random number generation
- [ ] Key management
- [ ] Certificate handling

---

## Phase 11: Performance Optimization (Weeks 39-42)

### 11.1 Kernel Optimization
- [ ] Profile kernel hot paths
  - [ ] Scheduler paths
  - [ ] System call entry/exit
  - [ ] Interrupt handlers
  - [ ] Memory allocation
- [ ] Lock optimization
  - [ ] RCU (Read-Copy-Update) for read-heavy data
  - [ ] Per-CPU data structures
  - [ ] Lock-free algorithms where possible
- [ ] Cache optimization
  - [ ] Cache-friendly data structures
  - [ ] Avoid false sharing
  - [ ] Prefetching hints

### 11.2 Memory Optimization
- [ ] Huge page support (transparent)
- [ ] Memory compression (zswap)
- [ ] Efficient page cache
- [ ] Memory deduplication (KSM-like)
- [ ] Minimize memory fragmentation

### 11.3 I/O Optimization
- [ ] Async I/O (io_uring-like interface)
- [ ] Block layer optimization
  - [ ] I/O scheduler tuning
  - [ ] Request merging
  - [ ] Multi-queue block layer
- [ ] File system optimizations
  - [ ] Delayed allocation
  - [ ] Extent-based allocation
  - [ ] Directory indexing

### 11.4 Network Optimization
- [ ] Zero-copy networking
- [ ] TCP offloading (TSO, GSO, LRO, GRO)
- [ ] Interrupt coalescing
- [ ] Multiqueue network devices
- [ ] XDP (eXpress Data Path) for packet processing

### 11.5 Graphics Optimization
- [ ] GPU-accelerated rendering (via Craft)
- [ ] VSync and frame pacing
- [ ] Triple buffering
- [ ] Minimize compositing overhead

### 11.6 Boot Optimization
- [ ] Parallel service startup
- [ ] Lazy module loading
- [ ] Initramfs optimization
- [ ] Fast boot path (skip unnecessary checks)
- [ ] Target: <5 second boot on SSD

### 11.7 Benchmarking
- [ ] Create comprehensive benchmark suite
  - [ ] Boot time
  - [ ] Process creation time
  - [ ] System call latency
  - [ ] Memory allocation speed
  - [ ] File system performance
  - [ ] Network throughput and latency
  - [ ] Graphics rendering FPS
- [ ] Compare against Linux, macOS, Windows
- [ ] Continuous performance monitoring

---

## Phase 12: Raspberry Pi Support (Weeks 43-48)

### 12.0 Raspberry Pi Foundation (Priority Target)

#### 12.0.1 Raspberry Pi Hardware Support
- [ ] **Raspberry Pi 4 Model B** (Primary target - ARM Cortex-A72, 4 cores, 1-8GB RAM)
  - [ ] Board-specific bootloader
    - [ ] Parse config.txt and cmdline.txt
    - [ ] Load kernel8.img (64-bit kernel)
    - [ ] GPU firmware interaction (start4.elf)
    - [ ] Device tree blob loading
  - [ ] BCM2711 SoC support
    - [ ] ARM Cortex-A72 initialization
    - [ ] Memory map setup (MMIO base 0xFE000000)
    - [ ] L1/L2 cache configuration
  - [ ] Peripheral drivers
    - [ ] Mini UART (primary serial console)
    - [ ] PL011 UART (secondary)
    - [ ] GPIO controller
    - [ ] SPI controller
    - [ ] I2C controller
    - [ ] PWM controller
  - [ ] Video Core IV GPU integration
    - [ ] Mailbox interface for GPU communication
    - [ ] Framebuffer allocation via mailbox
    - [ ] Display settings (resolution, depth)
    - [ ] Hardware video decoding (H.264)
  - [ ] Storage
    - [ ] SD/MMC controller (EMMC2)
    - [ ] USB 3.0 mass storage
    - [ ] Boot from USB support
    - [ ] Network boot (PXE)
  - [ ] Networking
    - [ ] Gigabit Ethernet (BCM54213PE PHY)
    - [ ] WiFi (Cypress CYW43455 chipset)
    - [ ] Bluetooth 5.0 (same chipset)
  - [ ] USB support
    - [ ] USB 3.0 controller (VL805)
    - [ ] USB 2.0 backward compatibility
    - [ ] USB hub support
    - [ ] USB OTG (USB-C port)
  - [ ] Audio
    - [ ] Analog audio (PWM-based)
    - [ ] HDMI audio output
    - [ ] I2S audio interface
    - [ ] USB audio devices
  - [ ] Display
    - [ ] Dual micro-HDMI outputs
    - [ ] 4K@60Hz support
    - [ ] DSI interface (touchscreen displays)
    - [ ] Composite video output
  - [ ] Power management
    - [ ] CPU frequency scaling (600MHz - 1.8GHz)
    - [ ] Thermal throttling
    - [ ] GPIO power rails
    - [ ] USB power management

- [ ] **Raspberry Pi 5** (Latest model - ARM Cortex-A76, 4 cores, 4-8GB RAM)
  - [ ] BCM2712 SoC support
    - [ ] ARM Cortex-A76 initialization (2.4GHz)
    - [ ] Updated memory map
    - [ ] Enhanced PCIe support (RP1 southbridge)
  - [ ] RP1 I/O controller
    - [ ] PCIe Gen 2.0 connection to SoC
    - [ ] Improved GPIO performance
    - [ ] Enhanced USB 3.0 support
    - [ ] Gigabit Ethernet (Broadcom BCM54213S)
  - [ ] Video Core VII GPU
    - [ ] Vulkan 1.2 support
    - [ ] OpenGL ES 3.1
    - [ ] H.265 (HEVC) hardware decode
    - [ ] Dual 4K@60Hz display output
  - [ ] PCIe 2.0 interface
    - [ ] M.2 HAT+ support
    - [ ] NVMe SSD support
    - [ ] External GPU support (experimental)
  - [ ] Enhanced power delivery
    - [ ] USB-C Power Delivery (5V/5A)
    - [ ] Power button support
    - [ ] RTC with battery backup
    - [ ] Power management IC

- [ ] **Raspberry Pi 3 Model B+** (Legacy support - ARM Cortex-A53, 1GB RAM)
  - [ ] BCM2837B0 SoC support
  - [ ] Basic peripheral support (UART, GPIO, SPI, I2C)
  - [ ] Single-core boot, then SMP
  - [ ] WiFi/Bluetooth (Cypress CYW43455)
  - [ ] Reduced feature set (target: minimal desktop)

#### 12.0.2 ARM64 Kernel Adaptations
- [ ] ARM-specific kernel entry
  - [ ] Exception level handling (EL2 → EL1 transition)
  - [ ] ARM64 system registers setup (SCTLR_EL1, TCR_EL1, MAIR_EL1)
  - [ ] Vector table (VBAR_EL1)
  - [ ] Stack pointer initialization
- [ ] Memory management (ARM64)
  - [ ] 4KB, 16KB, 64KB page granules (use 4KB for compatibility)
  - [ ] 4-level page tables (48-bit VA)
  - [ ] ASID (Address Space ID) management
  - [ ] Cache maintenance operations
  - [ ] Barrier instructions (DSB, DMB, ISB)
- [ ] Interrupt handling (ARM64)
  - [ ] GIC-400 initialization (Raspberry Pi 4)
  - [ ] GIC-600 support (Raspberry Pi 5)
  - [ ] IRQ/FIQ routing
  - [ ] SGI (Software Generated Interrupts) for IPI
  - [ ] Exception handlers
- [ ] SMP (Symmetric Multiprocessing)
  - [ ] Secondary CPU spin-up
  - [ ] Per-CPU stacks
  - [ ] TLB shootdown
  - [ ] CPU hotplug
- [ ] Timer support
  - [ ] ARM Generic Timer
  - [ ] System timer (BCM2835)
  - [ ] High-resolution timer
  - [ ] Tick scheduling

#### 12.0.3 Device Tree Integration
- [ ] Device tree compiler integration
  - [ ] Parse DTB (Device Tree Blob) from bootloader
  - [ ] Device tree overlay support
  - [ ] Runtime device tree modification
- [ ] Board-specific device trees
  - [ ] bcm2711-rpi-4-b.dts (Pi 4)
  - [ ] bcm2712-rpi-5-b.dts (Pi 5)
  - [ ] bcm2837-rpi-3-b-plus.dts (Pi 3)
  - [ ] Custom overlays for HATs
- [ ] Driver probing from device tree
  - [ ] Match compatible strings
  - [ ] Parse properties (reg, interrupts, clocks)
  - [ ] Resource allocation

#### 12.0.4 Raspberry Pi-Specific Optimizations
- [ ] Memory optimization for low-RAM models
  - [ ] Kernel memory footprint <50MB
  - [ ] Aggressive page reclamation
  - [ ] No swap (use ZRAM instead)
  - [ ] Compressed kernel modules
- [ ] Boot time optimization
  - [ ] Target: <3 seconds to shell (Pi 4/5)
  - [ ] Parallel device initialization
  - [ ] Lazy module loading
  - [ ] Skip unnecessary hardware probes
- [ ] Thermal management
  - [ ] CPU temperature monitoring
  - [ ] Passive cooling (throttling at 80°C)
  - [ ] Fan control (GPIO-based, if present)
  - [ ] Thermal zones for Pi 5
- [ ] Power efficiency
  - [ ] CPU idle states
  - [ ] Dynamic voltage and frequency scaling (DVFS)
  - [ ] Peripheral power gating
  - [ ] Display blanking

#### 12.0.5 HAT (Hardware Attached on Top) Support
- [ ] HAT detection via I2C EEPROM
  - [ ] Read HAT ID EEPROM
  - [ ] Parse HAT metadata
  - [ ] Load appropriate device tree overlay
- [ ] Common HAT support
  - [ ] Sense HAT (sensors, LED matrix)
  - [ ] Camera modules (v1, v2, v3)
  - [ ] Official touchscreen display
  - [ ] PoE HAT (Power over Ethernet)
  - [ ] Coral AI accelerator
  - [ ] M.2 HAT+ (NVMe, Wi-Fi cards)

#### 12.0.6 Cross-Platform Build System
- [ ] ARM64 cross-compilation toolchain
  - [ ] Home language ARM64 backend (via LLVM)
  - [ ] Cross-compile from x86-64 → ARM64
  - [ ] Build kernel and userspace for ARM64
- [ ] SD card image creation
  - [ ] Partition layout (FAT32 boot + ext4 root)
  - [ ] Bootloader installation (config.txt, start4.elf, kernel8.img)
  - [ ] Rootfs population
  - [ ] Image compression (xz or gzip)
- [ ] QEMU testing
  - [ ] QEMU ARM64 raspi3b machine
  - [ ] QEMU ARM64 raspi4b machine
  - [ ] Automated testing in QEMU
  - [ ] GDB remote debugging

#### 12.0.7 Raspberry Pi-Specific Applications
- [ ] GPIO control utility
  - [ ] Command-line GPIO manipulation
  - [ ] libgpiod-compatible API
  - [ ] PWM control
  - [ ] Hardware PWM vs software PWM
- [ ] Configuration tool (raspi-config equivalent)
  - [ ] System configuration TUI
  - [ ] Display settings
  - [ ] Overclock settings (with warnings)
  - [ ] Boot options
  - [ ] Locale and keyboard
- [ ] Hardware monitoring dashboard
  - [ ] CPU temperature
  - [ ] CPU frequency (current/min/max)
  - [ ] Throttling status
  - [ ] Voltage (under-voltage detection)
  - [ ] Memory usage

#### 12.0.8 Performance Targets (Raspberry Pi)
- **Raspberry Pi 4 (4GB model)**:
  - Boot time: <3 seconds to shell, <8 seconds to GUI
  - RAM usage (idle): <256MB (GUI), <128MB (headless)
  - Graphics: 1080p@60fps UI, 30fps for 4K
  - Network: 940 Mbps Ethernet, 150+ Mbps WiFi
  - Storage: >40 MB/s sequential read (SD card)

- **Raspberry Pi 5 (8GB model)**:
  - Boot time: <2 seconds to shell, <6 seconds to GUI
  - RAM usage (idle): <384MB (GUI), <192MB (headless)
  - Graphics: 4K@60fps UI with smooth animations
  - Network: 940 Mbps Ethernet, 300+ Mbps WiFi
  - Storage: >400 MB/s sequential read (NVMe via PCIe)

- **Raspberry Pi 3 B+ (1GB model)**:
  - Boot time: <5 seconds to shell, <15 seconds to minimal GUI
  - RAM usage (idle): <192MB (minimal GUI), <96MB (headless)
  - Graphics: 720p@30fps UI (acceptable)
  - Network: 300 Mbps Ethernet, 50+ Mbps WiFi

---

## Phase 13: Hardware Support & Compatibility (Weeks 49-52)

### 13.1 Architecture Support (Continued)

### 12.1 Architecture Support
- [ ] x86-64 (primary target, already in progress)
- [ ] ARM64 (AArch64) - **Raspberry Pi 3/4/5**
  - [ ] Boot process (U-Boot or UEFI)
  - [ ] Device tree support
  - [ ] MMU setup
  - [ ] GIC (Generic Interrupt Controller)
- [ ] RISC-V (future consideration)

### 13.2 Additional Hardware Support
- [ ] More storage controllers
  - [ ] RAID controllers
  - [ ] SAS controllers
  - [ ] SD/MMC card readers
- [ ] More network adapters
  - [ ] 10GbE and faster
  - [ ] Wireless chipsets (more variants)
- [ ] Bluetooth support
  - [ ] HCI (Host Controller Interface)
  - [ ] L2CAP, RFCOMM protocols
  - [ ] Audio profiles (A2DP)
  - [ ] Input devices
- [ ] Printer support
  - [ ] USB printers
  - [ ] Network printers (IPP)
  - [ ] CUPS-compatible API

### 13.3 Power Management
- [ ] ACPI (Advanced Configuration and Power Interface)
  - [ ] System sleep states (S3, S4)
  - [ ] CPU power states (P-states, C-states)
  - [ ] Thermal management
  - [ ] Battery monitoring
- [ ] CPU frequency scaling
  - [ ] Governor policies (performance, powersave, ondemand)
  - [ ] Per-core frequency control
- [ ] Device runtime power management
  - [ ] Suspend/resume devices
  - [ ] Wake-on-LAN
  - [ ] USB selective suspend

### 13.4 Laptop-Specific Features
- [ ] Lid switch handling
- [ ] Brightness control (keyboard and screen)
- [ ] Volume control
- [ ] Special function keys
- [ ] Battery status indicators
- [ ] Touchpad gestures

### 13.5 Virtualization Support
- [ ] Virtio drivers (as guest)
  - [ ] virtio-net
  - [ ] virtio-blk
  - [ ] virtio-scsi
  - [ ] virtio-gpu
  - [ ] virtio-balloon
- [ ] Paravirtualization optimizations
- [ ] KVM support (as host, future)
  - [ ] Virtual machine creation
  - [ ] CPU virtualization (Intel VT-x/AMD-V)
  - [ ] Memory virtualization (EPT/NPT)
  - [ ] Device emulation

---

## Phase 14: Developer Tools & Ecosystem (Weeks 53-56)

### 14.1 Build System
- [ ] Integrate with Home's build system
- [ ] Kernel build configuration
  - [ ] menuconfig-like interface
  - [ ] .config file generation
  - [ ] Dependency tracking
- [ ] Cross-compilation support
- [ ] Incremental builds
- [ ] Distributed builds

### 14.2 Debugging Tools
- [ ] Kernel debugger (KDB/KGDB-like)
  - [ ] Breakpoints
  - [ ] Single-stepping
  - [ ] Memory inspection
  - [ ] Stack traces
- [ ] User-space debugger (GDB-like)
  - [ ] Ptrace interface
  - [ ] Breakpoint support
  - [ ] Watchpoints
  - [ ] Remote debugging
- [ ] Profiling tools
  - [ ] CPU profiling (perf-like)
  - [ ] Memory profiling
  - [ ] I/O profiling
  - [ ] Lock contention analysis
- [ ] Tracing tools
  - [ ] System call tracing (strace-like)
  - [ ] Function tracing
  - [ ] Event tracing
  - [ ] eBPF support (for advanced tracing)

### 14.3 Development Environment
- [ ] SDK for application development
  - [ ] Headers and libraries
  - [ ] Documentation
  - [ ] Example applications
- [ ] IDE support
  - [ ] VSCode extension (leverage Home's extension)
  - [ ] Language server protocol
  - [ ] Debugger integration
- [ ] Package creation tools
  - [ ] Package manifest templates
  - [ ] Build scripts
  - [ ] Package signing

### 14.4 Documentation
- [ ] Kernel API documentation
- [ ] System call reference
- [ ] Driver development guide
- [ ] Application development guide
- [ ] Architecture overview
- [ ] Security guidelines
- [ ] Performance tuning guide

### 14.5 Testing Infrastructure
- [ ] Unit tests (per-component)
- [ ] Integration tests
- [ ] Regression tests
- [ ] Performance tests
- [ ] Hardware compatibility tests
- [ ] Continuous integration setup
  - [ ] Automated builds
  - [ ] Automated testing
  - [ ] Code coverage tracking

---

## Phase 15: Containerization & Virtualization (Weeks 57-60)

### 15.1 Container Runtime
- [ ] Namespace implementation (enhance Phase 2)
  - [ ] PID namespace
  - [ ] Mount namespace
  - [ ] Network namespace
  - [ ] UTS namespace (hostname)
  - [ ] IPC namespace
  - [ ] User namespace
  - [ ] Cgroup namespace
- [ ] Cgroups (Control Groups)
  - [ ] Resource limits (CPU, memory, I/O)
  - [ ] Accounting
  - [ ] Prioritization
  - [ ] Cgroup v2 support
- [ ] Container image format
  - [ ] OCI (Open Container Initiative) compatibility
  - [ ] Image layering (unionfs/overlayfs)
  - [ ] Image registry integration
- [ ] Container management
  - [ ] Create, start, stop, delete
  - [ ] Container networking
  - [ ] Volume management
  - [ ] Container logs

### 15.2 Container Orchestration (Basic)
- [ ] Pod abstraction (Kubernetes-inspired)
- [ ] Service discovery
- [ ] Load balancing
- [ ] Health checks
- [ ] Auto-restart on failure

### 15.3 Virtual Machine Support
- [ ] KVM integration (as host)
- [ ] QEMU-like device emulation
- [ ] VM creation and management
- [ ] VM networking (bridge, NAT)
- [ ] Live migration support

---

## Phase 16: Advanced Features & Polish (Weeks 61-66)

### 16.1 Multimedia Support
- [ ] Video playback
  - [ ] H.264/H.265 decoding
  - [ ] VP8/VP9 support
  - [ ] Container formats (MP4, MKV, WebM)
- [ ] Audio playback enhancements
  - [ ] Multiple formats (MP3, AAC, FLAC, Opus)
  - [ ] Audio effects (equalizer, etc.)
- [ ] Webcam support
  - [ ] V4L2 (Video4Linux2) interface
  - [ ] Camera application

### 16.2 Accessibility
- [ ] Screen reader
- [ ] High contrast themes
- [ ] Magnifier
- [ ] Keyboard-only navigation
- [ ] Text-to-speech (TTS)
- [ ] Speech-to-text (STT)

### 16.3 Internationalization (i18n)
- [ ] Unicode support (UTF-8)
- [ ] Multiple language support
- [ ] Keyboard layouts (extend Phase 4)
- [ ] Input methods (for CJK languages)
- [ ] RTL (Right-to-Left) text support
- [ ] Time zones and locales

### 16.4 System Management
- [ ] System logs viewer
- [ ] Crash reporting
- [ ] System updates
  - [ ] Atomic updates
  - [ ] Rollback capability
  - [ ] Delta updates
- [ ] Backup and restore
  - [ ] Full system backup
  - [ ] Incremental backups
  - [ ] User data backup

### 16.5 Cloud Integration
- [ ] Cloud storage support (optional)
- [ ] Remote desktop protocol (RDP/VNC)
- [ ] SSH server and client
- [ ] Cloud sync for settings

### 16.6 Gaming Support (Optional)
- [ ] Game controller input (enhance Phase 4)
- [ ] Vulkan API support (already in Craft)
- [ ] Steam compatibility layer (Proton-like)
- [ ] DirectX translation (DXVK-like)

### 16.7 Advanced Networking
- [ ] VPN client (OpenVPN, WireGuard)
- [ ] Advanced WiFi features
  - [ ] WiFi hotspot mode
  - [ ] WiFi Direct
- [ ] Bluetooth networking (PAN)
- [ ] IPv6 enhancements
- [ ] QoS (Quality of Service)

### 16.8 System Aesthetics
- [ ] Boot splash screen (enhance from Phase 1)
- [ ] Smooth animations throughout UI
- [ ] Multiple themes and icon packs
- [ ] Wallpaper management
- [ ] Font management and rendering
  - [ ] FreeType integration
  - [ ] Font hinting
  - [ ] Subpixel rendering

---

## Phase 17: Testing, Refinement & Release (Weeks 67-78)

### 17.1 Comprehensive Testing
- [ ] Alpha testing on virtual machines
- [ ] Beta testing on real hardware
  - [ ] Raspberry Pi 4 Model B (all RAM variants)
  - [ ] Raspberry Pi 5 (4GB and 8GB)
  - [ ] Raspberry Pi 3 B+ (legacy support)
  - [ ] x86-64 laptops and desktops
- [ ] User acceptance testing
- [ ] Security audit
- [ ] Performance benchmarking (final)
- [ ] Stability testing (stress tests, long runs)
- [ ] Compatibility testing (hardware matrix)

### 17.2 Bug Fixing & Refinement
- [ ] Address all critical bugs
- [ ] Fix high-priority bugs
- [ ] Performance tuning based on profiling
- [ ] Memory leak detection and fixing
- [ ] Race condition fixes
- [ ] Edge case handling

### 17.3 Documentation Polish
- [ ] User manual
- [ ] Installation guide
- [ ] Troubleshooting guide
- [ ] FAQ
- [ ] Video tutorials
- [ ] API documentation finalization

### 17.4 Installation System
- [ ] Live USB/CD creation (x86-64)
- [ ] SD card images for Raspberry Pi
  - [ ] Raspberry Pi Imager integration
  - [ ] Pre-configured images (desktop, server, minimal)
  - [ ] First-boot setup wizard
- [ ] Graphical installer
  - [ ] Disk partitioning
  - [ ] Timezone/locale selection
  - [ ] User creation
  - [ ] Network configuration
  - [ ] Bootloader installation
- [ ] Automated installation (preseed/kickstart-like)
- [ ] Upgrade path from previous versions

### 17.5 Release Preparation
- [ ] Version numbering scheme
- [ ] Release notes
- [ ] Change log
- [ ] Download mirrors
- [ ] Torrent distribution
- [ ] ISO checksums and signatures (x86-64)
- [ ] SD card image checksums and signatures (ARM64/Raspberry Pi)
- [ ] Marketing materials
  - [ ] Website
  - [ ] Screenshots
  - [ ] Feature highlights
  - [ ] Comparison with other OSes

### 17.6 Community Building
- [ ] Open source repository setup (GitHub/GitLab)
- [ ] Contribution guidelines
- [ ] Code of conduct
- [ ] Mailing lists/forums
- [ ] Issue tracker
- [ ] Wiki for community docs
- [ ] Social media presence

### 17.7 Post-Release Support
- [ ] Patch release cycle planning
- [ ] Security update process
- [ ] Bug bounty program (optional)
- [ ] User support channels
- [ ] Roadmap for future versions

---

## Phase 18: Edge Computing & IoT Features (Optional - Weeks 79-82)

### 18.1 IoT Device Support
- [ ] GPIO-based sensors (temperature, humidity, motion)
- [ ] I2C/SPI device drivers for common sensors
- [ ] Low-power modes for battery operation
- [ ] Wake-on-interrupt support
- [ ] Real-time kernel patches (PREEMPT_RT-like)

### 18.2 Edge Computing Features
- [ ] Container runtime optimized for ARM
- [ ] Kubernetes (k3s-like) lightweight orchestration
- [ ] MQTT broker for IoT messaging
- [ ] Time-series database (lightweight)
- [ ] Edge ML inference (TensorFlow Lite, ONNX)

### 18.3 Home Automation Integration
- [ ] Zigbee/Z-Wave USB dongle support
- [ ] Home Assistant compatibility layer
- [ ] Smart home dashboard (Craft-based)
- [ ] Automation rules engine
- [ ] Voice assistant integration (local, privacy-focused)

### 18.4 Industrial Applications
- [ ] CAN bus support (automotive, industrial)
- [ ] Modbus protocol (RTU and TCP)
- [ ] OPC UA client/server
- [ ] Deterministic scheduling (real-time tasks)
- [ ] Watchdog timer support

---

## Continuous Tasks (Throughout Development)

### Code Quality
- [ ] Code reviews for all major changes (PR template with checklist)
- [ ] Static analysis (linting, type checking via Home compiler)
- [ ] Memory leak detection (valgrind-like tools, Home's ownership analysis)
- [ ] Security scanning (automated vulnerability checks)
- [ ] Coding standards document (Home style guide)
- [ ] Pre-commit hooks (formatting, basic checks)

### Performance Monitoring
- [ ] Regular benchmarking (weekly automated runs)
- [ ] Profile-guided optimization (PGO builds)
- [ ] Resource usage tracking (memory, CPU, disk, I/O)
- [ ] Performance regression detection
- [ ] Flamegraph generation for hotspots
- [ ] Boot time tracking (per-phase breakdown)

### Documentation
- [ ] Keep docs updated with code (enforce via CI)
- [ ] Document design decisions (why, not just what)
- [ ] Architecture decision records (ADRs in docs/adr/)
- [ ] API documentation (auto-generated from code)
- [ ] Tutorial series (blog posts)
- [ ] Video walkthroughs (YouTube channel)

### Testing
- [ ] Write tests for new features (TDD where practical)
- [ ] Maintain test coverage >80% (kernel: >70%, userspace: >85%)
- [ ] Run regression tests regularly (on every PR)
- [ ] Fuzzing for security-critical components
- [ ] Hardware-in-the-loop testing (real Pi boards)
- [ ] Chaos engineering (random fault injection)

---

## Project Structure

```
home-os/
├── kernel/                 # Kernel source (Home)
│   ├── arch/              # Architecture-specific code
│   │   ├── x86_64/        # x86-64 support
│   │   └── aarch64/       # ARM64/Raspberry Pi
│   ├── drivers/           # Device drivers
│   ├── fs/                # File systems
│   ├── mm/                # Memory management
│   ├── net/               # Network stack
│   └── proc/              # Process management
├── userspace/             # User-space programs
│   ├── init/              # Init system
│   ├── shell/             # home-sh shell
│   ├── coreutils/         # Core utilities
│   └── apps/              # Applications (file manager, etc.)
├── libc/                  # home-libc implementation
├── ui/                    # Craft UI integration
│   ├── compositor/        # Wayland compositor
│   ├── desktop/           # Desktop environment
│   └── apps/              # GUI applications
├── pkgmgr/                # Pantry package manager port
├── bootloader/            # UEFI bootloader
│   ├── x86_64/           # x86-64 bootloader
│   └── aarch64/          # Raspberry Pi bootloader
├── toolchain/             # Build tools and cross-compilers
├── tests/                 # Test suites
│   ├── unit/             # Unit tests
│   ├── integration/      # Integration tests
│   └── hardware/         # Hardware tests
├── docs/                  # Documentation
│   ├── architecture/     # Architecture docs
│   ├── api/              # API reference
│   ├── tutorials/        # Tutorials
│   └── adr/              # Architecture Decision Records
├── scripts/              # Build and utility scripts
│   ├── build.home        # Build system
│   ├── qemu-test.sh      # QEMU testing
│   └── flash-pi.sh       # Flash to Raspberry Pi SD card
├── images/               # Disk images and installers
└── third-party/          # External dependencies
```

---

## Development Environment Setup

### Prerequisites
- Home compiler (from `~/Code/home`)
- Craft UI engine (from `~/Code/craft`)
- Pantry package manager (from `~/Code/pantry`)
- QEMU (for x86-64 and ARM64 testing)
- Cross-compilation toolchain (ARM64-linux-gnu)
- GNU Make or Ninja build system
- Git for version control

### Quick Start
```bash
# Clone and setup
git clone <home-os-repo>
cd home-os

# Install dependencies via Pantry
pantry install qemu gcc-aarch64-linux-gnu make

# Build for x86-64
./scripts/build.home --arch x86_64 --config debug

# Test in QEMU
./scripts/qemu-test.sh x86_64

# Build for Raspberry Pi 4
./scripts/build.home --arch aarch64 --board rpi4 --config release

# Flash to SD card
./scripts/flash-pi.sh /dev/sdX  # Replace X with your SD card
```

---

## Success Metrics

### Performance Targets
- **Boot Time**:
  - x86-64 (SSD): <5 seconds
  - Raspberry Pi 4: <8 seconds (GUI)
  - Raspberry Pi 5: <6 seconds (GUI)
- **RAM Usage (Idle)**:
  - x86-64: <512MB (full GUI environment)
  - Raspberry Pi 4: <256MB (full GUI)
  - Raspberry Pi 5: <384MB (full GUI)
  - Raspberry Pi 3: <192MB (minimal GUI)
- **Binary Size (Kernel)**: <10MB (x86-64), <8MB (ARM64)
- **Context Switch Time**: <2μs
- **System Call Latency**: <500ns
- **Network Throughput**: Near line rate (depends on hardware)
- **File System Performance**: Within 10% of ext4
- **GUI Responsiveness**: 60 FPS minimum, <100ms input latency

### Stability Targets
- **Uptime**: Support months of continuous operation
- **Crash Rate**: <1 kernel panic per 1000 hours
- **Memory Leaks**: None detected in 72-hour stress test

### Compatibility Targets
- **Hardware Support**:
  - Boot on 80% of consumer x86-64 laptops/desktops from last 5 years
  - Full support for Raspberry Pi 3 B+, 4, and 5
  - Support for common Raspberry Pi HATs
- **Application Compatibility**: Run top 50 open-source applications (via porting or compatibility layer)
- **POSIX Compliance**: 95% of POSIX.1-2017 interfaces
- **Cross-Platform**: Identical user experience on x86-64 and ARM64

### Security Targets
- **Memory Safety**: 100% (enforced by Home language)
- **Privilege Escalation**: No known vulnerabilities at release
- **Security Audit**: Pass independent security review

---

## Risk Mitigation

### Technical Risks
| Risk | Impact | Likelihood | Mitigation Strategy | Contingency Plan |
|------|--------|------------|---------------------|------------------|
| Home language not mature enough | High | Medium | Contribute to Home development, extensive testing | Hybrid approach (Home + Zig), or rewrite critical paths in Zig |
| WebKit porting too complex | Medium | High | Use lightweight alternatives (WebKitGTK subset) | Framebuffer-based rendering, or embed Servo |
| Hardware compatibility issues | Medium | Medium | Extensive testing, prioritize common hardware | Focus on well-supported hardware initially |
| Raspberry Pi firmware changes | Low | Low | Track official firmware updates | Maintain compatibility with multiple firmware versions |
| Performance targets not met | High | Medium | Profile-guided optimization, assembly hotspots | Adjust targets based on realistic measurements |
| Security vulnerabilities | High | Medium | Security audits, fuzzing, bounty program | Rapid patch releases, security-focused sprints |

### Resource Risks
| Risk | Impact | Likelihood | Mitigation Strategy | Contingency Plan |
|------|--------|------------|---------------------|------------------|
| Development takes longer than 78 weeks | Medium | High | Prioritize MVP features, defer nice-to-haves | Extend timeline, phase releases (alpha, beta, stable) |
| Insufficient developer resources | High | Medium | Open source early, build community | Focus on core features, recruit contributors |
| Budget constraints (hardware testing) | Medium | Low | Use QEMU extensively, community hardware testing | Partner with Raspberry Pi Foundation for hardware |
| Key developer leaves | Medium | Low | Documentation, knowledge sharing | Pair programming, cross-training |

### Adoption Risks
| Risk | Impact | Likelihood | Mitigation Strategy | Contingency Plan |
|------|--------|------------|---------------------|------------------|
| Lack of application ecosystem | High | High | Port key apps, compatibility layers | Focus on web apps via browser, terminal apps |
| User resistance to new OS | Medium | Medium | Excellent UX, clear migration path | Target early adopters, education sector |
| Competition from established OSes | Medium | High | Differentiate on performance, security, simplicity | Niche positioning (education, embedded, development) |
| Raspberry Pi community adoption | Medium | Medium | Engage Pi community early, showcase benefits | Highlight Pi-specific features, performance gains |

---

## Notes

- This is an ambitious 78-week (19.5 month) plan for building a full operating system from scratch
- **Raspberry Pi is a first-class target**, not an afterthought
- Phases can overlap where dependencies allow
- Some phases may take longer or shorter depending on complexity and team size
- Regular checkpoints and adjustments are expected
- Focus on MVP (Minimum Viable Product) first, then iterate
- Performance and security are first-class concerns throughout
- Leverage existing open-source components where possible (but ensure licensing compatibility)
- The OS should feel familiar to users of modern OSes while offering unique advantages (speed, security, developer experience)

### Key Principles
1. **Memory Safety First**: Home's ownership system prevents entire classes of bugs
2. **Performance by Design**: Every feature should be benchmarked and optimized
3. **Minimal Dependencies**: Keep the system small and auditable
4. **Documentation as Code**: Docs are as important as the code itself
5. **Test Everything**: If it's not tested, it's broken
6. **Community Driven**: Open source from day one, welcome contributions
7. **Educational Value**: Should be easy to understand and learn from
8. **Portability**: Write once, run on x86-64 and ARM64

### Decision Making Framework
When faced with a design choice, ask:
1. Does it improve security?
2. Does it improve performance?
3. Does it reduce complexity?
4. Is it testable?
5. Is it maintainable?
6. Does it align with the vision?

Choose the option that scores highest across these dimensions.

### Communication Channels (Post-Open Source)
- **GitHub Issues**: Bug reports, feature requests
- **GitHub Discussions**: Q&A, design discussions
- **Discord Server**: Real-time chat, community support
- **Mailing List**: Development updates, announcements
- **Blog**: Progress reports, technical deep-dives
- **Twitter/Mastodon**: Release announcements, highlights

### Funding Strategy
- **Open Source Foundation**: Apply for grants (Linux Foundation, etc.)
- **Sponsorships**: GitHub Sponsors, Open Collective
- **Corporate Partnerships**: Raspberry Pi Foundation, cloud providers
- **Hardware Vendors**: Collaborate with ARM, AMD, Intel
- **Educational Institutions**: Partner with universities
- **Consulting**: Offer paid support and custom development

---

## Quick Reference: Dependency Integration

### Home (Language)
- **Used For**: Kernel, drivers, system utilities, applications
- **Key Features**: Memory safety, zero-cost abstractions, fast compilation
- **Integration Points**: Everywhere - this is the primary language

### Craft (UI)
- **Used For**: Display server, window manager, desktop environment, applications
- **Key Features**: Lightweight (1.4MB), fast startup (<100ms), GPU-accelerated
- **Integration Points**: Phase 8 onwards, all graphical components

### Pantry (Package Manager)
- **Used For**: Package installation, environment management, system services
- **Key Features**:
  - Fast (sub-5ms environment switching)
  - Multi-source support: pkgx.sh (10,000+), npm, GitHub releases, custom HTTP endpoints
  - Project-aware with automatic environment activation
  - Service management (30+ pre-configured services)
- **Integration Points**: Phase 7 for system integration, used throughout for software distribution

---

## Changelog

### 2025-10-28
- Initial TODO.md created with 17 phases
- Added comprehensive Raspberry Pi support (Phase 12)
- Added development milestones for tracking progress
- Added project structure and setup instructions
- Enhanced risk mitigation with detailed tables
- Added Phase 18: Edge Computing & IoT Features (optional)
- Added key principles and decision-making framework
- Expanded continuous tasks with specific actions

### Future Updates
- [ ] After Phase 1: Review and adjust timeline based on actual progress
- [ ] After Phase 6: Assess if user-space is on track for milestone goals
- [ ] After Phase 12: Validate Raspberry Pi support on real hardware
- [ ] Weekly: Update task completion status
- [ ] Monthly: Review and update risk assessments

---

**Last Updated**: 2025-10-28
**Status**: Initial Comprehensive Draft
**Next Review**: After Phase 1 completion (Week 4)
**Version**: 1.0.0
**Total Tasks**: ~800+ across 18 phases
**Estimated Duration**: 78-82 weeks (19.5-20.5 months)
