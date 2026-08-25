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

    /* Export kernel start before any sections */
    __kernel_start = .;

    /* Boot headers MUST be at the very start of the image: the Multiboot1
       header within the first 8KB, the Multiboot2 header within 32KB. */
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

    /* IDT table (writable, must be page-aligned) */
    .idt ALIGN(4K) : {
        *(.idt)
    } :data

    /* End of data with file contents. Everything from __kernel_start to
       __load_end is copied verbatim by a Multiboot a.out-kludge loader; the
       gap up to __bss_end is zeroed by it. Both are read by the Multiboot1
       header in boot.s, so they must bracket .bss exactly. */
    __load_end = .;

    .bss ALIGN(4K) : {
        *(COMMON)
        *(.bss)
        *(.bss.*)
    } :data

    __bss_end = .;

    /* TLS support */
    .tdata ALIGN(4K) : {
        *(.tdata)
        *(.tdata.*)
    }

    .tbss ALIGN(4K) : {
        *(.tbss)
        *(.tbss.*)
    }

    /* Export kernel end */
    __kernel_end = .;
    __kernel_size = __kernel_end - __kernel_start;
}
