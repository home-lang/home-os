/* Linker script for the ARM64 kernel on QEMU's `virt` machine.
 *
 * `virt` places RAM at 0x40000000 and QEMU's `-kernel` loader puts an ELF
 * image at its own load address, so the kernel is linked to run where it is
 * loaded — there is no relocation and no bootloader in between.
 *
 * The Raspberry Pi 5 uses kernel/linker-rpi5.ld instead: same layout, load
 * address 0x80000, because that is where the Pi's EEPROM bootloader places
 * the image it names in config.txt.
 *
 * home-lang/home-os#57
 */

ENTRY(_start)

SECTIONS
{
    . = 0x40080000;

    __kernel_start = .;

    /* The entry point must be the first thing in the image: an ELF loader
       honours the entry address, but a raw binary is jumped to at its start. */
    .text ALIGN(16) : {
        KEEP(*(.text.boot))
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

    /* boot.s zeroes everything between these two symbols, so they must
       bracket .bss exactly. Both are 8-byte aligned because the zeroing loop
       stores a word at a time. */
    . = ALIGN(8);
    __bss_start = .;
    .bss ALIGN(8) : {
        *(.bss)
        *(.bss.*)
        *(COMMON)
    }
    . = ALIGN(8);
    __bss_end = .;

    /* One 64 KiB stack, growing down from __stack_top. The architecture
       requires sp to be 16-byte aligned at every instruction, not just at
       call boundaries, so the top is aligned rather than merely placed. */
    . = ALIGN(16);
    __stack_bottom = .;
    . += 64K;
    . = ALIGN(16);
    __stack_top = .;

    __kernel_end = .;

    /DISCARD/ : {
        *(.comment)
        *(.note.*)
        *(.eh_frame)
        *(.eh_frame_hdr)
    }
}
