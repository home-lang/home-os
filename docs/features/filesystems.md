# File Systems

HomeOS implements a comprehensive Virtual File System (VFS) layer that provides a unified interface to multiple file system implementations. Built entirely in the Home programming language, the file system subsystem supports ext4, FAT32, and a custom HomeFS designed specifically for HomeOS.

## Overview

The file system architecture in HomeOS consists of:

- **Virtual File System (VFS)**: Abstraction layer providing unified file operations
- **File System Drivers**: Implementations for specific file systems (ext4, FAT32, HomeFS)
- **Block Device Layer**: Interface to storage hardware
- **Buffer Cache**: In-memory caching of disk blocks
- **Inode Cache**: Caching of file metadata

## Virtual File System

The VFS provides a common interface for all file operations regardless of the underlying file system.

### VFS Data Structures

```home
// File system type registration
const FileSystemType = struct {
    name: [32]u8,
    mount: fn (*SuperBlock, *BlockDevice, []const u8) i32,
    unmount: fn (*SuperBlock) i32,
    next: ?*FileSystemType
}

// Superblock represents a mounted file system
const SuperBlock = struct {
    fs_type: *FileSystemType,
    device: *BlockDevice,
    block_size: u32,
    root_inode: *Inode,
    mount_point: [256]u8,
    flags: u32,
    fs_private: *anyopaque,
    inodes: InodeCache,
    dirty: bool
}

// Inode represents a file or directory
const Inode = struct {
    number: u64,
    mode: u16,
    uid: u32,
    gid: u32,
    size: u64,
    atime: u64,
    mtime: u64,
    ctime: u64,
    links_count: u32,
    blocks: u64,
    flags: u32,
    superblock: *SuperBlock,
    ops: *InodeOperations,
    private_data: *anyopaque,
    ref_count: u32
}

// File represents an open file
const File = struct {
    inode: *Inode,
    position: u64,
    flags: u32,
    ops: *FileOperations,
    private_data: *anyopaque
}

// Directory entry
const DirEntry = struct {
    inode_number: u64,
    name: [256]u8,
    name_len: u8,
    file_type: u8
}
```

### VFS Operations

```home
// Inode operations
const InodeOperations = struct {
    lookup: fn (*Inode, []const u8) ?*Inode,
    create: fn (*Inode, []const u8, u16) ?*Inode,
    mkdir: fn (*Inode, []const u8, u16) ?*Inode,
    rmdir: fn (*Inode, []const u8) i32,
    unlink: fn (*Inode, []const u8) i32,
    rename: fn (*Inode, []const u8, *Inode, []const u8) i32,
    readlink: fn (*Inode, []u8) isize,
    symlink: fn (*Inode, []const u8, []const u8) i32,
    truncate: fn (*Inode, u64) i32,
    getattr: fn (*Inode, *Stat) i32,
    setattr: fn (*Inode, *Stat) i32
}

// File operations
const FileOperations = struct {
    open: fn (*Inode, *File) i32,
    close: fn (*File) i32,
    read: fn (*File, []u8) isize,
    write: fn (*File, []const u8) isize,
    seek: fn (*File, i64, SeekWhence) i64,
    readdir: fn (*File, *DirEntry) i32,
    ioctl: fn (*File, u32, usize) i32,
    mmap: fn (*File, *VMA) i32,
    fsync: fn (*File) i32
}

const SeekWhence = enum {
    Set,
    Current,
    End
}
```

### Path Resolution

```home
import kernel/memory

export fn path_lookup(path: []const u8): ?*Inode {
    if path.len == 0 {
        return null
    }

    // Start from root or current directory
    let current = if path[0] == '/' {
        get_root_inode()
    } else {
        get_current_process().current_dir
    }

    if current == null {
        return null
    }

    // Parse path components
    let start: usize = 0
    if path[0] == '/' {
        start = 1
    }

    let i = start
    while i < path.len {
        // Find end of component
        let end = i
        while end < path.len and path[end] != '/' {
            end += 1
        }

        if end == i {
            i += 1
            continue
        }

        let component = path[i..end]

        // Handle special entries
        if mem_equal(component, ".") {
            // Stay in current directory
        } else if mem_equal(component, "..") {
            // Go to parent
            current = get_parent_inode(current) ?? current
        } else {
            // Look up component in current directory
            if current.ops.lookup == null {
                return null
            }
            let next = current.ops.lookup(current, component)
            if next == null {
                return null
            }
            inode_put(current)
            current = next
        }

        i = end + 1
    }

    return current
}

fn get_parent_inode(inode: *Inode): ?*Inode {
    return inode.ops.lookup(inode, "..")
}
```

### System Calls

```home
export fn sys_open(path: []const u8, flags: u32, mode: u16): i32 {
    let proc = get_current_process()

    // Resolve path
    let inode = path_lookup(path)

    // Handle O_CREAT
    if inode == null and (flags & O_CREAT) != 0 {
        // Get parent directory
        let parent_path = dirname(path)
        let name = basename(path)

        let parent = path_lookup(parent_path)
        if parent == null {
            return -ENOENT
        }

        inode = parent.ops.create(parent, name, mode)
        inode_put(parent)

        if inode == null {
            return -EIO
        }
    }

    if inode == null {
        return -ENOENT
    }

    // Check permissions
    if !check_permission(inode, flags) {
        inode_put(inode)
        return -EACCES
    }

    // Allocate file descriptor
    let fd = allocate_fd(proc)
    if fd < 0 {
        inode_put(inode)
        return -EMFILE
    }

    // Create file structure
    let file = memory.allocate(File)
    if file == null {
        free_fd(proc, fd)
        inode_put(inode)
        return -ENOMEM
    }

    file.* = File{
        .inode = inode,
        .position = 0,
        .flags = flags,
        .ops = inode.superblock.fs_type.file_ops,
        .private_data = null
    }

    // Handle O_TRUNC
    if (flags & O_TRUNC) != 0 and (flags & O_WRONLY or flags & O_RDWR) != 0 {
        inode.ops.truncate(inode, 0)
    }

    // Handle O_APPEND
    if (flags & O_APPEND) != 0 {
        file.position = inode.size
    }

    // Call file system open
    if file.ops.open != null {
        let result = file.ops.open(inode, file)
        if result < 0 {
            memory.free(file)
            free_fd(proc, fd)
            inode_put(inode)
            return result
        }
    }

    proc.open_files[fd] = file
    return fd
}

export fn sys_read(fd: i32, buf: []u8): isize {
    let proc = get_current_process()

    if fd < 0 or fd >= 256 {
        return -EBADF
    }

    let file = proc.open_files[fd]
    if file == null {
        return -EBADF
    }

    if file.ops.read == null {
        return -EINVAL
    }

    return file.ops.read(file, buf)
}

export fn sys_write(fd: i32, buf: []const u8): isize {
    let proc = get_current_process()

    if fd < 0 or fd >= 256 {
        return -EBADF
    }

    let file = proc.open_files[fd]
    if file == null {
        return -EBADF
    }

    if file.ops.write == null {
        return -EINVAL
    }

    return file.ops.write(file, buf)
}

export fn sys_close(fd: i32): i32 {
    let proc = get_current_process()

    if fd < 0 or fd >= 256 {
        return -EBADF
    }

    let file = proc.open_files[fd]
    if file == null {
        return -EBADF
    }

    // Call file system close
    if file.ops.close != null {
        file.ops.close(file)
    }

    // Release inode
    inode_put(file.inode)

    // Free file structure
    memory.free(file)
    proc.open_files[fd] = null

    return 0
}
```

## Buffer Cache

The buffer cache stores recently accessed disk blocks in memory.

```home
const BUFFER_CACHE_SIZE = 4096

const Buffer = struct {
    device: *BlockDevice,
    block_number: u64,
    data: [4096]u8,
    dirty: bool,
    valid: bool,
    ref_count: u32,
    hash_next: ?*Buffer,
    lru_prev: ?*Buffer,
    lru_next: ?*Buffer
}

// Hash table for quick lookup
let buffer_hash: [256]?*Buffer = undefined

// LRU list for eviction
let lru_head: ?*Buffer = null
let lru_tail: ?*Buffer = null

export fn buffer_cache_init() {
    for i in 0..256 {
        buffer_hash[i] = null
    }
}

fn hash_block(device: *BlockDevice, block: u64): usize {
    return (@intFromPtr(device) ^ block) % 256
}

export fn get_buffer(device: *BlockDevice, block: u64): *Buffer {
    let hash = hash_block(device, block)

    // Check hash table
    let buf = buffer_hash[hash]
    while buf != null {
        if buf.device == device and buf.block_number == block {
            buf.ref_count += 1
            remove_from_lru(buf)
            return buf
        }
        buf = buf.hash_next
    }

    // Not in cache, allocate or recycle
    buf = allocate_buffer()

    buf.device = device
    buf.block_number = block
    buf.valid = false
    buf.dirty = false
    buf.ref_count = 1

    // Add to hash table
    buf.hash_next = buffer_hash[hash]
    buffer_hash[hash] = buf

    return buf
}

export fn read_buffer(device: *BlockDevice, block: u64): *Buffer {
    let buf = get_buffer(device, block)

    if !buf.valid {
        // Read from disk
        device.read_blocks(block, 1, &buf.data)
        buf.valid = true
    }

    return buf
}

export fn write_buffer(buf: *Buffer) {
    buf.dirty = true
}

export fn release_buffer(buf: *Buffer) {
    buf.ref_count -= 1

    if buf.ref_count == 0 {
        add_to_lru(buf)
    }
}

export fn sync_buffer(buf: *Buffer) {
    if buf.dirty {
        buf.device.write_blocks(buf.block_number, 1, &buf.data)
        buf.dirty = false
    }
}

fn allocate_buffer(): *Buffer {
    // Try to recycle from LRU
    if lru_tail != null {
        let buf = lru_tail
        remove_from_lru(buf)

        // Write back if dirty
        if buf.dirty {
            sync_buffer(buf)
        }

        // Remove from old hash chain
        remove_from_hash(buf)

        return buf
    }

    // Allocate new buffer
    return memory.allocate(Buffer) ?? kernel_panic("Out of buffer cache memory")
}

fn add_to_lru(buf: *Buffer) {
    buf.lru_next = lru_head
    buf.lru_prev = null

    if lru_head != null {
        lru_head.lru_prev = buf
    }
    lru_head = buf

    if lru_tail == null {
        lru_tail = buf
    }
}

fn remove_from_lru(buf: *Buffer) {
    if buf.lru_prev != null {
        buf.lru_prev.lru_next = buf.lru_next
    } else {
        lru_head = buf.lru_next
    }

    if buf.lru_next != null {
        buf.lru_next.lru_prev = buf.lru_prev
    } else {
        lru_tail = buf.lru_prev
    }
}
```

## Ext4 File System

HomeOS includes a full ext4 implementation.

### Ext4 Structures

```home
const EXT4_SUPER_MAGIC = 0xEF53

const Ext4SuperBlock = packed struct {
    inodes_count: u32,
    blocks_count_lo: u32,
    r_blocks_count_lo: u32,
    free_blocks_count_lo: u32,
    free_inodes_count: u32,
    first_data_block: u32,
    log_block_size: u32,
    log_cluster_size: u32,
    blocks_per_group: u32,
    clusters_per_group: u32,
    inodes_per_group: u32,
    mtime: u32,
    wtime: u32,
    mnt_count: u16,
    max_mnt_count: u16,
    magic: u16,
    state: u16,
    errors: u16,
    minor_rev_level: u16,
    lastcheck: u32,
    checkinterval: u32,
    creator_os: u32,
    rev_level: u32,
    def_resuid: u16,
    def_resgid: u16,
    first_ino: u32,
    inode_size: u16,
    block_group_nr: u16,
    feature_compat: u32,
    feature_incompat: u32,
    feature_ro_compat: u32,
    uuid: [16]u8,
    volume_name: [16]u8
    // ... additional fields
}

const Ext4Inode = packed struct {
    mode: u16,
    uid: u16,
    size_lo: u32,
    atime: u32,
    ctime: u32,
    mtime: u32,
    dtime: u32,
    gid: u16,
    links_count: u16,
    blocks_lo: u32,
    flags: u32,
    osd1: u32,
    block: [60]u8,  // Extent tree or block pointers
    generation: u32,
    file_acl_lo: u32,
    size_high: u32,
    obso_faddr: u32,
    osd2: [12]u8,
    extra_isize: u16,
    checksum_hi: u16,
    ctime_extra: u32,
    mtime_extra: u32,
    atime_extra: u32,
    crtime: u32,
    crtime_extra: u32,
    version_hi: u32,
    projid: u32
}

const Ext4Extent = packed struct {
    block: u32,
    len: u16,
    start_hi: u16,
    start_lo: u32
}

const Ext4ExtentHeader = packed struct {
    magic: u16,
    entries: u16,
    max: u16,
    depth: u16,
    generation: u32
}
```

### Ext4 Implementation

```home
const Ext4FS = struct {
    sb: *SuperBlock,
    ext4_sb: *Ext4SuperBlock,
    block_size: u32,
    inodes_per_block: u32,
    groups_count: u32
}

export fn ext4_mount(sb: *SuperBlock, device: *BlockDevice, options: []const u8): i32 {
    // Read superblock from block 1
    let buf = read_buffer(device, 1)
    let ext4_sb: *Ext4SuperBlock = @ptrCast(&buf.data)

    // Verify magic number
    if ext4_sb.magic != EXT4_SUPER_MAGIC {
        release_buffer(buf)
        return -EINVAL
    }

    // Allocate file system state
    let fs = memory.allocate(Ext4FS) ?? return -ENOMEM

    fs.sb = sb
    fs.ext4_sb = memory.allocate(Ext4SuperBlock) ?? {
        memory.free(fs)
        return -ENOMEM
    }

    // Copy superblock
    @memcpy(fs.ext4_sb, ext4_sb, @sizeOf(Ext4SuperBlock))
    release_buffer(buf)

    // Calculate derived values
    fs.block_size = 1024 << fs.ext4_sb.log_block_size
    fs.inodes_per_block = fs.block_size / fs.ext4_sb.inode_size
    fs.groups_count = (fs.ext4_sb.blocks_count_lo + fs.ext4_sb.blocks_per_group - 1) / fs.ext4_sb.blocks_per_group

    sb.block_size = fs.block_size
    sb.fs_private = fs

    // Read root inode (inode 2)
    sb.root_inode = ext4_read_inode(fs, 2) ?? return -EIO

    return 0
}

fn ext4_read_inode(fs: *Ext4FS, ino: u64): ?*Inode {
    // Calculate block group and offset
    let group = (ino - 1) / fs.ext4_sb.inodes_per_group
    let index = (ino - 1) % fs.ext4_sb.inodes_per_group

    // Read group descriptor
    let gd_block = fs.ext4_sb.first_data_block + 1 + group / (fs.block_size / 32)
    let gd_buf = read_buffer(fs.sb.device, gd_block)
    let gd: *Ext4GroupDesc = @ptrCast(&gd_buf.data[(group % (fs.block_size / 32)) * 32])

    let inode_table = gd.inode_table_lo
    release_buffer(gd_buf)

    // Read inode
    let inode_block = inode_table + (index * fs.ext4_sb.inode_size) / fs.block_size
    let inode_offset = (index * fs.ext4_sb.inode_size) % fs.block_size

    let ino_buf = read_buffer(fs.sb.device, inode_block)
    let ext4_inode: *Ext4Inode = @ptrCast(&ino_buf.data[inode_offset])

    // Create VFS inode
    let inode = memory.allocate(Inode) ?? {
        release_buffer(ino_buf)
        return null
    }

    inode.number = ino
    inode.mode = ext4_inode.mode
    inode.uid = ext4_inode.uid
    inode.gid = ext4_inode.gid
    inode.size = ext4_inode.size_lo | (@as(u64, ext4_inode.size_high) << 32)
    inode.atime = ext4_inode.atime
    inode.mtime = ext4_inode.mtime
    inode.ctime = ext4_inode.ctime
    inode.links_count = ext4_inode.links_count
    inode.superblock = fs.sb
    inode.ops = &ext4_inode_ops
    inode.ref_count = 1

    // Store ext4-specific data
    let private = memory.allocate(Ext4InodePrivate)
    private.ext4_inode = memory.allocate(Ext4Inode)
    @memcpy(private.ext4_inode, ext4_inode, fs.ext4_sb.inode_size)
    inode.private_data = private

    release_buffer(ino_buf)
    return inode
}

fn ext4_read_file(file: *File, buf: []u8): isize {
    let inode = file.inode
    let fs: *Ext4FS = @ptrCast(inode.superblock.fs_private)
    let private: *Ext4InodePrivate = @ptrCast(inode.private_data)

    let to_read = @min(buf.len, inode.size - file.position)
    if to_read == 0 {
        return 0
    }

    let bytes_read: usize = 0

    while bytes_read < to_read {
        let block_offset = file.position / fs.block_size
        let offset_in_block = file.position % fs.block_size

        // Get physical block using extent tree
        let phys_block = ext4_extent_to_block(private, block_offset) ?? break

        let block_buf = read_buffer(inode.superblock.device, phys_block)
        let copy_size = @min(fs.block_size - offset_in_block, to_read - bytes_read)

        @memcpy(&buf[bytes_read], &block_buf.data[offset_in_block], copy_size)
        release_buffer(block_buf)

        bytes_read += copy_size
        file.position += copy_size
    }

    return bytes_read
}
```

## FAT32 File System

HomeOS also supports FAT32 for compatibility.

```home
const FAT32_SIGNATURE = 0xAA55

const Fat32BootSector = packed struct {
    jump: [3]u8,
    oem_name: [8]u8,
    bytes_per_sector: u16,
    sectors_per_cluster: u8,
    reserved_sectors: u16,
    num_fats: u8,
    root_entry_count: u16,
    total_sectors_16: u16,
    media_type: u8,
    fat_size_16: u16,
    sectors_per_track: u16,
    num_heads: u16,
    hidden_sectors: u32,
    total_sectors_32: u32,
    fat_size_32: u32,
    ext_flags: u16,
    fs_version: u16,
    root_cluster: u32,
    fs_info: u16,
    backup_boot_sector: u16,
    reserved: [12]u8,
    drive_number: u8,
    reserved1: u8,
    boot_sig: u8,
    volume_id: u32,
    volume_label: [11]u8,
    fs_type: [8]u8
}

const Fat32DirEntry = packed struct {
    name: [11]u8,
    attributes: u8,
    reserved: u8,
    create_time_tenth: u8,
    create_time: u16,
    create_date: u16,
    access_date: u16,
    cluster_high: u16,
    modify_time: u16,
    modify_date: u16,
    cluster_low: u16,
    file_size: u32
}

const FAT_ATTR_READ_ONLY = 0x01
const FAT_ATTR_HIDDEN = 0x02
const FAT_ATTR_SYSTEM = 0x04
const FAT_ATTR_VOLUME_ID = 0x08
const FAT_ATTR_DIRECTORY = 0x10
const FAT_ATTR_ARCHIVE = 0x20
const FAT_ATTR_LONG_NAME = 0x0F

export fn fat32_mount(sb: *SuperBlock, device: *BlockDevice, options: []const u8): i32 {
    // Read boot sector
    let buf = read_buffer(device, 0)
    let boot: *Fat32BootSector = @ptrCast(&buf.data)

    // Verify signature
    if buf.data[510] != 0x55 or buf.data[511] != 0xAA {
        release_buffer(buf)
        return -EINVAL
    }

    let fs = memory.allocate(Fat32FS) ?? return -ENOMEM

    fs.bytes_per_sector = boot.bytes_per_sector
    fs.sectors_per_cluster = boot.sectors_per_cluster
    fs.reserved_sectors = boot.reserved_sectors
    fs.num_fats = boot.num_fats
    fs.fat_size = boot.fat_size_32
    fs.root_cluster = boot.root_cluster
    fs.total_sectors = boot.total_sectors_32

    // Calculate first data sector
    fs.first_data_sector = fs.reserved_sectors + (fs.num_fats * fs.fat_size)

    release_buffer(buf)

    sb.block_size = fs.bytes_per_sector * fs.sectors_per_cluster
    sb.fs_private = fs

    // Create root inode
    sb.root_inode = fat32_create_inode(fs, fs.root_cluster, FAT_ATTR_DIRECTORY, 0)

    return 0
}

fn fat32_read_fat(fs: *Fat32FS, cluster: u32): u32 {
    let fat_offset = cluster * 4
    let fat_sector = fs.reserved_sectors + (fat_offset / fs.bytes_per_sector)
    let entry_offset = fat_offset % fs.bytes_per_sector

    let buf = read_buffer(fs.sb.device, fat_sector)
    let value: *u32 = @ptrCast(&buf.data[entry_offset])
    let result = value.* & 0x0FFFFFFF
    release_buffer(buf)

    return result
}

fn fat32_cluster_to_sector(fs: *Fat32FS, cluster: u32): u32 {
    return fs.first_data_sector + (cluster - 2) * fs.sectors_per_cluster
}
```

## Summary

HomeOS file system support includes:

- **Virtual File System**: Unified interface for all file systems
- **Buffer Cache**: Efficient disk block caching with LRU eviction
- **Path Resolution**: Full path parsing with symbolic link support
- **ext4 Support**: Complete implementation with extent trees
- **FAT32 Support**: Compatibility with external drives and boot partitions
- **System Calls**: POSIX-compatible file operations

All file system code is implemented in the Home programming language, with packed structs ensuring correct on-disk structure representation.
