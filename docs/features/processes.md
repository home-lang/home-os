# Process Management

HomeOS provides a comprehensive process management subsystem that handles process creation, scheduling, and lifecycle management. Built entirely in the Home programming language, the process manager offers modern features while maintaining high performance.

## Overview

The HomeOS process model is based on a hierarchical structure where each process has a unique identifier (PID) and maintains relationships with parent and child processes. The kernel manages processes through a combination of data structures and scheduling algorithms optimized for both throughput and responsiveness.

## Process Structure

Every process in HomeOS is represented by a Process Control Block (PCB) that contains all the information the kernel needs to manage the process.

```home
// Process Control Block definition
const ProcessState = enum {
    Created,
    Ready,
    Running,
    Blocked,
    Terminated
}

const Process = packed struct {
    pid: u32,
    parent_pid: u32,
    state: ProcessState,
    priority: u8,
    cpu_time: u64,
    memory_map: *PageTable,
    registers: RegisterContext,
    stack_pointer: usize,
    instruction_pointer: usize,
    open_files: [256]FileDescriptor,
    working_directory: [256]u8,
    name: [64]u8
}

// Register context for context switching
const RegisterContext = packed struct {
    rax: u64,
    rbx: u64,
    rcx: u64,
    rdx: u64,
    rsi: u64,
    rdi: u64,
    rbp: u64,
    r8: u64,
    r9: u64,
    r10: u64,
    r11: u64,
    r12: u64,
    r13: u64,
    r14: u64,
    r15: u64,
    rflags: u64
}
```

## Process Creation

HomeOS supports process creation through the `fork()` and `exec()` system calls, following the traditional Unix model while adding Home-specific enhancements.

### Fork System Call

The `fork()` system call creates a new process by duplicating the calling process.

```home
import kernel/process
import kernel/memory

// Fork implementation
export fn sys_fork(parent: *Process): i32 {
    // Allocate new PID
    let child_pid = process.allocate_pid()
    if child_pid < 0 {
        return -1  // No available PIDs
    }

    // Create child process control block
    let child = process.create_pcb()
    if child == null {
        process.free_pid(child_pid)
        return -1
    }

    // Copy parent's address space
    let new_page_table = memory.clone_address_space(parent.memory_map)
    if new_page_table == null {
        process.destroy_pcb(child)
        process.free_pid(child_pid)
        return -1
    }

    // Initialize child process
    child.pid = child_pid
    child.parent_pid = parent.pid
    child.state = ProcessState.Ready
    child.priority = parent.priority
    child.memory_map = new_page_table
    child.registers = parent.registers

    // Child returns 0 from fork
    child.registers.rax = 0

    // Add to scheduler
    process.add_to_ready_queue(child)

    // Parent returns child PID
    return child_pid
}
```

### Exec System Call

The `exec()` system call replaces the current process image with a new program.

```home
import kernel/process
import kernel/memory
import kernel/filesystem

export fn sys_exec(proc: *Process, path: []const u8, args: [][]const u8): i32 {
    // Open executable file
    let file = filesystem.open(path, OpenFlags.ReadOnly)
    if file == null {
        return -1  // File not found
    }

    // Validate ELF header
    let header = elf.read_header(file)
    if !elf.validate(header) {
        filesystem.close(file)
        return -1  // Invalid executable
    }

    // Free old address space (except kernel mappings)
    memory.free_user_pages(proc.memory_map)

    // Load program segments
    for segment in elf.get_program_headers(header) {
        if segment.type == PT_LOAD {
            let vaddr = segment.virtual_address
            let size = segment.memory_size

            // Allocate pages for segment
            memory.map_pages(proc.memory_map, vaddr, size, segment.flags)

            // Load segment data
            filesystem.seek(file, segment.offset)
            filesystem.read(file, @ptrFromInt(vaddr), segment.file_size)
        }
    }

    // Set up stack
    let stack_top = 0x7FFFFFFFE000
    memory.map_pages(proc.memory_map, stack_top - 0x100000, 0x100000, PAGE_USER | PAGE_WRITE)

    // Push arguments onto stack
    let sp = setup_stack_args(stack_top, args)

    // Set entry point
    proc.instruction_pointer = header.entry_point
    proc.stack_pointer = sp

    // Clear registers
    proc.registers = RegisterContext{}

    filesystem.close(file)
    return 0
}
```

## Process Scheduling

HomeOS implements a multi-level feedback queue (MLFQ) scheduler that balances responsiveness for interactive processes with throughput for batch processes.

### Scheduler Implementation

