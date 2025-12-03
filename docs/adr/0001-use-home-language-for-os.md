# ADR 0001: Use Home Programming Language for Operating System Development

**Status**: Accepted
**Date**: 2025-11-24
**Decision Makers**: Core Team
**Tags**: `architecture`, `language`, `foundation`

---

## Context

We need to choose a programming language for developing a new operating system that targets Raspberry Pi and other embedded devices. The language must support:
- Low-level hardware access
- Memory safety
- Good performance
- Clean, maintainable code

### Options Considered

1. **C** - Traditional OS language
2. **C++** - More features than C
3. **Rust** - Memory safety with zero-cost abstractions
4. **Zig** - Modern low-level language
5. **Home** - Our own programming language

---

## Decision

**We will use the Home programming language exclusively for home-os development.**

All kernel code, drivers, and system utilities will be written in `.home` files. Other languages may only be used where absolutely unavoidable (bootloader assembly).

---

## Rationale

### Why Home?

1. **Dogfooding**: Home-os is the perfect testbed for the Home language compiler
2. **Control**: We can extend Home with OS-specific features as needed
3. **Safety**: Home provides memory safety like Rust
4. **Simplicity**: Cleaner syntax than C/C++/Rust
5. **Integration**: Direct integration between OS and language

### Key Advantages

**Memory Safety**
- Bounds checking by default
- No null pointer dereferences
- Safe pointer arithmetic
- Ownership/borrowing model

**Low-Level Access**
- Inline assembly support via kernel package
- Direct hardware access (MMIO, ports)
- Packed structs for hardware registers
- Volatile pointer support

**Modern Features**
- Generics
- Async/await
- Error handling (try-catch)
- Compile-time evaluation
- Macros

**OS-Specific Support**
- Kernel package (`~/Code/home/packages/kernel/`)
- 60+ modules for kernel development
- Driver support package
- Threading primitives
- FFI for legacy code

### Compared to Alternatives

**vs C**
- ✅ Memory safety (Home wins)
- ✅ Modern syntax (Home wins)
- ❌ Ecosystem maturity (C wins)
- ✅ OS integration (Home wins)

**vs Rust**
- ✅ Control over language (Home wins)
- ✅ Simpler syntax (Home wins)
- ❌ Ecosystem (Rust wins)
- ✅ Faster iteration (Home wins - we control the compiler)

**vs Zig**
- ✅ Memory safety (Home wins - safer by default)
- ✅ OS integration (Home wins)
- ≈ Low-level access (tie)
- ❌ Maturity (Zig wins)

---

## Consequences

### Positive

1. **Language Evolution**: We can add features to Home as we discover OS needs
2. **Tight Integration**: OS and language co-evolve
3. **Learning**: Building an OS teaches us what language features are needed
4. **Unique Selling Point**: OS built with its own language
5. **Full Control**: No waiting for upstream language changes

### Negative

1. **Compiler Bugs**: We must fix Home compiler bugs ourselves
2. **No Ecosystem**: No existing OS libraries in Home
3. **Learning Curve**: Team must learn Home
4. **Risk**: Home compiler issues could block OS development

### Mitigations

1. **Dual Development**: Improve Home compiler alongside OS work
2. **Document Everything**: Create comprehensive Home language docs
3. **Test Suite**: Extensive testing of both compiler and OS
4. **Fallback**: Assembly escape hatch for critical paths

---

## Implementation

### Phase 1: Foundation (Current)
- Write all kernel core in Home
- Use Home's kernel package features
- Document Home patterns for OS development

### Phase 2: Extension
- Add missing features to Home compiler as needed
- Create OS-specific Home modules
- Build standard library for OS work

### Phase 3: Optimization
- Optimize Home compiler for OS code patterns
- Add OS-specific optimizations
- Profile and improve codegen

---

## Examples

### Before (if using C)
```c
void* kmalloc(size_t size) {
    void* ptr = allocate(size);
    if (!ptr) return NULL;  // Unchecked null
    memset(ptr, 0, size);   // Possible buffer overflow
    return ptr;
}
```

### After (with Home)
```home
fn kmalloc(size: u64): *u8 {
  let ptr: *u8 = allocate(size)
  if ptr == 0 {
    return 0
  }
  memory.memset(ptr as u64, 0, size)  // Bounds checked
  return ptr
}
```

---

## Related Decisions

- [ADR-0002](0002-kernel-architecture.md) - Kernel architecture
- [ADR-0003](0003-memory-management.md) - Memory management approach
- [ADR-0005](0005-build-system.md) - Build system design

---

## References

- Home Compiler: `~/Code/home/`
- Home Kernel Package: `~/Code/home/packages/kernel/`
- CLAUDE.md: Project development guidelines
- HOME_KERNEL_FEATURES.md: Complete kernel feature audit

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-24 | Core Team | Initial decision |
