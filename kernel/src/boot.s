/* Boot assembly for home-os kernel */
/* Multiboot2-compliant 32-bit -> 64-bit transition */

.set MAGIC,    0xe85250d6                # Multiboot2 magic number
.set ARCH,     0                         # Architecture: i386 (32-bit protected mode)
.set HEADER_LENGTH, multiboot_header_end - multiboot_header_start
.set CHECKSUM, -(MAGIC + ARCH + HEADER_LENGTH)

/* Multiboot2 header */
.section .multiboot
.align 8
multiboot_header_start:
    .long MAGIC
    .long ARCH
    .long HEADER_LENGTH
    .long CHECKSUM

    /* End tag */
    .align 8
    .short 0    # type
    .short 0    # flags
    .long 8     # size
multiboot_header_end:

/* Stack */
.section .bss
.align 16
stack_bottom:
    .skip 16384  # 16KB stack
stack_top:

/* Page tables for 64-bit mode */
.align 4096
pml4:
    .skip 4096
pdpt:
    .skip 4096
pd:
    .skip 4096

/* Boot code */
.section .text
.code32
.global _start
.type _start, @function
_start:
    /* Set up stack */
    mov $stack_top, %esp
    mov %esp, %ebp

    /* Save Multiboot2 info */
    push %ebx  # Multiboot info address
    push %eax  # Multiboot magic

    /* Check for CPUID support */
    pushfd
    pop %eax
    mov %eax, %ecx
    xor $0x00200000, %eax
    push %eax
    popfd
    pushfd
    pop %eax
    push %ecx
    popfd
    xor %ecx, %eax
    jz no_cpuid

    /* Check for long mode support */
    mov $0x80000000, %eax
    cpuid
    cmp $0x80000001, %eax
    jb no_long_mode

    mov $0x80000001, %eax
    cpuid
    test $0x20000000, %edx  # LM bit
    jz no_long_mode

    /* Set up page tables (identity map first 1GB) */
    /* PML4[0] -> PDPT */
    mov $pdpt, %eax
    or $0x03, %eax  # Present + Writable
    mov %eax, pml4

    /* PDPT[0] -> PD */
    mov $pd, %eax
    or $0x03, %eax  # Present + Writable
    mov %eax, pdpt

    /* PD entries: 512 * 2MB pages = 1GB */
    mov $pd, %edi
    mov $0x00000083, %eax  # Present + Writable + Huge (2MB pages)
    mov $512, %ecx

.fill_pd:
    mov %eax, (%edi)
    add $0x200000, %eax  # 2MB
    add $8, %edi
    loop .fill_pd

    /* Load PML4 into CR3 */
    mov $pml4, %eax
    mov %eax, %cr3

    /* Enable PAE */
    mov %cr4, %eax
    or $0x20, %eax  # PAE bit
    mov %eax, %cr4

    /* Enable long mode */
    mov $0xC0000080, %ecx  # EFER MSR
    rdmsr
    or $0x00000100, %eax   # LM bit
    wrmsr

    /* Enable paging */
    mov %cr0, %eax
    or $0x80000000, %eax  # PG bit
    mov %eax, %cr0

    /* Load 64-bit GDT */
    lgdt gdt64_pointer

    /* Far jump to 64-bit code */
    ljmp $0x08, $long_mode_start

no_cpuid:
    mov $0x4F524F45, 0xb8000  # 'E'
    mov $0x4F524F52, 0xb8002  # 'R'
    mov $0x4F524F52, 0xb8004  # 'R'
    hlt
    jmp no_cpuid

no_long_mode:
    mov $0x4F4E4F45, 0xb8000  # 'E'
    mov $0x4F364F52, 0xb8002  # 'R'
    mov $0x4F344F52, 0xb8004  # 'R'
    hlt
    jmp no_long_mode

/* 64-bit code */
.code64
long_mode_start:
    /* Clear segment registers */
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss

    /* Restore Multiboot2 info (zero-extend to 64-bit) */
    pop %rax  # magic
    pop %rbx  # info address
    mov %eax, %edi  # First argument (magic)
    mov %ebx, %esi  # Second argument (info_addr)

    /* Call kernel main */
    call kernel_main

    /* Halt if kernel returns */
.hang:
    hlt
    jmp .hang

.size _start, . - _start

/* 64-bit GDT */
.section .rodata
.align 16
gdt64:
    .quad 0                         # Null descriptor
    .quad 0x00209A0000000000        # Code segment (64-bit)
    .quad 0x0000920000000000        # Data segment
gdt64_end:

gdt64_pointer:
    .word gdt64_end - gdt64 - 1
    .quad gdt64
