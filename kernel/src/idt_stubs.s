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

/* ---------------------------------------------------------------------------
 * System call entry — int $0x80
 *
 * A separate stub from the interrupt path: the interrupt path saves fifteen
 * registers so a handler can inspect the interrupted state, which a syscall
 * does not need, and it has no way to put a return value back in %rax.
 *
 * Arguments arrive as they do on Linux: %rax the call number, then %rdi,
 * %rsi, %rdx. The handler is called with them shifted along, and its return
 * value goes back to the caller in %rax.
 * ------------------------------------------------------------------------ */
/* u64 syscall_entry_addr(void) — the address of the entry below, so the IDT
 * can be built from Home. */
.set KERNEL_CONTEXT_MAX, 8

.global syscall_entry_addr
syscall_entry_addr:
    lea syscall_entry(%rip), %rax
    ret

.global syscall_entry
syscall_entry:
    /* %rbp first, because this stub uses it as the scratch that holds the
     * stack pointer across the ABI alignment below. It is callee-saved, so
     * the handler would have preserved it — but the stub clobbered it before
     * the handler was ever called, and every syscall returned to userspace
     * with %rbp pointing into the kernel stack.
     *
     * Nothing noticed while the only userspace programs were hand-written
     * assembly that never used a frame pointer. The first compiled program
     * to make a syscall faulted on its next local-variable access. */
    push %rbp

    /* The other callee-saved registers are preserved by the handler; these
     * are the caller-saved ones the userspace program expects to keep. %rax
     * is not saved: it carries the return value out. */
    push %rcx
    push %r11
    push %rdi
    push %rsi
    push %rdx
    push %r8
    push %r9
    push %r10

    /* syscall_entry_dispatch(nr, a1, a2, a3, frame)
     *
     * `frame` is where the pushes above ended up, with the iretq frame just
     * beyond them — the whole user context in one place. fork copies it into
     * the child, and enter_usermode_resume reads it back in the same order.
     * Passing the address costs nothing here and saves the dispatcher having
     * to reconstruct a layout only this stub knows. */
    push %rax           /* the syscall number's slot becomes the child's
                         * return value, and keeps the block 16-byte aligned */
    mov %rsp, %r9       /* frame -> 5th argument, before %rax is reused */

    mov %rdx, %rcx      /* a3 -> 4th argument */
    mov %rsi, %rdx      /* a2 -> 3rd */
    mov %rdi, %rsi      /* a1 -> 2nd */
    mov %rax, %rdi      /* nr -> 1st */
    mov %r9, %r8        /* frame -> 5th */

    mov %rsp, %rbp
    and $-16, %rsp
    call syscall_entry_dispatch
    mov %rbp, %rsp

    add $8, %rsp        /* drop the slot pushed above */

    pop %r10
    pop %r9
    pop %r8
    pop %rdx
    pop %rsi
    pop %rdi
    pop %r11
    pop %rcx
    pop %rbp
    iretq

/* ---------------------------------------------------------------------------
 * enter_usermode(rip, rsp) — drop to ring 3 and never come back.
 *
 * There is no instruction that lowers privilege directly; the way down is to
 * build the frame an interrupt from ring 3 would have pushed and execute the
 * return. RFLAGS is set to 0x202 — reserved bit 1, plus IF, so the timer
 * keeps running once userspace is live.
 * ------------------------------------------------------------------------ */
/* enter_usermode(rip, rsp, argc, argv) — rdi, rsi, rdx, rcx.
 *
 * argc and argv reach the program in %rdi and %rsi, which is home-os's
 * process ABI. SysV puts them on the stack above the initial %rsp; this does
 * not, because every program here is compiled by the Home compiler and a
 * function's first two parameters already arrive in those registers — so
 * `_start(argc, argv)` is an ordinary function rather than something that has
 * to read its own stack before its prologue has run. A binary built by
 * another toolchain would need the stack form; nothing builds one today, and
 * that is the trade being made rather than an oversight.
 */
.global enter_usermode
enter_usermode:
    /* Save the kernel context so exit() can come back to it. Without this a
     * program that exits has nowhere to return: iretq is one-way, and the
     * kernel stack it left behind is the only way to resume the caller. */
    push %rbx
    push %rbp
    push %r12
    push %r13
    push %r14
    push %r15
    /* Out of the argument registers first, before anything below uses one as
     * scratch. The context save that follows needs %rax and %rcx, and %rcx is
     * carrying argv: saving the context before this move handed every program
     * an argv pointing at saved_kernel_rsp, and the first program to read its
     * arguments took a page fault on a kernel address. */
    mov %rdi, %r8           /* rip  */
    mov %rsi, %r9           /* rsp  */
    mov %rdx, %r10          /* argc */
    mov %rcx, %r11          /* argv */

    /* Pushed, not stored. A child runs from inside its parent's wait()
     * syscall, which is itself inside an enter_usermode — with one global
     * slot the child's entry would overwrite the parent's context and the
     * parent would have nowhere to return to. */
    mov saved_depth(%rip), %rax
    cmp $KERNEL_CONTEXT_MAX, %rax
    jge enter_usermode_too_deep
    lea saved_kernel_rsp(%rip), %rcx
    mov %rsp, (%rcx,%rax,8)
    inc %rax
    mov %rax, saved_depth(%rip)

    mov $0x23, %ax          /* user data selector, RPL 3 */
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs

    push $0x23              /* ss */
    push %r9                /* rsp */
    push $0x202             /* rflags */
    push $0x1b              /* cs: user code selector, RPL 3 */
    push %r8                /* rip */

    mov %r10, %rdi          /* argc */
    mov %r11, %rsi          /* argv */

    /* Everything else is zeroed rather than left holding whatever the kernel
     * had in it. A register carried across the privilege drop is a kernel
     * value readable at ring 3, and the program has no use for any of them. */
    xor %rax, %rax
    xor %rbx, %rbx
    xor %rcx, %rcx
    xor %rdx, %rdx
    xor %rbp, %rbp
    xor %r8, %r8
    xor %r9, %r9
    xor %r10, %r10
    xor %r11, %r11
    xor %r12, %r12
    xor %r13, %r13
    xor %r14, %r14
    xor %r15, %r15
    iretq

/* enter_usermode_resume(frame, cr3) — continue a user context that was saved
 * at a syscall, in the address space `cr3` names.
 *
 * `frame` points at the register block syscall_entry pushed, with the iretq
 * frame above it — the same shape, so a context saved at fork can be resumed
 * here without a second layout to keep in step.
 *
 * The saved %rax is whatever the caller put there: fork stores 0, so the
 * child returns 0 from the call its parent returned a pid from.
 */
.global enter_usermode_resume
enter_usermode_resume:
    push %rbx
    push %rbp
    push %r12
    push %r13
    push %r14
    push %r15

    mov saved_depth(%rip), %rax
    cmp $KERNEL_CONTEXT_MAX, %rax
    jge enter_usermode_too_deep
    lea saved_kernel_rsp(%rip), %rcx
    mov %rsp, (%rcx,%rax,8)
    inc %rax
    mov %rax, saved_depth(%rip)

    /* The address space first: everything below reads the frame, which the
     * kernel half of every space maps identically. */
    test %rsi, %rsi
    jz .Lresume_no_cr3
    mov %rsi, %cr3
.Lresume_no_cr3:

    mov %rdi, %rsp          /* the saved block becomes the stack to pop from */

    mov $0x23, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs

    /* The frame's lowest slot is the %rax pushed last by syscall_entry, so
     * that comes off first. The order below is the push order reversed, and
     * it has to stay in step with the stub above — they are two halves of one
     * layout.
     *
     *   frame+0   rax        <- the value the resumed call returns
     *   frame+8   r10
     *   frame+16  r9
     *   frame+24  r8
     *   frame+32  rdx
     *   frame+40  rsi
     *   frame+48  rdi
     *   frame+56  r11
     *   frame+64  rcx
     *   frame+72  rbp
     *   frame+80  the iretq frame: rip, cs, rflags, rsp, ss
     */
    pop %rax                /* the value the call returns */
    pop %r10
    pop %r9
    pop %r8
    pop %rdx
    pop %rsi
    pop %rdi
    pop %r11
    pop %rcx
    pop %rbp
    iretq

enter_usermode_too_deep:
    /* Nested too far. Halting is the honest answer: the alternative is to
     * overwrite a saved context and return somewhere that no longer exists. */
    hlt
    jmp enter_usermode_too_deep

return_to_kernel_underflow:
    hlt
    jmp return_to_kernel_underflow

/* return_to_kernel() — resume enter_usermode's caller.
 *
 * Called from the exit syscall. Restores the stack enter_usermode saved and
 * returns through it, so run_user_program returns normally and the shell that
 * invoked it carries on.
 */
.global return_to_kernel
return_to_kernel:
    /* Re-enable interrupts.
     *
     * The syscall arrived through an interrupt gate, which clears IF, and
     * this path never executes the iretq that would restore it. Returning
     * with interrupts still masked left the kernel halted in its idle loop
     * with nothing able to wake it: the console stopped responding the
     * moment a program exited.
     */
    sti

    mov saved_depth(%rip), %rax
    test %rax, %rax
    jz return_to_kernel_underflow
    dec %rax
    mov %rax, saved_depth(%rip)
    lea saved_kernel_rsp(%rip), %rcx
    mov (%rcx,%rax,8), %rsp
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %rbp
    pop %rbx
    ret

.section .bss
.align 8
saved_kernel_rsp:
    .space 8 * 8          /* KERNEL_CONTEXT_MAX entries */
saved_depth:
    .quad 0

.section .text
