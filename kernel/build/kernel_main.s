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
    movq $16384, %rax
    movq $8192, %rax
    movq $10, %rax
    movq $0, %rax
    movq $1, %rax
    movq $2, %rax
    movq $3, %rax
    movq $4, %rax
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
    movq $0, %rax
    movq $1, %rax
    movq $2, %rax
    movq $4, %rax
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
    # cpuid - get CPU info
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
    # rdtsc - read timestamp counter
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

    movq $1, %rax
    movq $0, %rax
smp_init:
    pushq %rbp
    movq %rsp, %rbp
    # SMP initialization - detect and start APs
    movq %rbp, %rsp
    popq %rbp
    ret

smp_get_cpu_count:
    pushq %rbp
    movq %rsp, %rbp
    # Load variable cpu_count
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

smp_get_current_cpu:
    pushq %rbp
    movq %rsp, %rbp
    # Load variable current_cpu
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

smp_send_ipi:
    pushq %rbp
    movq %rsp, %rbp
    # Send inter-processor interrupt
    movq %rbp, %rsp
    popq %rbp
    ret

apic_init:
    pushq %rbp
    movq %rsp, %rbp
    # Initialize Local APIC
    movq %rbp, %rsp
    popq %rbp
    ret

apic_send_eoi:
    pushq %rbp
    movq %rsp, %rbp
    # Send EOI to APIC
    movq %rbp, %rsp
    popq %rbp
    ret

apic_timer_init:
    pushq %rbp
    movq %rsp, %rbp
    # Initialize APIC timer
    movq %rbp, %rsp
    popq %rbp
    ret

ioapic_init:
    pushq %rbp
    movq %rsp, %rbp
    # Initialize I/O APIC
    movq %rbp, %rsp
    popq %rbp
    ret

    movq $1, %rax
    movq $0, %rax
    movq $0, %rax
pcb_create:
    pushq %rbp
    movq %rsp, %rbp
    # Create new PCB
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

pcb_destroy:
    pushq %rbp
    movq %rsp, %rbp
    # Destroy PCB
    movq %rbp, %rsp
    popq %rbp
    ret

pcb_get_state:
    pushq %rbp
    movq %rsp, %rbp
    # Get process state
    # Load variable PROCESS_READY
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

pcb_set_state:
    pushq %rbp
    movq %rsp, %rbp
    # Set process state
    movq %rbp, %rsp
    popq %rbp
    ret

pcb_set_cpu_affinity:
    pushq %rbp
    movq %rsp, %rbp
    # Set CPU affinity mask
    movq %rbp, %rsp
    popq %rbp
    ret

pcb_get_cpu_affinity:
    pushq %rbp
    movq %rsp, %rbp
    # Get CPU affinity mask
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

process_create:
    pushq %rbp
    movq %rsp, %rbp
    # Create new process
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
    # Terminate process
    movq %rbp, %rsp
    popq %rbp
    ret

process_fork:
    pushq %rbp
    movq %rsp, %rbp
    # Fork current process
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

process_exec:
    pushq %rbp
    movq %rsp, %rbp
    # Execute program
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

process_wait:
    pushq %rbp
    movq %rsp, %rbp
    # Wait for process
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

process_get_current:
    pushq %rbp
    movq %rsp, %rbp
    # Load variable current_process
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

process_set_priority:
    pushq %rbp
    movq %rsp, %rbp
    # Set process priority
    movq %rbp, %rsp
    popq %rbp
    ret

process_get_priority:
    pushq %rbp
    movq %rsp, %rbp
    # Get process priority
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

    movq $1, %rax
    movq $0, %rax
thread_create:
    pushq %rbp
    movq %rsp, %rbp
    # Create new thread
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
    # Create user-space thread
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

thread_destroy:
    pushq %rbp
    movq %rsp, %rbp
    # Destroy thread
    movq %rbp, %rsp
    popq %rbp
    ret

thread_yield:
    pushq %rbp
    movq %rsp, %rbp
    # Yield CPU to another thread
    movq %rbp, %rsp
    popq %rbp
    ret

