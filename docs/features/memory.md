# Memory Management

HomeOS implements a sophisticated memory management system that handles both physical and virtual memory. Built entirely in the Home programming language, the memory subsystem provides efficient allocation, paging, and protection mechanisms essential for a modern operating system.

## Overview

The memory management system in HomeOS consists of several key components:

- **Physical Memory Manager (PMM)**: Tracks and allocates physical memory frames
- **Virtual Memory Manager (VMM)**: Manages virtual address spaces and page tables
- **Kernel Heap**: Provides dynamic memory allocation for kernel data structures
- **Page Allocator**: Handles page-level allocation requests

## Physical Memory Manager

The PMM tracks all available physical memory using a bitmap allocator for efficiency.

### Physical Memory Structures

```home
import kernel/multiboot

const PAGE_SIZE = 4096
const MAX_PHYSICAL_MEMORY = 16 * 1024 * 1024 * 1024  // 16 GB max

// Bitmap to track free/used frames
let frame_bitmap: [MAX_PHYSICAL_MEMORY / PAGE_SIZE / 64]u64 = undefined
let total_frames: usize = 0
let free_frames: usize = 0

// Memory region information from bootloader
const MemoryRegion = struct {
    base: u64,
    length: u64,
    type: MemoryType
}

const MemoryType = enum(u32) {
    Available = 1,
    Reserved = 2,
    ACPIReclaimable = 3,
    ACPINVS = 4,
    BadMemory = 5
}
```

### PMM Initialization

```home
export fn pmm_init(multiboot_info: *MultibootInfo) {
    // Parse memory map from bootloader
    let mmap = multiboot.get_memory_map(multiboot_info)

    // Initialize bitmap to all used
    for i in 0..frame_bitmap.len {
        frame_bitmap[i] = 0xFFFFFFFFFFFFFFFF
    }

    // Mark available regions as free
    for region in mmap {
        if region.type == MemoryType.Available {
            let start_frame = (region.base + PAGE_SIZE - 1) / PAGE_SIZE
            let end_frame = (region.base + region.length) / PAGE_SIZE

            for frame in start_frame..end_frame {
                clear_frame_bit(frame)
                free_frames += 1
            }
            total_frames += end_frame - start_frame
        }
    }

    // Reserve kernel memory
    let kernel_start = @intFromPtr(&__kernel_start)
    let kernel_end = @intFromPtr(&__kernel_end)
    let kernel_frames = (kernel_end - kernel_start + PAGE_SIZE - 1) / PAGE_SIZE

    for i in 0..kernel_frames {
        let frame = kernel_start / PAGE_SIZE + i
        set_frame_bit(frame)
        free_frames -= 1
    }

    // Reserve first 1MB for BIOS/legacy
    for frame in 0..256 {
        set_frame_bit(frame)
        free_frames -= 1
    }
}

fn set_frame_bit(frame: usize) {
    let index = frame / 64
    let bit = frame % 64
    frame_bitmap[index] |= (1 << bit)
}

fn clear_frame_bit(frame: usize) {
    let index = frame / 64
    let bit = frame % 64
    frame_bitmap[index] &= ~(1 << bit)
}

fn test_frame_bit(frame: usize): bool {
    let index = frame / 64
    let bit = frame % 64
    return (frame_bitmap[index] & (1 << bit)) != 0
}
```

### Frame Allocation

