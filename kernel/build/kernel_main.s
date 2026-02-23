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
    jz .L_else_4314016840
.L_else_4314016840:
    movq $0, %rax
    pushq %rax
    # Load variable boot_info (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314017536
    # Load variable boot_info (not in locals)
    pushq %rax
    popq %rdi
    call parse_boot_info
.L_else_4314017536:
    call post_init_integrations
.L_while_start_4314022256:
    movq $1, %rax
    testq %rax, %rax
    jz .L_while_end_4314022256
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -312(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314020320
.L_else_4314020320:
    pushq %rax
    movq $3, %rax
    pushq %rax
    movq -320(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314021888
.L_else_4314021888:
    jmp .L_while_start_4314022256
.L_while_end_4314022256:

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
.L_while_start_4314031424:
    # Load variable total_size (not in locals)
    pushq %rax
    # Load variable offset (not in locals)
    popq %rcx
    testq %rax, %rax
    jz .L_while_end_4314031424
    movq $0, %rax
    pushq %rax
    # Load variable tag_type (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314028576
.L_else_4314028576:
    movq $6, %rax
    pushq %rax
    # Load variable tag_type (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314030376
    jmp .L_endif_4314030376
.L_else_4314030376:
    movq $8, %rax
    pushq %rax
    # Load variable tag_type (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314030272
.L_else_4314030272:
.L_endif_4314030376:
    jmp .L_while_start_4314031424
.L_while_end_4314031424:
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
    jz .L_else_4314062368
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
    jz .L_else_4314041008
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4314041008:
    movq $0, %rax
    pushq %rax
    movq -336(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314045632
    jmp .L_endif_4314045632
.L_else_4314045632:
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4313325710(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
.L_endif_4314045632:
    jmp .L_endif_4314062368
.L_else_4314062368:
    movq -104(%rbp), %rax
    pushq %rax
    # Load variable vector (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314062264
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -344(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314050304
    jmp .L_endif_4314050304
.L_else_4314050304:
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4313326283(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
.L_endif_4314050304:
    jmp .L_endif_4314062264
.L_else_4314062264:
    movq -72(%rbp), %rax
    pushq %rax
    # Load variable vector (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314062160
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4313326385(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
    jmp .L_endif_4314062160
.L_else_4314062160:
    movq -8(%rbp), %rax
    pushq %rax
    # Load variable vector (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314062056
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -352(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314053664
    jmp .L_endif_4314053664
.L_else_4314053664:
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4313326626(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
.L_endif_4314053664:
    jmp .L_endif_4314062056
.L_else_4314062056:
    movq -56(%rbp), %rax
    pushq %rax
    # Load variable vector (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314061952
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -360(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314056272
    jmp .L_endif_4314056272
.L_else_4314056272:
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4313326885(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
.L_endif_4314056272:
    jmp .L_endif_4314061952
.L_else_4314061952:
    movq -32(%rbp), %rax
    pushq %rax
    # Load variable vector (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314061848
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -368(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314059376
.L_else_4314059376:
    jmp .L_endif_4314061848
.L_else_4314061848:
    # Load variable rsp (not in locals)
    pushq %rax
    # Load variable rip (not in locals)
    pushq %rax
    leaq .L_str_4313327520(%rip), %rax
    pushq %rax
    popq %rdi
    popq %rsi
    popq %rdx
    call kernel_panic
.L_endif_4314061848:
.L_endif_4314061952:
.L_endif_4314062056:
.L_endif_4314062160:
.L_endif_4314062264:
.L_endif_4314062368:
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
    jz .L_else_4314069264
    pushq %rax
    movq $0, %rax
    pushq %rax
    movq -376(%rbp), %rax
    popq %rcx
    cmpq %rcx, %rax
    setne %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314066232
.L_else_4314066232:
    jmp .L_endif_4314069264
.L_else_4314069264:
    movq -160(%rbp), %rax
    pushq %rax
    # Load variable irq (not in locals)
    popq %rcx
    cmpq %rcx, %rax
    sete %al
    movzbq %al, %rax
    testq %rax, %rax
    jz .L_else_4314069160
    jmp .L_endif_4314069160
.L_else_4314069160:
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
    jz .L_else_4314069056
    jmp .L_endif_4314069056
.L_else_4314069056:
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
    jz .L_else_4314068952
.L_else_4314068952:
.L_endif_4314069056:
.L_endif_4314069160:
.L_endif_4314069264:
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
    jz .L_else_4314073128
    movq %rbp, %rsp
    popq %rbp
    ret
.L_else_4314073128:
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
.L_while_start_4314083224:
    movq $1, %rax
    testq %rax, %rax
    jz .L_while_end_4314083224
    jmp .L_while_start_4314083224
.L_while_end_4314083224:
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
    jz .L_else_4314088392
.L_else_4314088392:
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
.L_str_4313325710:
    .asciz "Page fault in kernel mode"
.L_str_4313326283:
    .asciz "GPF in kernel mode"
.L_str_4313326385:
    .asciz "Double fault"
.L_str_4313326626:
    .asciz "Divide error in kernel"
.L_str_4313326885:
    .asciz "Invalid opcode in kernel"
.L_str_4313327520:
    .asciz "Unhandled exception"
