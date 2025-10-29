.section .text
.global kernel_main

    # Load variable export
.global kernel_main
kernel_main:
    pushq %rbp
    movq %rsp, %rbp
    movq $42, %rax
    # Load variable magic
.L_while_start_4313450872:
    movq $1, %rax
    testq %rax, %rax
    jz .L_while_end_4313450872
    jmp .L_while_start_4313450872
.L_while_end_4313450872:

