# File System Support

HomeOS supports 10 different file systems, including both native disk formats and virtual file systems for system information.

## Supported File Systems

| File System | Type | Read | Write | Description |
|-------------|------|------|-------|-------------|
| FAT32 | Disk | Yes | Yes | Windows-compatible, SD cards |
| ext2 | Disk | Yes | Yes | Linux native file system |
| NTFS | Disk | Yes | Yes | Windows NT file system |
| Btrfs | Disk | Yes | Yes | Copy-on-write, snapshots |
| exFAT | Disk | Yes | Yes | Large files, flash drives |
| ISO9660 | Disk | Yes | No | CD/DVD file system |
| procfs | Virtual | Yes | No | Process information |
| sysfs | Virtual | Yes | Partial | System/device information |
| tmpfs | Virtual | Yes | Yes | RAM-based temporary storage |
| devfs | Virtual | Yes | No | Device nodes |

## Native File Systems

### FAT32

The FAT32 driver provides compatibility with Windows and SD cards, making it ideal for Raspberry Pi boot partitions.

**Features:**
- Long filename support (LFN)
- 4GB maximum file size
- 2TB maximum volume size
- Subdirectory support

**Location:** `kernel/src/fs/fat32.home`

**Usage:**
```home
let result = fat32_mount("/dev/sda1", "/mnt/sdcard")
let file = fat32_open("/mnt/sdcard/data.txt", O_RDONLY)
fat32_read(file, buffer, size)
fat32_close(file)
```

### ext2

The ext2 driver provides native Linux file system support with full POSIX semantics.

**Features:**
- Inodes and block groups
- File permissions (rwx)
- Symbolic and hard links
- Large file support

**Location:** `kernel/src/fs/ext2.home`

### NTFS

The NTFS driver enables reading and writing Windows partitions.

**Features:**
- MFT (Master File Table) parsing
- Compressed file support
- Large file support (16 EB)
- Unicode filenames

**Location:** `kernel/src/fs/ntfs.home`

### Btrfs

The Btrfs driver provides modern copy-on-write semantics.

**Features:**
- Copy-on-write (CoW)
- Snapshots
- Checksums for data integrity
- Subvolumes

**Location:** `kernel/src/fs/btrfs.home`

### exFAT

The exFAT driver is optimized for flash storage with large files.

**Features:**
- No 4GB file size limit
- Optimized for flash memory
- Wide compatibility

**Location:** `kernel/src/fs/exfat.home`

### ISO9660

The ISO9660 driver provides CD/DVD read support.

**Features:**
- Rock Ridge extensions
- Joliet extensions
- Multi-session support

**Location:** `kernel/src/fs/iso9660.home`

## Virtual File Systems

### procfs

The procfs provides a file-based interface to process and kernel information.

**Mount point:** `/proc`

**Key files:**
```
/proc/
├── [pid]/              # Per-process directories
│   ├── cmdline         # Command line arguments
│   ├── cwd             # Current working directory
│   ├── environ         # Environment variables
│   ├── exe             # Executable path
│   ├── fd/             # File descriptors
│   ├── maps            # Memory maps
│   ├── stat            # Process status
│   └── status          # Human-readable status
├── cpuinfo             # CPU information
├── meminfo             # Memory information
├── uptime              # System uptime
├── version             # Kernel version
├── mounts              # Mounted file systems
└── interrupts          # Interrupt statistics
```

**Location:** `kernel/src/fs/procfs.home`

### sysfs

The sysfs exports kernel object information in a hierarchical structure.

**Mount point:** `/sys`

**Structure:**
```
/sys/
├── block/              # Block devices
├── bus/                # System buses
│   ├── pci/
│   ├── usb/
│   └── i2c/
├── class/              # Device classes
│   ├── net/
│   ├── input/
│   └── block/
├── devices/            # Device hierarchy
├── firmware/           # Firmware interfaces
├── fs/                 # File system info
├── kernel/             # Kernel parameters
└── power/              # Power management
```

**Location:** `kernel/src/fs/sysfs.home`

### tmpfs

The tmpfs provides a RAM-based file system for temporary files.

**Features:**
- Fast read/write (no disk I/O)
- Automatic size management
- Lost on reboot
- Ideal for `/tmp` and `/run`

**Location:** `kernel/src/fs/tmpfs.home`

**Mount options:**
```bash
mount -t tmpfs -o size=100M tmpfs /tmp
```

### devfs

The devfs provides device node access.

**Mount point:** `/dev`

**Key devices:**
```
/dev/
├── null                # Null device
├── zero                # Zero device
├── random              # Random number generator
├── urandom             # Non-blocking random
├── console             # System console
├── tty                 # Current terminal
├── tty[0-9]            # Virtual terminals
├── sda, sda1, ...      # SATA/SCSI disks
├── mmcblk0, mmcblk0p1  # SD/MMC devices
├── nvme0n1             # NVMe devices
├── fb0                 # Framebuffer
├── input/              # Input devices
│   ├── mice
│   ├── mouse0
│   └── event0
└── net/                # Network devices
    └── tun
```