thread_sleep:
    pushq %rbp
    movq %rsp, %rbp
    # Sleep for milliseconds
    movq %rbp, %rsp
    popq %rbp
    ret

thread_set_tls:
    pushq %rbp
    movq %rsp, %rbp
    # Set thread-local storage base
    movq %rbp, %rsp
    popq %rbp
    ret

thread_get_tls:
    pushq %rbp
    movq %rsp, %rbp
    # Get thread-local storage base
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

    movq $0, %rax
scheduler_init:
    pushq %rbp
    movq %rsp, %rbp
    # Initialize scheduler
    movq %rbp, %rsp
    popq %rbp
    ret

scheduler_add_process:
    pushq %rbp
    movq %rsp, %rbp
    # Add process to run queue
    movq %rbp, %rsp
    popq %rbp
    ret

scheduler_remove_process:
    pushq %rbp
    movq %rsp, %rbp
    # Remove process from run queue
    movq %rbp, %rsp
    popq %rbp
    ret

scheduler_pick_next:
    pushq %rbp
    movq %rsp, %rbp
    # Pick next process to run (CFS)
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

scheduler_pick_next_cpu:
    pushq %rbp
    movq %rsp, %rbp
    # Pick next process for specific CPU
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

scheduler_tick:
    pushq %rbp
    movq %rsp, %rbp
    # Scheduler tick
    movq %rbp, %rsp
    popq %rbp
    ret

scheduler_schedule:
    pushq %rbp
    movq %rsp, %rbp
    # Perform context switch
    movq %rbp, %rsp
    popq %rbp
    ret

scheduler_balance_load:
    pushq %rbp
    movq %rsp, %rbp
    # Balance load across CPUs
    movq %rbp, %rsp
    popq %rbp
    ret

context_save:
    pushq %rbp
    movq %rsp, %rbp
    # Save process context
    movq %rbp, %rsp
    popq %rbp
    ret

context_restore:
    pushq %rbp
    movq %rsp, %rbp
    # Restore process context
    movq %rbp, %rsp
    popq %rbp
    ret

context_switch:
    pushq %rbp
    movq %rsp, %rbp
    # Switch from one process to another
    movq %rbp, %rsp
    popq %rbp
    ret

fpu_save:
    pushq %rbp
    movq %rsp, %rbp
    # Save FPU/SSE state
    movq %rbp, %rsp
    popq %rbp
    ret

fpu_restore:
    pushq %rbp
    movq %rsp, %rbp
    # Restore FPU/SSE state
    movq %rbp, %rsp
    popq %rbp
    ret

tlb_flush:
    pushq %rbp
    movq %rsp, %rbp
    # Flush TLB
    movq %rbp, %rsp
    popq %rbp
    ret

tlb_flush_single:
    pushq %rbp
    movq %rsp, %rbp
    # Flush single TLB entry
    movq %rbp, %rsp
    popq %rbp
    ret

    # Load variable export
syscall_handler:
    pushq %rbp
    movq %rsp, %rbp
    movq $0, %rax
    pushq %rax
    # Load variable syscall_num
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4338916024
    movq $0, %rax
    pushq %rax
    popq %rdi
    call process_terminate
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4338916024:
    movq $1, %rax
    pushq %rax
    # Load variable syscall_num
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4338916856
    call process_fork
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4338916856:
    movq $2, %rax
    pushq %rax
    # Load variable syscall_num
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4338917560
    call process_get_current
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4338917560:
    movq $9, %rax
    pushq %rax
    # Load variable syscall_num
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4338918584
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
    call mmap
    # Load variable addr
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4338918584:
    movq $10, %rax
    pushq %rax
    # Load variable syscall_num
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4338919440
    movq $0, %rax
    pushq %rax
    movq $0, %rax
    pushq %rax
    popq %rdi
    popq %rsi
    call munmap
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4338919440:
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
    # Create shared memory segment
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

