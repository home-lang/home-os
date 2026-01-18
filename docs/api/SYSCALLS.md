# System Call Reference

HomeOS provides a POSIX-compatible system call interface. System calls are the primary interface between user-space applications and the kernel.

## Overview

System calls allow user-space programs to request services from the kernel, such as file operations, process management, and network access. HomeOS implements 100+ system calls for comprehensive functionality.

## Syscall Calling Convention

### x86-64

- **Syscall number:** `RAX`
- **Arguments:** `RDI`, `RSI`, `RDX`, `R10`, `R8`, `R9`
- **Return value:** `RAX`
- **Instruction:** `syscall`

### ARM64

- **Syscall number:** `X8`
- **Arguments:** `X0`, `X1`, `X2`, `X3`, `X4`, `X5`
- **Return value:** `X0`
- **Instruction:** `svc #0`

## System Call Table

| Number | Name | Description |
|--------|------|-------------|
| 0 | exit | Terminate the calling process |
| 1 | fork | Create a child process |
| 2 | read | Read from a file descriptor |
| 3 | write | Write to a file descriptor |
| 4 | open | Open a file |
| 5 | close | Close a file descriptor |
| 6 | wait | Wait for a child process |
| 7 | exec | Execute a program |
| 8 | getpid | Get process ID |
| 9 | kill | Send a signal to a process |
| 10 | mmap | Map files or devices into memory |
| 11 | munmap | Unmap memory |
| 12 | brk | Change data segment size |
| 13 | lseek | Reposition file offset |
| 14 | mkdir | Create a directory |
| 15 | rmdir | Remove a directory |
| 16 | setuid | Set user ID |
| 17 | setgid | Set group ID |
| 18 | chroot | Change root directory |
| 19 | ptrace | Process trace |
| 20 | reboot | Reboot the system |
| 21 | mknod | Create a special file |
| 22 | socket | Create a socket |
| 23 | bind | Bind a socket to an address |
| 24 | ioctl | Device control operations |
| 25 | capget | Get process capabilities |
| 26 | capset | Set process capabilities |
| 27 | settimeofday | Set the time of day |
| 28 | setrlimit | Set resource limits |
| 29 | stat | Get file status |
| 30 | fstat | Get file status by descriptor |
| 31 | lstat | Get symbolic link status |
| 32 | unlink | Delete a file |
| 33 | link | Create a hard link |
| 34 | symlink | Create a symbolic link |
| 35 | readlink | Read a symbolic link |
| 36 | rename | Rename a file |
| 37 | access | Check file accessibility |
| 38 | chmod | Change file mode |
| 39 | chown | Change file owner |
| 40 | fchmod | Change file mode by descriptor |
| 41 | fchown | Change file owner by descriptor |
| 42 | truncate | Truncate a file |
| 43 | ftruncate | Truncate a file by descriptor |
| 44 | chdir | Change working directory |
| 45 | fchdir | Change directory by descriptor |
| 46 | getcwd | Get current working directory |
| 47 | getdents | Get directory entries |
| 48 | getppid | Get parent process ID |
| 49 | getuid | Get user ID |
| 50 | getgid | Get group ID |
| 51 | geteuid | Get effective user ID |
| 52 | getegid | Get effective group ID |
| 53 | setpgid | Set process group ID |
| 54 | getpgid | Get process group ID |
| 55 | setsid | Create a new session |
| 56 | getsid | Get session ID |
| 57 | getgroups | Get supplementary group IDs |
| 58 | setgroups | Set supplementary group IDs |
| 59 | gettimeofday | Get the time of day |
| 60 | clock_gettime | Get clock time |
| 61 | clock_getres | Get clock resolution |
| 62 | nanosleep | High-resolution sleep |
| 63 | sigaction | Set signal handler |
| 64 | sigprocmask | Block/unblock signals |
| 65 | sigpending | Get pending signals |
| 66 | sigsuspend | Wait for a signal |
| 67 | mprotect | Set memory protection |
| 68 | msync | Synchronize memory with file |
| 69 | madvise | Give memory advice |
| 70 | mincore | Check if pages are resident |
| 71 | connect | Connect to a remote socket |
| 72 | listen | Listen for connections |
| 73 | accept | Accept a connection |
| 74 | send | Send data on a socket |
| 75 | recv | Receive data from a socket |
| 76 | sendto | Send a datagram |
| 77 | recvfrom | Receive a datagram |
| 78 | shutdown | Shut down socket send/receive |
| 79 | getsockopt | Get socket options |
| 80 | setsockopt | Set socket options |
| 81 | getpeername | Get peer socket address |
| 82 | getsockname | Get socket address |
| 83 | poll | Wait for events on file descriptors |
| 84 | select | Synchronous I/O multiplexing |
| 85 | epoll_create | Create an epoll instance |
| 86 | epoll_ctl | Control an epoll instance |
| 87 | epoll_wait | Wait for epoll events |
| 88 | eventfd | Create an event file descriptor |
| 89 | timerfd_create | Create a timer file descriptor |
| 90 | timerfd_settime | Set timer expiration |
| 91 | timerfd_gettime | Get timer expiration |
| 92 | dup | Duplicate a file descriptor |
| 95 | pipe | Create a pipe |
| 97 | fcntl | File control operations |
| 98 | flock | Apply or remove an advisory lock |
| 99 | fsync | Synchronize file to storage |
| 100 | fdatasync | Synchronize file data to storage |
| 101 | uname | Get system information |
| 102 | getrlimit | Get resource limits |
| 103 | getrusage | Get resource usage |
| 104 | sysinfo | Get system statistics |
| 105 | umask | Set file mode creation mask |
| 106 | mount | Mount a file system |
| 107 | umount | Unmount a file system |
| 425 | io_uring_setup | Set up io_uring instance |
| 426 | io_uring_enter | Submit and wait for io_uring |
| 427 | io_uring_register | Register buffers/files |

## Syscall Categories

### Process Management

| Syscall | Description |
|---------|-------------|
| `fork` | Create a child process |
| `exec` | Execute a program |
| `exit` | Terminate the calling process |
| `wait` / `waitpid` | Wait for a child process |
| `getpid` / `getppid` | Get process/parent process ID |
| `kill` | Send a signal to a process |

### File Operations

| Syscall | Description |
|---------|-------------|
| `open` | Open a file |
| `close` | Close a file descriptor |
| `read` | Read from a file descriptor |
| `write` | Write to a file descriptor |
| `lseek` | Reposition file offset |
| `stat` / `fstat` / `lstat` | Get file status |
| `unlink` | Delete a file |
| `rename` | Rename a file |
| `mkdir` / `rmdir` | Create/remove directory |

### File Descriptor Operations

| Syscall | Description |
|---------|-------------|
| `dup` / `dup2` / `dup3` | Duplicate file descriptor |
| `pipe` / `pipe2` | Create a pipe |
| `fcntl` | File control operations |
| `ioctl` | Device control operations |

### Memory Management

| Syscall | Description |
|---------|-------------|
| `mmap` | Map files or devices into memory |
| `munmap` | Unmap memory |
| `mprotect` | Set memory protection |
| `brk` / `sbrk` | Change data segment size |

### Network Operations

| Syscall | Description |
|---------|-------------|
| `socket` | Create a socket |
| `bind` | Bind a socket to an address |
| `listen` | Listen for connections |
| `accept` | Accept a connection |
| `connect` | Connect to a remote socket |
| `send` / `recv` | Send/receive data |
| `sendto` / `recvfrom` | Send/receive datagrams |

### Signal Handling

| Syscall | Description |
|---------|-------------|
| `sigaction` | Set signal handler |
| `sigprocmask` | Block/unblock signals |
| `sigpending` | Get pending signals |
| `sigsuspend` | Wait for a signal |

### Time Operations

| Syscall | Description |
|---------|-------------|
| `gettimeofday` | Get current time |
| `clock_gettime` | Get clock time |
| `nanosleep` | High-resolution sleep |

### System Information

| Syscall | Description |
|---------|-------------|
| `uname` | Get system information |
| `getrlimit` / `setrlimit` | Get/set resource limits |
| `sysinfo` | Get system statistics |

## Detailed Reference

### Process Management

#### fork

Create a new child process.

```home
fn fork(): i32
```

**Returns:**
- In parent: Child's PID (positive)
- In child: 0
- On error: -1

#### exec

Replace current process with a new program.

