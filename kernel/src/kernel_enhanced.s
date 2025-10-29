.section .text
.global kernel_main

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

outb:
    pushq %rbp
    movq %rsp, %rbp
    # outb - write byte to port
    movq %rbp, %rsp
    popq %rbp
    ret

inb:
    pushq %rbp
    movq %rsp, %rbp
    # inb - read byte from port
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
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
    jz .L_else_4344265136
    movq $1, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    jmp .L_endif_4344265136
.L_else_4344265136:
    movq $0, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
.L_endif_4344265136:
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
    jz .L_else_4344265904
    # Load variable a
    movq %rbp, %rsp
    popq %rbp
    ret
    jmp .L_endif_4344265904
.L_else_4344265904:
    # Load variable b
    movq %rbp, %rsp
    popq %rbp
    ret
.L_endif_4344265904:
    movq %rbp, %rsp
    popq %rbp
    ret

add:
    pushq %rbp
    movq %rsp, %rbp
    movq $42, %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

double:
    pushq %rbp
    movq %rsp, %rbp
    # Load variable value
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

init_vga:
    pushq %rbp
    movq %rsp, %rbp
    # init_vga - setup video memory
    movq %rbp, %rsp
    popq %rbp
    ret

init_serial:
    pushq %rbp
    movq %rsp, %rbp
    # init_serial - configure COM1
    movq %rbp, %rsp
    popq %rbp
    ret

init_idt:
    pushq %rbp
    movq %rsp, %rbp
    # init_idt - setup interrupt handlers
    movq %rbp, %rsp
    popq %rbp
    ret

init_memory:
    pushq %rbp
    movq %rsp, %rbp
    # init_memory - setup paging
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
    jz .L_else_4344270912
    call init_vga
    call init_serial
    call init_idt
    call init_memory
    movq $20, %rax
    pushq %rax
    movq $10, %rax
    pushq %rax
    popq %rdi
    popq %rsi
    call add
    # Load variable x
    pushq %rax
    popq %rdi
    call double
    # Load variable y
    pushq %rax
    # Load variable x
    pushq %rax
    popq %rdi
    popq %rsi
    call max
    jmp .L_endif_4344270912
.L_else_4344270912:
    call halt_cpu
.L_endif_4344270912:
    call enable_interrupts
.L_while_start_4344271352:
    movq $1, %rax
    testq %rax, %rax
    jz .L_while_end_4344271352
    call halt_cpu
    jmp .L_while_start_4344271352
.L_while_end_4344271352:

