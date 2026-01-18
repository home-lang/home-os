# Contributing to HomeOS

This guide covers the development philosophy, building kernel modules, and testing procedures for HomeOS.

## Development Philosophy

### Home Language Only

HomeOS is built exclusively with the **Home programming language**. This is a fundamental principle of the project.

**Language Policy:**

| Language | Usage |
|----------|-------|
| Home | ALL kernel code, drivers, applications, utilities |
| Assembly | ONLY for bootloader and CPU initialization that cannot be done in Home |
| Other languages | NEVER - extend Home instead |

### Decision Framework

When you need a feature:

1. **Check if Home has it** - Review the Home compiler (`~/Code/home/`)
2. **If missing, extend Home** - Add the feature to the Home compiler first
3. **Document the addition** - Update CLAUDE.md with what was added
4. **Use the new feature** - Then implement in HomeOS

**Never work around limitations with other languages.**

### Project Structure

```
home-os/
├── kernel/
│   ├── src/
│   │   ├── *.home          # All kernel code in Home
│   │   ├── core/           # Core kernel (scheduler, memory, VFS)
│   │   ├── drivers/        # Device drivers
│   │   ├── fs/             # File systems
│   │   ├── net/            # Networking stack
│   │   └── *.s             # Assembly only for boot/low-level
│   ├── build.home          # Home build configuration
│   └── linker.ld           # Linker script
├── apps/                   # User applications
├── docs/                   # Documentation
├── scripts/                # Build scripts
├── CLAUDE.md               # Development guidelines
└── TODO.md                 # Development roadmap
```

## Home Language Features

### Currently Implemented

The Home compiler supports all features needed for kernel development:

**Core Language:**
- Basic types: `int`, `float`, `string`, `bool`
- Structs with named fields
- Enums
- Arrays and slices
- Functions with return types
- Control flow: `if`, `while`, `for`, `switch`
- Operators: arithmetic, logical, bitwise
- Type aliases
- Generics
- Async/await
- Try-catch error handling
- Compile-time evaluation (`comptime`)

**Kernel-Specific Features:**
- Inline assembly
- Packed structs with exact bit layout
- Volatile pointers for MMIO
- Alignment control
- Export/extern functions
- Raw pointer arithmetic
- Bit manipulation builtins

### Home Syntax Examples

```home
// Hello World
fn main() {
  print("Hello, Home!")
}

// Functions with parameters and return types
fn add(a: int, b: int): int {
  return a + b
}

// Variables
let result = add(10, 32)
let msg = "hello"

// Infinite loop
loop {
  cpu.hlt()
}

// Conditionals
if condition {
  // do something
}

// Export for kernel entry points
export fn kernel_main(magic: u32, info: u32): never {
  loop {
    cpu.hlt()
  }
}
```

**Key Differences from Other Languages:**
- `let` for variable declarations
- `loop` for infinite loops
- `:` for return types (TypeScript-style)
- No semicolons in many cases
- `never` type for non-returning functions

## Building Kernel Modules

### Module Structure

Each kernel module follows a standard structure:

```home
// kernel/src/drivers/example.home

// Module-level constants
const EXAMPLE_BASE: u64 = 0x10000000
const EXAMPLE_STATUS: u32 = 0x00
const EXAMPLE_CONTROL: u32 = 0x04

// Module state
var initialized: bool = false

// Initialization function
pub fn init(): i32 {
  if initialized {
    return 0
  }

  // Initialize hardware
  let base = @ptrFromInt(*volatile u32, EXAMPLE_BASE)
  base[EXAMPLE_CONTROL] = 1

  initialized = true
  return 0
}

// Cleanup function
pub fn deinit(): i32 {
  if !initialized {
    return 0
  }

  // Cleanup
  initialized = false
  return 0
}

// Driver operations
pub fn read(buffer: *u8, size: u32): i32 {
  // Implementation
  return 0
}

pub fn write(buffer: *u8, size: u32): i32 {
  // Implementation
  return 0
}
```

### Driver Registration

Drivers register with the kernel's driver framework:

```home
struct DriverModule {
  name: [64]u8
  init_fn: fn(): u32
  exit_fn: fn(): u32
  dependencies: [8]u32
  priority: u32
  loaded: u32
}

pub fn register_driver(module: *DriverModule): i32 {
  // Register with driver manager
  return driver_manager.register(module)
}
```

### Using Kernel Packages

Home provides built-in kernel support:

```home
// Import kernel support modules
import kernel/asm          // Inline assembly
import kernel/interrupts   // IDT/interrupt handling
import kernel/gdt          // GDT management
import kernel/paging       // Page tables
import kernel/vmm          // Virtual memory
import kernel/pmm          // Physical memory
```

## Testing

### QEMU Testing

The primary testing environment is QEMU:

**x86-64:**
```bash
# Build and run in QEMU
./scripts/build.sh
./scripts/run-qemu.sh

# Or with GDB debugging
./scripts/run-qemu.sh --debug
```

