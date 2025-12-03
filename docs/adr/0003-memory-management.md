# ADR 0003: Memory Management Strategy

**Status**: Accepted
**Date**: 2025-11-24
**Decision Makers**: Core Team
**Tags**: `architecture`, `memory`, `performance`

---

## Context

Home-os targets memory-constrained devices (Raspberry Pi with 1-8GB RAM). We need a memory management strategy that:
- Runs efficiently on low-memory devices (Pi 3 with 1GB)
- Scales to larger systems (Pi 5 with 8GB)
- Provides memory safety
- Enables good performance

---

## Decision

**We will use a multi-tier memory management system:**

1. **Physical Memory Manager (PMM)**: Buddy allocator
2. **Virtual Memory Manager (VMM)**: 4-level page tables (ARM64)
3. **Kernel Allocators**: Slab + pools
4. **Swap**: ZRAM compressed swap
5. **Optimization**: Memory pools, slab caching, leak detection

---

## Rationale

### Physical Memory (PMM)

**Choice**: Buddy Allocator

**Pros**:
- Fast allocation/deallocation (O(log n))
- Low fragmentation with coalescing
- Well-understood algorithm
- Good for page-sized allocations

**Implementation**:
```home
// Buddy allocator orders: 4KB, 8KB, 16KB, ..., 4MB
const BUDDY_MIN_ORDER: u32 = 0  // 4KB
const BUDDY_MAX_ORDER: u32 = 10 // 4MB

struct BuddyAllocator {
  free_lists: [BUDDY_MAX_ORDER]FreeList
  bitmap: *u8
  total_pages: u64
  free_pages: u64
}
```

**Location**: `kernel/src/mm/pmm.home`

### Virtual Memory (VMM)

**Choice**: 4-Level Page Tables (ARM64)

**Configuration**:
- Page size: 4KB (configurable 4KB/16KB/64KB)
- Address space: 48-bit (256TB)
- Kernel space: Upper half (0xFFFF000000000000+)
- User space: Lower half (0x0000000000000000-0x0000FFFFFFFFFFFF)

**Implementation**:
```home
// Page table levels
const PT_LEVELS: u32 = 4
const PAGE_SIZE: u64 = 4096

struct PageTable {
  entries: [512]u64  // 512 entries per table
  flags: u64
  refcount: u32
}
```

**Features**:
- KPTI (Kernel Page Table Isolation)
- ASID (Address Space Identifiers)
- TLB management
- Identity mapping for kernel

**Location**: `kernel/src/arch/arm64/mmu.home`

### Kernel Allocators

**Choice**: Slab + Pools

**Slab Allocator** (for variable-sized objects):
- Bonwick's magazine-layer design
- Per-CPU caches (15-object magazines)
- Common sizes: 16, 32, 64, 128, 256, 512, 1024, 2048, 4096 bytes

```home
struct SlabCache {
  object_size: u32
  objects_per_slab: u32
  magazines: [MAX_CPUS]SlabMagazine
  slabs_full: *Slab
  slabs_partial: *Slab
  slabs_empty: *Slab
}
```

**Location**: `kernel/src/mm/slab.home` (517 lines)

**Memory Pools** (for fixed-sized objects):
- 13 pre-allocated pools (16B-4KB)
- Fast O(1) allocation
- Reduced fragmentation

**Location**: `kernel/src/mm/pool.home` (445 lines)

### Swap

**Choice**: ZRAM (Compressed RAM Swap)

**Rationale**:
- No disk I/O needed
- 2-3x compression ratio
- Fast (in-memory compression)
- Perfect for SD card-based systems

**Configuration**:
- Max size: 512MB
- Compression: LZ4-style
- Page-based swapping

**Location**: `kernel/src/mm/zram.home` (565 lines)

### Memory Budget

**Targets**:

| System | RAM | Kernel Budget | User Space |
|--------|-----|---------------|------------|
| Pi 3 B+ | 1GB | <96MB | ~900MB |
| Pi 4 (4GB) | 4GB | <128MB | ~3.9GB |
| Pi 5 (8GB) | 8GB | <192MB | ~7.8GB |

**Enforcement**:
- Memory audit tool tracks allocations
- Budget checks in allocators
- Leak detection for long-running systems

**Location**: `kernel/src/debug/memory_audit.home` (325 lines)

---

## Consequences

### Positive

1. **Low Fragmentation**: Buddy allocator + slab
2. **Fast Allocation**: O(1) for pools, O(log n) for PMM
3. **Memory Safety**: Home language + bounds checking
4. **Good Performance**: Per-CPU caches reduce contention
5. **ZRAM**: Extends usable memory on low-RAM devices

### Negative

1. **Complexity**: Multiple allocator tiers
2. **Memory Overhead**: Metadata for buddy/slab
3. **ZRAM CPU**: Compression uses CPU cycles

### Mitigations

**Complexity**: Clear documentation and interfaces
**Overhead**: Minimized with careful design (~2% overhead)
**ZRAM CPU**: Only enabled on low-memory systems

---

## Implementation

### Memory Layout (ARM64)

```
0xFFFFFFFFFFFFFFFF ┐
                   │ Kernel Space (Upper Half)
                   │ - Kernel code/data
                   │ - Driver memory
                   │ - MMIO mappings
0xFFFF000000000000 ├─ KPTI Boundary
                   │
0x0000FFFFFFFFFFFF ┐
                   │ User Space (Lower Half)
                   │ - Process memory
                   │ - Heap
                   │ - Stack
0x0000000000000000 ┘
```

### Allocation Flow

```
User Request
    ↓
Size Check
    ↓
    ├─ < 4KB ──→ Slab Allocator ──→ Per-CPU Magazine
    │                ↓ (miss)
    │            Slab Cache
    │                ↓ (miss)
    │            PMM (Buddy)
    │
    ├─ Fixed Size ──→ Memory Pool
    │                    ↓ (miss)
    │                 PMM (Buddy)
    │
    └─ > 4KB ──→ PMM (Buddy) directly
```

### Page Fault Handling

```home
export fn handle_page_fault(addr: u64, is_write: u32) {
  // 1. Check if address is valid
  if !is_valid_address(addr) {
    panic(PANIC_PAGE_FAULT)
  }

  // 2. Check if page is swapped
  if is_page_swapped(addr) {
    swap_in_page(addr)
    return
  }

  // 3. Allocate page on demand
  if is_demand_paging(addr) {
    allocate_page(addr, is_write)
    return
  }

  // 4. Genuine fault
  panic(PANIC_PAGE_FAULT)
}
```

### ZRAM Integration

```home
// Swap out page
export fn swap_out_page(page_addr: u64): u32 {
  let page_data: *u8 = page_addr as *u8
  let compressed: [2048]u8

  let compressed_size: u32 = zram_compress_page(
    page_data,
    &compressed[0],
    4096
  )

  let index: u32 = zram_allocate_slot()
  zram_write_page(index, &compressed[0], compressed_size)

  mark_page_swapped(page_addr, index)
  free_physical_page(page_addr)

  return 0
}
```

---

## Performance Optimizations

### 1. Per-CPU Caches
- Reduce lock contention
- Better cache locality
- Faster allocation (no locks in common case)

### 2. TLB Management
- ASID-based flushing (avoid full TLB flush)
- Lazy TLB shootdowns
- Context-specific invalidation

### 3. Page Coloring
- Reduce cache conflicts
- Better I-cache/D-cache usage
- Configurable color count

### 4. Huge Pages (Future)
- 2MB huge pages for large allocations
- Reduced TLB pressure
- Better performance for databases/VMs

---

## Memory Safety

### Checks Performed

1. **Bounds Checking**: All array accesses checked
2. **Null Pointer**: Checked before dereference
3. **Use-After-Free**: Detected by leak detector
4. **Double-Free**: Caught by allocator assertions
5. **Buffer Overflow**: Stack canaries + guard pages

### Tools

- **Memory Leak Detector**: `kernel/src/debug/memleak.home` (476 lines)
  - Tracks 10,000 allocations
  - Stack traces
  - Periodic reporting

- **Memory Audit**: `kernel/src/debug/memory_audit.home` (325 lines)
  - Budget enforcement
  - Allocation tracking
  - Footprint analysis

---

## Comparison with Other Systems

### vs Linux

| Feature | Linux | home-os | Notes |
|---------|-------|---------|-------|
| PMM | Buddy + SLUB | Buddy + Slab | Similar approach |
| VMM | 4/5-level PT | 4-level PT | Linux more scalable |
| Swap | Disk swap | ZRAM | home-os better for SD cards |
| Safety | Manual | Language | home-os safer |
| Performance | Excellent | Good | Linux decades optimized |

### vs FreeBSD

| Feature | FreeBSD | home-os | Notes |
|---------|---------|---------|-------|
| PMM | Buddy | Buddy | Same |
| VMM | UMA | Slab | Similar concepts |
| Swap | Disk | ZRAM | Different targets |
| NUMA | Yes | No | Not needed for Pi |

---

## Future Enhancements

### Phase 1 (Current)
✅ Buddy allocator
✅ Slab caching
✅ Memory pools
✅ ZRAM
✅ Leak detection

### Phase 2 (Next)
- [ ] Huge page support
- [ ] Page compression (zswap-style)
- [ ] Memory cgroups
- [ ] NUMA awareness (for future SBCs)

### Phase 3 (Future)
- [ ] Transparent huge pages
- [ ] KSM (Kernel Samepage Merging)
- [ ] Memory ballooning
- [ ] CMA (Contiguous Memory Allocator)

---

## Related Decisions

- [ADR-0002](0002-kernel-architecture.md) - Kernel architecture
- [ADR-0006](0006-security-architecture.md) - Security (KPTI, guard pages)
- [ADR-0007](0007-performance-targets.md) - Performance goals

---

## References

**Papers**:
- "The Slab Allocator: An Object-Caching Kernel Memory Allocator" (Bonwick, 1994)
- "Magazines and Vmem" (Bonwick & Adams, 2001)
- "Compressed Caching for Linux" (Sengupta et al., 2015)

**Implementation References**:
- Linux kernel mm/ subsystem
- FreeBSD UMA
- OpenBSD malloc
- jemalloc

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-24 | Core Team | Initial decision |
