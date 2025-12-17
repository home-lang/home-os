/* home-os MBR Linker Script
 *
 * MBR is loaded by BIOS at 0x7C00 and must be exactly 512 bytes.
 * The last 66 bytes are reserved for partition table (64) + signature (2).
 */

OUTPUT_FORMAT("binary")
OUTPUT_ARCH(i386)
ENTRY(_start)

SECTIONS
{
    . = 0x7C00;

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

    /* Ensure MBR is exactly 512 bytes */
    . = 0x7C00 + 510;
    .signature : {
        SHORT(0xAA55)
    }

    /DISCARD/ : {
        *(.eh_frame)
        *(.comment)
        *(.note*)
        *(.bss)
    }
}
