.section .text
.global kernel_main

    movq $0, %rax
    # Load variable x36d76289
    movq $0, %rax
    # Load variable x3F8
    movq $0, %rax
    # Load variable xB8000
    movq $4096, %rax
    movq $256, %rax
    movq $1024, %rax
    movq $64, %rax
    movq $1024, %rax
    movq $65536, %rax
    movq $64, %rax
    movq $4096, %rax
    movq $1, %rax
    movq $2, %rax
    movq $3, %rax
    movq $4, %rax
    movq $5, %rax
    movq $6, %rax
    movq $4, %rax
    movq $2, %rax
    movq $1, %rax
    movq $0, %rax
    movq $1, %rax
    movq $2, %rax
    movq $64, %rax
    movq $512, %rax
    movq $1024, %rax
    movq $0, %rax
    movq $1, %rax
    movq $2, %rax
    movq $3, %rax
    movq $4, %rax
    movq $5, %rax
    movq $6, %rax
    movq $7, %rax
    movq $8, %rax
    movq $9, %rax
    movq $10, %rax
    movq $11, %rax
    movq $12, %rax
    movq $13, %rax
    movq $14, %rax
    movq $15, %rax
    movq $16, %rax
    movq $17, %rax
    movq $18, %rax
    movq $19, %rax
cli:
    pushq %rbp
    movq %rsp, %rbp
    cli
    movq %rbp, %rsp
    popq %rbp
    ret

sti:
    pushq %rbp
    movq %rsp, %rbp
    sti
    movq %rbp, %rsp
    popq %rbp
    ret

hlt:
    pushq %rbp
    movq %rsp, %rbp
    hlt
    movq %rbp, %rsp
    popq %rbp
    ret

outb:
    pushq %rbp
    movq %rsp, %rbp
    # outb
    movq %rbp, %rsp
    popq %rbp
    ret

inb:
    pushq %rbp
    movq %rsp, %rbp
    # inb
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

cpuid:
    pushq %rbp
    movq %rsp, %rbp
    # cpuid
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

rdtsc:
    pushq %rbp
    movq %rsp, %rbp
    # rdtsc
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

    movq $1, %rax
inode_create:
    pushq %rbp
    movq %rsp, %rbp
    # Create new inode
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

inode_destroy:
    pushq %rbp
    movq %rsp, %rbp
    # Destroy inode
    movq %rbp, %rsp
    popq %rbp
    ret

inode_read:
    pushq %rbp
    movq %rsp, %rbp
    # Read from inode
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

inode_write:
    pushq %rbp
    movq %rsp, %rbp
    # Write to inode
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

inode_get_size:
    pushq %rbp
    movq %rsp, %rbp
    # Get inode size
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

inode_set_size:
    pushq %rbp
    movq %rsp, %rbp
    # Set inode size
    movq %rbp, %rsp
    popq %rbp
    ret

inode_get_type:
    pushq %rbp
    movq %rsp, %rbp
    # Get inode type
    # Load variable FILE_TYPE_REGULAR
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

inode_get_mode:
    pushq %rbp
    movq %rsp, %rbp
    # Get inode permissions
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

inode_set_mode:
    pushq %rbp
    movq %rsp, %rbp
    # Set inode permissions
    movq %rbp, %rsp
    popq %rbp
    ret

dentry_create:
    pushq %rbp
    movq %rsp, %rbp
    # Create directory entry
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

dentry_lookup:
    pushq %rbp
    movq %rsp, %rbp
    # Lookup directory entry
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

dentry_add:
    pushq %rbp
    movq %rsp, %rbp
    # Add dentry to parent
    movq %rbp, %rsp
    popq %rbp
    ret

dentry_remove:
    pushq %rbp
    movq %rsp, %rbp
    # Remove dentry from parent
    movq %rbp, %rsp
    popq %rbp
    ret

dentry_cache_add:
    pushq %rbp
    movq %rsp, %rbp
    # Add dentry to cache
    movq %rbp, %rsp
    popq %rbp
    ret

dentry_cache_lookup:
    pushq %rbp
    movq %rsp, %rbp
    # Lookup dentry in cache
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

vfs_open:
    pushq %rbp
    movq %rsp, %rbp
    # Open file
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

vfs_close:
    pushq %rbp
    movq %rsp, %rbp
    # Close file
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

vfs_read:
    pushq %rbp
    movq %rsp, %rbp
    # Read from file
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

vfs_write:
    pushq %rbp
    movq %rsp, %rbp
    # Write to file
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

vfs_seek:
    pushq %rbp
    movq %rsp, %rbp
    # Seek in file
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

vfs_stat:
    pushq %rbp
    movq %rsp, %rbp
    # Get file status
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

vfs_mkdir:
    pushq %rbp
    movq %rsp, %rbp
    # Create directory
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

vfs_rmdir:
    pushq %rbp
    movq %rsp, %rbp
    # Remove directory
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

vfs_unlink:
    pushq %rbp
    movq %rsp, %rbp
    # Delete file
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

vfs_rename:
    pushq %rbp
    movq %rsp, %rbp
    # Rename file
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

vfs_chmod:
    pushq %rbp
    movq %rsp, %rbp
    # Change file permissions
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

vfs_chown:
    pushq %rbp
    movq %rsp, %rbp
    # Change file ownership
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

superblock_create:
    pushq %rbp
    movq %rsp, %rbp
    # Create superblock
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

superblock_destroy:
    pushq %rbp
    movq %rsp, %rbp
    # Destroy superblock
    movq %rbp, %rsp
    popq %rbp
    ret

superblock_read_inode:
    pushq %rbp
    movq %rsp, %rbp
    # Read inode from superblock
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

superblock_write_inode:
    pushq %rbp
    movq %rsp, %rbp
    # Write inode to superblock
    movq %rbp, %rsp
    popq %rbp
    ret

superblock_sync:
    pushq %rbp
    movq %rsp, %rbp
    # Sync superblock to disk
    movq %rbp, %rsp
    popq %rbp
    ret

fd_table_create:
    pushq %rbp
    movq %rsp, %rbp
    # Create FD table for process
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

fd_table_destroy:
    pushq %rbp
    movq %rsp, %rbp
    # Destroy FD table
    movq %rbp, %rsp
    popq %rbp
    ret

fd_alloc:
    pushq %rbp
    movq %rsp, %rbp
    # Allocate file descriptor
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

fd_free:
    pushq %rbp
    movq %rsp, %rbp
    # Free file descriptor
    movq %rbp, %rsp
    popq %rbp
    ret

fd_get:
    pushq %rbp
    movq %rsp, %rbp
    # Get file from descriptor
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

fd_set_cloexec:
    pushq %rbp
    movq %rsp, %rbp
    # Set close-on-exec flag
    movq %rbp, %rsp
    popq %rbp
    ret

fd_dup:
    pushq %rbp
    movq %rsp, %rbp
    # Duplicate file descriptor
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

fd_dup2:
    pushq %rbp
    movq %rsp, %rbp
    # Duplicate to specific FD
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

path_resolve:
    pushq %rbp
    movq %rsp, %rbp
    # Resolve path to inode
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

path_resolve_absolute:
    pushq %rbp
    movq %rsp, %rbp
    # Resolve absolute path
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

path_resolve_relative:
    pushq %rbp
    movq %rsp, %rbp
    # Resolve relative path
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

path_follow_symlink:
    pushq %rbp
    movq %rsp, %rbp
    # Follow symlink (with loop detection)
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

path_check_permissions:
    pushq %rbp
    movq %rsp, %rbp
    # Check path permissions
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

path_traverse_mount:
    pushq %rbp
    movq %rsp, %rbp
    # Traverse mount point
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

mount_init:
    pushq %rbp
    movq %rsp, %rbp
    # Initialize mount system
    movq %rbp, %rsp
    popq %rbp
    ret

