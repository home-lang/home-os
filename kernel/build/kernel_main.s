.section .text
.global kernel_main

    movq $0, %rax
    pushq %rax
    movq $1, %rax
    pushq %rax
    movq $2, %rax
    pushq %rax
    movq $3, %rax
    pushq %rax
    movq $4, %rax
    pushq %rax
    movq $5, %rax
    pushq %rax
    movq $6, %rax
    pushq %rax
    movq $7, %rax
    pushq %rax
    movq $8, %rax
    pushq %rax
    movq $10, %rax
    pushq %rax
    movq $11, %rax
    pushq %rax
    movq $12, %rax
    pushq %rax
    movq $13, %rax
    pushq %rax
    movq $14, %rax
    pushq %rax
    movq $16, %rax
    pushq %rax
    movq $17, %rax
    pushq %rax
    movq $18, %rax
    pushq %rax
    movq $19, %rax
    pushq %rax
    movq $32, %rax
    pushq %rax
    movq $33, %rax
    pushq %rax
    movq $34, %rax
    pushq %rax
    movq $35, %rax
    pushq %rax
    movq $36, %rax
    pushq %rax
    movq $37, %rax
    pushq %rax
    movq $38, %rax
    pushq %rax
    movq $39, %rax
    pushq %rax
    movq $40, %rax
    pushq %rax
    movq $41, %rax
    pushq %rax
    movq $42, %rax
    pushq %rax
    movq $43, %rax
    pushq %rax
    movq $44, %rax
    pushq %rax
    movq $45, %rax
    pushq %rax
    movq $46, %rax
    pushq %rax
    movq $47, %rax
    pushq %rax
    movq $128, %rax
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq $0, %rax
    pushq %rax
.global kernel_main
kernel_main:
    pushq %rbp
    movq %rsp, %rbp
    movq $920085129, %rax
    pushq %rax
    # Load variable magic (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349930568
.L_else_4349930568:
    movq $0, %rax
    pushq %rax
    # Load variable boot_info (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349931264
    # Load variable boot_info (not in locals)
    pushq %rax
    popq %rdi
    call parse_boot_info
.L_else_4349931264:
    call post_init_integrations
