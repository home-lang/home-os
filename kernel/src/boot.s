/* Boot assembly for home-os kernel */
/* Multiboot2-compliant 32-bit -> 64-bit transition */

.set MAGIC,    0xe85250d6                # Multiboot2 magic number
.set ARCH,     0                         # Architecture: i386 (32-bit protected mode)
.set HEADER_LENGTH, multiboot_header_end - multiboot_header_start
.set CHECKSUM, -(MAGIC + ARCH + HEADER_LENGTH)

/* Boot code with Multiboot2 header at the very start */
.section .text
.code32
.global _start
.type _start, @function

/* Multiboot2 header MUST be at start of .text section */
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

/* Entry point immediately after header */
.align 16
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

    /* Set up page tables (identity map first 2GB) */
    /* CRITICAL: Zero out all page tables first */
    mov $pml4, %edi
    mov $3072, %ecx        # 3 pages * 1024 dwords = 3072
    xor %eax, %eax
    rep stosl              # Zero PML4, PDPT, and PD

    /* PML4[0] -> PDPT (with Present + Writable flags) */
    mov $pdpt, %eax
    or $0x03, %eax         # Present + Writable
    mov %eax, pml4
    movl $0, pml4 + 4      # Clear upper 32 bits

    /* PDPT[0] -> PD (with Present + Writable flags) */
    mov $pd, %eax
    or $0x03, %eax         # Present + Writable
    mov %eax, pdpt
    movl $0, pdpt + 4      # Clear upper 32 bits

    /* PD entries: Map first 2GB using 1024 * 2MB huge pages */
    /* This ensures kernel, stack, and all data are writable */
    mov $pd, %edi
    mov $0x00000083, %eax  # Present + Writable + Huge (2MB pages)
    xor %edx, %edx         # Upper 32 bits = 0
    mov $1024, %ecx        # Map 1024 * 2MB = 2GB

.fill_pd:
    mov %eax, (%edi)       # Write lower 32 bits
    mov %edx, 4(%edi)      # Write upper 32 bits (0)
    add $0x200000, %eax    # Next 2MB physical address (lower)
    adc $0, %edx           # Add carry to upper 32 bits
    add $8, %edi           # Next PDE (8 bytes = 64 bits)
    loop .fill_pd

    /* Load PML4 into CR3 */
    mov $pml4, %eax
    mov %eax, %cr3

    /* Flush TLB by reloading CR3 */
    mov %cr3, %eax
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

    /* Enable paging and ensure WP bit is CLEAR */
    mov %cr0, %eax
    and $0xFFFEFFFF, %eax  # Clear WP bit (bit 16)
    or $0x80000000, %eax   # Set PG bit (bit 31)
    mov %eax, %cr0

    /* Load 64-bit GDT */
    lgdt gdt64_pointer

    /* Far jump to 64-bit code */
    ljmp $0x08, $long_mode_start

no_cpuid:
    movl $0x4F524F45, 0xb8000  # 'E'
    movl $0x4F524F52, 0xb8002  # 'R'
    movl $0x4F524F52, 0xb8004  # 'R'
    hlt
    jmp no_cpuid

no_long_mode:
    movl $0x4F4E4F45, 0xb8000  # 'E'
    movl $0x4F364F52, 0xb8002  # 'R'
    movl $0x4F344F52, 0xb8004  # 'R'
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

    /* Ensure WP bit is STILL clear in 64-bit mode */
    mov %cr0, %rax
    and $0xFFFFFFFFFFFEFFFF, %rax  # Clear WP bit (bit 16) in 64-bit
    mov %rax, %cr0

    /* Zero out .bss section */
    /* Note: We can't use external symbols here as they may not be accessible yet */
    /* So we'll skip .bss zeroing and rely on Zig's undefined initialization */

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

/* Page tables MUST come first to avoid stack corruption */
.section .bss
.align 4096
pml4:
    .skip 4096
pdpt:
    .skip 4096
pd:
    .skip 4096

/* Stack comes after page tables */
.align 16
stack_bottom:
    .skip 16384  # 16KB stack
stack_top:
