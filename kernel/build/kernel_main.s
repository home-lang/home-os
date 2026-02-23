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
    jz .L_else_4380077128
.L_else_4380077128:
    movq $0, %rax
    pushq %rax
    # Load variable boot_info (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380077824
    # Load variable boot_info (not in locals)
    pushq %rax
    popq %rdi
    call parse_boot_info
.L_else_4380077824:
    call post_init_integrations
.L_while_start_4380082544:
    movq $1, %rax
    testq %rax, %rax
    jz .L_while_end_4380082544
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -312(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380080608
.L_else_4380080608:
    pushq %rax
    movq $3, %rax
    pushq %rax
    movq -320(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380082176
.L_else_4380082176:
    jmp .L_while_start_4380082544
.L_while_end_4380082544:

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
.L_while_start_4380091712:
    # Load variable total_size (not in locals)
    pushq %rax
    # Load variable offset (not in locals)
    popq %rcx
    testq %rax, %rax
    jz .L_while_end_4380091712
    movq $0, %rax
    pushq %rax
    # Load variable tag_type (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380088864
.L_else_4380088864:
    movq $6, %rax
    pushq %rax
    # Load variable tag_type (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380090664
    jmp .L_endif_4380090664
.L_else_4380090664:
    movq $8, %rax
    pushq %rax
    # Load variable tag_type (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380090560
.L_else_4380090560:
.L_endif_4380090664:
    jmp .L_while_start_4380091712
.L_while_end_4380091712:
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
    jz .L_else_4380122656
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
    jz .L_else_4380101296
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4380101296:
    movq $0, %rax
    pushq %rax
    movq -336(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380105920
    jmp .L_endif_4380105920
.L_else_4380105920:
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4379385998(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
.L_endif_4380105920:
    jmp .L_endif_4380122656
.L_else_4380122656:
    movq -104(%rbp), %rax
    pushq %rax
    # Load variable vector (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380122552
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -344(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380110592
    jmp .L_endif_4380110592
.L_else_4380110592:
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4379386571(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
.L_endif_4380110592:
    jmp .L_endif_4380122552
.L_else_4380122552:
    movq -72(%rbp), %rax
    pushq %rax
    # Load variable vector (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380122448
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4379386673(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
    jmp .L_endif_4380122448
.L_else_4380122448:
    movq -8(%rbp), %rax
    pushq %rax
    # Load variable vector (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380122344
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -352(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380113952
    jmp .L_endif_4380113952
.L_else_4380113952:
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4379386914(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
.L_endif_4380113952:
    jmp .L_endif_4380122344
.L_else_4380122344:
    movq -56(%rbp), %rax
    pushq %rax
    # Load variable vector (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380122240
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -360(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380116560
    jmp .L_endif_4380116560
.L_else_4380116560:
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4379387173(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
.L_endif_4380116560:
    jmp .L_endif_4380122240
.L_else_4380122240:
    movq -32(%rbp), %rax
    pushq %rax
    # Load variable vector (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380122136
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -368(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380119664
.L_else_4380119664:
    jmp .L_endif_4380122136
.L_else_4380122136:
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4379387808(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
.L_endif_4380122136:
.L_endif_4380122240:
.L_endif_4380122344:
.L_endif_4380122448:
.L_endif_4380122552:
.L_endif_4380122656:
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
    jz .L_else_4380129552
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -376(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380126520
.L_else_4380126520:
    jmp .L_endif_4380129552
.L_else_4380129552:
    movq -160(%rbp), %rax
    pushq %rax
    # Load variable irq (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4380129448
    jmp .L_endif_4380129448
.L_else_4380129448:
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
    jz .L_else_4380129344
    jmp .L_endif_4380129344
.L_else_4380129344:
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
    jz .L_else_4380129240
.L_else_4380129240:
.L_endif_4380129344:
.L_endif_4380129448:
.L_endif_4380129552:
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
    jz .L_else_4380133416
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4380133416:
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
.L_while_start_4380143512:
    movq $1, %rax
    testq %rax, %rax
    jz .L_while_end_4380143512
    jmp .L_while_start_4380143512
.L_while_end_4380143512:
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
    jz .L_else_4380148680
.L_else_4380148680:
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
.L_str_4379385998:
    .asciz "Page fault in kernel mode"
.L_str_4379386571:
    .asciz "GPF in kernel mode"
.L_str_4379386673:
    .asciz "Double fault"
.L_str_4379386914:
    .asciz "Divide error in kernel"
.L_str_4379387173:
    .asciz "Invalid opcode in kernel"
.L_str_4379387808:
    .asciz "Unhandled exception"
