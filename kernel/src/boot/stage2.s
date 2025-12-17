/* home-os Stage 2 Bootloader
 *
 * Loaded by MBR at 0x7E00. Responsible for:
 *   1. Enabling A20 line (access memory above 1MB)
 *   2. Loading the kernel from disk
 *   3. Getting memory map from BIOS (E820)
 *   4. Setting up GDT for protected mode
 *   5. Transitioning to 32-bit protected mode
 *   6. Then transitioning to 64-bit long mode
 *   7. Jumping to kernel entry point
 *
 * Memory Layout:
 *   0x0500-0x7BFF  - Free (used for stack, data)
 *   0x7C00-0x7DFF  - MBR (relocated to 0x0600)
 *   0x7E00-0xFFFF  - Stage 2 bootloader (this code)
 *   0x10000+       - Kernel load area
 */

.code16
.section .text
.global _start

/* Constants */
.set STAGE2_BASE,       0x7E00
.set KERNEL_LOAD_ADDR,  0x100000    /* 1MB - kernel load address */
.set KERNEL_LOW_ADDR,   0x10000     /* Temporary kernel buffer (64KB) */
.set KERNEL_SECTOR,     33          /* Kernel starts after Stage 2 (sector 33) */
.set KERNEL_SECTORS,    256         /* Load 256 sectors (128KB) initially */
.set E820_BUFFER,       0x8000      /* Memory map buffer */
.set MAX_E820_ENTRIES,  32

_start:
    /* Set up segments */
    cli
    xor %ax, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov $0x7C00, %sp    /* Stack below Stage 2 */
    mov %ax, %ss
    sti

    /* Save boot drive */
    mov %dl, boot_drive

    /* Print Stage 2 banner */
    mov $msg_stage2, %si
    call print_string

    /* Enable A20 line */
    call enable_a20
    jc a20_failed

    mov $msg_a20_ok, %si
    call print_string

    /* Get memory map from BIOS (E820) */
    call get_memory_map

    /* Load kernel into low memory first (below 1MB) */
    mov $msg_loading, %si
    call print_string

    call load_kernel

    mov $msg_kernel_ok, %si
    call print_string

    /* Switch to protected mode */
    mov $msg_pmode, %si
    call print_string

    call switch_to_protected_mode
    /* Never returns - jumps to 32-bit code */

a20_failed:
    mov $msg_a20_fail, %si
    call print_string
    jmp halt

/* ============================================================================
 * A20 Line Activation
 * Tries multiple methods to enable A20 gate:
 *   1. BIOS INT 15h, AX=2401h
 *   2. Keyboard controller (8042)
 *   3. Fast A20 (port 0x92)
 * ============================================================================
 */
enable_a20:
    /* First check if A20 is already enabled */
    call check_a20
    jnc .a20_done       /* A20 already enabled */

    /* Method 1: BIOS */
    mov $0x2401, %ax
    int $0x15
    call check_a20
    jnc .a20_done

    /* Method 2: Keyboard controller */
    call .a20_keyboard
    call check_a20
    jnc .a20_done

    /* Method 3: Fast A20 */
    in $0x92, %al
    test $0x02, %al
    jnz .a20_fast_done  /* Already set */
    or $0x02, %al
    and $0xFE, %al      /* Don't reset CPU! */
    out %al, $0x92
.a20_fast_done:
    call check_a20
    jnc .a20_done

    /* All methods failed */
    stc
    ret

.a20_done:
    clc
    ret

/* A20 via keyboard controller */
.a20_keyboard:
    call .wait_8042_input
    mov $0xAD, %al      /* Disable keyboard */
    out %al, $0x64

    call .wait_8042_input
    mov $0xD0, %al      /* Read output port */
    out %al, $0x64

    call .wait_8042_output
    in $0x60, %al
    push %ax

    call .wait_8042_input
    mov $0xD1, %al      /* Write output port */
    out %al, $0x64

    call .wait_8042_input
    pop %ax
    or $0x02, %al       /* Set A20 bit */
    out %al, $0x60

    call .wait_8042_input
    mov $0xAE, %al      /* Enable keyboard */
    out %al, $0x64

    call .wait_8042_input
    ret

.wait_8042_input:
    in $0x64, %al
    test $0x02, %al
    jnz .wait_8042_input
    ret

.wait_8042_output:
    in $0x64, %al
    test $0x01, %al
    jz .wait_8042_output
    ret

/* Check if A20 is enabled by comparing memory wrap-around */
check_a20:
    push %ds
    push %es
    push %di
    push %si

    xor %ax, %ax
    mov %ax, %es
    mov $0x0500, %di    /* ES:DI = 0000:0500 */

    mov $0xFFFF, %ax
    mov %ax, %ds
    mov $0x0510, %si    /* DS:SI = FFFF:0510 = 0x100500 (wraps to 0x0500 if A20 off) */

    /* Save original values */
    mov %es:(%di), %al
    push %ax
    mov %ds:(%si), %al
    push %ax

    /* Write different values */
    movb $0x00, %es:(%di)
    movb $0xFF, %ds:(%si)

    /* Check if they're the same (A20 disabled = wrap-around) */
    cmpb $0xFF, %es:(%di)

    /* Restore original values */
    pop %ax
    mov %al, %ds:(%si)
    pop %ax
    mov %al, %es:(%di)

    pop %si
    pop %di
    pop %es
    pop %ds

    /* If equal, A20 is disabled (carry set) */
    je .a20_disabled
    clc                 /* A20 enabled */
    ret
.a20_disabled:
    stc                 /* A20 disabled */
    ret

/* ============================================================================
 * Get Memory Map (E820)
 * Stores memory map at E820_BUFFER for kernel to use
 * ============================================================================
 */
get_memory_map:
    push %es
    push %di
    push %ebx
    push %ecx
    push %edx

    xor %ax, %ax
    mov %ax, %es
    mov $E820_BUFFER + 4, %di   /* Leave room for entry count */
    xor %ebx, %ebx              /* Continuation value */
    xor %bp, %bp                /* Entry counter */

.e820_loop:
    mov $0x0000E820, %eax
    mov $24, %ecx               /* Buffer size */
    mov $0x534D4150, %edx       /* 'SMAP' signature */
    int $0x15

    jc .e820_done               /* Carry = error or end */

    cmp $0x534D4150, %eax       /* Check signature */
    jne .e820_done

    /* Valid entry */
    inc %bp
    add $24, %di

    /* Check for more entries */
    test %ebx, %ebx
    jz .e820_done

    cmp $MAX_E820_ENTRIES, %bp
    jl .e820_loop

.e820_done:
    /* Store entry count at start of buffer */
    mov %bp, (E820_BUFFER)

    pop %edx
    pop %ecx
    pop %ebx
    pop %di
    pop %es
    ret

/* ============================================================================
 * Load Kernel from Disk
 * Uses LBA extended read to load kernel into low memory
 * ============================================================================
 */
load_kernel:
    /* Set up DAP for kernel load */
    movw $KERNEL_SECTORS, kernel_dap_count
    movl $KERNEL_SECTOR, kernel_dap_lba

    mov $kernel_dap, %si
    mov $0x42, %ah
    mov boot_drive, %dl
    int $0x13
    jc .load_error

    ret

.load_error:
    mov $msg_load_err, %si
    call print_string
    jmp halt

/* ============================================================================
 * Switch to Protected Mode
 * ============================================================================
 */
switch_to_protected_mode:
    cli

    /* Load GDT */
    lgdt gdt32_ptr

    /* Set PE bit in CR0 */
    mov %cr0, %eax
    or $0x01, %eax
    mov %eax, %cr0

    /* Far jump to flush prefetch and enter 32-bit mode */
    ljmp $0x08, $protected_mode_entry

/* ============================================================================
 * 32-bit Protected Mode Code
 * ============================================================================
 */
.code32
protected_mode_entry:
    /* Set up data segments */
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss
    mov $0x7C00, %esp

    /* Print 'P' to show we're in protected mode (direct VGA write) */
    movl $0x0F500F50, 0xB8000   /* 'PP' in white on black */

    /* Copy kernel from low memory to high memory (1MB) */
    mov $KERNEL_LOW_ADDR, %esi
    mov $KERNEL_LOAD_ADDR, %edi
    mov $(KERNEL_SECTORS * 512 / 4), %ecx  /* Copy as dwords */
    rep movsl

    /* Now set up for long mode */
    /* Check for long mode support */
    mov $0x80000000, %eax
    cpuid
    cmp $0x80000001, %eax
    jb no_long_mode_32

    mov $0x80000001, %eax
    cpuid
    test $(1 << 29), %edx   /* LM bit */
    jz no_long_mode_32

    /* Set up page tables for long mode */
    call setup_page_tables

    /* Load page table address */
    mov $pml4_table, %eax
    mov %eax, %cr3

    /* Enable PAE */
    mov %cr4, %eax
    or $(1 << 5), %eax      /* PAE bit */
    mov %eax, %cr4

    /* Enable long mode in EFER MSR */
    mov $0xC0000080, %ecx   /* EFER MSR */
    rdmsr
    or $(1 << 8), %eax      /* LM bit */
    wrmsr

    /* Enable paging (enters long mode) */
    mov %cr0, %eax
    or $(1 << 31), %eax     /* PG bit */
    mov %eax, %cr0

    /* Load 64-bit GDT */
    lgdt gdt64_ptr

    /* Far jump to 64-bit code */
    ljmp $0x08, $long_mode_entry

no_long_mode_32:
    /* Print error and halt */
    movl $0x4F4E4F4F, 0xB8000   /* 'NO' in red */
    movl $0x4F4D4F4C, 0xB8004   /* 'LM' in red */
    jmp halt32