**ARM64 (Raspberry Pi 5):**
```bash
# Build for Raspberry Pi 5
./scripts/build-rpi5.sh

# Run in QEMU (limited hardware support)
./scripts/run-qemu-arm64.sh
```

### Unit Testing

HomeOS includes a test framework:

```home
// kernel/tests/test_memory.home

import test

fn test_pmm_alloc() {
  let page = pmm_alloc_page()
  test.assert(page != null, "PMM allocation should succeed")

  pmm_free_page(page)
  test.pass("PMM alloc/free test passed")
}

fn test_vmm_map() {
  let virt = 0x1000000
  let phys = pmm_alloc_page()

  let result = vmm_map_page(virt, phys, PAGE_PRESENT | PAGE_RW)
  test.assert(result == 0, "VMM mapping should succeed")

  vmm_unmap_page(virt)
  pmm_free_page(phys)
  test.pass("VMM map/unmap test passed")
}

pub fn run_all_tests() {
  test_pmm_alloc()
  test_vmm_map()
}
```

### Integration Testing

For full system tests:

```bash
# Run integration tests
./scripts/run-tests.sh

# Run specific test suite
./scripts/run-tests.sh --suite=memory
./scripts/run-tests.sh --suite=network
./scripts/run-tests.sh --suite=fs
```

### Real Hardware Testing

For Raspberry Pi 5:

1. Build the kernel
2. Prepare SD card (see [Raspberry Pi Guide](/os/guide/raspberry-pi))
3. Connect serial console
4. Boot and observe output

## Code Style

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Functions | snake_case | `init_driver()` |
| Variables | snake_case | `page_count` |
| Constants | SCREAMING_SNAKE | `MAX_PAGES` |
| Types/Structs | PascalCase | `PageTable` |
| Modules | snake_case | `memory_manager` |

### Documentation

Document all public functions:

```home
/// Allocates a physical page from the free list.
///
/// Returns a pointer to the allocated page, or null if
/// no free pages are available.
///
/// Example:
///   let page = pmm_alloc_page()
///   if page != null {
///     // Use page
///   }
pub fn pmm_alloc_page(): *u8 {
  // Implementation
}
```

### Error Handling

Use return codes for kernel functions:

```home
const ERR_SUCCESS: i32 = 0
const ERR_NOMEM: i32 = -1
const ERR_INVALID: i32 = -2
const ERR_BUSY: i32 = -3
const ERR_IO: i32 = -4

pub fn some_operation(): i32 {
  if !valid_state {
    return ERR_INVALID
  }

  let result = perform_operation()
  if result < 0 {
    return ERR_IO
  }

  return ERR_SUCCESS
}
```

## Development Workflow

### 1. Setup

```bash
# Clone repositories
git clone https://github.com/home-lang/homeos ~/Code/home-os
git clone https://github.com/home-lang/home ~/Code/home

# Build Home compiler
cd ~/Code/home
zig build

# Build HomeOS
cd ~/Code/home-os
./scripts/build.sh
```

### 2. Make Changes

1. Create a feature branch
2. Write code in `.home` files
3. If Home needs a feature, add it to the compiler first
4. Build and test in QEMU

### 3. Test

```bash
# Quick build and test
./scripts/build.sh && ./scripts/run-qemu.sh

# Run unit tests
./scripts/run-tests.sh

# Check for issues
./scripts/lint.sh
```

### 4. Submit

1. Ensure all tests pass
2. Update documentation if needed
3. Create pull request
4. Address review feedback

## Debugging

### Serial Console

Debug output via serial:

```home
import serial

fn debug_log(msg: *u8) {
  serial.write_string(msg)
  serial.write_char('\n')
}
```

### GDB Debugging

```bash
# Terminal 1: Start QEMU with GDB stub
./scripts/run-qemu.sh --debug

# Terminal 2: Connect GDB
gdb build/kernel.elf
(gdb) target remote localhost:1234
(gdb) break kernel_main
(gdb) continue
```

### Common Debug Commands

```gdb
# Examine memory
x/10x 0x100000

# View registers
info registers

# Backtrace
bt

# Step instruction
si

# Continue
c
```

## Resources

### Documentation

- [Architecture Guide](/os/guide/architecture) - Kernel internals
- [Raspberry Pi Guide](/os/guide/raspberry-pi) - Hardware deployment
- [Driver Reference](/os/guide/drivers) - Driver development
- [Home Language](/home/) - Language documentation

### Code References

- `~/Code/home/packages/kernel/` - Home kernel package
- `kernel/src/core/` - Core kernel implementation
- `kernel/src/drivers/` - Driver examples
- `docs/api/` - API reference

### External Resources

- [OSDev Wiki](https://wiki.osdev.org/) - OS development reference
- [ARM Documentation](https://developer.arm.com/documentation/) - ARM architecture
- [Intel SDM](https://www.intel.com/sdm) - x86-64 reference
