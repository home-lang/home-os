/* home-os Stage 2 Bootloader Linker Script
 *
 * Stage 2 is loaded by MBR at 0x7E00 (right after MBR at 0x7C00).
 * Maximum size: 32 sectors = 16KB = 0x4000 bytes
 * Address range: 0x7E00 - 0xBDFF
 */

OUTPUT_FORMAT("binary")
OUTPUT_ARCH(i386)
ENTRY(_start)

SECTIONS
{
    . = 0x7E00;

    .text : {
        *(.text)
        *(.text.*)
    }

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    }

    .data : {
        *(.data)
        *(.data.*)
    }

    /* BSS section for page tables - must be page aligned */
    . = ALIGN(4096);
    .bss : {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        __bss_end = .;
    }

    /* Ensure we don't exceed 16KB */
    ASSERT(. <= 0x7E00 + 0x4000, "Stage 2 bootloader exceeds 16KB!")

    /DISCARD/ : {
        *(.eh_frame)
        *(.comment)
        *(.note*)
    }
}
