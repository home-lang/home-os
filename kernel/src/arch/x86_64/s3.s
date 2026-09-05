/* S3 suspend and resume.
 *
 * Two pieces of code that cannot be written in Home, for the same reason the
 * boot path cannot: the machine comes back from S3 in *real mode*, sixteen
 * bits wide with paging off and no long-mode GDT, and has to climb back to
 * where it was. Nothing above the instruction level exists at that point.
 *
 * The firmware resumes by jumping to the physical address in the FACS waking
 * vector, so the trampoline has to live below 1 MB and be position-dependent
 * at the address it was copied to. It is assembled as if at S3_TRAMPOLINE
 * and every internal reference is written as an absolute address computed
 * from that base — which is why the base is a constant here and in the Home
 * side, rather than something chosen at run time.
 *
 * The save area is a separate fixed page so that both this file and the
 * kernel can address it without either needing the other's layout.
 */

.set S3_TRAMPOLINE, 0x8000
.set S3_SAVE,       0x9000

/* Save-area layout, shared with drivers/acpi.home. */
.set SAVE_CR3,  S3_SAVE + 0
.set SAVE_RSP,  S3_SAVE + 8
.set SAVE_RIP,  S3_SAVE + 16
.set SAVE_RBX,  S3_SAVE + 24
.set SAVE_RBP,  S3_SAVE + 32
.set SAVE_R12,  S3_SAVE + 40
.set SAVE_R13,  S3_SAVE + 48
.set SAVE_R14,  S3_SAVE + 56
.set SAVE_R15,  S3_SAVE + 64
.set SAVE_GDTR, S3_SAVE + 72
.set SAVE_IDTR, S3_SAVE + 88

.section .text
.code64

/* asm_s3_suspend(pm1a_port, pm1a_value, pm1b_port, pm1b_value)
 *
 * Saves everything the resume path needs, writes the sleep registers, and
 * does not return until the machine has come back — at which point it returns
 * 1. If the write does not suspend the machine, the bounded wait below
 * expires and it returns 0 rather than spinning forever: a firmware that
 * ignores the write is a real outcome, and hanging is not a report.
 *
 * Only the callee-saved registers are preserved, because that is the contract
 * a call already has: everything else was the caller's to lose across
 * asm_s3_suspend() whether or not the machine slept in the middle.
 */
.global asm_s3_suspend
asm_s3_suspend:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15

    /* The state the trampoline restores. */
    movq %cr3, %rax
    movq %rax, SAVE_CR3
    movq %rsp, SAVE_RSP
    movq %rbx, SAVE_RBX
    movq %rbp, SAVE_RBP
    movq %r12, SAVE_R12
    movq %r13, SAVE_R13
    movq %r14, SAVE_R14
    movq %r15, SAVE_R15
    sgdt SAVE_GDTR
    sidt SAVE_IDTR
    leaq .Ls3_resumed(%rip), %rax
    movq %rax, SAVE_RIP

    /* Write PM1a_CNT, and PM1b_CNT when there is one. Arguments arrive in
     * rdi/rsi/rdx/rcx; `out` wants the port in dx and the value in ax. */
    movq %rdi, %r10          /* pm1a port  */
    movq %rsi, %r11          /* pm1a value */
    movq %rdx, %r8           /* pm1b port  */
    movq %rcx, %r9           /* pm1b value */

    movq %r10, %rdx
    movq %r11, %rax
    outw %ax, %dx

    testq %r8, %r8
    jz .Ls3_wait
    movq %r8, %rdx
    movq %r9, %rax
    outw %ax, %dx

.Ls3_wait:
    /* The transition is not instantaneous. Halting is what a suspending
     * machine should be doing; the counter bounds how long "not suspending"
     * takes to become an answer. */
    movq $0x2000000, %rcx
.Ls3_spin:
    hlt
    decq %rcx
    jnz .Ls3_spin

    /* Never suspended. */
    xorq %rax, %rax
    jmp .Ls3_return

.Ls3_resumed:
    /* Reached from the trampoline, in 64-bit mode with rsp restored. */
    movq SAVE_RBX, %rbx
    movq SAVE_RBP, %rbp
    movq SAVE_R12, %r12
    movq SAVE_R13, %r13
    movq SAVE_R14, %r14
    movq SAVE_R15, %r15
    lgdt SAVE_GDTR
    lidt SAVE_IDTR
    movq $1, %rax

.Ls3_return:
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

/* The blob the kernel copies to S3_TRAMPOLINE. Assembled as 16-bit code that
 * climbs back to 64-bit: real mode, then protected, then long. */
.global s3_trampoline_start
.global s3_trampoline_end

.code16
s3_trampoline_start:
    cli
    cld
    xorw %ax, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %ss

    lgdtl S3_TRAMPOLINE + (.Lgdt32_ptr - s3_trampoline_start)

    movl %cr0, %eax
    orl $1, %eax
    movl %eax, %cr0

    ljmpl $0x08, $(S3_TRAMPOLINE + (.Lprot32 - s3_trampoline_start))

.code32
.Lprot32:
    movw $0x10, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
    movw %ax, %gs
    movw %ax, %ss

    /* PAE, which long mode requires. */
    movl %cr4, %eax
    orl $0x20, %eax
    movl %eax, %cr4

    /* The page tables the kernel was using. They are still there — S3 keeps
     * memory — so there is nothing to rebuild. */
    movl SAVE_CR3, %eax
    movl %eax, %cr3

    /* EFER.LME */
    movl $0xC0000080, %ecx
    rdmsr
    orl $0x100, %eax
    wrmsr

    /* Paging on: this is the instruction that enters long mode. */
    movl %cr0, %eax
    orl $0x80000000, %eax
    movl %eax, %cr0

    lgdt S3_TRAMPOLINE + (.Lgdt64_ptr - s3_trampoline_start)
    ljmpl $0x08, $(S3_TRAMPOLINE + (.Llong64 - s3_trampoline_start))

.code64
.Llong64:
    movw $0x10, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
    movw %ax, %gs
    movw %ax, %ss

    movq SAVE_RSP, %rsp
    movq SAVE_RIP, %rax
    jmp *%rax

/* Two GDTs, because the climb passes through both widths. They live inside
 * the blob so they are addressable from the low copy. */
.align 8
.Lgdt32:
    .quad 0x0000000000000000
    .quad 0x00CF9A000000FFFF        /* 32-bit code */
    .quad 0x00CF92000000FFFF        /* 32-bit data */
.Lgdt32_ptr:
    .word 23
    .long S3_TRAMPOLINE + (.Lgdt32 - s3_trampoline_start)

.align 8
.Lgdt64:
    .quad 0x0000000000000000
    .quad 0x00AF9A000000FFFF        /* 64-bit code */
    .quad 0x00CF92000000FFFF        /* data */
.Lgdt64_ptr:
    .word 23
    .long S3_TRAMPOLINE + (.Lgdt64 - s3_trampoline_start)

s3_trampoline_end:
