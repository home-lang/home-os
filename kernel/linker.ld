/* Linker script for home-os kernel */
/* Based on Multiboot2 specification */

ENTRY(_start)

PHDRS
{
    boot PT_LOAD FLAGS(5); /* Read + Execute */
    data PT_LOAD FLAGS(6); /* Read + Write */
}

SECTIONS
{
    /* Kernel loaded at 1MB physical */
    . = 1M;

    /* Multiboot2 header MUST be in first 32KB - place at very start */
    .multiboot ALIGN(8) : {
        KEEP(*(.multiboot))
    } :boot

    /* Text section immediately after, in same segment */
    .text ALIGN(16) : {
        *(.text)
        *(.text.*)
    } :boot

    .rodata ALIGN(4K) : {
        *(.rodata)
        *(.rodata.*)
    } :boot

    .data ALIGN(4K) : {
        *(.data)
        *(.data.*)
    } :data

    .bss ALIGN(4K) : {
        *(COMMON)
        *(.bss)
        *(.bss.*)
    } :data

    /* TLS support */
    .tdata ALIGN(4K) : {
        *(.tdata)
        *(.tdata.*)
    }

    .tbss ALIGN(4K) : {
        *(.tbss)
        *(.tbss.*)
    }

    /* Export kernel boundaries */
    __kernel_start = 1M;
    __kernel_end = .;
    __kernel_size = __kernel_end - __kernel_start;
}