halt32:
    cli
    hlt
    jmp halt32

/* Set up identity-mapped page tables for first 2GB */
setup_page_tables:
    /* Zero out page tables */
    mov $pml4_table, %edi
    mov $4096 * 3, %ecx     /* 3 pages */
    xor %eax, %eax
    rep stosb

    /* PML4[0] -> PDPT */
    mov $pdpt_table, %eax
    or $0x03, %eax          /* Present + Writable */
    mov %eax, pml4_table

    /* PDPT[0] -> PD */
    mov $pd_table, %eax
    or $0x03, %eax
    mov %eax, pdpt_table

    /* Fill PD with 2MB huge pages (map first 2GB) */
    mov $pd_table, %edi
    mov $0x00000083, %eax   /* Present + Writable + Huge */
    mov $512, %ecx          /* 512 entries * 2MB = 1GB */

.fill_pd_loop:
    mov %eax, (%edi)
    movl $0, 4(%edi)        /* Upper 32 bits = 0 */
    add $0x200000, %eax     /* Next 2MB */
    add $8, %edi
    loop .fill_pd_loop

    ret

/* ============================================================================
 * 64-bit Long Mode Code
 * ============================================================================
 */
.code64
long_mode_entry:
    /* Set up 64-bit segments */
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss

    /* Set up 64-bit stack */
    mov $0x7C00, %rsp

    /* Print 'L' to show we're in long mode */
    movl $0x0F4C0F4C, 0xB8004   /* 'LL' after 'PP' */

    /* Prepare arguments for kernel_main */
    /* RDI = magic number (custom for legacy boot) */
    /* RSI = pointer to boot info structure */
    mov $0x48424F4F, %edi       /* 'HBOO' - Home Boot magic */
    mov $boot_info, %rsi

    /* Jump to kernel */
    mov $KERNEL_LOAD_ADDR, %rax
    jmp *%rax

/* 64-bit halt loop */
.halt64:
    cli
    hlt
    jmp .halt64

/* ============================================================================
 * 16-bit Helper Functions
 * ============================================================================
 */
.code16

/* Print null-terminated string (SI = string pointer) */
print_string:
    pusha
.ps_loop:
    lodsb
    test %al, %al
    jz .ps_done
    mov $0x0E, %ah
    mov $0x07, %bx
    int $0x10
    jmp .ps_loop
.ps_done:
    popa
    ret

/* Halt */
halt:
    cli
    hlt
    jmp halt

/* ============================================================================
 * Data Section
 * ============================================================================
 */
.section .data

boot_drive:
    .byte 0

/* Messages */
msg_stage2:
    .asciz "home-os Stage2\r\n"
msg_a20_ok:
    .asciz "A20 enabled\r\n"
msg_a20_fail:
    .asciz "A20 FAILED!\r\n"
msg_loading:
    .asciz "Loading kernel...\r\n"
msg_kernel_ok:
    .asciz "Kernel loaded\r\n"
msg_pmode:
    .asciz "Entering protected mode...\r\n"
msg_load_err:
    .asciz "Kernel load error!\r\n"

/* Kernel load DAP */
.align 4
kernel_dap:
    .byte 16                    /* Size */
    .byte 0                     /* Reserved */
kernel_dap_count:
    .word 0                     /* Sectors to read */
    .word KERNEL_LOW_ADDR       /* Offset */
    .word 0                     /* Segment */
kernel_dap_lba:
    .long 0                     /* LBA low */
    .long 0                     /* LBA high */

/* Boot info structure passed to kernel */
.align 8
boot_info:
    .long 0x48424F4F            /* Magic 'HBOO' */
    .long boot_info_end - boot_info  /* Size */
    .long E820_BUFFER           /* Memory map address */
    .long MAX_E820_ENTRIES      /* Max entries */
    .long KERNEL_LOAD_ADDR      /* Kernel load address */
    .long KERNEL_SECTORS * 512  /* Kernel size */
boot_info_end:

/* 32-bit GDT */
.align 16
gdt32:
    .quad 0                     /* Null descriptor */
    .quad 0x00CF9A000000FFFF    /* Code: base=0, limit=4GB, 32-bit */
    .quad 0x00CF92000000FFFF    /* Data: base=0, limit=4GB, 32-bit */
gdt32_end:

gdt32_ptr:
    .word gdt32_end - gdt32 - 1
    .long gdt32

/* 64-bit GDT */
.align 16
gdt64:
    .quad 0                     /* Null descriptor */
    .quad 0x00209A0000000000    /* Code: 64-bit */
    .quad 0x0000920000000000    /* Data */
gdt64_end:

gdt64_ptr:
    .word gdt64_end - gdt64 - 1
    .quad gdt64

/* ============================================================================
 * BSS Section - Page Tables
 * ============================================================================
 */
.section .bss
.align 4096

pml4_table:
    .skip 4096

pdpt_table:
    .skip 4096

pd_table:
    .skip 4096
