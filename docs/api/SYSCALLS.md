# home-os System Call Reference

This document is auto-generated from `kernel/src/sys/syscall.home`.

## Overview

home-os provides a POSIX-compatible system call interface. System calls are the primary interface between user-space applications and the kernel.

## Syscall Calling Convention

### x86-64
- Syscall number: `RAX`
- Arguments: `RDI`, `RSI`, `RDX`, `R10`, `R8`, `R9`
- Return value: `RAX`
- Instruction: `syscall`

### ARM64
- Syscall number: `X8`
- Arguments: `X0`, `X1`, `X2`, `X3`, `X4`, `X5`
- Return value: `X0`
- Instruction: `svc #0`

## System Call Table

| Number | Name | Description |
|--------|------|-------------|
| 0 | exit | `SYS_EXIT` |
| 1 | fork | `SYS_FORK` |
| 2 | read | `SYS_READ` |
| 3 | write | `SYS_WRITE` |
| 4 | open | `SYS_OPEN` |
| 5 | close | `SYS_CLOSE` |
| 6 | wait | `SYS_WAIT` |
| 7 | exec | `SYS_EXEC` |
| 8 | getpid | `SYS_GETPID` |
| 9 | kill | `SYS_KILL` |
| 10 | mmap | `SYS_MMAP` |
| 11 | munmap | `SYS_MUNMAP` |
| 12 | brk | `SYS_BRK` |
| 13 | lseek | `SYS_LSEEK` |
| 14 | mkdir | `SYS_MKDIR` |
| 15 | rmdir | `SYS_RMDIR` |
| 16 | setuid | `SYS_SETUID` |
| 17 | setgid | `SYS_SETGID` |
| 18 | chroot | `SYS_CHROOT` |
| 19 | ptrace | `SYS_PTRACE` |
| 20 | reboot | `SYS_REBOOT` |
| 21 | mknod | `SYS_MKNOD` |
| 22 | socket | `SYS_SOCKET` |
| 23 | bind | `SYS_BIND` |
| 24 | ioctl | `SYS_IOCTL` |
| 25 | capget | `SYS_CAPGET` |
| 26 | capset | `SYS_CAPSET` |
| 27 | settimeofday | `SYS_SETTIMEOFDAY` |
| 28 | setrlimit | `SYS_SETRLIMIT` |
| 29 | stat | `SYS_STAT` |
| 30 | fstat | `SYS_FSTAT` |
| 31 | lstat | `SYS_LSTAT` |
| 32 | unlink | `SYS_UNLINK` |
| 33 | link | `SYS_LINK` |
| 34 | symlink | `SYS_SYMLINK` |
| 35 | readlink | `SYS_READLINK` |
| 36 | rename | `SYS_RENAME` |
| 37 | access | `SYS_ACCESS` |
| 38 | chmod | `SYS_CHMOD` |
| 39 | chown | `SYS_CHOWN` |
| 40 | fchmod | `SYS_FCHMOD` |
| 41 | fchown | `SYS_FCHOWN` |
| 42 | truncate | `SYS_TRUNCATE` |
| 43 | ftruncate | `SYS_FTRUNCATE` |
| 44 | chdir | `SYS_CHDIR` |
| 45 | fchdir | `SYS_FCHDIR` |
| 46 | getcwd | `SYS_GETCWD` |
| 47 | getdents | `SYS_GETDENTS` |
| 48 | getppid | `SYS_GETPPID` |
| 49 | getuid | `SYS_GETUID` |
| 50 | getgid | `SYS_GETGID` |
| 51 | geteuid | `SYS_GETEUID` |
| 52 | getegid | `SYS_GETEGID` |
| 53 | setpgid | `SYS_SETPGID` |
| 54 | getpgid | `SYS_GETPGID` |
| 55 | setsid | `SYS_SETSID` |
| 56 | getsid | `SYS_GETSID` |
| 57 | getgroups | `SYS_GETGROUPS` |
| 58 | setgroups | `SYS_SETGROUPS` |
| 59 | gettimeofday | `SYS_GETTIMEOFDAY` |
| 60 | clock_gettime | `SYS_CLOCK_GETTIME` |
| 61 | clock_getres | `SYS_CLOCK_GETRES` |
| 62 | nanosleep | `SYS_NANOSLEEP` |
| 63 | sigaction | `SYS_SIGACTION` |
| 64 | sigprocmask | `SYS_SIGPROCMASK` |
| 65 | sigpending | `SYS_SIGPENDING` |
| 66 | sigsuspend | `SYS_SIGSUSPEND` |
| 67 | mprotect | `SYS_MPROTECT` |
| 68 | msync | `SYS_MSYNC` |
| 69 | madvise | `SYS_MADVISE` |
| 70 | mincore | `SYS_MINCORE` |
| 71 | connect | `SYS_CONNECT` |
| 72 | listen | `SYS_LISTEN` |
| 73 | accept | `SYS_ACCEPT` |
| 74 | send | `SYS_SEND` |
| 75 | recv | `SYS_RECV` |
| 76 | sendto | `SYS_SENDTO` |
| 77 | recvfrom | `SYS_RECVFROM` |
| 78 | shutdown | `SYS_SHUTDOWN` |
| 79 | getsockopt | `SYS_GETSOCKOPT` |
| 80 | setsockopt | `SYS_SETSOCKOPT` |
| 81 | getpeername | `SYS_GETPEERNAME` |
| 82 | getsockname | `SYS_GETSOCKNAME` |
| 83 | poll | `SYS_POLL` |
| 84 | select | `SYS_SELECT` |
| 85 | epoll_create | `SYS_EPOLL_CREATE` |
| 86 | epoll_ctl | `SYS_EPOLL_CTL` |
| 87 | epoll_wait | `SYS_EPOLL_WAIT` |
| 88 | eventfd | `SYS_EVENTFD` |
| 89 | timerfd_create | `SYS_TIMERFD_CREATE` |
| 90 | timerfd_settime | `SYS_TIMERFD_SETTIME` |
| 91 | timerfd_gettime | `SYS_TIMERFD_GETTIME` |
| 92 | dup | `SYS_DUP` |
| 95 | pipe | `SYS_PIPE` |
| 97 | fcntl | `SYS_FCNTL` |
| 98 | flock | `SYS_FLOCK` |
| 99 | fsync | `SYS_FSYNC` |
| 100 | fdatasync | `SYS_FDATASYNC` |
| 101 | uname | `SYS_UNAME` |
| 102 | getrlimit | `SYS_GETRLIMIT` |
| 103 | getrusage | `SYS_GETRUSAGE` |
| 104 | sysinfo | `SYS_SYSINFO` |
| 105 | umask | `SYS_UMASK` |
| 106 | mount | `SYS_MOUNT` |
| 107 | umount | `SYS_UMOUNT` |
| 425 | io_uring_setup | `SYS_IO_URING_SETUP` |
| 426 | io_uring_enter | `SYS_IO_URING_ENTER` |
| 427 | io_uring_register | `SYS_IO_URING_REGISTER` |

## Syscall Categories

### Process Management
- `fork` - Create a child process
- `exec` - Execute a program
- `exit` - Terminate the calling process
- `wait` / `waitpid` - Wait for a child process
- `getpid` / `getppid` - Get process/parent process ID
- `kill` - Send a signal to a process

### File Operations
- `open` - Open a file
- `close` - Close a file descriptor
- `read` - Read from a file descriptor
- `write` - Write to a file descriptor
- `lseek` - Reposition file offset
- `stat` / `fstat` / `lstat` - Get file status
- `unlink` - Delete a file
- `rename` - Rename a file
- `mkdir` / `rmdir` - Create/remove directory

### File Descriptor Operations
- `dup` / `dup2` / `dup3` - Duplicate file descriptor
- `pipe` / `pipe2` - Create a pipe
- `fcntl` - File control operations
- `ioctl` - Device control operations

### Memory Management
- `mmap` - Map files or devices into memory
- `munmap` - Unmap memory
- `mprotect` - Set memory protection
- `brk` / `sbrk` - Change data segment size

### Network Operations
- `socket` - Create a socket
- `bind` - Bind a socket to an address
- `listen` - Listen for connections
- `accept` - Accept a connection
- `connect` - Connect to a remote socket
- `send` / `recv` - Send/receive data
- `sendto` / `recvfrom` - Send/receive datagrams

### Signal Handling
- `sigaction` - Set signal handler
- `sigprocmask` - Block/unblock signals
- `sigpending` - Get pending signals
- `sigsuspend` - Wait for a signal

### Time Operations
- `gettimeofday` - Get current time
- `clock_gettime` - Get clock time
- `nanosleep` - High-resolution sleep

### System Information
- `uname` - Get system information
- `getrlimit` / `setrlimit` - Get/set resource limits
- `sysinfo` - Get system statistics

## Error Codes

All syscalls return -1 on error and set `errno`:

| Code | Name | Description |
|------|------|-------------|
| 1 | EPERM | Operation not permitted |
| 2 | ENOENT | No such file or directory |
| 3 | ESRCH | No such process |
| 4 | EINTR | Interrupted system call |
| 5 | EIO | I/O error |
| 9 | EBADF | Bad file descriptor |
| 11 | EAGAIN | Resource temporarily unavailable |
| 12 | ENOMEM | Out of memory |
| 13 | EACCES | Permission denied |
| 14 | EFAULT | Bad address |
| 17 | EEXIST | File exists |
| 22 | EINVAL | Invalid argument |
| 28 | ENOSPC | No space left on device |

