/* Flat-binary layout for home-os userspace.
 *
 * The kernel's loader (kernel/src/arch/x86_64/usermode.home) reads an image
 * into a page and enters it at offset zero, so the entry point must be first
 * and there is no ELF header to skip. Programs reach their own data through
 * %rip, which makes the image independent of where it is mapped.
 */
ENTRY(_start)
SECTIONS {
    . = 0;
    .text : { *(.text.entry) *(.text*) *(.rodata*) }
    .data : { *(.data*) }
    .bss  : { *(.bss*) *(COMMON) }
    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}
