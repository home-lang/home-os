# Kernel Modules

HomeOS supports loadable kernel modules that extend kernel functionality without requiring a full reboot. Written in the Home programming language, modules can add device drivers, file systems, and other kernel features dynamically.

## Overview

The kernel module system provides:

- **Dynamic Loading**: Load and unload modules at runtime
- **Dependency Resolution**: Automatic handling of module dependencies
- **Symbol Export**: Controlled sharing of kernel symbols
- **Versioning**: Module ABI compatibility checking
- **Security**: Signature verification for trusted modules

## Module Structure

### Basic Module Definition

```home
import kernel/module

// Module metadata
const module_info = ModuleInfo{
    .name = "example_module",
    .version = "1.0.0",
    .author = "HomeOS Team",
    .description = "Example kernel module",
    .license = "MIT"
}

// Module dependencies
const dependencies = [_][]const u8{
    "core",
    "pci"
}

// Module initialization
export fn module_init(): i32 {
    kernel_log("Example module loaded\n")

    // Register functionality
    let result = register_driver(&example_driver)
    if result < 0 {
        return result
    }

    return 0
}

// Module cleanup
export fn module_exit() {
    kernel_log("Example module unloaded\n")

    // Unregister functionality
    unregister_driver(&example_driver)
}

// Export module entry points
comptime {
    module.register_init(module_init)
    module.register_exit(module_exit)
    module.set_info(&module_info)
    module.set_dependencies(&dependencies)
}
```

### Module Metadata

```home
const ModuleInfo = struct {
    name: [64]u8,
    version: [16]u8,
    author: [64]u8,
    description: [256]u8,
    license: [32]u8,
    vermagic: [64]u8,  // Kernel version magic
    srcversion: [32]u8
}

const ModuleState = enum {
    Unloaded,
    Loading,
    Live,
    Unloading
}

const Module = struct {
    info: ModuleInfo,
    state: ModuleState,
    init: fn () i32,
    exit: fn () void,
    dependencies: []const []const u8,
    dependents: ModuleList,
    ref_count: u32,
    base_addr: usize,
    size: usize,
    symbols: SymbolTable,
    sections: []Section
}
```

## Module Loading

### Loading Process

```home
import kernel/memory
import kernel/elf

const MODULE_MAGIC = 0x4D4F4455  // "MODU"

export fn load_module(path: []const u8): i32 {
    // Open module file
    let file = filesystem.open(path, O_RDONLY)
    if file == null {
        return -ENOENT
    }

    // Read ELF header
    let header = elf.read_header(file)
    if header == null or !elf.validate(header) {
        filesystem.close(file)
        return -ENOEXEC
    }

    // Verify module signature (if secure boot enabled)
    if secure_boot_enabled() {
        if !verify_module_signature(file) {
            filesystem.close(file)
            return -EKEYREJECTED
        }
    }

    // Allocate module structure
    let module = memory.allocate(Module) ?? {
        filesystem.close(file)
        return -ENOMEM
    }

    module.state = ModuleState.Loading

    // Calculate total memory needed
    let total_size = calculate_module_size(header)

    // Allocate memory for module
    let base = memory.allocate_kernel_pages((total_size + PAGE_SIZE - 1) / PAGE_SIZE)
    if base == null {
        memory.free(module)
        filesystem.close(file)
        return -ENOMEM
    }

    module.base_addr = @intFromPtr(base)
    module.size = total_size

    // Load sections
    let result = load_sections(file, header, module)
    if result < 0 {
        memory.free_kernel_pages(base)
        memory.free(module)
        filesystem.close(file)
        return result
    }

    filesystem.close(file)

    // Process relocations
    result = apply_relocations(module)
    if result < 0 {
        free_module(module)
        return result
    }

    // Resolve symbol dependencies
    result = resolve_symbols(module)
    if result < 0 {
        free_module(module)
        return result
    }

    // Load dependencies first
    result = load_dependencies(module)
    if result < 0 {
        free_module(module)
        return result
    }

    // Parse module info section
    parse_module_info(module)

    // Call module init function
    if module.init != null {
        result = module.init()
        if result < 0 {
            unload_dependencies(module)
            free_module(module)
            return result
        }
    }

    module.state = ModuleState.Live

    // Add to loaded modules list
    add_to_modules_list(module)

    kernel_log("Module {} loaded at {x}\n", module.info.name, module.base_addr)

    return 0
}

fn load_sections(file: *File, header: *ElfHeader, module: *Module): i32 {
    let section_count = header.shnum
    let section_offset = header.shoff

    module.sections = memory.allocate_array(Section, section_count) ?? return -ENOMEM

    var current_offset: usize = 0

    for i in 0..section_count {
        filesystem.seek(file, section_offset + i * header.shentsize, SEEK_SET)

        let shdr = filesystem.read_struct(file, ElfSectionHeader) ?? return -EIO

        if shdr.type == SHT_NULL {
            continue
        }

        let section = &module.sections[i]
        section.name_offset = shdr.name
        section.type = shdr.type
        section.flags = shdr.flags
        section.size = shdr.size
        section.addr = module.base_addr + current_offset

        if shdr.type != SHT_NOBITS {
            // Load section data
            filesystem.seek(file, shdr.offset, SEEK_SET)
            filesystem.read(file, @ptrFromInt(section.addr), shdr.size)
        } else {
            // BSS section - zero it
            @memset(@ptrFromInt(section.addr), 0, shdr.size)
        }

        current_offset = align_up(current_offset + shdr.size, shdr.addralign)
    }

    return 0
}
```

