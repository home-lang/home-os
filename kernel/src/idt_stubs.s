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

/* Hardware IRQ stubs.
 *
 * The PIC is remapped to vectors 32-47 (see interrupts.home), so IRQ n
 * arrives as vector 32+n. These push a dummy error code for a uniform frame
 * and route to the same common stub as the exceptions; the Home dispatcher
 * tells the two apart by vector number.
 */
.macro IRQ_STUB num
.global isr\num
isr\num:
    push $0
    push $\num
    jmp isr_common_stub
.endm

IRQ_STUB 32   /* timer     */
IRQ_STUB 33   /* keyboard  */
IRQ_STUB 34
IRQ_STUB 35
IRQ_STUB 36
IRQ_STUB 37
IRQ_STUB 38
IRQ_STUB 39
IRQ_STUB 40
IRQ_STUB 41
IRQ_STUB 42
IRQ_STUB 43
IRQ_STUB 44
IRQ_STUB 45
IRQ_STUB 46
IRQ_STUB 47

/* Every vector without a stub of its own. Leaving them absent from the IDT
 * turns a stray interrupt into a triple fault with nothing on the console;
 * routing them here makes it a message.
 */
.global isr_unhandled
isr_unhandled:
    push $0
    push $255
    jmp isr_common_stub

/* Address lookup, so the IDT can be filled by index from Home rather than by
 * 256 hand-written references. Home cannot name a linker symbol directly, so
 * this is reached through the extern function below.
 */
.section .rodata
.align 8
isr_stub_table:
    .quad isr0,  isr1,  isr2,  isr3,  isr4,  isr5,  isr6,  isr7
    .quad isr8,  isr9,  isr10, isr11, isr12, isr13, isr14, isr15
    .quad isr16, isr17, isr18, isr19, isr20, isr21
    .quad isr_unhandled, isr_unhandled, isr_unhandled, isr_unhandled
    .quad isr_unhandled, isr_unhandled, isr_unhandled, isr_unhandled
    .quad isr30, isr31
    .quad isr32, isr33, isr34, isr35, isr36, isr37, isr38, isr39
    .quad isr40, isr41, isr42, isr43, isr44, isr45, isr46, isr47
isr_stub_table_end:

.section .text

/* u64 isr_stub_addr(u64 vector) — the stub for a vector, or the catch-all. */
.global isr_stub_addr
isr_stub_addr:
    lea isr_stub_table(%rip), %rax
    cmp $48, %rdi
    jae 1f
    mov (%rax,%rdi,8), %rax
    ret
1:  lea isr_unhandled(%rip), %rax
    ret

/* Common ISR stub - saves state and calls the Home interrupt dispatcher */
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

    /* Three arguments, all in registers. The frame also holds CS, RFLAGS,
     * RSP and SS, but passing them would put the seventh on the stack, and a
     * stack-passed argument across the assembly/Home boundary is a needless
     * place for the two calling conventions to disagree. A handler that wants
     * them can walk the frame.
     *
     * Offsets from %rsp, after 15 register pushes (120 bytes):
     *   120 vector, 128 error code, 136 RIP, 144 CS, 152 RFLAGS, 160 RSP,
     *   168 SS
     */
    mov 120(%rsp), %rdi  /* vector */
    mov 128(%rsp), %rsi  /* error code */
    mov 136(%rsp), %rdx  /* RIP */

    /* Align to 16 bytes for the System V ABI, keeping the old %rsp to
     * restore from — `and` cannot be undone. */
    mov %rsp, %rbp
    and $-16, %rsp

    call interrupt_dispatch

    mov %rbp, %rsp

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
