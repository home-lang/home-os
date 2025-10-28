/* Linker script for home-os kernel */
/* Based on Multiboot2 specification */

ENTRY(_start)

SECTIONS
{
    /* Kernel loaded at 1MB physical */
    . = 1M;

    /* Multiboot2 header MUST be in first 32KB and in a LOAD segment */
    .multiboot : {
        KEEP(*(.multiboot))
    }

    /* Text section right after multiboot, ensuring it's in first segment */
    .text : {
        *(.text)
        *(.text.*)
    }

    .rodata ALIGN(4K) : {
        *(.rodata)
        *(.rodata.*)
    }

    .data ALIGN(4K) : {
        *(.data)
        *(.data.*)
    }

    .bss ALIGN(4K) : {
        *(COMMON)
        *(.bss)
        *(.bss.*)
    }

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
