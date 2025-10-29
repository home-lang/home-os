.section .text
.global kernel_main

    movq $0, %rax
    # Load variable x36d76289
    movq $0, %rax
    # Load variable x3F8
    movq $0, %rax
    # Load variable xB8000
    movq $80, %rax
    movq $25, %rax
disable_interrupts:
    pushq %rbp
    movq %rsp, %rbp
    cli
    movq %rbp, %rsp
    popq %rbp
    ret

enable_interrupts:
    pushq %rbp
    movq %rsp, %rbp
    sti
    movq %rbp, %rsp
    popq %rbp
    ret

halt_cpu:
    pushq %rbp
    movq %rsp, %rbp
    hlt
    movq %rbp, %rsp
    popq %rbp
    ret

serial_init:
    pushq %rbp
    movq %rsp, %rbp
    # serial_init - COM1 initialization
    movq %rbp, %rsp
    popq %rbp
    ret

serial_write_char:
    pushq %rbp
    movq %rsp, %rbp
    # serial_write_char
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

vga_write_char:
    pushq %rbp
    movq %rsp, %rbp
    # vga_write_char
    movq %rbp, %rsp
    popq %rbp
    ret

pmm_init:
    pushq %rbp
    movq %rsp, %rbp
    # pmm_init - physical memory manager
    movq %rbp, %rsp
    popq %rbp
    ret

vmm_init:
    pushq %rbp
    movq %rsp, %rbp
    # vmm_init - virtual memory manager
    movq %rbp, %rsp
    popq %rbp
    ret

heap_init:
    pushq %rbp
    movq %rsp, %rbp
    # heap_init - kernel heap
    movq %rbp, %rsp
    popq %rbp
    ret

idt_init:
    pushq %rbp
    movq %rsp, %rbp
    # idt_init - interrupt descriptor table
    movq %rbp, %rsp
    popq %rbp
    ret

is_zero:
    pushq %rbp
    movq %rsp, %rbp
    movq $0, %rax
    pushq %rax
    # Load variable value
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4354628264
    movq $1, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    jmp .L_endif_4354628264
.L_else_4354628264:
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
.L_endif_4354628264:
    movq %rbp, %rsp
    popq %rbp
    ret

max:
    pushq %rbp
    movq %rsp, %rbp
    # Load variable b
    pushq %rax
    # Load variable a
    popq %rcx
    testq %rax, %rax
    jz .L_else_4354629032
    # Load variable a
    movq %rbp, %rsp
    popq %rbp
    ret
    jmp .L_endif_4354629032
.L_else_4354629032:
    # Load variable b
    movq %rbp, %rsp
    popq %rbp
    ret
.L_endif_4354629032:
    movq %rbp, %rsp
    popq %rbp
    ret

add:
    pushq %rbp
    movq %rsp, %rbp
    movq $0, %rax
    # add operation
    # Load variable result
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

    # Load variable export
.global kernel_main
kernel_main:
    pushq %rbp
    movq %rsp, %rbp
    call disable_interrupts
    # Load variable magic
    pushq %rax
    popq %rdi
    call is_zero
    movq $0, %rax
    pushq %rax
    # Load variable is_multiboot
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4354634360
    call serial_init
    call vga_init
    call pmm_init
    call vmm_init
    call heap_init
    call idt_init
    movq $20, %rax
    pushq %rax
    movq $10, %rax
    pushq %rax
    popq %rdi
    popq %rsi
    call add
    movq $50, %rax
    pushq %rax
    # Load variable x
    pushq %rax
    popq %rdi
    popq %rsi
    call max
    movq $100, %rax
    pushq %rax
    # Load variable y
    pushq %rax
    popq %rdi
    popq %rsi
    call max
    call enable_interrupts
    jmp .L_endif_4354634360
.L_else_4354634360:
    call halt_cpu
.L_endif_4354634360:
.L_while_start_4354634656:
    movq $1, %rax
    testq %rax, %rax
    jz .L_while_end_4354634656
    call halt_cpu
    jmp .L_while_start_4354634656
.L_while_end_4354634656:

