# initramfs

Contents handed to the kernel as a Multiboot boot module by
`scripts/boot-gate.sh`, which packs this directory into a newc cpio archive
and passes it to QEMU as `-initrd`.

These files are asserted against by `scripts/boot-milestones.txt` — the gate
runs `cat /etc/motd` and checks the text comes back — so changing them means
changing the milestones to match.
