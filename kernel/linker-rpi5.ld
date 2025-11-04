/* Linker script for HomeOS on Raspberry Pi 5 (ARM64) */

/* Entry point */
ENTRY(_start)

/* Memory layout for Raspberry Pi 5
 * The kernel is loaded at 0x80000 by the firmware
 */
MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000, LENGTH = 32M
}

SECTIONS
{
    /* Kernel load address */
    . = 0x80000;

    /* Boot code section - must be first */
    .text.boot : {
        KEEP(*(.text.boot))
    } > RAM

    /* Code section */
    .text : ALIGN(4096) {
        *(.text)
        *(.text.*)
    } > RAM

    /* Read-only data */
    .rodata : ALIGN(4096) {
        *(.rodata)
        *(.rodata.*)
    } > RAM

    /* Exception vectors */
    .vectors : ALIGN(2048) {
        *(.vectors)
    } > RAM

    /* Data section */
    .data : ALIGN(4096) {
        *(.data)
        *(.data.*)
    } > RAM

    /* BSS section (uninitialized data) */
    .bss : ALIGN(4096) {
        bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        bss_end = .;
    } > RAM

    /* Stack (16KB per CPU core, 4 cores = 64KB total) */
    .stack : ALIGN(4096) {
        . = . + 0x10000; /* 64KB stack space */
        stack_top = .;
    } > RAM

    /* Page tables (requires 16KB alignment for TTBR) */
    .page_tables : ALIGN(16384) {
        page_tables_start = .;
        . = . + 0x10000; /* 64KB for page tables */
        page_tables_end = .;
    } > RAM

    /* Kernel end marker */
    __kernel_start = 0x80000;
    __kernel_end = .;
    __kernel_size = __kernel_end - __kernel_start;

    /* Discard sections we don't need */
    /DISCARD/ : {
        *(.comment)
        *(.gnu*)
        *(.note*)
        *(.eh_frame*)
    }
}
