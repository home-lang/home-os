/* ISR (Interrupt Service Routine) stubs for home-os */
/* Handles CPU exceptions and passes control to Zig handler */

.section .text
.code64

/* Macro for exceptions WITHOUT error code */
.macro ISR_NOERRCODE num
.global isr\num
isr\num:
    push $0              /* Push dummy error code */
    push $\num           /* Push interrupt number */
    jmp isr_common_stub
.endm

/* Macro for exceptions WITH error code */
.macro ISR_ERRCODE num
.global isr\num
isr\num:
    push $\num           /* Push interrupt number (error code already pushed by CPU) */
    jmp isr_common_stub
.endm

/* CPU Exception ISRs (0-31) */
ISR_NOERRCODE 0   /* Division By Zero */
ISR_NOERRCODE 1   /* Debug */
ISR_NOERRCODE 2   /* Non-Maskable Interrupt */
ISR_NOERRCODE 3   /* Breakpoint */
ISR_NOERRCODE 4   /* Overflow */
ISR_NOERRCODE 5   /* Bound Range Exceeded */
ISR_NOERRCODE 6   /* Invalid Opcode */
ISR_NOERRCODE 7   /* Device Not Available */
ISR_ERRCODE   8   /* Double Fault */
ISR_NOERRCODE 9   /* Coprocessor Segment Overrun */
ISR_ERRCODE   10  /* Invalid TSS */
ISR_ERRCODE   11  /* Segment Not Present */
ISR_ERRCODE   12  /* Stack-Segment Fault */
ISR_ERRCODE   13  /* General Protection Fault */
ISR_ERRCODE   14  /* Page Fault */
ISR_NOERRCODE 15  /* Reserved */
ISR_NOERRCODE 16  /* x87 Floating-Point Exception */
ISR_ERRCODE   17  /* Alignment Check */
ISR_NOERRCODE 18  /* Machine Check */
ISR_NOERRCODE 19  /* SIMD Floating-Point Exception */
ISR_NOERRCODE 20  /* Virtualization Exception */
ISR_ERRCODE   21  /* Control Protection Exception */
ISR_NOERRCODE 30  /* Security Exception */
ISR_NOERRCODE 31  /* Reserved */

/* Common ISR stub - saves state and calls Zig exception handler */
isr_common_stub:
    /* Save all registers */
    push %rax
    push %rbx
    push %rcx
    push %rdx
    push %rsi
    push %rdi
    push %rbp
    push %r8
    push %r9
    push %r10
    push %r11
    push %r12
    push %r13
    push %r14
    push %r15

    /* Call Zig exception handler */
    /* Stack layout (from top):
       - Saved registers (15 * 8 bytes)
       - Interrupt number (8 bytes)
       - Error code (8 bytes)
       - RIP (8 bytes) - pushed by CPU
       - CS (8 bytes) - pushed by CPU
       - RFLAGS (8 bytes) - pushed by CPU
       - RSP (8 bytes) - pushed by CPU
       - SS (8 bytes) - pushed by CPU
    */

    /* Get interrupt number and error code */
    mov 120(%rsp), %rdi  /* vector (interrupt number) */
    mov 128(%rsp), %rsi  /* error code */

    /* Get CPU-pushed values */
    mov 136(%rsp), %rdx  /* RIP */
    mov 144(%rsp), %rcx  /* CS */
    mov 152(%rsp), %r8   /* RFLAGS */
    mov 160(%rsp), %r9   /* RSP */

    /* SS is 7th argument - push to stack for calling convention */
    mov 168(%rsp), %rax  /* SS */
    push %rax

    /* Align stack to 16 bytes (required by System V ABI) */
    mov %rsp, %rbp
    and $-16, %rsp

    /* Call exceptionHandler(vector, error_code, rip, cs, rflags, rsp, ss) */
    call exceptionHandler

    /* Restore stack */
    mov %rbp, %rsp
    pop %rax

    /* Restore all registers */
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %r11
    pop %r10
    pop %r9
    pop %r8
    pop %rbp
    pop %rdi
    pop %rsi
    pop %rdx
    pop %rcx
    pop %rbx
    pop %rax

    /* Remove error code and interrupt number from stack */
    add $16, %rsp

    /* Return from interrupt */
    iretq