.L_while_start_4349935984:
    movq $1, %rax
    testq %rax, %rax
    jz .L_while_end_4349935984
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -312(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349934048
.L_else_4349934048:
    pushq %rax
    movq $3, %rax
    pushq %rax
    movq -320(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349935616
.L_else_4349935616:
    jmp .L_while_start_4349935984
.L_while_end_4349935984:

_start_x86_64:
    pushq %rbp
    movq %rsp, %rbp
    # Load variable boot_info (not in locals)
    pushq %rax
    # Load variable magic (not in locals)
    pushq %rax
    popq %rdi
    popq %rsi
    call kernel_main

_start_aarch64:
    pushq %rbp
    movq %rsp, %rbp

_start_rpi:
    pushq %rbp
    movq %rsp, %rbp

_start_riscv:
    pushq %rbp
    movq %rsp, %rbp

parse_boot_info:
    pushq %rbp
    movq %rsp, %rbp
.L_while_start_4349945152:
    # Load variable total_size (not in locals)
    pushq %rax
    # Load variable offset (not in locals)
    popq %rcx
    testq %rax, %rax
    jz .L_while_end_4349945152
    movq $0, %rax
    pushq %rax
    # Load variable tag_type (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349942304
.L_else_4349942304:
    movq $6, %rax
    pushq %rax
    # Load variable tag_type (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349944104
    jmp .L_endif_4349944104
.L_else_4349944104:
    movq $8, %rax
    pushq %rax
    # Load variable tag_type (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349944000
.L_else_4349944000:
.L_endif_4349944104:
    jmp .L_while_start_4349945152
.L_while_end_4349945152:
    movq %rbp, %rsp
    popq %rbp
    ret

post_init_integrations:
    pushq %rbp
    movq %rsp, %rbp
    movq %rbp, %rsp
    popq %rbp
    ret

exception_handler:
    pushq %rbp
    movq %rsp, %rbp
    movq -112(%rbp), %rax
    pushq %rax
    # Load variable vector (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349976096
    pushq %rax
    pushq %rax
    movq $0, %rax
    pushq %rax
    # Load variable result (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349954736
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4349954736:
    movq $0, %rax
    pushq %rax
    movq -336(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349959360
    jmp .L_endif_4349959360
.L_else_4349959360:
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4349239438(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
.L_endif_4349959360:
    jmp .L_endif_4349976096
.L_else_4349976096:
    movq -104(%rbp), %rax
    pushq %rax
    # Load variable vector (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349975992
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -344(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349964032
    jmp .L_endif_4349964032
.L_else_4349964032:
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4349240011(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
.L_endif_4349964032:
    jmp .L_endif_4349975992
.L_else_4349975992:
    movq -72(%rbp), %rax
    pushq %rax
    # Load variable vector (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349975888
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4349240113(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
    jmp .L_endif_4349975888
.L_else_4349975888:
    movq -8(%rbp), %rax
    pushq %rax
    # Load variable vector (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349975784
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -352(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349967392
    jmp .L_endif_4349967392
.L_else_4349967392:
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4349240354(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
.L_endif_4349967392:
    jmp .L_endif_4349975784
.L_else_4349975784:
    movq -56(%rbp), %rax
    pushq %rax
    # Load variable vector (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349975680
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -360(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349970000
    jmp .L_endif_4349970000
.L_else_4349970000:
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4349240613(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
.L_endif_4349970000:
    jmp .L_endif_4349975680
.L_else_4349975680:
    movq -32(%rbp), %rax
    pushq %rax
    # Load variable vector (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349975576
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -368(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349973104
.L_else_4349973104:
    jmp .L_endif_4349975576
.L_else_4349975576:
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4349241248(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
.L_endif_4349975576:
.L_endif_4349975680:
.L_endif_4349975784:
.L_endif_4349975888:
.L_endif_4349975992:
.L_endif_4349976096:
    movq %rbp, %rsp
    popq %rbp
    ret

irq_handler:
    pushq %rbp
    movq %rsp, %rbp
    movq -152(%rbp), %rax
    pushq %rax
    # Load variable irq (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349982992
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -376(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349979960
.L_else_4349979960:
    jmp .L_endif_4349982992
.L_else_4349982992:
    movq -160(%rbp), %rax
    pushq %rax
    # Load variable irq (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349982888
    jmp .L_endif_4349982888
.L_else_4349982888:
    movq -272(%rbp), %rax
    pushq %rax
    # Load variable irq (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    pushq %rax
    movq -264(%rbp), %rax
    pushq %rax
    # Load variable irq (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    popq %rcx
    testq %rax, %rax
    jz .L_else_4349982784
    jmp .L_endif_4349982784
.L_else_4349982784:
    movq $55, %rax
    pushq %rax
    # Load variable irq (not in locals)
    popq %rcx
    pushq %rax
    movq $48, %rax
    pushq %rax
    # Load variable irq (not in locals)
    popq %rcx
    popq %rcx
    testq %rax, %rax
    jz .L_else_4349982680
.L_else_4349982680:
.L_endif_4349982784:
.L_endif_4349982888:
.L_endif_4349982992:
    movq %rbp, %rsp
    popq %rbp
    ret

syscall_entry:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rax
    movq $0, %rax
    pushq %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4349986856
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4349986856:
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

.global kernel_panic
kernel_panic:
    pushq %rbp
    movq %rsp, %rbp
    # Load variable rsp (not in locals)
    pushq %rax
    popq %rdi
    call print_stack_trace
.L_while_start_4349996952:
    movq $1, %rax
    testq %rax, %rax
    jz .L_while_end_4349996952
    jmp .L_while_start_4349996952
.L_while_end_4349996952:
    movq %rbp, %rsp
    popq %rbp
    ret

print_stack_trace:
    pushq %rbp
    movq %rsp, %rbp
    # Load variable rsp (not in locals)
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq $0, %rax
    pushq %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4350002120
.L_else_4350002120:
    movq %rbp, %rsp
    popq %rbp
    ret

.global kernel_is_running
kernel_is_running:
    pushq %rbp
    movq %rsp, %rbp
    movq -288(%rbp), %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

in_interrupt_context:
    pushq %rbp
    movq %rsp, %rbp
    movq -296(%rbp), %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

get_interrupt_nesting:
    pushq %rbp
    movq %rsp, %rbp
    movq -304(%rbp), %rax
    movq %rbp, %rsp
    popq %rbp
    ret
    movq %rbp, %rsp
    popq %rbp
    ret

.global kernel_shutdown
kernel_shutdown:
    pushq %rbp
    movq %rsp, %rbp
    movq %rbp, %rsp
    popq %rbp
    ret

.global kernel_reboot
kernel_reboot:
    pushq %rbp
    movq %rsp, %rbp
    movq %rbp, %rsp
    popq %rbp
    ret


.section .rodata
.L_str_4349239438:
    .asciz "Page fault in kernel mode"
.L_str_4349240011:
    .asciz "GPF in kernel mode"
.L_str_4349240113:
    .asciz "Double fault"
.L_str_4349240354:
    .asciz "Divide error in kernel"
.L_str_4349240613:
    .asciz "Invalid opcode in kernel"
.L_str_4349241248:
    .asciz "Unhandled exception"