```home
export fn allocate_frame(): ?usize {
    if free_frames == 0 {
        return null
    }

    // Find first free frame using bitmap scanning
    for i in 0..frame_bitmap.len {
        if frame_bitmap[i] != 0xFFFFFFFFFFFFFFFF {
            // Found a word with at least one free bit
            let bit = find_first_zero_bit(frame_bitmap[i])
            let frame = i * 64 + bit

            set_frame_bit(frame)
            free_frames -= 1

            // Zero the frame
            let addr = frame * PAGE_SIZE
            @memset(@ptrFromInt(addr), 0, PAGE_SIZE)

            return addr
        }
    }

    return null
}

export fn free_frame(addr: usize) {
    let frame = addr / PAGE_SIZE

    if !test_frame_bit(frame) {
        // Double free detected
        kernel_panic("Double free of physical frame")
    }

    clear_frame_bit(frame)
    free_frames += 1
}

export fn allocate_contiguous_frames(count: usize): ?usize {
    if free_frames < count {
        return null
    }

    // Find contiguous region
    let start: usize = 0
    let found: usize = 0

    for frame in 0..total_frames {
        if !test_frame_bit(frame) {
            if found == 0 {
                start = frame
            }
            found += 1

            if found == count {
                // Found enough contiguous frames
                for i in 0..count {
                    set_frame_bit(start + i)
                }
                free_frames -= count
                return start * PAGE_SIZE
            }
        } else {
            found = 0
        }
    }

    return null
}

fn find_first_zero_bit(value: u64): usize {
    for i in 0..64 {
        if (value & (1 << i)) == 0 {
            return i
        }
    }
    return 64  // No zero bit found
}
```

## Virtual Memory Manager

The VMM manages virtual address spaces using 4-level paging on x86-64.

### Page Table Structures

```home
const PAGE_PRESENT = 1 << 0
const PAGE_WRITE = 1 << 1
const PAGE_USER = 1 << 2
const PAGE_WRITETHROUGH = 1 << 3
const PAGE_NOCACHE = 1 << 4
const PAGE_ACCESSED = 1 << 5
const PAGE_DIRTY = 1 << 6
const PAGE_HUGE = 1 << 7
const PAGE_GLOBAL = 1 << 8
const PAGE_NX = 1 << 63

// Page table entry
const PageTableEntry = packed struct(u64) {
    present: bool,
    writable: bool,
    user: bool,
    write_through: bool,
    cache_disable: bool,
    accessed: bool,
    dirty: bool,
    huge_page: bool,
    global: bool,
    available: u3,
    physical_address: u40,
    available2: u11,
    no_execute: bool
}

// 512 entries per table, 8 bytes each = 4KB page
const PageTable = [512]PageTableEntry

// PML4 is the top-level page table
let kernel_pml4: *PageTable = undefined
```

### Address Space Creation

```home
export fn create_address_space(): ?*PageTable {
    // Allocate PML4
    let pml4_phys = allocate_frame() ?? return null
    let pml4: *PageTable = @ptrFromInt(pml4_phys + KERNEL_OFFSET)

    // Clear all entries
    for i in 0..512 {
        pml4[i] = PageTableEntry{}
    }

    // Copy kernel mappings (upper half)
    for i in 256..512 {
        pml4[i] = kernel_pml4[i]
    }

    return pml4
}

export fn destroy_address_space(pml4: *PageTable) {
    // Free all user page tables (lower half only)
    for i in 0..256 {
        if pml4[i].present {
            free_page_table_recursive(pml4[i], 3)
        }
    }

    // Free PML4 itself
    free_frame(@intFromPtr(pml4) - KERNEL_OFFSET)
}

fn free_page_table_recursive(entry: PageTableEntry, level: u32) {
    if level == 0 {
        return
    }

    let table: *PageTable = @ptrFromInt(entry.physical_address << 12 + KERNEL_OFFSET)

    for i in 0..512 {
        if table[i].present and !table[i].huge_page {
            free_page_table_recursive(table[i], level - 1)
        }
    }

    free_frame(entry.physical_address << 12)
}
```

### Page Mapping

```home
export fn map_page(pml4: *PageTable, vaddr: usize, paddr: usize, flags: u64) {
    let indices = get_page_indices(vaddr)

    // Get or create PDPT
    let pdpt = get_or_create_table(pml4, indices.pml4, flags)
    if pdpt == null {
        kernel_panic("Failed to allocate PDPT")
    }

    // Get or create PD
    let pd = get_or_create_table(pdpt, indices.pdpt, flags)
    if pd == null {
        kernel_panic("Failed to allocate PD")
    }

    // Get or create PT
    let pt = get_or_create_table(pd, indices.pd, flags)
    if pt == null {
        kernel_panic("Failed to allocate PT")
    }

    // Set the page table entry
    pt[indices.pt] = PageTableEntry{
        .present = true,
        .writable = (flags & PAGE_WRITE) != 0,
        .user = (flags & PAGE_USER) != 0,
        .write_through = (flags & PAGE_WRITETHROUGH) != 0,
        .cache_disable = (flags & PAGE_NOCACHE) != 0,
        .accessed = false,
        .dirty = false,
        .huge_page = false,
        .global = (flags & PAGE_GLOBAL) != 0,
        .available = 0,
        .physical_address = @truncate(paddr >> 12),
        .available2 = 0,
        .no_execute = (flags & PAGE_NX) != 0
    }

    // Flush TLB for this address
    invalidate_page(vaddr)
}

fn get_or_create_table(table: *PageTable, index: usize, flags: u64): ?*PageTable {
    if table[index].present {
        return @ptrFromInt((table[index].physical_address << 12) + KERNEL_OFFSET)
    }

    // Allocate new table
    let new_table_phys = allocate_frame() ?? return null
    let new_table: *PageTable = @ptrFromInt(new_table_phys + KERNEL_OFFSET)

    // Clear new table
    for i in 0..512 {
        new_table[i] = PageTableEntry{}
    }

    // Set entry pointing to new table
    table[index] = PageTableEntry{
        .present = true,
        .writable = true,
        .user = (flags & PAGE_USER) != 0,
        .physical_address = @truncate(new_table_phys >> 12)
    }

    return new_table
}

fn get_page_indices(vaddr: usize): PageIndices {
    return PageIndices{
        .pml4 = (vaddr >> 39) & 0x1FF,
        .pdpt = (vaddr >> 30) & 0x1FF,
        .pd = (vaddr >> 21) & 0x1FF,
        .pt = (vaddr >> 12) & 0x1FF,
        .offset = vaddr & 0xFFF
    }
}

const PageIndices = struct {
    pml4: usize,
    pdpt: usize,
    pd: usize,
    pt: usize,
    offset: usize
}

fn invalidate_page(vaddr: usize) {
    asm volatile ("invlpg (%[addr])" : : [addr] "r" (vaddr) : "memory")
}
```

### Huge Page Support

```home
export fn map_huge_page_2mb(pml4: *PageTable, vaddr: usize, paddr: usize, flags: u64) {
    let indices = get_page_indices(vaddr)

    // Get or create PDPT
    let pdpt = get_or_create_table(pml4, indices.pml4, flags)
    if pdpt == null {
        kernel_panic("Failed to allocate PDPT")
    }

    // Get or create PD
    let pd = get_or_create_table(pdpt, indices.pdpt, flags)
    if pd == null {
        kernel_panic("Failed to allocate PD")
    }

    // Set 2MB huge page entry directly in PD
    pd[indices.pd] = PageTableEntry{
        .present = true,
        .writable = (flags & PAGE_WRITE) != 0,
        .user = (flags & PAGE_USER) != 0,
        .huge_page = true,
        .global = (flags & PAGE_GLOBAL) != 0,
        .physical_address = @truncate(paddr >> 12),
        .no_execute = (flags & PAGE_NX) != 0
    }

    invalidate_page(vaddr)
}

export fn map_huge_page_1gb(pml4: *PageTable, vaddr: usize, paddr: usize, flags: u64) {
    let indices = get_page_indices(vaddr)

    // Get or create PDPT
    let pdpt = get_or_create_table(pml4, indices.pml4, flags)
    if pdpt == null {
        kernel_panic("Failed to allocate PDPT")
    }

    // Set 1GB huge page entry directly in PDPT
    pdpt[indices.pdpt] = PageTableEntry{
        .present = true,
        .writable = (flags & PAGE_WRITE) != 0,
        .user = (flags & PAGE_USER) != 0,
        .huge_page = true,
        .global = (flags & PAGE_GLOBAL) != 0,
        .physical_address = @truncate(paddr >> 12),
        .no_execute = (flags & PAGE_NX) != 0
    }

    invalidate_page(vaddr)
}
```

