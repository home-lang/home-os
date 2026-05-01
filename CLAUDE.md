# CLAUDE - Critical Development Guidelines for home-os

## 🚨 MOST IMPORTANT RULE 🚨

**ALWAYS USE THE HOME PROGRAMMING LANGUAGE FOR home-os DEVELOPMENT**

This is **HomeOS** - an operating system built with the Home programming language. We are NOT using Zig, Rust, C, or any other language except where absolutely unavoidable (like bootloader assembly).

### Language Policy

1. **Default to Home**: All new code MUST be written in Home (`.home` files)
2. **Home Compiler Location**: `~/Code/home/`
3. **Import Statement**: Use `const basics = @import("basics")` NOT `const std = @import("std")`
4. **File Extensions**: `.home` for Home language files

### When to Use Other Languages

Only use non-Home languages in these specific cases:
- **Assembly (`.s` files)**: ONLY for bootloader and low-level CPU initialization that absolutely cannot be done in Home
- **Zig/C/Other**: NEVER - if Home is missing a feature, extend Home first

### If Home is Missing Features

When Home doesn't have a feature we need:

1. **STOP** - Don't write Zig code as a workaround
2. **EXTEND HOME** - Add the feature to the Home compiler first
3. **DOCUMENT** - Update this file with what was added
4. **CONTINUE** - Then use the new Home feature in home-os

### Home Compiler Features (Current)

#### ✅ Implemented
- Basic types: `int`, `float`, `string`, `bool`
- Structs with named fields
- Enums
- Arrays and slices
- Functions with return types
- Control flow: `if`, `while`, `for`, `switch`
- Operators: arithmetic, logical, bitwise
- Type aliases
- String interpolation
- Tuples
- Ternary operator
- Null coalescing (`??`)
- Pipe operator (`|>`)
- Safe navigation (`?.`)
- Spread operator (`...`)
- Try-catch error handling
- Do-while loops
- Generics
- Async/await
- Compile-time evaluation (`comptime`)
- Macros
- Reflection
- Cross-platform support
- FFI (Foreign Function Interface)
- Threading support
- Variadic functions
- Custom linker support
- Driver support packages

#### ✅ Kernel Features (ALL IMPLEMENTED!)

**GREAT NEWS:** All kernel development features are already implemented in Home!

📦 **Location:** `~/Code/home/packages/kernel/`

**All Features Available:**

1. ✅ **Inline Assembly** - `packages/kernel/src/asm.zig`
   - I/O ports (outb, inb, outw, inw, outl, inl)
   - CPU control registers (cr0, cr2, cr3, cr4)
   - MSR access, CPUID, interrupts (cli, sti, hlt)
   - TLB management, atomic operations, memory barriers

2. ✅ **Packed Structs** - Built into Home
   - Syntax: `packed struct(u128) { ... }`
   - No padding, exact bit layout
   - Compile-time size validation

3. ✅ **IDT/Interrupts** - `packages/kernel/src/interrupts.zig`
   - Complete IDT entry structures
   - Interrupt/trap gate creation
   - LIDT instruction wrapper
   - Exception and IRQ definitions

4. ✅ **GDT** - `packages/kernel/src/gdt.zig`
   - GDT entry structures
   - Segment descriptors
   - TSS support, LGDT wrapper

5. ✅ **Memory Management**
   - Page tables (`paging.zig`)
   - Virtual memory (`vmm.zig`)
   - Physical allocator (`pmm.zig`)
   - Heap allocator (`kheap.zig`)

6. ✅ **Volatile Pointers** - Built into Home
   - `*volatile T` type
   - MMIO support

7. ✅ **Alignment Control** - Built into Home
   - `align(N)` for variables/fields
   - Page-aligned structures

8. ✅ **Export/Extern** - Built into Home
   - `export fn` for linker visibility
   - `extern fn` for external functions
   - Calling conventions supported

9. ✅ **Raw Pointers** - Built into Home
   - Pointer arithmetic
   - `@intFromPtr(ptr)`, `@ptrFromInt(addr)`
   - Null pointers, pointer casting