### Symbol Resolution

```home
const Symbol = struct {
    name: [128]u8,
    addr: usize,
    size: usize,
    type: SymbolType,
    binding: SymbolBinding,
    module: ?*Module
}

const SymbolType = enum {
    NoType,
    Object,
    Func,
    Section,
    File
}

const SymbolBinding = enum {
    Local,
    Global,
    Weak
}

// Kernel symbol table
let kernel_symbols: HashMap([]const u8, *Symbol) = undefined

export fn export_symbol(name: []const u8, addr: usize) {
    let sym = memory.allocate(Symbol) ?? return

    @memcpy(&sym.name, name.ptr, @min(name.len, 127))
    sym.addr = addr
    sym.type = SymbolType.Func
    sym.binding = SymbolBinding.Global
    sym.module = null

    kernel_symbols.put(name, sym)
}

export fn export_symbol_gpl(name: []const u8, addr: usize) {
    let sym = memory.allocate(Symbol) ?? return

    @memcpy(&sym.name, name.ptr, @min(name.len, 127))
    sym.addr = addr
    sym.type = SymbolType.Func
    sym.binding = SymbolBinding.Global
    sym.module = null
    sym.gpl_only = true

    kernel_symbols.put(name, sym)
}

fn resolve_symbols(module: *Module): i32 {
    // Find symbol table section
    let symtab = find_section(module, SHT_SYMTAB) ?? return 0

    let sym_count = symtab.size / @sizeOf(ElfSymbol)

    for i in 0..sym_count {
        let sym: *ElfSymbol = @ptrFromInt(symtab.addr + i * @sizeOf(ElfSymbol))

        if sym.shndx == SHN_UNDEF and sym.name != 0 {
            // Undefined symbol - need to resolve
            let name = get_symbol_name(module, sym.name)

            let resolved = kernel_symbols.get(name)
            if resolved == null {
                kernel_log("Unresolved symbol: {}\n", name)
                return -ENOENT
            }

            // Check GPL compatibility
            if resolved.gpl_only and !module_is_gpl(module) {
                kernel_log("Symbol {} requires GPL license\n", name)
                return -EINVAL
            }

            // Update symbol value
            sym.value = resolved.addr
        }
    }

    return 0
}

fn apply_relocations(module: *Module): i32 {
    // Process RELA sections
    for section in module.sections {
        if section.type != SHT_RELA {
            continue
        }

        let target_section = &module.sections[section.info]
        let rela_count = section.size / @sizeOf(ElfRela)

        for i in 0..rela_count {
            let rela: *ElfRela = @ptrFromInt(section.addr + i * @sizeOf(ElfRela))

            let sym_idx = rela.info >> 32
            let type_ = rela.info & 0xFFFFFFFF
            let sym = get_symbol(module, sym_idx)

            let target = target_section.addr + rela.offset
            let value = sym.value + rela.addend

            apply_relocation(target, value, type_)
        }
    }

    return 0
}

fn apply_relocation(target: usize, value: usize, type_: u32) {
    switch type_ {
        R_X86_64_64 => {
            let ptr: *u64 = @ptrFromInt(target)
            ptr.* = value
        },
        R_X86_64_PC32 => {
            let ptr: *i32 = @ptrFromInt(target)
            ptr.* = @truncate(value - target)
        },
        R_X86_64_PLT32 => {
            let ptr: *i32 = @ptrFromInt(target)
            ptr.* = @truncate(value - target)
        },
        R_X86_64_32 => {
            let ptr: *u32 = @ptrFromInt(target)
            ptr.* = @truncate(value)
        },
        R_X86_64_32S => {
            let ptr: *i32 = @ptrFromInt(target)
            ptr.* = @truncate(value)
        },
        else => {
            kernel_log("Unknown relocation type: {}\n", type_)
        }
    }
}
```

## Module Unloading

```home
export fn unload_module(name: []const u8): i32 {
    let module = find_module_by_name(name)
    if module == null {
        return -ENOENT
    }

    // Check if module can be unloaded
    if module.ref_count > 0 {
        kernel_log("Module {} is still in use\n", name)
        return -EBUSY
    }

    // Check for dependents
    if !module.dependents.is_empty() {
        kernel_log("Module {} has active dependents\n", name)
        return -EBUSY
    }

    module.state = ModuleState.Unloading

    // Call module exit function
    if module.exit != null {
        module.exit()
    }

    // Decrement dependency reference counts
    for dep_name in module.dependencies {
        let dep = find_module_by_name(dep_name)
        if dep != null {
            dep.ref_count -= 1
            dep.dependents.remove(module)
        }
    }

    // Remove from modules list
    remove_from_modules_list(module)

    // Unexport symbols
    for sym in module.symbols {
        kernel_symbols.remove(sym.name)
    }

    // Free module memory
    memory.free_kernel_pages(@ptrFromInt(module.base_addr))
    memory.free(module.sections)
    memory.free(module)

    kernel_log("Module {} unloaded\n", name)

    return 0
}
```

## Module Parameters

```home
const ModuleParam = struct {
    name: [64]u8,
    type: ParamType,
    value: *anyopaque,
    permissions: u16,
    description: [256]u8
}

const ParamType = enum {
    Bool,
    Int,
    UInt,
    String,
    IntArray,
    StringArray
}

// Declare a module parameter
pub fn module_param(comptime name: []const u8, comptime T: type, default: T, desc: []const u8) *T {
    const storage = struct {
        var value: T = default
    }

    comptime {
        register_param(ModuleParam{
            .name = name,
            .type = param_type_for(T),
            .value = &storage.value,
            .permissions = 0o644,
            .description = desc
        })
    }

    return &storage.value
}

// Usage example
const debug_level = module_param("debug", u32, 0, "Debug verbosity level (0-5)")
const enable_feature = module_param("enable_feature", bool, false, "Enable experimental feature")

fn module_init(): i32 {
    if debug_level.* > 0 {
        kernel_log("Debug level: {}\n", debug_level.*)
    }

    if enable_feature.* {
        kernel_log("Experimental feature enabled\n")
    }

    return 0
}

// Parse module parameters from command line
fn parse_module_params(module: *Module, params: []const u8) {
    var iter = split(params, ' ')

    while iter.next()) |param| {
        let eq_pos = find_char(param, '=') ?? continue
        let name = param[0..eq_pos]
        let value = param[eq_pos + 1..]

        for mod_param in module.params {
            if mem_equal(mod_param.name, name) {
                set_param_value(mod_param, value)
                break
            }
        }
    }
}
```

## Module Dependencies

```home
fn load_dependencies(module: *Module): i32 {
    for dep_name in module.dependencies {
        // Check if already loaded
        let dep = find_module_by_name(dep_name)

        if dep == null {
            // Try to load dependency
            var path_buf: [256]u8 = undefined
            let path = format_path(&path_buf, "/lib/modules/{}.ko", dep_name)

            let result = load_module(path)
            if result < 0 {
                kernel_log("Failed to load dependency: {}\n", dep_name)
                return result
            }

            dep = find_module_by_name(dep_name)
        }

        if dep != null {
            dep.ref_count += 1
            dep.dependents.add(module)
        }
    }

    return 0
}

fn unload_dependencies(module: *Module) {
    for dep_name in module.dependencies {
        let dep = find_module_by_name(dep_name)
        if dep != null {
            dep.ref_count -= 1
            dep.dependents.remove(module)
        }
    }
}

// Topological sort for module loading order
fn get_load_order(modules: [][]const u8): [][]const u8 {
    let result = ArrayList([]const u8).init()
    let visited = HashSet([]const u8).init()
    let in_progress = HashSet([]const u8).init()

    for mod_name in modules {
        visit(mod_name, &result, &visited, &in_progress)
    }

    return result.items
}

fn visit(name: []const u8, result: *ArrayList([]const u8), visited: *HashSet([]const u8), in_progress: *HashSet([]const u8)) {
    if visited.contains(name) {
        return
    }

    if in_progress.contains(name) {
        kernel_panic("Circular dependency detected")
    }

    in_progress.add(name)

    let module = find_module_by_name(name)
    if module != null {
        for dep in module.dependencies {
            visit(dep, result, visited, in_progress)
        }
    }

    in_progress.remove(name)
    visited.add(name)
    result.append(name)
}
```

## System Calls

```home
export fn sys_init_module(image: []const u8, params: []const u8): i32 {
    // Check permission
    if !capable(CAP_SYS_MODULE) {
        return -EPERM
    }

    // Check lockdown
    if !lockdown_check(LockdownOperation.ModuleLoad) {
        return -EPERM
    }

    // Load from memory image
    return load_module_from_image(image, params)
}

export fn sys_finit_module(fd: i32, params: []const u8, flags: u32): i32 {
    if !capable(CAP_SYS_MODULE) {
        return -EPERM
    }

    if !lockdown_check(LockdownOperation.ModuleLoad) {
        return -EPERM
    }

    let file = get_file_from_fd(fd) ?? return -EBADF

    return load_module_from_file(file, params, flags)
}

export fn sys_delete_module(name: []const u8, flags: u32): i32 {
    if !capable(CAP_SYS_MODULE) {
        return -EPERM
    }

    if flags & O_NONBLOCK != 0 {
        return try_unload_module(name)
    }

    return unload_module(name)
}
```

## Summary

HomeOS kernel modules provide:

- **Dynamic Loading**: Load modules at runtime from ELF object files
- **Symbol Resolution**: Automatic kernel symbol linking
- **Relocation**: Full support for x86-64 relocations
- **Dependencies**: Automatic dependency loading and ordering
- **Parameters**: Runtime configurable module options
- **Security**: Signature verification and capability checks

All module code is written in the Home programming language, providing type-safe symbol exports and memory management.
