# Getting Started

This guide will help you build and run HomeOS on your target platform.

## Prerequisites

### Common Requirements

1. **Home Compiler**

   The Home compiler is required to build HomeOS. Clone and build it:

   ```bash
   cd ~/Code/home
   zig build
   ```

2. **Zig** (temporary, until Home self-hosts)

   ```bash
   # macOS
   brew install zig

   # Ubuntu/Debian
   sudo apt install zig
   ```

### For Raspberry Pi 5

1. **ARM64 Cross-compilation Tools**

   ```bash
   # macOS
   brew install aarch64-elf-gcc

   # Ubuntu/Debian
   sudo apt install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu

   # Arch Linux
   sudo pacman -S aarch64-linux-gnu-gcc aarch64-linux-gnu-binutils
   ```

2. **Raspberry Pi Firmware Files**

   Download from the [Raspberry Pi firmware repository](https://github.com/raspberrypi/firmware/tree/master/boot):

   - `start4.elf` - GPU firmware
   - `fixup4.dat` - GPU memory configuration
   - `bcm2712-rpi-5-b.dtb` - Device tree binary for Pi 5

   Place these in the `rpi5/` directory.

3. **Hardware**
   - Raspberry Pi 5 (4GB or 8GB RAM)
   - MicroSD card (8GB minimum, Class 10 recommended)
   - USB-to-Serial adapter (3.3V logic levels)
   - 5V/5A USB-C power supply

### For x86-64 (QEMU)

1. **QEMU**

   ```bash
   # macOS
   brew install qemu

   # Ubuntu/Debian
   sudo apt install qemu-system-x86
   ```

2. **GRUB Tools** (for bootable ISO)

   ```bash
   # macOS
   brew install grub xorriso

   # Ubuntu/Debian
   sudo apt install grub-pc-bin xorriso
   ```

## Building for QEMU (x86-64)

The simplest way to test HomeOS is using QEMU emulation.

### Quick Build and Run

```bash
cd ~/Code/home-os/kernel
zig build qemu
```

This will:
1. Compile the kernel
2. Create a bootable ISO
3. Launch QEMU with the kernel

### Build Only

```bash
cd ~/Code/home-os/kernel
zig build iso    # Create bootable ISO
```

The ISO will be created at `kernel/build/home-os.iso`.

### Running with Options

```bash
# Run with debugging enabled
./scripts/run-qemu.sh --debug

# Run with KVM acceleration (Linux only)
./scripts/run-qemu.sh --kvm
```

### Expected Output

When HomeOS boots successfully, you should see:

1. **GRUB Menu** (5 second timeout)
   ```
   home-os
   home-os (debug mode)
   home-os (safe mode)
   ```

2. **Boot Messages** (serial console)
   ```
   home-os kernel starting...
   Multiboot2 magic verified: 0x36d76289
   Boot info address: 0x...
   Bootloader: GRUB 2.xx

   Memory map:
     0x0000000000000000 - 0x000000000009fc00 (639 KB) - Available
     ...
   Total usable memory: XXX MB

   Kernel initialized successfully!
   Entering idle loop...
   ```

## Building for Raspberry Pi 5

### Quick Build

```bash
cd ~/Code/home-os
./scripts/build-rpi5.sh
```

This will:
1. Compile the Home kernel source to ARM64
2. Assemble the ARM64 boot code
3. Link with the Raspberry Pi 5 linker script
4. Create `home-kernel.img` binary
5. Prepare boot configuration files

### Build Output

After building, you'll find these files in `build/rpi5/boot/`:

```
build/rpi5/boot/
├── home-kernel.img      # HomeOS kernel
├── config.txt           # Bootloader configuration
├── cmdline.txt          # Kernel command line
├── start4.elf          # Raspberry Pi GPU firmware
├── fixup4.dat          # GPU memory config
└── bcm2712-rpi-5-b.dtb # Device tree for Pi 5
```

### Preparing the SD Card

1. **Format the SD card as FAT32**

   **macOS:**
   ```bash
   diskutil list                          # Find your SD card (e.g., /dev/disk4)
   diskutil unmountDisk /dev/diskX
   sudo diskutil eraseDisk FAT32 HOMEOS /dev/diskX
   ```

   **Linux:**
   ```bash
   lsblk                                  # Find your SD card (e.g., /dev/sdb)
   sudo mkfs.vfat -F 32 /dev/sdX1
   sudo mkdir -p /mnt/homeos
   sudo mount /dev/sdX1 /mnt/homeos
   ```

2. **Copy boot files**

   ```bash
   cp -r build/rpi5/boot/* /path/to/sd-card/
   ```

3. **Verify files on SD card**

   Your SD card should contain:
   ```
   /
   ├── home-kernel.img      # HomeOS kernel
   ├── config.txt           # Boot configuration
   ├── cmdline.txt          # Kernel parameters
   ├── start4.elf          # Raspberry Pi firmware
   ├── fixup4.dat          # GPU config
   └── bcm2712-rpi-5-b.dtb # Device tree
   ```

4. **Eject safely**

   ```bash
   # macOS
   diskutil eject /dev/diskX

   # Linux
   sudo umount /mnt/homeos
   ```

## First Boot

### Serial Console Setup

Connect your USB-to-Serial adapter to the Raspberry Pi GPIO pins:

```
USB-Serial Adapter     Raspberry Pi 5 GPIO
──────────────────     ──────────────────────
GND (Black)       →    Pin 6  (GND)
RX  (White)       →    Pin 8  (GPIO 14 - TXD)
TX  (Green)       →    Pin 10 (GPIO 15 - RXD)

DO NOT CONNECT VCC/5V - Power via USB-C only!
```

**Important:** Raspberry Pi GPIO uses 3.3V logic. Ensure your USB-to-serial adapter is set to 3.3V mode, NOT 5V.

### Connecting to Serial Console

**macOS:**
```bash
ls /dev/tty.usb*                           # Find the serial device
screen /dev/tty.usbserial-XXXXX 115200     # Connect at 115200 baud
```

**Linux:**
```bash
ls /dev/ttyUSB*                            # Find the serial device
screen /dev/ttyUSB0 115200                 # Connect at 115200 baud
```

### Boot Sequence

1. Insert the prepared SD card into Raspberry Pi 5
2. Connect serial console
3. Power on via USB-C
4. Watch the serial console for output

### Expected Output

```
HomeOS booting on Raspberry Pi 5...

=== Device Tree Information ===
Model: Raspberry Pi 5 Model B Rev 1.0
Memory regions:
  0x0000000000000000 - 0x0000000100000000 (4096 MB)
CPUs detected: 4

Blinking status LED...
LED blink test complete!
Entering idle loop...
```

The green activity LED on the board should blink 5 times.

## Troubleshooting

### No Serial Output

1. Verify wiring (RX/TX are swapped correctly)
2. Check baud rate is 115200
3. Ensure USB-to-serial adapter is recognized
4. Try a different serial terminal program

### SD Card Not Recognized

1. Ensure SD card is FAT32 formatted
2. Verify all firmware files are present
3. Check that files are in the root directory
4. Try a different SD card

### Kernel Doesn't Start

1. Check `config.txt` has correct kernel name
2. Verify kernel was built for ARM64
3. Check linker script uses correct load address (0x80000)

### QEMU Issues

1. Ensure QEMU is installed: `qemu-system-x86_64 --version`
2. Check for virtualization support
3. Verify ISO was created correctly

## Next Steps

- Read the [Architecture Guide](/guide/architecture) to understand the kernel design
- Explore [File Systems](/guide/filesystems) supported by HomeOS
- Learn about [Networking](/guide/networking) capabilities
- Check [Device Drivers](/guide/drivers) for hardware support
- Deploy on [Raspberry Pi 5](/guide/rpi5) with full hardware support