## Kernel Heap

The kernel heap provides dynamic memory allocation using a slab allocator.

### Slab Allocator

```home
const SLAB_SIZES = [_]usize{ 16, 32, 64, 128, 256, 512, 1024, 2048, 4096 }

const SlabHeader = struct {
    next: ?*SlabHeader,
    size: usize,
    free_count: usize,
    total_count: usize,
    free_list: ?*FreeBlock
}

const FreeBlock = struct {
    next: ?*FreeBlock
}

// One cache per slab size
let slab_caches: [SLAB_SIZES.len]*SlabHeader = undefined

export fn heap_init() {
    for i in 0..SLAB_SIZES.len {
        slab_caches[i] = create_slab(SLAB_SIZES[i])
    }
}

fn create_slab(size: usize): *SlabHeader {
    // Allocate a page for the slab
    let page = allocate_frame() ?? kernel_panic("Out of memory for slab")
    let slab: *SlabHeader = @ptrFromInt(page + KERNEL_OFFSET)

    let header_size = @sizeOf(SlabHeader)
    let usable_size = PAGE_SIZE - header_size
    let block_count = usable_size / size

    slab.* = SlabHeader{
        .next = null,
        .size = size,
        .free_count = block_count,
        .total_count = block_count,
        .free_list = null
    }

    // Initialize free list
    let base = @intFromPtr(slab) + header_size
    for i in 0..block_count {
        let block: *FreeBlock = @ptrFromInt(base + i * size)
        block.next = slab.free_list
        slab.free_list = block
    }

    return slab
}
```

### Memory Allocation

```home
export fn kmalloc(size: usize): ?*anyopaque {
    // Find appropriate slab size
    for i in 0..SLAB_SIZES.len {
        if SLAB_SIZES[i] >= size {
            return slab_alloc(slab_caches[i])
        }
    }

    // Size too large for slab, allocate pages directly
    let pages = (size + PAGE_SIZE - 1) / PAGE_SIZE
    let addr = allocate_contiguous_frames(pages) ?? return null
    return @ptrFromInt(addr + KERNEL_OFFSET)
}

fn slab_alloc(cache: *SlabHeader): ?*anyopaque {
    // Find a slab with free blocks
    let slab = cache
    while slab != null {
        if slab.free_list != null {
            let block = slab.free_list
            slab.free_list = block.next
            slab.free_count -= 1
            return @ptrCast(block)
        }
        slab = slab.next
    }

    // No free blocks, create new slab
    let new_slab = create_slab(cache.size)
    new_slab.next = cache.next
    cache.next = new_slab

    // Allocate from new slab
    let block = new_slab.free_list
    new_slab.free_list = block.next
    new_slab.free_count -= 1
    return @ptrCast(block)
}

export fn kfree(ptr: *anyopaque) {
    let addr = @intFromPtr(ptr)

    // Check if this is a slab allocation
    for i in 0..SLAB_SIZES.len {
        let slab = slab_caches[i]
        while slab != null {
            let slab_start = @intFromPtr(slab)
            let slab_end = slab_start + PAGE_SIZE

            if addr >= slab_start and addr < slab_end {
                // Found the slab
                let block: *FreeBlock = @ptrCast(ptr)
                block.next = slab.free_list
                slab.free_list = block
                slab.free_count += 1
                return
            }
            slab = slab.next
        }
    }

    // Must be a large allocation, free pages
    let phys = addr - KERNEL_OFFSET
    free_frame(phys)
}
```

### Aligned Allocation

```home
export fn kmalloc_aligned(size: usize, alignment: usize): ?*anyopaque {
    // Allocate extra space for alignment
    let total_size = size + alignment - 1 + @sizeOf(usize)
    let ptr = kmalloc(total_size) ?? return null

    // Align the pointer
    let addr = @intFromPtr(ptr)
    let aligned = (addr + @sizeOf(usize) + alignment - 1) & ~(alignment - 1)

    // Store original pointer before aligned address
    let original_ptr: *usize = @ptrFromInt(aligned - @sizeOf(usize))
    original_ptr.* = addr

    return @ptrFromInt(aligned)
}

export fn kfree_aligned(ptr: *anyopaque) {
    let aligned = @intFromPtr(ptr)
    let original_ptr: *usize = @ptrFromInt(aligned - @sizeOf(usize))
    let original = original_ptr.*

    kfree(@ptrFromInt(original))
}
```

## Page Fault Handler

The page fault handler manages memory access violations and implements demand paging.

```home
import kernel/interrupts

const PAGE_FAULT_PRESENT = 1 << 0
const PAGE_FAULT_WRITE = 1 << 1
const PAGE_FAULT_USER = 1 << 2
const PAGE_FAULT_RESERVED = 1 << 3
const PAGE_FAULT_INSTRUCTION = 1 << 4

export fn page_fault_handler(frame: *InterruptFrame) {
    // Get faulting address from CR2
    let fault_addr: usize = undefined
    asm volatile ("mov %%cr2, %[addr]" : [addr] "=r" (fault_addr))

    let error_code = frame.error_code
    let proc = get_current_process()

    // Check if this is a valid page fault
    if error_code & PAGE_FAULT_PRESENT != 0 {
        // Page was present, protection violation
        if error_code & PAGE_FAULT_USER != 0 {
            // User process violated protection
            send_signal(proc, SIGSEGV)
            return
        }
        kernel_panic("Kernel protection fault at address")
    }

    // Page not present - check if it's a valid mapping
    let vma = find_vma(proc, fault_addr)
    if vma == null {
        if error_code & PAGE_FAULT_USER != 0 {
            send_signal(proc, SIGSEGV)
            return
        }
        kernel_panic("Kernel accessed unmapped address")
    }

    // Demand paging - allocate and map the page
    let phys = allocate_frame() ?? {
        // Out of memory
        if error_code & PAGE_FAULT_USER != 0 {
            send_signal(proc, SIGKILL)
            return
        }
        kernel_panic("Out of memory in page fault handler")
    }

    let page_addr = fault_addr & ~(PAGE_SIZE - 1)
    let flags = vma.flags | PAGE_PRESENT

    map_page(proc.memory_map, page_addr, phys, flags)

    // If this is a file-backed mapping, load the data
    if vma.file != null {
        let offset = page_addr - vma.start + vma.file_offset
        vma.file.read_at(offset, @ptrFromInt(page_addr), PAGE_SIZE)
    }
}

const VMA = struct {
    start: usize,
    end: usize,
    flags: u64,
    file: ?*File,
    file_offset: usize,
    next: ?*VMA
}

fn find_vma(proc: *Process, addr: usize): ?*VMA {
    let vma = proc.vma_list
    while vma != null {
        if addr >= vma.start and addr < vma.end {
            return vma
        }
        vma = vma.next
    }
    return null
}
```

## Copy-on-Write

Copy-on-write (COW) optimization for fork().

