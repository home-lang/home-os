# home-os Kernel Structure

## Clean, Modular Architecture

The kernel is now organized into logical, manageable modules instead of one massive file.

---

## Directory Structure

```
kernel/src/
├── main.home                      # Main entry point (50 lines)
├── kernel.home                    # Core kernel (850 lines)
├── integration.home               # Integration module (150 lines)
│
├── lib/                           # Integration libraries
│   ├── pantry_lib.home           # Pantry integration (400 lines)
│   ├── den_lib.home              # Den shell integration (500 lines)
│   └── craft_lib.home            # Craft UI integration (400 lines)
│
├── boot.s                         # Assembly bootloader
├── kernel_enhanced.s              # Assembly helpers
├── idt_stubs.s                    # IDT stubs
│
├── multiboot2.home                # Multiboot2 support
├── serial.home                    # Serial driver
├── vga.home                       # VGA driver
├── pmm.home                       # Physical memory manager
├── vmm.home                       # Virtual memory manager
├── heap.home                      # Heap allocator
└── idt.home                       # Interrupt descriptor table
```

---

## File Responsibilities

### **Core Kernel Files**

#### `main.home` (50 lines)
**Purpose:** Clean entry point that orchestrates initialization

**Responsibilities:**
- Import all modules
- Initialize kernel phases in order
- Initialize integrations
- Enter main loop

**Why separate:** Keeps entry point clean and readable

---

#### `kernel.home` (850 lines)
**Purpose:** Core kernel functionality (Phases 1-7)

**Contains:**
- Phase 1: Foundation (bootloader, GDT, IDT, memory, interrupts)
- Phase 2: Process Management (PCB, scheduler, threads, IPC)
- Phase 3: Advanced Features (SMP, advanced memory)
- Phase 4: File System (VFS, home-fs, multiple FS support)
- Phase 5: Device Management (drivers, devfs, USB, PCI)
- Phase 6: Networking (TCP/IP stack, sockets)
- Phase 7: User Space (syscalls, ELF loader, dynamic linker)

**Why separate:** Core OS functionality should be in one cohesive module

---

### **Integration Files**

#### `integration.home` (150 lines)
**Purpose:** Central integration point for external libraries

**Contains:**
- Unified initialization
- System call wrappers for all libraries
- Integrated workflows

**Why separate:** Clean interface between kernel and external libraries

---

#### `lib/pantry_lib.home` (400 lines)
**Purpose:** Pantry package manager integration

**Contains:**
- Package management functions
- Registry management
- Environment management
- Service management
- Complete data structures

**Why separate:** All Pantry integration logic in one place

---

#### `lib/den_lib.home` (500 lines)
**Purpose:** Den shell integration

**Contains:**
- Command execution
- Environment variables
- Aliases
- History
- Job control
- Complete data structures

**Why separate:** All shell integration logic in one place

---

#### `lib/craft_lib.home` (400 lines)
**Purpose:** Craft UI integration

**Contains:**
- Window management
- Widget system
- Desktop environment
- Notifications
- Compositor
- Complete data structures

**Why separate:** All UI integration logic in one place

---

### **Low-Level Modules**

#### `multiboot2.home` (200 lines)
**Purpose:** Multiboot2 protocol support
**Why separate:** Bootloader-specific code

#### `serial.home` (100 lines)
**Purpose:** Serial port driver (COM1)
**Why separate:** Hardware-specific driver

#### `vga.home` (150 lines)
**Purpose:** VGA text mode driver
**Why separate:** Hardware-specific driver

#### `pmm.home` (200 lines)
**Purpose:** Physical memory manager
**Why separate:** Memory management subsystem

#### `vmm.home` (300 lines)
**Purpose:** Virtual memory manager
**Why separate:** Memory management subsystem

#### `heap.home` (200 lines)
**Purpose:** Kernel heap allocator
**Why separate:** Memory management subsystem

#### `idt.home` (250 lines)
**Purpose:** Interrupt descriptor table
**Why separate:** Interrupt handling subsystem

---

## Import Graph

```
main.home
  ├── kernel.home
  │     ├── multiboot2.home
  │     ├── serial.home
  │     ├── vga.home
  │     ├── pmm.home
  │     ├── vmm.home
  │     ├── heap.home
  │     └── idt.home
  │
  └── integration.home
        ├── lib/pantry_lib.home
        ├── lib/den_lib.home
        └── lib/craft_lib.home
```

---

## Benefits of This Structure

### **1. Modularity**
- Each file has a single, clear purpose
- Easy to find specific functionality
- Changes are isolated to relevant modules

### **2. Maintainability**
- Smaller files are easier to understand
- Clear separation of concerns
- Easier to debug and test

### **3. Scalability**
- Easy to add new modules
- Can split large modules further if needed
- Clear extension points

### **4. Collaboration**
- Multiple developers can work on different modules
- Less merge conflicts
- Clear ownership of components

### **5. Build Optimization**
- Can compile modules independently
- Faster incremental builds
- Better caching

---

## File Size Guidelines

### **Ideal Sizes**
- **Entry points:** 50-100 lines
- **Drivers:** 100-200 lines
- **Subsystems:** 200-400 lines
- **Integration libraries:** 400-500 lines
- **Core kernel:** 800-1000 lines (max)

### **When to Split**
- File exceeds 500 lines → Consider splitting
- File has multiple responsibilities → Split by responsibility
- File is hard to navigate → Split into logical sections

---

## Current Status

### **Total Lines**
- main.home: 50 lines
- kernel.home: 850 lines
- integration.home: 150 lines
- lib/pantry_lib.home: 400 lines
- lib/den_lib.home: 500 lines
- lib/craft_lib.home: 400 lines
- Low-level modules: ~1,400 lines
- **Total: ~3,750 lines**

### **Files**
- Core: 2 files (main, kernel)
- Integration: 4 files (integration + 3 libraries)
- Low-level: 7 files (drivers, memory, interrupts)
- **Total: 13 files**

---

## Future Improvements

### **Potential Splits**

#### **kernel.home** (850 lines) could become:
- `core/foundation.home` - Phase 1 (150 lines)
- `core/process.home` - Phase 2 (200 lines)
- `core/advanced.home` - Phase 3 (100 lines)
- `core/filesystem.home` - Phase 4 (200 lines)
- `core/devices.home` - Phase 5 (100 lines)
- `core/network.home` - Phase 6 (100 lines)

This would give us **6 files of ~100-200 lines each** instead of one 850-line file.

#### **Benefits:**
- ✅ Each phase in its own file
- ✅ Easier to navigate
- ✅ Better organization
- ✅ Clearer dependencies

#### **Trade-offs:**
- ⚠️ More files to manage
- ⚠️ More imports needed
- ⚠️ Slightly more complex build

**Recommendation:** Keep kernel.home as-is for now (850 lines is manageable). Split only if it grows beyond 1000 lines.

---

## Best Practices

### **1. One Responsibility Per File**
Each file should have a single, clear purpose.

### **2. Clear Naming**
File names should describe their contents:
- `pantry_lib.home` - Pantry library integration
- `den_lib.home` - Den shell integration
- `serial.home` - Serial driver

### **3. Logical Grouping**
Related files should be in the same directory:
- `lib/` - Integration libraries
- `core/` - Core kernel modules (future)
- `drivers/` - Hardware drivers (future)

### **4. Minimal Coupling**
Files should depend on as few other files as possible.

### **5. Clear Interfaces**
Use `export` to clearly define public APIs.

---