shm_create_anon:
    pushq %rbp
    movq %rsp, %rbp
    # Create anonymous shared memory
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

shm_attach:
    pushq %rbp
    movq %rsp, %rbp
    # Attach to shared memory
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

shm_detach:
    pushq %rbp
    movq %rsp, %rbp
    # Detach from shared memory
    movq %rbp, %rsp
    popq %rbp
    ret

shm_destroy:
    pushq %rbp
    movq %rsp, %rbp
    # Destroy shared memory
    movq %rbp, %rsp
    popq %rbp
    ret

shm_set_cow:
    pushq %rbp
    movq %rsp, %rbp
    # Enable copy-on-write for shared memory
    movq %rbp, %rsp
    popq %rbp
    ret

mq_create:
    pushq %rbp
    movq %rsp, %rbp
    # Create message queue
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

mq_send:
    pushq %rbp
    movq %rsp, %rbp
    # Send message
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

mq_send_priority:
    pushq %rbp
    movq %rsp, %rbp
    # Send message with priority
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

mq_receive:
    pushq %rbp
    movq %rsp, %rbp
    # Receive message
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

mq_receive_nonblock:
    pushq %rbp
    movq %rsp, %rbp
    # Receive message (non-blocking)
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

mq_destroy:
    pushq %rbp
    movq %rsp, %rbp
    # Destroy message queue
    movq %rbp, %rsp
    popq %rbp
    ret

pipe_create:
    pushq %rbp
    movq %rsp, %rbp
    # Create anonymous pipe
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

pipe_create_named:
    pushq %rbp
    movq %rsp, %rbp
    # Create named pipe (FIFO)
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

pipe_read:
    pushq %rbp
    movq %rsp, %rbp
    # Read from pipe
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

pipe_write:
    pushq %rbp
    movq %rsp, %rbp
    # Write to pipe
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

pipe_close:
    pushq %rbp
    movq %rsp, %rbp
    # Close pipe
    movq %rbp, %rsp
    popq %rbp
    ret

pipe_set_buffer_size:
    pushq %rbp
    movq %rsp, %rbp
    # Set pipe buffer size
    movq %rbp, %rsp
    popq %rbp
    ret

signal_send:
    pushq %rbp
    movq %rsp, %rbp
    # Send signal to process
    movq %rbp, %rsp
    popq %rbp
    ret

signal_send_rt:
    pushq %rbp
    movq %rsp, %rbp
    # Send real-time signal with value
    movq %rbp, %rsp
    popq %rbp
    ret

signal_handle:
    pushq %rbp
    movq %rsp, %rbp
    # Set signal handler
    movq %rbp, %rsp
    popq %rbp
    ret

signal_mask:
    pushq %rbp
    movq %rsp, %rbp
    # Mask signal
    movq %rbp, %rsp
    popq %rbp
    ret

signal_unmask:
    pushq %rbp
    movq %rsp, %rbp
    # Unmask signal
    movq %rbp, %rsp
    popq %rbp
    ret

socket_create:
    pushq %rbp
    movq %rsp, %rbp
    # Create Unix domain socket
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

socket_bind:
    pushq %rbp
    movq %rsp, %rbp
    # Bind socket to path
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

socket_listen:
    pushq %rbp
    movq %rsp, %rbp
    # Listen on socket
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

socket_accept:
    pushq %rbp
    movq %rsp, %rbp
    # Accept connection
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

socket_connect:
    pushq %rbp
    movq %rsp, %rbp
    # Connect to socket
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

socket_send:
    pushq %rbp
    movq %rsp, %rbp
    # Send data on socket
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

socket_recv:
    pushq %rbp
    movq %rsp, %rbp
    # Receive data from socket
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

socket_close:
    pushq %rbp
    movq %rsp, %rbp
    # Close socket
    movq %rbp, %rsp
    popq %rbp
    ret

socket_sendfd:
    pushq %rbp
    movq %rsp, %rbp
    # Send file descriptor over socket
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

socket_recvfd:
    pushq %rbp
    movq %rsp, %rbp
    # Receive file descriptor from socket
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