```home
export fn clone_address_space_cow(src_pml4: *PageTable): ?*PageTable {
    let dst_pml4 = create_address_space() ?? return null

    // Walk through all user pages
    for pml4_idx in 0..256 {
        if !src_pml4[pml4_idx].present {
            continue
        }

        let src_pdpt: *PageTable = @ptrFromInt((src_pml4[pml4_idx].physical_address << 12) + KERNEL_OFFSET)

        for pdpt_idx in 0..512 {
            if !src_pdpt[pdpt_idx].present {
                continue
            }

            let src_pd: *PageTable = @ptrFromInt((src_pdpt[pdpt_idx].physical_address << 12) + KERNEL_OFFSET)

            for pd_idx in 0..512 {
                if !src_pd[pd_idx].present {
                    continue
                }

                let src_pt: *PageTable = @ptrFromInt((src_pd[pd_idx].physical_address << 12) + KERNEL_OFFSET)

                for pt_idx in 0..512 {
                    if !src_pt[pt_idx].present {
                        continue
                    }

                    // Calculate virtual address
                    let vaddr = (pml4_idx << 39) | (pdpt_idx << 30) | (pd_idx << 21) | (pt_idx << 12)
                    let paddr = src_pt[pt_idx].physical_address << 12

                    // Mark both pages as read-only for COW
                    src_pt[pt_idx].writable = false

                    // Increment reference count
                    increment_page_ref(paddr)

                    // Map same physical page in destination
                    let flags = get_page_flags(src_pt[pt_idx]) & ~PAGE_WRITE
                    map_page(dst_pml4, vaddr, paddr, flags | PAGE_COW)
                }
            }
        }
    }

    return dst_pml4
}

fn handle_cow_fault(proc: *Process, fault_addr: usize) {
    let page_addr = fault_addr & ~(PAGE_SIZE - 1)
    let entry = get_page_entry(proc.memory_map, page_addr)

    if entry == null or !entry.present {
        return  // Not a COW page
    }

    let old_phys = entry.physical_address << 12

    if get_page_ref(old_phys) == 1 {
        // Only one reference, just make it writable
        entry.writable = true
        invalidate_page(page_addr)
        return
    }

    // Multiple references, need to copy
    let new_phys = allocate_frame() ?? kernel_panic("OOM in COW handler")

    // Copy page contents
    @memcpy(@ptrFromInt(new_phys + KERNEL_OFFSET), @ptrFromInt(old_phys + KERNEL_OFFSET), PAGE_SIZE)

    // Update mapping
    decrement_page_ref(old_phys)
    entry.physical_address = @truncate(new_phys >> 12)
    entry.writable = true
    invalidate_page(page_addr)
}
```

## Memory Statistics

```home
const MemoryStats = struct {
    total_physical: usize,
    free_physical: usize,
    used_physical: usize,
    kernel_heap_used: usize,
    kernel_heap_free: usize,
    page_tables: usize,
    slab_pages: usize
}

export fn get_memory_stats(): MemoryStats {
    let heap_used: usize = 0
    let heap_free: usize = 0
    let slab_pages: usize = 0

    for i in 0..SLAB_SIZES.len {
        let slab = slab_caches[i]
        while slab != null {
            slab_pages += 1
            heap_used += (slab.total_count - slab.free_count) * slab.size
            heap_free += slab.free_count * slab.size
            slab = slab.next
        }
    }

    return MemoryStats{
        .total_physical = total_frames * PAGE_SIZE,
        .free_physical = free_frames * PAGE_SIZE,
        .used_physical = (total_frames - free_frames) * PAGE_SIZE,
        .kernel_heap_used = heap_used,
        .kernel_heap_free = heap_free,
        .page_tables = count_page_tables() * PAGE_SIZE,
        .slab_pages = slab_pages * PAGE_SIZE
    }
}
```

## Summary

HomeOS memory management provides:

- **Physical Memory Manager**: Bitmap-based frame allocator with contiguous allocation support
- **Virtual Memory Manager**: 4-level paging with huge page support (2MB and 1GB)
- **Kernel Heap**: Slab allocator for efficient small allocations
- **Demand Paging**: Pages allocated on first access
- **Copy-on-Write**: Efficient fork() implementation
- **Memory Protection**: User/kernel separation, read/write/execute permissions

All memory management code is implemented in the Home programming language, using packed structs for precise hardware structure representation and inline assembly for CPU register access.
