# home-os

> A modern, performant, minimal operating system built from scratch using Home, Craft, and Pantry

## Status

🚧 **Active Development** - Phase 1: Foundation & Bootloader

### Current Milestone

**Milestone 1: "Hello World" (Week 4)**
- [ ] Bootable kernel that prints "home-os" to serial console
- [ ] Runs on QEMU x86-64

## Technology Stack

- **Language**: Home (memory-safe systems language)
  - Source: `~/Code/home`
  - Features: Multiboot2, FFI, Threading, Variadic functions
- **UI Engine**: Craft (GPU-accelerated, 1.4MB binary)
  - Source: `~/Code/craft`
- **Package Manager**: Pantry (multi-source, sub-5ms switching)
  - Source: `~/Code/pantry`

## Quick Start

```bash
# Build kernel
cd kernel
home build

# Run in QEMU
home build qemu

# Run tests
home test
```

## Project Structure

```
home-os/
├── kernel/           # Kernel source (Home)
├── boot/             # Bootloader
├── userspace/        # User-space programs
├── libc/             # home-libc implementation
├── ui/               # Craft UI integration
├── pkgmgr/           # Pantry package manager port
├── toolchain/        # Build tools
├── tests/            # Test suites
├── docs/             # Documentation
├── scripts/          # Build scripts
└── images/           # ISO images
```

## Building from Source

Prerequisites:
- Home compiler (from `~/Code/home`)
- QEMU (for testing)
- GRUB tools (for bootable images)

```bash
# Install dependencies via Pantry
pantry install qemu grub-pc-bin xorriso

# Build
./scripts/build.sh

# Test
./scripts/test.sh
```

## Architecture Support

- ✅ x86-64 (primary)
- 🚧 ARM64 (Raspberry Pi 3/4/5)

## License

MIT

## Contributing

See [CONTRIBUTING.md](docs/CONTRIBUTING.md)

---

Built with ❤️ using Home, Craft, and Pantry
