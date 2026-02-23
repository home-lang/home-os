/* Minimal kernel stub for CI builds without the Home compiler.
 * Provides kernel_main that prints a message to COM1 serial and halts.
 * Used by build-unified.sh when Home compiler is not available. */
.section .text
.global kernel_main
kernel_main:
    /* Write "HomeOS stub\n" to COM1 (0x3F8) */
    mov $stub_msg, %rsi
.Lstub_loop:
    lodsb
    test %al, %al
    jz .Lstub_halt
    mov $0x3F8, %dx
.Lstub_wait:
    add $5, %dx
    inb %dx, %al
    test $0x20, %al
    jz .Lstub_wait
    sub $5, %dx
    mov -1(%rsi), %al
    outb %al, %dx
    jmp .Lstub_loop
.Lstub_halt:
    hlt
    jmp .Lstub_halt
.section .rodata
stub_msg:
    .asciz "HomeOS kernel stub (Home compiler not available)\r\n"