mount_fs:
    pushq %rbp
    movq %rsp, %rbp
    # Mount file system
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

umount_fs:
    pushq %rbp
    movq %rsp, %rbp
    # Unmount file system
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

mount_bind:
    pushq %rbp
    movq %rsp, %rbp
    # Bind mount
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

mount_get_root:
    pushq %rbp
    movq %rsp, %rbp
    # Get root mount point
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

mount_lookup:
    pushq %rbp
    movq %rsp, %rbp
    # Lookup mount point
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

homefs_format:
    pushq %rbp
    movq %rsp, %rbp
    # Format device with home-fs
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

homefs_mount:
    pushq %rbp
    movq %rsp, %rbp
    # Mount home-fs
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

homefs_unmount:
    pushq %rbp
    movq %rsp, %rbp
    # Unmount home-fs
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

homefs_create_file:
    pushq %rbp
    movq %rsp, %rbp
    # Create file in home-fs
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

homefs_delete_file:
    pushq %rbp
    movq %rsp, %rbp
    # Delete file from home-fs
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

homefs_read_block:
    pushq %rbp
    movq %rsp, %rbp
    # Read block from home-fs
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

homefs_write_block:
    pushq %rbp
    movq %rsp, %rbp
    # Write block to home-fs
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

homefs_alloc_block:
    pushq %rbp
    movq %rsp, %rbp
    # Allocate block in home-fs
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

homefs_free_block:
    pushq %rbp
    movq %rsp, %rbp
    # Free block in home-fs
    movq %rbp, %rsp
    popq %rbp
    ret

homefs_alloc_inode:
    pushq %rbp
    movq %rsp, %rbp
    # Allocate inode in home-fs
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

homefs_free_inode:
    pushq %rbp
    movq %rsp, %rbp
    # Free inode in home-fs
    movq %rbp, %rsp
    popq %rbp
    ret

homefs_set_xattr:
    pushq %rbp
    movq %rsp, %rbp
    # Set extended attribute
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

homefs_get_xattr:
    pushq %rbp
    movq %rsp, %rbp
    # Get extended attribute
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

homefs_create_snapshot:
    pushq %rbp
    movq %rsp, %rbp
    # Create snapshot
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

homefs_clone_file:
    pushq %rbp
    movq %rsp, %rbp
    # Clone file (COW)
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

ext4_mount:
    pushq %rbp
    movq %rsp, %rbp
    # Mount ext4 file system
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

fat32_mount:
    pushq %rbp
    movq %rsp, %rbp
    # Mount FAT32 file system
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

procfs_init:
    pushq %rbp
    movq %rsp, %rbp
    # Initialize procfs
    movq %rbp, %rsp
    popq %rbp
    ret

sysfs_init:
    pushq %rbp
    movq %rsp, %rbp
    # Initialize sysfs
    movq %rbp, %rsp
    popq %rbp
    ret

tmpfs_create:
    pushq %rbp
    movq %rsp, %rbp
    # Create tmpfs
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

smp_init:
    pushq %rbp
    movq %rsp, %rbp
    # SMP init
    movq %rbp, %rsp
    popq %rbp
    ret

apic_init:
    pushq %rbp
    movq %rsp, %rbp
    # APIC init
    movq %rbp, %rsp
    popq %rbp
    ret

    movq $1, %rax
process_create:
    pushq %rbp
    movq %rsp, %rbp
    # process_create
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

process_terminate:
    pushq %rbp
    movq %rsp, %rbp
    # process_terminate
    movq %rbp, %rsp
    popq %rbp
    ret

process_fork:
    pushq %rbp
    movq %rsp, %rbp
    # process_fork
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

thread_create:
    pushq %rbp
    movq %rsp, %rbp
    # thread_create
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

thread_create_user:
    pushq %rbp
    movq %rsp, %rbp
    # thread_create_user
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

scheduler_init:
    pushq %rbp
    movq %rsp, %rbp
    # scheduler_init
    movq %rbp, %rsp
    popq %rbp
    ret

scheduler_schedule:
    pushq %rbp
    movq %rsp, %rbp
    # scheduler_schedule
    movq %rbp, %rsp
    popq %rbp
    ret

scheduler_balance_load:
    pushq %rbp
    movq %rsp, %rbp
    # scheduler_balance_load
    movq %rbp, %rsp
    popq %rbp
    ret

context_switch:
    pushq %rbp
    movq %rsp, %rbp
    # context_switch
    movq %rbp, %rsp
    popq %rbp
    ret

fpu_save:
    pushq %rbp
    movq %rsp, %rbp
    # fpu_save
    movq %rbp, %rsp
    popq %rbp
    ret

fpu_restore:
    pushq %rbp
    movq %rsp, %rbp
    # fpu_restore
    movq %rbp, %rsp
    popq %rbp
    ret

pmm_init:
    pushq %rbp
    movq %rsp, %rbp
    # pmm_init
    movq %rbp, %rsp
    popq %rbp
    ret

vmm_init:
    pushq %rbp
    movq %rsp, %rbp
    # vmm_init
    movq %rbp, %rsp
    popq %rbp
    ret

heap_init:
    pushq %rbp
    movq %rsp, %rbp
    # heap_init
    movq %rbp, %rsp
    popq %rbp
    ret

mmap:
    pushq %rbp
    movq %rsp, %rbp
    # mmap
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

munmap:
    pushq %rbp
    movq %rsp, %rbp
    # munmap
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

shm_create:
    pushq %rbp
    movq %rsp, %rbp
    # shm_create
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

mq_create:
    pushq %rbp
    movq %rsp, %rbp
    # mq_create
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

pipe_create:
    pushq %rbp
    movq %rsp, %rbp
    # pipe_create
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

socket_create:
    pushq %rbp
    movq %rsp, %rbp
    # socket_create
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

sem_create:
    pushq %rbp
    movq %rsp, %rbp
    # sem_create
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

mutex_create:
    pushq %rbp
    movq %rsp, %rbp
    # mutex_create
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

idt_init:
    pushq %rbp
    movq %rsp, %rbp
    # idt_init
    movq %rbp, %rsp
    popq %rbp
    ret

pic_init:
    pushq %rbp
    movq %rsp, %rbp
    # pic_init
    movq %rbp, %rsp
    popq %rbp
    ret

pit_init:
    pushq %rbp
    movq %rsp, %rbp
    # pit_init
    movq %rbp, %rsp
    popq %rbp
    ret

serial_init:
    pushq %rbp
    movq %rsp, %rbp
    # serial_init
    movq %rbp, %rsp
    popq %rbp
    ret

serial_write_string:
    pushq %rbp
    movq %rsp, %rbp
    # serial_write_string
    movq %rbp, %rsp
    popq %rbp
    ret

vga_init:
    pushq %rbp
    movq %rsp, %rbp
    # vga_init
    movq %rbp, %rsp
    popq %rbp
    ret

vga_write_string:
    pushq %rbp
    movq %rsp, %rbp
    # vga_write_string
    movq %rbp, %rsp
    popq %rbp
    ret

    # Load variable export
syscall_handler:
    pushq %rbp
    movq %rsp, %rbp
    movq $5, %rax
    pushq %rax
    # Load variable num
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4315225632
    # Load variable arg2
    pushq %rax
    # Load variable arg1
    pushq %rax
    movq $0, %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call vfs_read
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4315225632:
    movq $6, %rax
    pushq %rax
    # Load variable num
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4315226504
    # Load variable arg2
    pushq %rax
    # Load variable arg1
    pushq %rax
    movq $0, %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call vfs_write
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4315226504:
    movq $7, %rax
    pushq %rax
    # Load variable num
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4315227480
    movq $0, %rax
    pushq %rax
    movq $0, %rax
    pushq %rax
    # Load variable arg1
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call vfs_open
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4315227480:
    movq $8, %rax
    pushq %rax
    # Load variable num
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4315228240
    movq $0, %rax
    pushq %rax
    popq %rdi
    call vfs_close
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4315228240:
    movq $13, %rax
    pushq %rax
    # Load variable num
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4315229168
    # Load variable arg2
    pushq %rax
    # Load variable arg1
    pushq %rax
    popq %rdi
    popq %rsi
    call vfs_stat
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4315229168:
    movq $14, %rax
    pushq %rax
    # Load variable num
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4315230096
    movq $0, %rax
    pushq %rax
    # Load variable arg1
    pushq %rax
    popq %rdi
    popq %rsi
    call vfs_mkdir
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4315230096:
    movq $15, %rax
    pushq %rax
    # Load variable num
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4315230856
    # Load variable arg1
    pushq %rax
    popq %rdi
    call vfs_rmdir
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4315230856:
    movq $16, %rax
    pushq %rax
    # Load variable num
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4315231616
    # Load variable arg1
    pushq %rax
    popq %rdi
    call vfs_unlink
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4315231616:
    movq $17, %rax
    pushq %rax
    # Load variable num
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4315232544
    # Load variable arg2
    pushq %rax
    # Load variable arg1
    pushq %rax
    popq %rdi
    popq %rsi
    call vfs_rename
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4315232544:
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

    # Load variable export
exceptionHandler:
    pushq %rbp
    movq %rsp, %rbp
    call cli
.L_while_start_4315234136:
    movq $1, %rax
    testq %rax, %rax
    jz .L_while_end_4315234136
    call hlt
    jmp .L_while_start_4315234136
.L_while_end_4315234136:
    movq %rbp, %rsp
    popq %rbp
    ret

    # Load variable export
irq_handler:
    pushq %rbp
    movq %rsp, %rbp
    movq $0, %rax
    pushq %rax
    # Load variable irq
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4315238936
    call scheduler_schedule
.L_else_4315238936:
    movq %rbp, %rsp
    popq %rbp
    ret

.global kernel_init_phase1
kernel_init_phase1:
    pushq %rbp
    movq %rsp, %rbp
    call serial_init
    call vga_init
    call idt_init
    call pic_init
    movq $100, %rax
    pushq %rax
    popq %rdi
    call pit_init
    call pmm_init
    call vmm_init
    call heap_init
    movq %rbp, %rsp
    popq %rbp
    ret

.global kernel_init_phase2
kernel_init_phase2:
    pushq %rbp
    movq %rsp, %rbp
    call scheduler_init
    movq $1, %rax
    pushq %rax
    movq $0, %rax
    pushq %rax
    popq %rdi
    popq %rsi
    call process_create
    movq %rbp, %rsp
    popq %rbp
    ret

.global kernel_init_phase3
kernel_init_phase3:
    pushq %rbp
    movq %rsp, %rbp
    call smp_init
    call apic_init
    movq %rbp, %rsp
    popq %rbp
    ret

.global kernel_init_phase4
kernel_init_phase4:
    pushq %rbp
    movq %rsp, %rbp
    call mount_init
    call procfs_init
    call sysfs_init
    movq $0, %rax
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq $0, %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    popq %rcx
    call mount_fs
    call serial_write_string
    call vga_write_string
    movq %rbp, %rsp
    popq %rbp
    ret

    # Load variable export
.global kernel_main
kernel_main:
    pushq %rbp
    movq %rsp, %rbp
    call cli
    movq $0, %rax
    # Load variable MULTIBOOT2_MAGIC
    pushq %rax
    # Load variable magic
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4315244536
.L_else_4315244536:
    movq $1, %rax
    pushq %rax
    # Load variable valid
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4315245664
    call kernel_init_phase1
    call kernel_init_phase2
    call kernel_init_phase3
    call kernel_init_phase4
    call sti
.L_else_4315245664:
.L_while_start_4315245960:
    movq $1, %rax
    testq %rax, %rax
    jz .L_while_end_4315245960
    call hlt
    jmp .L_while_start_4315245960
.L_while_end_4315245960:

