/* ELF layout for home-os userspace.
 *
 * Unlike userland/flat.ld this keeps the ELF headers: the kernel's loader
 * (kernel/src/loader/elf.home) reads them to find out where each segment
 * wants to live, so the addresses here are the ones it will map.
 *
 * 0x40200000 sits above the flat loader's fixed window at 0x40000000 and
 * below the user stack at 0x40100000..., so a session can exercise both
 * loaders without one landing on the other.
 */
ENTRY(_start)
SECTIONS {
    . = 0x40200000;
    .text : { *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss : { *(.bss*) *(COMMON) }
    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}
