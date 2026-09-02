/* HomeOS ARM64 boot code.
 *
 * The only assembly in the ARM64 path, and the only place CLAUDE.md permits
 * it: the CPU arrives here with no stack, no zeroed BSS and possibly at the
 * wrong exception level, none of which a Home function can be entered
 * without.
 *
 * Entry contract, identical on QEMU's `virt` machine and on a Raspberry Pi 5:
 *   x0  = physical address of the device tree blob
 *   x1-x3 = reserved, zero
 *   EL  = EL2 on a Pi 5 and on `virt` with virtualization=on, otherwise EL1
 *   MMU off, caches off, one core running (the Pi's other three are parked by
 *   its firmware in a spin loop, and `virt` starts only core 0 unless told
 *   otherwise)
 *
 * Everything after `bl kernel_main` is Home.
 *
 * home-lang/home-os#57
 */

.section .text.boot
.global _start

_start:
    /* Park every core but the first. On the Pi the firmware releases the
       secondaries into this same entry point, and without this they would all
       race through the same stack and BSS zeroing. SMP bring-up
       (home-lang/home-os#64) replaces the parking loop with a spin table. */
    mrs     x4, mpidr_el1
    and     x4, x4, #0xff
    cbnz    x4, park_secondary

    /* The device tree address is the one thing the bootloader gives us that
       cannot be recovered later, so save it before anything can clobber x0. */
    adrp    x5, dtb_address
    add     x5, x5, :lo12:dtb_address
    str     x0, [x5]

    /* Mask every interrupt: there are no vectors installed yet, so anything
       arriving now would go to whatever address VBAR_EL1 happens to hold. */
    msr     daifset, #0xf

    /* If we are at EL2, drop to EL1. The kernel runs at EL1; staying at EL2
       would make every system register access address the wrong bank. */
    mrs     x4, CurrentEL
    lsr     x4, x4, #2
    and     x4, x4, #3
    cmp     x4, #2
    b.ne    at_el1

    /* EL1 will be AArch64, not AArch32. */
    mov     x4, #(1 << 31)
    msr     hcr_el2, x4

    /* A sane EL1 system control register: MMU off, caches off, alignment
       checking off, little-endian. Bits 11, 20, 22, 23, 28 and 29 are RES1 on
       ARMv8, and leaving them clear is architecturally unpredictable. */
    mov     x4, #0x0800
    movk    x4, #0x30d0, lsl #16
    msr     sctlr_el1, x4

    /* Return to EL1h — EL1 with its own stack pointer, which is what a kernel
       wants — with all interrupts still masked. */
    mov     x4, #0x3c5
    msr     spsr_el2, x4
    adr     x4, at_el1
    msr     elr_el2, x4
    eret

at_el1:
    /* One stack, growing down from the symbol the linker script places after
       the image. It is 16-byte aligned there, which the architecture requires
       of sp at every instruction, not merely at call boundaries. */
    adrp    x4, __stack_top
    add     x4, x4, :lo12:__stack_top
    mov     sp, x4

    /* Zero the BSS. Home's globals live here and are declared initialised to
       zero; nothing else guarantees that on bare metal. */
    adrp    x4, __bss_start
    add     x4, x4, :lo12:__bss_start
    adrp    x5, __bss_end
    add     x5, x5, :lo12:__bss_end
zero_bss:
    cmp     x4, x5
    b.hs    bss_done
    str     xzr, [x4], #8
    b       zero_bss
bss_done:

    /* Hand the device tree address to the kernel as its first argument. */
    adrp    x4, dtb_address
    add     x4, x4, :lo12:dtb_address
    ldr     x0, [x4]

    bl      kernel_main

    /* kernel_main is declared to loop forever. If it ever returns, halting is
       the only honest thing left to do — falling through would execute
       whatever bytes follow. */
halt_forever:
    wfe
    b       halt_forever

park_secondary:
    wfe
    b       park_secondary

.section .bss
.balign 8
.global dtb_address
dtb_address:
    .skip 8
