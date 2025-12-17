/* home-os Master Boot Record (MBR) Boot Sector
 *
 * This is the first code executed when booting from a legacy BIOS system.
 * It is loaded at 0x7C00 and must fit within 512 bytes (446 bytes of code,
 * 64 bytes for partition table, 2 bytes for boot signature).
 *
 * Purpose:
 *   1. Set up minimal environment (stack, segments)
 *   2. Relocate itself to 0x0600 to make room for Stage 2
 *   3. Load Stage 2 bootloader from disk
 *   4. Jump to Stage 2
 */

.code16
.section .text
.global _start

/* Constants */
.set MBR_LOAD_ADDR,     0x7C00      /* Where BIOS loads MBR */
.set MBR_RELOC_ADDR,    0x0600      /* Where we relocate MBR to */
.set STAGE2_LOAD_ADDR,  0x7E00      /* Where to load Stage 2 */
.set STAGE2_SECTOR,     1           /* Stage 2 starts at sector 1 (0-indexed) */
.set STAGE2_SECTORS,    32          /* Load 32 sectors (16KB) for Stage 2 */
.set STACK_TOP,         0x7C00      /* Stack grows down from MBR load address */

_start:
    /* Disable interrupts during setup */
    cli

    /* Set up segments - BIOS may have left them in unknown state */
    xor %ax, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss
    mov $STACK_TOP, %sp

    /* Re-enable interrupts */
    sti

    /* Save boot drive number (BIOS passes it in DL) */
    mov %dl, boot_drive

    /* Relocate MBR from 0x7C00 to 0x0600 */
    mov $MBR_LOAD_ADDR, %si
    mov $MBR_RELOC_ADDR, %di
    mov $256, %cx           /* 256 words = 512 bytes */
    rep movsw

    /* Far jump to relocated code */
    ljmp $0x0000, $relocated

relocated:
    /* Print boot message */
    mov $msg_boot, %si
    call print_string

    /* Reset disk system */
    xor %ah, %ah
    mov boot_drive, %dl
    int $0x13
    jc disk_error

    /* Load Stage 2 bootloader using LBA (if available) or CHS */
    /* First, check for LBA extensions */
    mov $0x41, %ah
    mov $0x55AA, %bx
    mov boot_drive, %dl
    int $0x13
    jc no_lba
    cmp $0xAA55, %bx
    jne no_lba

    /* LBA extensions available - use extended read */
    call load_stage2_lba
    jmp stage2_loaded

no_lba:
    /* Fall back to CHS read */
    call load_stage2_chs

stage2_loaded:
    /* Print success message */
    mov $msg_loaded, %si
    call print_string

    /* Jump to Stage 2 */
    mov boot_drive, %dl     /* Pass boot drive to Stage 2 */
    ljmp $0x0000, $STAGE2_LOAD_ADDR

/* Load Stage 2 using LBA (extended read) */
load_stage2_lba:
    mov $dap, %si
    mov $0x42, %ah
    mov boot_drive, %dl
    int $0x13
    jc disk_error
    ret

/* Load Stage 2 using CHS (legacy read) */
load_stage2_chs:
    /* Read sectors one at a time for compatibility */
    mov $STAGE2_SECTORS, %cx    /* Sectors to read */
    mov $STAGE2_SECTOR, %al     /* Starting sector (1-indexed for CHS) */
    add $1, %al                 /* CHS sectors start at 1 */
    mov $STAGE2_LOAD_ADDR, %bx  /* Destination buffer */

.read_loop:
    push %cx
    push %ax
    push %bx

    /* Convert LBA to CHS (simplified for first track) */
    /* Sector = LBA + 1 (for CHS) */
    /* Head = 0, Cylinder = 0 for sectors < 63 */
    mov %al, %cl            /* Sector number (1-63) */
    xor %ch, %ch            /* Cylinder 0 */
    xor %dh, %dh            /* Head 0 */
    mov boot_drive, %dl
    mov $0x0201, %ax        /* Read 1 sector */
    int $0x13
    jc disk_error

    pop %bx
    pop %ax
    pop %cx

    /* Advance to next sector */
    inc %al
    add $512, %bx
    loop .read_loop

    ret

/* Disk error handler */
disk_error:
    mov $msg_disk_err, %si
    call print_string
    mov %ah, %al            /* Error code */
    call print_hex
    jmp halt

/* Print null-terminated string (SI = string pointer) */
print_string:
    pusha
.print_loop:
    lodsb
    test %al, %al
    jz .print_done
    mov $0x0E, %ah
    mov $0x07, %bx
    int $0x10
    jmp .print_loop
.print_done:
    popa
    ret

/* Print AL as hex digit */
print_hex:
    pusha
    mov %al, %ah
    shr $4, %al
    call .print_nibble
    mov %ah, %al
    and $0x0F, %al
    call .print_nibble
    popa
    ret

.print_nibble:
    cmp $10, %al
    jl .digit
    add $('A' - 10), %al
    jmp .output
.digit:
    add $'0', %al
.output:
    mov $0x0E, %ah
    mov $0x07, %bx
    int $0x10
    ret

/* Halt the system */
halt:
    mov $msg_halt, %si
    call print_string
.halt_loop:
    cli
    hlt
    jmp .halt_loop

/* Data */
boot_drive:
    .byte 0

msg_boot:
    .asciz "home-os MBR\r\n"

msg_loaded:
    .asciz "Stage2 OK\r\n"

msg_disk_err:
    .asciz "Disk err: "

msg_halt:
    .asciz "\r\nHALT"

/* Disk Address Packet for LBA read */
.align 4
dap:
    .byte 16                /* Size of DAP */
    .byte 0                 /* Reserved */
    .word STAGE2_SECTORS    /* Sectors to read */
    .word STAGE2_LOAD_ADDR  /* Offset */
    .word 0                 /* Segment */
    .long STAGE2_SECTOR     /* LBA low 32 bits */
    .long 0                 /* LBA high 32 bits */

/* Padding to reach partition table at offset 446 */
.org 446

/* Partition table (64 bytes) - empty for now */
partition_table:
    .fill 64, 1, 0

/* Boot signature */
.org 510
boot_signature:
    .word 0xAA55