```home
fn exec(path: *u8, argv: **u8, envp: **u8): i32
```

**Parameters:**
- `path` - Path to executable
- `argv` - Argument array (NULL-terminated)
- `envp` - Environment array (NULL-terminated)

**Returns:** Does not return on success, -1 on error

#### exit

Terminate the calling process.

```home
fn exit(status: i32): never
```

**Parameters:**
- `status` - Exit status (0-255)

### File Operations

#### open

Open or create a file.

```home
fn open(path: *u8, flags: u32, mode: u32): i32
```

**Parameters:**
- `path` - Path to file
- `flags` - Open flags (O_RDONLY, O_WRONLY, O_RDWR, O_CREAT, etc.)
- `mode` - File permissions (when creating)

**Returns:** File descriptor on success, -1 on error

**Flags:**
| Flag | Value | Description |
|------|-------|-------------|
| O_RDONLY | 0x0000 | Read only |
| O_WRONLY | 0x0001 | Write only |
| O_RDWR | 0x0002 | Read and write |
| O_CREAT | 0x0100 | Create if not exists |
| O_TRUNC | 0x0200 | Truncate to zero |
| O_APPEND | 0x0400 | Append mode |

#### read

Read from a file descriptor.

```home
fn read(fd: i32, buf: *u8, count: u64): i64
```

**Parameters:**
- `fd` - File descriptor
- `buf` - Buffer to read into
- `count` - Maximum bytes to read

**Returns:** Number of bytes read, 0 on EOF, -1 on error

#### write

Write to a file descriptor.

```home
fn write(fd: i32, buf: *u8, count: u64): i64
```

**Parameters:**
- `fd` - File descriptor
- `buf` - Buffer to write from
- `count` - Number of bytes to write

**Returns:** Number of bytes written, -1 on error

### Memory Management

#### mmap

Map files or devices into memory.

```home
fn mmap(addr: *u8, length: u64, prot: u32, flags: u32, fd: i32, offset: i64): *u8
```

**Parameters:**
- `addr` - Suggested address (or NULL)
- `length` - Length of mapping
- `prot` - Protection flags (PROT_READ, PROT_WRITE, PROT_EXEC)
- `flags` - Mapping flags (MAP_SHARED, MAP_PRIVATE, MAP_ANONYMOUS)
- `fd` - File descriptor (or -1 for anonymous)
- `offset` - Offset in file

**Returns:** Mapped address, or MAP_FAILED on error

### Network Operations

#### socket

Create a socket.

```home
fn socket(domain: u32, type: u32, protocol: u32): i32
```

**Parameters:**
- `domain` - Address family (AF_INET, AF_INET6)
- `type` - Socket type (SOCK_STREAM, SOCK_DGRAM)
- `protocol` - Protocol (usually 0)

**Returns:** Socket file descriptor, -1 on error

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

## Example Usage

### Hello World

```home
fn main(): i32 {
  let msg = "Hello, World!\n"
  write(1, msg, 14)  // fd 1 = stdout
  exit(0)
}
```

### File Copy

```home
fn copy_file(src: *u8, dst: *u8): i32 {
  let src_fd = open(src, O_RDONLY, 0)
  if src_fd < 0 {
    return -1
  }

  let dst_fd = open(dst, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
  if dst_fd < 0 {
    close(src_fd)
    return -1
  }

  let buffer: [4096]u8
  loop {
    let n = read(src_fd, &buffer, 4096)
    if n <= 0 {
      break
    }
    write(dst_fd, &buffer, n)
  }

  close(src_fd)
  close(dst_fd)
  return 0
}
```

### TCP Client

```home
fn connect_to_server(host: u32, port: u16): i32 {
  let fd = socket(AF_INET, SOCK_STREAM, 0)
  if fd < 0 {
    return -1
  }

  let addr = sockaddr_in {
    sin_family: AF_INET
    sin_port: htons(port)
    sin_addr: host
  }

  if connect(fd, &addr, sizeof(sockaddr_in)) < 0 {
    close(fd)
    return -1
  }

  return fd
}
```

## Related Documentation

- [Architecture](/guide/architecture) - Syscall implementation
- [Networking](/guide/networking) - Network syscalls
- [File Systems](/guide/filesystems) - File syscalls