mmap:
    pushq %rbp
    movq %rsp, %rbp
    # Map memory region
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
    # Unmap memory region
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

mprotect:
    pushq %rbp
    movq %rsp, %rbp
    # Change memory protection
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

page_fault_handler:
    pushq %rbp
    movq %rsp, %rbp
    # Handle page fault - demand paging, COW
    movq %rbp, %rsp
    popq %rbp
    ret

copy_on_write:
    pushq %rbp
    movq %rsp, %rbp
    # Implement copy-on-write
    movq %rbp, %rsp
    popq %rbp
    ret

page_cache_add:
    pushq %rbp
    movq %rsp, %rbp
    # Add page to cache
    movq %rbp, %rsp
    popq %rbp
    ret

page_cache_get:
    pushq %rbp
    movq %rsp, %rbp
    # Get page from cache
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

page_reclaim:
    pushq %rbp
    movq %rsp, %rbp
    # Reclaim pages
    movq %rbp, %rsp
    popq %rbp
    ret

lru_evict:
    pushq %rbp
    movq %rsp, %rbp
    # LRU page eviction
    movq %rbp, %rsp
    popq %rbp
    ret

memory_compact:
    pushq %rbp
    movq %rsp, %rbp
    # Memory compaction
    movq %rbp, %rsp
    popq %rbp
    ret

oom_killer:
    pushq %rbp
    movq %rsp, %rbp
    # Out-of-memory killer
    movq %rbp, %rsp
    popq %rbp
    ret

isolate_address_space:
    pushq %rbp
    movq %rsp, %rbp
    # Isolate process address space
    movq %rbp, %rsp
    popq %rbp
    ret

set_user_mode:
    pushq %rbp
    movq %rsp, %rbp
    # Switch to user mode
    movq %rbp, %rsp
    popq %rbp
    ret

set_kernel_mode:
    pushq %rbp
    movq %rsp, %rbp
    # Switch to kernel mode
    movq %rbp, %rsp
    popq %rbp
    ret

check_capability:
    pushq %rbp
    movq %rsp, %rbp
    # Check process capability
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

pmm_init:
    pushq %rbp
    movq %rsp, %rbp
    # Physical memory manager init
    movq %rbp, %rsp
    popq %rbp
    ret

pmm_alloc_page:
    pushq %rbp
    movq %rsp, %rbp
    # Allocate physical page
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

pmm_free_page:
    pushq %rbp
    movq %rsp, %rbp
    # Free physical page
    movq %rbp, %rsp
    popq %rbp
    ret

vmm_init:
    pushq %rbp
    movq %rsp, %rbp
    # Virtual memory manager init
    movq %rbp, %rsp
    popq %rbp
    ret

vmm_map_page:
    pushq %rbp
    movq %rsp, %rbp
    # Map virtual page
    movq %rbp, %rsp
    popq %rbp
    ret

vmm_unmap_page:
    pushq %rbp
    movq %rsp, %rbp
    # Unmap virtual page
    movq %rbp, %rsp
    popq %rbp
    ret

heap_init:
    pushq %rbp
    movq %rsp, %rbp
    # Heap allocator init
    movq %rbp, %rsp
    popq %rbp
    ret

heap_alloc:
    pushq %rbp
    movq %rsp, %rbp
    # Allocate heap memory
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

heap_free:
    pushq %rbp
    movq %rsp, %rbp
    # Free heap memory
    movq %rbp, %rsp
    popq %rbp
    ret

idt_init:
    pushq %rbp
    movq %rsp, %rbp
    # IDT initialization
    movq %rbp, %rsp
    popq %rbp
    ret

pic_init:
    pushq %rbp
    movq %rsp, %rbp
    # PIC initialization
    movq %rbp, %rsp
    popq %rbp
    ret

pic_send_eoi:
    pushq %rbp
    movq %rsp, %rbp
    # Send EOI to PIC
    movq %rbp, %rsp
    popq %rbp
    ret

pit_init:
    pushq %rbp
    movq %rsp, %rbp
    # PIT initialization
    movq %rbp, %rsp
    popq %rbp
    ret

serial_init:
    pushq %rbp
    movq %rsp, %rbp
    # Serial port init
    movq %rbp, %rsp
    popq %rbp
    ret

serial_write_string:
    pushq %rbp
    movq %rsp, %rbp
    # Write string to serial
    movq %rbp, %rsp
    popq %rbp
    ret

vga_init:
    pushq %rbp
    movq %rsp, %rbp
    # VGA init
    movq %rbp, %rsp
    popq %rbp
    ret

vga_write_string:
    pushq %rbp
    movq %rsp, %rbp
    # Write string to VGA
    movq %rbp, %rsp
    popq %rbp
    ret

sem_create:
    pushq %rbp
    movq %rsp, %rbp
    # Create semaphore
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

sem_wait:
    pushq %rbp
    movq %rsp, %rbp
    # Wait on semaphore
    movq %rbp, %rsp
    popq %rbp
    ret

sem_post:
    pushq %rbp
    movq %rsp, %rbp
    # Post semaphore
    movq %rbp, %rsp
    popq %rbp
    ret

sem_destroy:
    pushq %rbp
    movq %rsp, %rbp
    # Destroy semaphore
    movq %rbp, %rsp
    popq %rbp
    ret

mutex_create:
    pushq %rbp
    movq %rsp, %rbp
    # Create mutex
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

mutex_lock:
    pushq %rbp
    movq %rsp, %rbp
    # Lock mutex
    movq %rbp, %rsp
    popq %rbp
    ret

mutex_unlock:
    pushq %rbp
    movq %rsp, %rbp
    # Unlock mutex
    movq %rbp, %rsp
    popq %rbp
    ret

mutex_destroy:
    pushq %rbp
    movq %rsp, %rbp
    # Destroy mutex
    movq %rbp, %rsp
    popq %rbp
    ret

    # Load variable export
exceptionHandler:
    pushq %rbp
    movq %rsp, %rbp
    call cli
    movq $14, %rax
    pushq %rax
    # Load variable vector
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4338955848
    movq $0, %rax
    pushq %rax
    movq $0, %rax
    pushq %rax
    popq %rdi
    popq %rsi
    call page_fault_handler
.L_else_4338955848:
    call serial_write_string
.L_while_start_4338956288:
    movq $1, %rax
    testq %rax, %rax
    jz .L_while_end_4338956288
    call hlt
    jmp .L_while_start_4338956288
.L_while_end_4338956288:
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
    jz .L_else_4338957408
    call scheduler_tick
    call scheduler_balance_load
    call scheduler_schedule
.L_else_4338957408:
    call apic_send_eoi
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
    # Load variable init_pid
    pushq %rax
    popq %rdi
    call scheduler_add_process
    movq %rbp, %rsp
    popq %rbp
    ret

.global kernel_init_phase3
kernel_init_phase3:
    pushq %rbp
    movq %rsp, %rbp
    call smp_init
    call apic_init
    call ioapic_init
    movq $100, %rax
    pushq %rax
    popq %rdi
    call apic_timer_init
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
    jz .L_else_4338962568
.L_else_4338962568:
    movq $1, %rax
    pushq %rax
    # Load variable is_valid
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4338964184
    call kernel_init_phase1
    call kernel_init_phase2
    call kernel_init_phase3
    call sti
    call serial_write_string
    call vga_write_string
    jmp .L_endif_4338964184
.L_else_4338964184:
.L_while_start_4338964088:
    movq $1, %rax
    testq %rax, %rax
    jz .L_while_end_4338964088
    call hlt
    jmp .L_while_start_4338964088
.L_while_end_4338964088:
.L_endif_4338964184:
.L_while_start_4338964480:
    movq $1, %rax
    testq %rax, %rax
    jz .L_while_end_4338964480
    call hlt
    jmp .L_while_start_4338964480
.L_while_end_4338964480:

