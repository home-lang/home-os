/* hello_elf — the same greeting as hello.s, but as a real ELF64 executable.
 *
 * Where hello.s is a flat image the kernel reads and jumps into, this one
 * carries program headers saying where it wants to live, and the loader in
 * kernel/src/loader/elf.home maps it there. That is the difference the
 * `exec` shell command exercises.
 *
 * Linked at 0x40200000 — above the flat loader's fixed window and below the
 * user stack, so both loaders can be exercised in one session without one
 * overwriting the other.
 *
 * Syscalls use home-os's numbering: exit is 0, write is 3.
 */
.section .text
.code64
.global _start
_start:
    mov $3, %rax            /* write */
    mov $1, %rdi            /* stdout */
    lea msg(%rip), %rsi
    mov $msg_len, %rdx
    int $0x80

    /* Also prove .data made it: the loader has to copy filesz bytes and zero
     * the rest, and a segment that arrives blank looks exactly like one that
     * was never read. */
    mov $3, %rax
    mov $1, %rdi
    lea marker(%rip), %rsi
    mov $marker_len, %rdx
    int $0x80

    mov $0, %rax            /* exit */
    mov $9, %rdi
    int $0x80

1:  jmp 1b

.section .rodata
msg:
    .ascii "hello from an ELF at ring 3\n"
msg_len = . - msg

.section .data
marker:
    .ascii "elf data segment intact\n"
marker_len = . - marker