**Location:** `kernel/src/fs/devfs.home`

## Virtual File System (VFS) Layer

The VFS provides a unified interface for all file systems.

### Architecture

```
┌─────────────────────────────────────┐
│         System Calls                │
│  (open, read, write, close, etc.)   │
├─────────────────────────────────────┤
│             VFS Layer               │
│  - Path resolution                  │
│  - Mount management                 │
│  - Inode caching                    │
│  - Buffer cache                     │
├─────────────────────────────────────┤
│  FAT32 │ ext2 │ NTFS │ procfs │ ... │
├─────────────────────────────────────┤
│         Block I/O Layer             │
├─────────────────────────────────────┤
│  ATA │ AHCI │ NVMe │ SD/MMC │ RAM   │
└─────────────────────────────────────┘
```

### VFS Operations

Each file system implements these operations:

```home
struct FileSystemOps {
  mount: fn(device: *u8, mountpoint: *u8) -> i32
  umount: fn(mountpoint: *u8) -> i32
  open: fn(path: *u8, flags: u32) -> i32
  close: fn(fd: i32) -> i32
  read: fn(fd: i32, buf: *u8, count: u32) -> i32
  write: fn(fd: i32, buf: *u8, count: u32) -> i32
  lseek: fn(fd: i32, offset: i64, whence: i32) -> i64
  stat: fn(path: *u8, buf: *Stat) -> i32
  mkdir: fn(path: *u8, mode: u32) -> i32
  rmdir: fn(path: *u8) -> i32
  unlink: fn(path: *u8) -> i32
  readdir: fn(fd: i32, entry: *DirEntry) -> i32
}
```

### VFS Features

- **Path Resolution** - Handles `.`, `..`, symlinks
- **Mount Points** - Overlay file systems
- **Inode Cache** - LRU caching for metadata
- **Buffer Cache** - Page cache for file data
- **File Locking** - POSIX advisory locks
- **Extended Attributes** - xattr support
- **Hard Links** - Multiple names for same file
- **Symbolic Links** - Path-based references

**Location:** `kernel/src/core/vfs_*.home`

## File Operations API

### Opening Files

```home
// Open flags
const O_RDONLY: u32 = 0x0000    // Read only
const O_WRONLY: u32 = 0x0001    // Write only
const O_RDWR: u32 = 0x0002      // Read and write
const O_CREAT: u32 = 0x0100     // Create if not exists
const O_TRUNC: u32 = 0x0200     // Truncate to zero
const O_APPEND: u32 = 0x0400    // Append mode

let fd = open("/path/to/file", O_RDWR | O_CREAT, 0o644)
```

### Reading and Writing

```home
let bytes_read = read(fd, buffer, buffer_size)
let bytes_written = write(fd, data, data_size)
```

### Seeking

```home
const SEEK_SET: i32 = 0  // From beginning
const SEEK_CUR: i32 = 1  // From current position
const SEEK_END: i32 = 2  // From end

let position = lseek(fd, offset, SEEK_SET)
```

### File Information

```home
struct Stat {
  st_dev: u64      // Device ID
  st_ino: u64      // Inode number
  st_mode: u32     // File mode
  st_nlink: u32    // Number of hard links
  st_uid: u32      // Owner user ID
  st_gid: u32      // Owner group ID
  st_size: i64     // File size
  st_atime: i64    // Last access time
  st_mtime: i64    // Last modification time
  st_ctime: i64    // Last status change time
}

let result = stat("/path/to/file", &stat_buf)
```

### Directory Operations

```home
// Create directory
mkdir("/path/to/dir", 0o755)

// Remove directory
rmdir("/path/to/dir")

// Read directory entries
let dir_fd = open("/path/to/dir", O_RDONLY | O_DIRECTORY)
while readdir(dir_fd, &entry) > 0 {
  // Process entry.name
}
close(dir_fd)
```

## Mounting File Systems

```bash
# Mount FAT32 partition
mount -t fat32 /dev/mmcblk0p1 /boot

# Mount ext2 partition
mount -t ext2 /dev/sda1 /home

# Mount tmpfs
mount -t tmpfs -o size=256M tmpfs /tmp

# List mounts
cat /proc/mounts
```

## Performance Optimization

### Buffer Cache

HomeOS uses a page cache for file data:
- LRU eviction policy
- Write-back caching
- Read-ahead for sequential access

### Inode Hash Table

Fast inode lookup using hash table:
- O(1) average lookup
- Caches recently used inodes

### Asynchronous I/O

HomeOS supports asynchronous file operations:
- io_uring-like interface
- Non-blocking reads/writes
- Completion notifications

## Related Documentation

- [Driver Reference](/guide/drivers) - Storage drivers
- [Architecture](/guide/architecture) - VFS integration
- [System Calls](/api/syscalls) - File-related syscalls
