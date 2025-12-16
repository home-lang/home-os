# home-os Kernel API Reference

This document is auto-generated from exported functions in the kernel source.

## Core APIs

### Foundation - Basic kernel utilities

**File:** `kernel/src/core/foundation.home`

**Functions:**

```c
cli();
sti();
hlt();
outb(port: u16, value: u8);
inb(port: u16): u8;
cpuid(leaf: u32): u32;
rdtsc(): u64;
serial_init();
serial_write_char(c: u8);
serial_write_string(s: u64);
vga_clear();
vga_write_char(c: u8);
vga_write_string(s: u64);
gdt_init();
foundation_init();
```

### Memory - Memory management

**File:** `kernel/src/core/memory.home`

**Functions:**

```c
pmm_init(memory_size: u64);
pmm_alloc_page(): u64;
pmm_free_page(addr: u64);
pmm_get_used_pages(): u32;
pmm_get_free_pages(): u32;
vmm_init();
vmm_map_page(virt: u64, phys: u64, flags: u64): u32;
vmm_unmap_page(virt: u64);
heap_init();
kmalloc(size: u64): u64;
kfree(ptr: u64);
heap_get_stats(total: *u64, used: *u64, free: *u64, largest_free: *u64);
heap_compact();
heap_check(): u32;
krealloc(ptr: u64, new_size: u64): u64;
kcalloc(count: u64, size: u64): u64;
memset(addr: u64, value: u8, size: u64);
memcpy(dst: u64, src: u64, size: u64);
vmm_create_address_space(pid: u32): u64;
vmm_map_page_process(pid: u32, virt: u64, phys: u64, prot: u32): u32;
vmm_unmap_page_process(pid: u32, virt: u64);
vmm_get_physical(pid: u32, virt: u64): u64;
vmm_set_protection(pid: u32, virt: u64, prot: u32);
vmm_set_cow(pid: u32, virt: u64);
vmm_handle_cow(pid: u32, virt: u64): u32;
vmm_switch_address_space(pid: u32);
vmm_free_address_space(pid: u32);
memory_init(memory_size: u64);
```

### Process - Process management

**File:** `kernel/src/core/process.home`

**Functions:**

```c
process_create(entry_point: u64): u32;
process_destroy(pid: u32): u32;
scheduler_init();
scheduler_tick();
sys_fork(): u32;
sys_exec(entry_point: u64): u32;
sys_exit(exit_code: u32);
sys_wait(pid: u32): u32;
sys_getpid(): u32;
process_get_count(): u32;
process_get_info(pid: u32): u64;
process_init();
```

### Filesystem - VFS operations

**File:** `kernel/src/core/filesystem.home`

**Functions:**

```c
dir_add_entry(dir_ino: u32, name: *[u8; 256], name_len: u32, entry_ino: u32): u32;
dir_remove_entry(dir_ino: u32, name: *[u8; 256], name_len: u32): u32;
get_inode_table_ptr(): u64;
get_inode_at_index(idx: u32): u64;
get_inode_count(): u32;
get_max_inodes(): u32;
vfs_open(path: u64, flags: u32): u32;
vfs_close(fd: u32): u32;
vfs_read(fd: u32, buffer: u64, count: u64): u64;
vfs_write(fd: u32, buffer: u64, count: u64): u64;
vfs_lseek(fd: u32, offset: u64, whence: u32): u64;
vfs_mkdir(path: u64, mode: u32): u32;
vfs_rmdir(path: u64): u32;
vfs_chmod(path: u64, mode: u32): u32;
vfs_chown(path: u64, uid: u32, gid: u32): u32;
vfs_set_uid(uid: u32);
vfs_set_gid(gid: u32);
vfs_statfs(path: u64, buf: *StatFS): u32;
vfs_get_mount_count(): u32;
vfs_get_mount_info(index: u32, path: *[u8; 64], device: *[u8; 32],
vfs_readdir(path: u64, entries: *[DirEntryInfo; 256], max_entries: u32): u32;
vfs_get_size(path: u64): u64;
vfs_get_type(path: u64): u32;
vfs_get_tree_size(path: u64): u64;
vfs_pread(fd: u32, buffer: u64, count: u64, offset: u64): u64;
vfs_pwrite(fd: u32, buffer: u64, count: u64, offset: u64): u64;
vfs_get_inode(fd: u32): u32;
filesystem_init();
```

### Syscall - System call interface

**File:** `kernel/src/sys/syscall.home`

**Functions:**

```c
syscall_set_current_pid(pid: u32);
syscall_handler(syscall_num: u32, arg1: u64, arg2: u64, arg3: u64, arg4: u64): u64;
syscall_tick_time(ns_elapsed: u64);
syscall_set_time(sec: u64, usec: u64);
syscall_init();
io_uring_prep_read(ring_id: u32, fd: u32, buffer: u64, size: u32, offset: u64, user_data: u64): u32;
io_uring_prep_write(ring_id: u32, fd: u32, buffer: u64, size: u32, offset: u64, user_data: u64): u32;
io_uring_prep_fsync(ring_id: u32, fd: u32, user_data: u64): u32;
io_uring_wait_cqe(ring_id: u32, user_data_out: u64, result_out: u64): u32;
```

### Signal - Signal handling

**File:** `kernel/src/sys/signal.home`

**Functions:**

```c
signal_init();
signal_set_handler(pid: u32, signum: u32, handler: u64, flags: u32, mask: u64): u32;
signal_get_handler(pid: u32, signum: u32): u64;
signal_block(pid: u32, mask: u64): u64;
signal_unblock(pid: u32, mask: u64): u64;
signal_setmask(pid: u32, mask: u64): u64;
signal_pending(pid: u32): u64;
signal_send(target_pid: u32, signum: u32, sender_pid: u32): u32;
signal_send_info(target_pid: u32, signum: u32, code: u32, value: u64): u32;
signal_deliver(pid: u32): u32;
signal_return(pid: u32);
signal_fork(parent_pid: u32, child_pid: u32);
signal_exec(pid: u32);
signal_exit(pid: u32);
signal_send_group(pgid: u32, signum: u32, sender_pid: u32): u32;
signal_send_all(signum: u32, sender_pid: u32): u32;
signal_wait(pid: u32, mask: u64): u32;
signal_get_stats(sent: *u64, delivered: *u64, ignored: *u64);
```