```home
import kernel/cpu
import kernel/timer

const NUM_PRIORITY_LEVELS = 8
const TIME_QUANTUM_BASE = 10  // milliseconds

// Ready queues for each priority level
let ready_queues: [NUM_PRIORITY_LEVELS]ProcessQueue = undefined

// Currently running process per CPU
let current_process: [MAX_CPUS]*Process = undefined

export fn scheduler_init() {
    for i in 0..NUM_PRIORITY_LEVELS {
        ready_queues[i] = ProcessQueue.init()
    }

    // Set up timer interrupt for preemption
    timer.set_handler(scheduler_tick)
    timer.set_interval(TIME_QUANTUM_BASE)
}

export fn schedule(): *Process {
    let cpu_id = cpu.get_current_id()

    // Find highest priority non-empty queue
    for priority in 0..NUM_PRIORITY_LEVELS {
        if !ready_queues[priority].is_empty() {
            let next = ready_queues[priority].dequeue()
            next.state = ProcessState.Running
            current_process[cpu_id] = next
            return next
        }
    }

    // No ready processes, return idle process
    return get_idle_process(cpu_id)
}

fn scheduler_tick() {
    let cpu_id = cpu.get_current_id()
    let current = current_process[cpu_id]

    if current == null {
        return
    }

    current.cpu_time += TIME_QUANTUM_BASE

    // Check if time quantum expired
    let quantum = TIME_QUANTUM_BASE << current.priority
    if current.cpu_time >= quantum {
        // Demote priority (if not already lowest)
        if current.priority < NUM_PRIORITY_LEVELS - 1 {
            current.priority += 1
        }

        // Put back in ready queue
        current.state = ProcessState.Ready
        current.cpu_time = 0
        ready_queues[current.priority].enqueue(current)

        // Switch to next process
        let next = schedule()
        context_switch(current, next)
    }
}
```

### Context Switching

Context switching saves the state of the current process and restores the state of the next process.

```home
import kernel/cpu

export fn context_switch(old: *Process, new: *Process) {
    if old == new {
        return
    }

    // Save current process state
    if old != null {
        save_context(old)
    }

    // Switch address space
    cpu.set_cr3(@intFromPtr(new.memory_map))

    // Restore new process state
    restore_context(new)
}

fn save_context(proc: *Process) {
    // Save general purpose registers
    asm volatile (
        "mov %%rax, %[rax]"
        "mov %%rbx, %[rbx]"
        "mov %%rcx, %[rcx]"
        "mov %%rdx, %[rdx]"
        "mov %%rsi, %[rsi]"
        "mov %%rdi, %[rdi]"
        "mov %%rbp, %[rbp]"
        "mov %%r8, %[r8]"
        "mov %%r9, %[r9]"
        "mov %%r10, %[r10]"
        "mov %%r11, %[r11]"
        "mov %%r12, %[r12]"
        "mov %%r13, %[r13]"
        "mov %%r14, %[r14]"
        "mov %%r15, %[r15]"
        : [rax] "=m" (proc.registers.rax),
          [rbx] "=m" (proc.registers.rbx),
          [rcx] "=m" (proc.registers.rcx),
          [rdx] "=m" (proc.registers.rdx),
          [rsi] "=m" (proc.registers.rsi),
          [rdi] "=m" (proc.registers.rdi),
          [rbp] "=m" (proc.registers.rbp),
          [r8] "=m" (proc.registers.r8),
          [r9] "=m" (proc.registers.r9),
          [r10] "=m" (proc.registers.r10),
          [r11] "=m" (proc.registers.r11),
          [r12] "=m" (proc.registers.r12),
          [r13] "=m" (proc.registers.r13),
          [r14] "=m" (proc.registers.r14),
          [r15] "=m" (proc.registers.r15)
    )

    // Save flags
    asm volatile (
        "pushfq"
        "pop %[flags]"
        : [flags] "=m" (proc.registers.rflags)
    )
}

fn restore_context(proc: *Process) {
    // Restore flags
    asm volatile (
        "push %[flags]"
        "popfq"
        :
        : [flags] "m" (proc.registers.rflags)
    )

    // Restore general purpose registers
    asm volatile (
        "mov %[rax], %%rax"
        "mov %[rbx], %%rbx"
        "mov %[rcx], %%rcx"
        "mov %[rdx], %%rdx"
        "mov %[rsi], %%rsi"
        "mov %[rdi], %%rdi"
        "mov %[rbp], %%rbp"
        "mov %[r8], %%r8"
        "mov %[r9], %%r9"
        "mov %[r10], %%r10"
        "mov %[r11], %%r11"
        "mov %[r12], %%r12"
        "mov %[r13], %%r13"
        "mov %[r14], %%r14"
        "mov %[r15], %%r15"
        :
        : [rax] "m" (proc.registers.rax),
          [rbx] "m" (proc.registers.rbx),
          [rcx] "m" (proc.registers.rcx),
          [rdx] "m" (proc.registers.rdx),
          [rsi] "m" (proc.registers.rsi),
          [rdi] "m" (proc.registers.rdi),
          [rbp] "m" (proc.registers.rbp),
          [r8] "m" (proc.registers.r8),
          [r9] "m" (proc.registers.r9),
          [r10] "m" (proc.registers.r10),
          [r11] "m" (proc.registers.r11),
          [r12] "m" (proc.registers.r12),
          [r13] "m" (proc.registers.r13),
          [r14] "m" (proc.registers.r14),
          [r15] "m" (proc.registers.r15)
    )
}
```

## Inter-Process Communication

HomeOS provides several IPC mechanisms for processes to communicate with each other.

### Pipes

Pipes provide unidirectional data flow between processes.

```home
import kernel/memory

const PIPE_BUFFER_SIZE = 4096

const Pipe = struct {
    buffer: [PIPE_BUFFER_SIZE]u8,
    read_pos: usize,
    write_pos: usize,
    readers: u32,
    writers: u32,
    read_blocked: ProcessQueue,
    write_blocked: ProcessQueue
}

export fn sys_pipe(fds: *[2]i32): i32 {
    let pipe = memory.allocate(Pipe)
    if pipe == null {
        return -1
    }

    pipe.* = Pipe{
        .buffer = undefined,
        .read_pos = 0,
        .write_pos = 0,
        .readers = 1,
        .writers = 1,
        .read_blocked = ProcessQueue.init(),
        .write_blocked = ProcessQueue.init()
    }

    // Allocate file descriptors
    let read_fd = allocate_fd(pipe, FD_PIPE_READ)
    let write_fd = allocate_fd(pipe, FD_PIPE_WRITE)

    if read_fd < 0 or write_fd < 0 {
        memory.free(pipe)
        return -1
    }

    fds[0] = read_fd
    fds[1] = write_fd

    return 0
}

export fn pipe_read(pipe: *Pipe, buf: []u8): isize {
    let bytes_read: usize = 0

    while bytes_read < buf.len {
        // Wait for data
        while pipe.read_pos == pipe.write_pos {
            if pipe.writers == 0 {
                return bytes_read  // EOF
            }

            // Block until data available
            let current = get_current_process()
            current.state = ProcessState.Blocked
            pipe.read_blocked.enqueue(current)
            schedule()
        }

        // Read available data
        while pipe.read_pos != pipe.write_pos and bytes_read < buf.len {
            buf[bytes_read] = pipe.buffer[pipe.read_pos]
            pipe.read_pos = (pipe.read_pos + 1) % PIPE_BUFFER_SIZE
            bytes_read += 1
        }

        // Wake up writers
        while !pipe.write_blocked.is_empty() {
            let writer = pipe.write_blocked.dequeue()
            writer.state = ProcessState.Ready
            add_to_ready_queue(writer)
        }
    }

    return bytes_read
}

export fn pipe_write(pipe: *Pipe, buf: []const u8): isize {
    let bytes_written: usize = 0

    while bytes_written < buf.len {
        // Wait for space
        while (pipe.write_pos + 1) % PIPE_BUFFER_SIZE == pipe.read_pos {
            if pipe.readers == 0 {
                return -1  // Broken pipe
            }

            // Block until space available
            let current = get_current_process()
            current.state = ProcessState.Blocked
            pipe.write_blocked.enqueue(current)
            schedule()
        }

        // Write data
        while (pipe.write_pos + 1) % PIPE_BUFFER_SIZE != pipe.read_pos and bytes_written < buf.len {
            pipe.buffer[pipe.write_pos] = buf[bytes_written]
            pipe.write_pos = (pipe.write_pos + 1) % PIPE_BUFFER_SIZE
            bytes_written += 1
        }

        // Wake up readers
        while !pipe.read_blocked.is_empty() {
            let reader = pipe.read_blocked.dequeue()
            reader.state = ProcessState.Ready
            add_to_ready_queue(reader)
        }
    }

    return bytes_written
}
```

### Shared Memory

Shared memory allows processes to share regions of memory directly.

```home
import kernel/memory

const SharedMemoryRegion = struct {
    key: u64,
    physical_address: usize,
    size: usize,
    ref_count: u32,
    permissions: u32
}

let shared_regions: HashMap(u64, *SharedMemoryRegion) = undefined

export fn sys_shmget(key: u64, size: usize, flags: u32): i32 {
    // Check if region exists
    if shared_regions.get(key)) |existing| {
        if flags & IPC_CREAT and flags & IPC_EXCL {
            return -1  // Already exists and exclusive requested
        }
        return existing.key
    }

    // Create new region
    let region = memory.allocate(SharedMemoryRegion)
    if region == null {
        return -1
    }

    let pages = (size + PAGE_SIZE - 1) / PAGE_SIZE
    let phys = memory.allocate_physical_pages(pages)
    if phys == 0 {
        memory.free(region)
        return -1
    }

    region.* = SharedMemoryRegion{
        .key = key,
        .physical_address = phys,
        .size = size,
        .ref_count = 0,
        .permissions = flags & 0o777
    }

    shared_regions.put(key, region)
    return key
}

export fn sys_shmat(key: u64, addr: ?*anyopaque, flags: u32): *anyopaque {
    let region = shared_regions.get(key) ?? return null

    let proc = get_current_process()

    // Find virtual address
    let vaddr = if addr != null {
        @intFromPtr(addr)
    } else {
        memory.find_free_region(proc.memory_map, region.size)
    }

    if vaddr == 0 {
        return null
    }

    // Map shared memory into process
    let page_flags = PAGE_USER | PAGE_PRESENT
    if flags & SHM_RDONLY == 0 {
        page_flags |= PAGE_WRITE
    }

    memory.map_physical_pages(proc.memory_map, vaddr, region.physical_address, region.size, page_flags)

    region.ref_count += 1

    return @ptrFromInt(vaddr)
}
```

## Process Termination

When a process terminates, the kernel must clean up all its resources and notify its parent.

```home
export fn sys_exit(status: i32) {
    let proc = get_current_process()

    // Close all open files
    for i in 0..256 {
        if proc.open_files[i].is_valid() {
            filesystem.close_fd(proc, i)
        }
    }

    // Free address space
    memory.free_user_pages(proc.memory_map)
    memory.free_page_table(proc.memory_map)

    // Reparent children to init
    reparent_children(proc)

    // Store exit status and become zombie
    proc.exit_status = status
    proc.state = ProcessState.Terminated

    // Wake up parent if waiting
    let parent = get_process(proc.parent_pid)
    if parent != null and parent.state == ProcessState.Blocked {
        parent.state = ProcessState.Ready
        add_to_ready_queue(parent)
    }

    // Switch to another process
    schedule()
}

export fn sys_wait(status: *i32): i32 {
    let proc = get_current_process()

    loop {
        // Look for terminated children
        for child in get_children(proc) {
            if child.state == ProcessState.Terminated {
                let pid = child.pid
                status.* = child.exit_status

                // Free zombie process
                process.destroy_pcb(child)
                process.free_pid(pid)

                return pid
            }
        }

        // Check if we have any children
        if !has_children(proc) {
            return -1  // No children
        }

        // Block until child terminates
        proc.state = ProcessState.Blocked
        schedule()
    }
}
```

## Thread Support

HomeOS supports kernel threads and user-level threads through the threading API.

```home
import kernel/memory
import kernel/cpu

const Thread = struct {
    tid: u32,
    process: *Process,
    stack: []u8,
    registers: RegisterContext,
    state: ProcessState,
    priority: u8
}

export fn sys_thread_create(entry: fn (*anyopaque) void, arg: *anyopaque): i32 {
    let proc = get_current_process()

    // Allocate thread structure
    let thread = memory.allocate(Thread)
    if thread == null {
        return -1
    }

    // Allocate stack
    let stack = memory.allocate_pages(16)  // 64KB stack
    if stack == null {
        memory.free(thread)
        return -1
    }

    let tid = allocate_tid()

    thread.* = Thread{
        .tid = tid,
        .process = proc,
        .stack = stack,
        .registers = RegisterContext{},
        .state = ProcessState.Ready,
        .priority = proc.priority
    }

    // Set up initial stack frame
    let stack_top = @intFromPtr(stack.ptr) + stack.len
    thread.registers.rsp = stack_top - 8
    thread.registers.rip = @intFromPtr(entry)
    thread.registers.rdi = @intFromPtr(arg)

    // Add to scheduler
    add_thread_to_ready_queue(thread)

    return tid
}

export fn sys_thread_join(tid: u32): i32 {
    let thread = get_thread(tid)
    if thread == null {
        return -1
    }

    let current = get_current_thread()

    // Wait for thread to terminate
    while thread.state != ProcessState.Terminated {
        current.state = ProcessState.Blocked
        schedule()
    }

    // Clean up thread
    memory.free_pages(thread.stack)
    memory.free(thread)
    free_tid(tid)

    return 0
}
```

## Summary

HomeOS process management provides:

- **Comprehensive PCB**: Full process state tracking with register context
- **Fork/Exec Model**: Traditional Unix-style process creation
- **MLFQ Scheduler**: Balanced scheduling for interactive and batch workloads
- **IPC Mechanisms**: Pipes, shared memory, and signals
- **Thread Support**: Kernel threads with shared address space
- **Clean Termination**: Proper resource cleanup and zombie handling

All process management code is written in the Home programming language, leveraging its packed structs for precise memory layout and inline assembly for hardware interaction.