10. ✅ **Bit Manipulation** - Built into Home
    - `@truncate(value)`, `@bitCast()`
    - Bit fields in packed structs
    - Shift/bitwise operators

**Plus 60+ additional kernel modules** including APIC, ACPI, KASAN, security features, networking, debugging, and multi-arch support (x86_64, ARM64, RISC-V)!

📖 **See:** `HOME_KERNEL_FEATURES.md` for complete feature audit

### Home Kernel Modules

Home provides these built-in kernel support modules:

- `kernel/multiboot2` - Multiboot2 bootloader support
- `ffi` - Foreign Function Interface
- `threading` - Threading primitives
- `driver` - Driver development support

### Project Structure

```
home-os/
├── kernel/
│   ├── src/
│   │   ├── *.home          # All kernel code in Home
│   │   └── *.s             # Assembly only for boot/low-level
│   ├── build.home          # Home build configuration
│   └── linker.ld           # Linker script
├── CLAUDE.md               # This file - READ THIS FIRST!
└── TODO.md                 # 78-week development roadmap
```

### Development Workflow

1. Check if feature exists in Home compiler (`~/Code/home/`)
2. If missing, add it to Home first
3. Write home-os code using Home language
4. Build with Home compiler
5. Test in QEMU
6. Iterate

### Build System

- **Build Tool**: Home's native build system
- **Build File**: `kernel/build.home`
- **Build Command**: `home build` (once Home compiler supports it)
- **Temporary**: Using `zig` to compile until Home self-hosts

### Examples of Home Syntax

Based on the actual Home compiler source at `~/Code/home/`:

```home
// Hello World
fn main() {
  print("Hello, Home!")
}

// Functions with parameters and return types
fn add(a: int, b: int): int {
  return a + b
}

fn greet(name: string) {
  print("Hello")
  print(name)
}

// Variables
let result = add(10, 32)
let msg = "hello"

// Loops
loop {
  // infinite loop
}

// Conditionals
if condition {
  // do something
}

// Import statements (Zig-style for now since Home is Zig-based)
import basics/os/serial  // Home-style path
const serial = @import("os/serial.zig")  // Current Zig implementation

// Export functions (for kernel entry points)
export fn kernel_main(magic: u32, info: u32): never {
  // never return type for functions that don't return
  loop {
    cpu.hlt()
  }
}
```

**Key Differences from Zig:**
- `let` for variable declarations (not `const` or `var`)
- `loop` for infinite loops (not `while (true)`)
- `:` for return types with space before colon (TypeScript-style, not `->`)
- No semicolons needed in many cases
- `import` statements use `/` path separators
- `never` type for non-returning functions

### Current Development Status

As of October 28, 2025:

- **Phase**: Building kernel in Home, extending Home compiler as needed
- **Approach**: Write `.home` code for OS, add missing features to Home compiler itself
- **Current Architecture**:
  - `kernel/src/*.home` - All kernel code written in Home
  - `kernel/src/*.s` - Assembly only for boot/initialization
  - `~/Code/home/` - Home compiler (extend this when features are needed)
  - `~/Code/home/packages/basics/src/os/` - Home's OS basics modules
  - `~/Code/home/packages/kernel/src/` - Home's comprehensive kernel package

- **Current Task**: Write all OS code in `.home` files, extend Home compiler as needed
- **Philosophy**: If Home doesn't have it, add it to Home - never work around with other languages
- **Next Steps**:
  1. ✅ Understand Home's actual architecture (DONE)
  2. ✅ Remove unnecessary bridge files (DONE)
  3. ✅ Update documentation with correct syntax (DONE)
  4. 🔄 Write kernel code in `.home` files
  5. 🔄 Extend Home compiler when features are needed but missing
  6. 🔄 Leverage Home's kernel package modules as reference
  7. 🔄 Continue with TODO.md Phase 1 tasks (IDT, memory management) in Home

### Remember

**THIS IS HomeOS - BUILDING WITH HOME**

**Philosophy**: This OS is built with the Home programming language. When Home needs a feature, we extend Home itself:

1. **Current State (Phase 1 - Foundation)**:
   - ✅ Always write `.home` files for all OS code
   - ✅ Reference Home's kernel package (`~/Code/home/packages/kernel/`) for architecture
   - ✅ Use Home language features that exist today
   - ✅ Extend Home compiler when features are missing

2. **Development Strategy**:
   - Write all OS code in `.home` files
   - If a feature needs nicer API/syntax that doesn't exist yet → Add it to Home compiler first
   - If a feature cannot be implemented in current Home → Extend Home compiler, then implement
   - Keep OS code clean, well-documented, and idiomatic Home

3. **When to Use Each Language**:
   - **Home**: ALL kernel code, drivers, system utilities, everything
   - **Assembly**: ONLY for bootloader and CPU initialization that cannot be done in Home
   - **Other languages**: NEVER (extend Home instead)

4. **Decision Framework**:
   - Need a feature? → Check if Home has it
   - Home missing the feature? → Add it to Home compiler (`~/Code/home/`)
   - Need better API/syntax? → Design and implement in Home compiler first
   - Feature now exists? → Use it in home-os
   - Absolutely unavoidable low-level boot code? → Assembly only

**Bottom Line**: Write `.home` files for the OS. When Home lacks a feature, extend Home first, then use it. Never use other languages except Assembly for unavoidable boot code.

---

*Last Updated: October 29, 2025*
*This file is the source of truth for home-os development practices.*

---

## Linting

- Use **pickier** for linting — never use eslint directly
- Run `bunx --bun pickier .` to lint, `bunx --bun pickier . --fix` to auto-fix
- When fixing unused variable warnings, prefer `// eslint-disable-next-line` comments over prefixing with `_`

## Frontend

- Use **stx** for templating — never write vanilla JS (`var`, `document.*`, `window.*`) in stx templates
- Use **crosswind** as the default CSS framework which enables standard Tailwind-like utility classes
- stx `<script>` tags should only contain stx-compatible code (signals, composables, directives)

## Dependencies

- **buddy-bot** handles dependency updates — not renovatebot
- **better-dx** provides shared dev tooling as peer dependencies — do not install its peers (e.g., `typescript`, `pickier`, `bun-plugin-dtsx`) separately if `better-dx` is already in `package.json`
- If `better-dx` is in `package.json`, ensure `bunfig.toml` includes `linker = "hoisted"`

## Build Scripts & Environment

There is **one canonical build entry**: `scripts/build.sh`. It is a dispatcher
that exposes every legacy build path as a subcommand. Run
`./scripts/build.sh --help` to see the full list.

Common invocations:

```bash
./scripts/build.sh                       # generic x86-64 kernel + ISO
./scripts/build.sh rpi5                  # Raspberry Pi 5 build
./scripts/build.sh home                  # build via the Home compiler
./scripts/build.sh --target=rpi5 --release   # multi-target unified build
./scripts/build.sh unified all --iso     # build every target + ISO
./scripts/build.sh --help                # full subcommand reference
```

Subcommands map 1:1 to the old build-*.sh scripts: `kernel`, `home`,
`home-zig`, `home-simple`, `standalone`, `rpi5`, `pi-image`, `pi3-minimal`,
`legacy-boot`, `initramfs`, `all`, `unified`.

Paths are derived from the script's own location, so the build works
regardless of where the repo is checked out. Override these env vars if
your layout differs from the defaults:

- `KERNEL_DIR` — kernel directory (default: `<repo-root>/kernel`)
- `ISO_DIR` — ISO staging directory (default: `$KERNEL_DIR/iso`)
- `BUILD_DIR` — kernel build artifacts (default: `$KERNEL_DIR/build`)
- `PROJECT_BUILD_DIR` — multi-target build root (default: `<repo-root>/build`)
- `HOME_REPO` — Home compiler repo (default: `<repo-root>/../home`)
- `HOME_COMPILER` — `home` binary (default: `$HOME_REPO/zig-out/bin/home`)
- `RPI5_DIR` — Pi 5 firmware staging directory (default: `<repo-root>/rpi5`)

Expected sibling layout:

```
parent/
├── home-os/   # this repo
└── home/      # Home compiler repo (HOME_REPO)
```

If your Home compiler lives elsewhere, export `HOME_REPO` (or `HOME_COMPILER`)
before invoking the build script.
