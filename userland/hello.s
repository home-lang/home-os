/* hello — the first home-os userspace program.
 *
 * A flat binary, not an ELF: the loader reads it straight into a page and
 * jumps to offset zero. It is position-independent by construction — the
 * message is reached through %rip, so it does not care where it is mapped.
 *
 * Syscalls use home-os's own numbering, from kernel/src/sys/syscall.home —
 * exit is 0 and write is 3, not Linux's 60 and 1. The register convention is
 * the System V one: %rax the call number, then %rdi, %rsi, %rdx, entered
 * with `int $0x80`.
 */
.section .text
.code64
.global _start
_start:
    /* write(1, msg, len) */
    mov $3, %rax
    mov $1, %rdi
    lea msg(%rip), %rsi
    mov $msg_len, %rdx
    int $0x80

    /* exit(7) — a value the kernel prints back, so the gate can tell a real
     * return from a default one. */
    mov $0, %rax
    mov $7, %rdi
    int $0x80

    /* exit does not return. If it ever does, stop rather than running into
     * whatever follows in the page. */
1:  jmp 1b

msg:
    .ascii "hello from ring 3\n"
msg_len = . - msg
