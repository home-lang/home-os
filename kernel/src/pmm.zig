// Physical Memory Manager (PMM) for home-os
// Manages physical page frames using a bitmap allocator
// Zig implementation (will migrate to pmm.home when Home compiler is ready)

const serial = @import("serial.zig");

// Page size constants
pub const PAGE_SIZE: usize = 4096;
pub const PAGE_SHIFT: u6 = 12;

// Memory bitmap (1 bit per page frame)
// For 32MB RAM: 32MB / 4KB = 8,192 pages = 1,024 bytes bitmap
const MAX_PAGES: usize = 8192;  // 32MB max
const BITMAP_SIZE: usize = MAX_PAGES / 8;  // 1KB

// PMM state structure
const PMMState = struct {
    bitmap: [BITMAP_SIZE]u8,
    total_pages: usize,
    used_pages: usize,
    free_pages: usize,
};

// Global PMM state
var pmm_state_global: PMMState = undefined;
var pmm_initialized: bool = false;

// Multiboot2 memory map constants
const MULTIBOOT2_TAG_TYPE_MMAP: u32 = 6;
const MEMORY_AVAILABLE: u32 = 1;
const MEMORY_RESERVED: u32 = 2;
const MEMORY_ACPI_RECLAIMABLE: u32 = 3;
const MEMORY_NVS: u32 = 4;
const MEMORY_BADRAM: u32 = 5;

/// Multiboot2 tag header
const MultibootTag = packed struct {
    type: u32,
    size: u32,
};

/// Multiboot2 memory map entry
const MultibootMemoryEntry = packed struct {
    base_addr: u64,
    length: u64,
    type: u32,
    reserved: u32,
};

/// Initialize physical memory manager
pub fn init(mboot_info_addr: u32) void {
    _ = mboot_info_addr;

    // Initialize PMM state - mark 8MB-24MB as free (16MB)
    pmm_state_global.bitmap = [_]u8{0xFF} ** BITMAP_SIZE;  // All pages used initially
    pmm_state_global.total_pages = 0;
    pmm_state_global.used_pages = 0;
    pmm_state_global.free_pages = 0;

    // Mark 8MB-24MB as free (4,096 pages = 16MB)
    const start_page: usize = 2048;   // 8MB / 4KB
    const end_page: usize = 6144;     // 24MB / 4KB
    pmm_state_global.total_pages = end_page;

    var page: usize = start_page;
    while (page < end_page) : (page += 1) {
        clear_bit(page);
        pmm_state_global.free_pages += 1;
    }

    pmm_initialized = true;
    serial.writeString("PMM initialized\n");
    get_stats();
}

/// Parse Multiboot2 tags
fn parse_multiboot2_tags(info_addr: u32) void {
    serial.writeString("Multiboot2 info at: 0x");
    serial.writeHex(info_addr);
    serial.writeString("\n");

    // For now, skip multiboot2 parsing and use a simple memory layout
    // TODO: Implement full Multiboot2 tag parsing once we fix memory access
    serial.writeString("Using simple memory layout (skip Multiboot2 parsing for now)\n");

    // Assume standard memory layout:
    // 0-1MB: Reserved (BIOS, VGA, etc.)
    // 1MB-5MB: Kernel
    // 5MB-512MB: Free RAM

    // Mark 5MB-128MB as available (conservative)
    mark_region_free(5 * 1024 * 1024, 123 * 1024 * 1024);

    serial.writeString("Memory layout initialized\n");
}

/// Parse memory map tag
fn parse_memory_map(tag_addr: u32) void {
    const tag = @as(*MultibootTag, @ptrFromInt(@as(usize, tag_addr)));
    const entry_size = @as(*u32, @ptrFromInt(@as(usize, tag_addr + 8))).*;
    const entry_version = @as(*u32, @ptrFromInt(@as(usize, tag_addr + 12))).*;

    serial.writeString("Memory map found, entry size: ");
    serial.writeHex(entry_size);
    serial.writeString(", version: ");
    serial.writeHex(entry_version);
    serial.writeString("\n");

    // Entries start after the header (type, size, entry_size, entry_version)
    var entry_addr = tag_addr + 16;
    const end_addr = tag_addr + tag.size;

    while (entry_addr < end_addr) {
        const entry = @as(*MultibootMemoryEntry, @ptrFromInt(@as(usize, entry_addr)));

        serial.writeString("  Memory region: 0x");
        serial.writeHex(@as(u32, @truncate(entry.base_addr)));
        serial.writeString(" - 0x");
        serial.writeHex(@as(u32, @truncate(entry.base_addr + entry.length)));
        serial.writeString(", type: ");
        serial.writeHex(entry.type);
        serial.writeString("\n");

        // Mark available memory as free
        if (entry.type == MEMORY_AVAILABLE) {
            mark_region_free(entry.base_addr, entry.length);
        }

        entry_addr += entry_size;
    }
}

/// Mark a physical memory region as free
fn mark_region_free(base_addr: u64, length: u64) void {
    if (!pmm_initialized) return;

    const page_start = base_addr >> PAGE_SHIFT;
    const page_count = length >> PAGE_SHIFT;

    var i: usize = 0;
    while (i < page_count) : (i += 1) {
        const page = page_start + i;
        if (page < MAX_PAGES) {
            if (is_bit_set(page)) {
                clear_bit(page);
                pmm_state_global.free_pages += 1;
            }
            pmm_state_global.total_pages = @max(pmm_state_global.total_pages, page + 1);
        }
    }
}

/// Mark a physical memory region as used
fn mark_region_used(base_addr: u64, length: u64) void {
    if (!pmm_initialized) return;

    const page_start = base_addr >> PAGE_SHIFT;
    const page_count = length >> PAGE_SHIFT;

    var i: usize = 0;
    while (i < page_count) : (i += 1) {
        const page = page_start + i;
        if (page < MAX_PAGES) {
            if (!is_bit_set(page)) {
                set_bit(page);
                if (pmm_state_global.free_pages > 0) {
                    pmm_state_global.free_pages -= 1;
                }
                pmm_state_global.used_pages += 1;
            }
        }
    }
}

/// Allocate a physical page frame
pub fn alloc_page() ?usize {
    if (!pmm_initialized) return null;

    // Find first free page
    var byte_index: usize = 0;
    while (byte_index < BITMAP_SIZE) : (byte_index += 1) {
        if (pmm_state_global.bitmap[byte_index] != 0xFF) {
            // Found a byte with at least one free page
            var bit_index: u3 = 0;
            while (bit_index < 8) : (bit_index += 1) {
                const mask: u8 = @as(u8, 1) << bit_index;
                if ((pmm_state_global.bitmap[byte_index] & mask) == 0) {
                    // Found free page
                    pmm_state_global.bitmap[byte_index] |= mask;
                    const page = (byte_index * 8) + bit_index;
                    pmm_state_global.free_pages -= 1;
                    pmm_state_global.used_pages += 1;
                    return page << PAGE_SHIFT;
                }
            }
        }
    }

    // Out of memory
    serial.writeString("[PMM] ERROR: Out of physical memory!\n");
    return null;
}

/// Free a physical page frame
pub fn free_page(phys_addr: usize) void {
    if (!pmm_initialized) return;

    const page = phys_addr >> PAGE_SHIFT;

    if (page >= MAX_PAGES) {
        serial.writeString("[PMM] ERROR: Attempt to free invalid page: 0x");
        serial.writeHex(@as(u32, @truncate(phys_addr)));
        serial.writeString("\n");
        return;
    }

    if (is_bit_set(page)) {
        clear_bit(page);
        pmm_state_global.free_pages += 1;
        if (pmm_state_global.used_pages > 0) {
            pmm_state_global.used_pages -= 1;
        }
    }
}

/// Set a bit in the bitmap (mark page as used)
fn set_bit(page: usize) void {
    if (page >= MAX_PAGES) return;
    const byte_index = page / 8;
    const bit_index: u3 = @truncate(page % 8);
    const mask: u8 = @as(u8, 1) << bit_index;
    pmm_state_global.bitmap[byte_index] |= mask;
}

/// Clear a bit in the bitmap (mark page as free)
fn clear_bit(page: usize) void {
    if (page >= MAX_PAGES) return;
    const byte_index = page / 8;
    const bit_index: u3 = @truncate(page % 8);
    const mask: u8 = @as(u8, 1) << bit_index;
    pmm_state_global.bitmap[byte_index] &= ~mask;
}

/// Check if a bit is set (page is used)
fn is_bit_set(page: usize) bool {
    if (page >= MAX_PAGES) return true;
    const byte_index = page / 8;
    const bit_index: u3 = @truncate(page % 8);
    const mask: u8 = @as(u8, 1) << bit_index;
    return (pmm_state_global.bitmap[byte_index] & mask) != 0;
}

/// Get memory statistics
pub fn get_stats() void {
    if (!pmm_initialized) return;

    serial.writeString("\n=== PMM Statistics ===\n");
    serial.writeString("Total: ");
    serial.writeHex(@as(u32, @truncate(pmm_state_global.total_pages)));
    serial.writeString(" pages (");
    serial.writeHex(@as(u32, @truncate((pmm_state_global.total_pages * PAGE_SIZE) / (1024 * 1024))));
    serial.writeString(" MB)\n");

    serial.writeString("Used:  ");
    serial.writeHex(@as(u32, @truncate(pmm_state_global.used_pages)));
    serial.writeString(" pages (");
    serial.writeHex(@as(u32, @truncate((pmm_state_global.used_pages * PAGE_SIZE) / (1024 * 1024))));
    serial.writeString(" MB)\n");

    serial.writeString("Free:  ");
    serial.writeHex(@as(u32, @truncate(pmm_state_global.free_pages)));
    serial.writeString(" pages (");
    serial.writeHex(@as(u32, @truncate((pmm_state_global.free_pages * PAGE_SIZE) / (1024 * 1024))));
    serial.writeString(" MB)\n");
    serial.writeString("======================\n\n");
}
