# HomeOS on Raspberry Pi 5

Complete guide for building, deploying, and testing HomeOS on the Raspberry Pi 5.

## Overview

HomeOS now supports the Raspberry Pi 5, utilizing its ARM64 architecture (Cortex-A76 CPU cores). The OS boots directly on bare metal without QEMU emulation, using the Raspberry Pi's native bootloader.

### Hardware Requirements

- **Raspberry Pi 5** (4GB or 8GB RAM model)
- **MicroSD card** (8GB minimum, Class 10 recommended)
- **USB-to-Serial adapter** (for console output)
  - FTDI FT232RL or similar
  - Must support 3.3V logic levels
- **Power supply** (5V/5A USB-C for Pi 5)
- **Jumper wires** (female-to-female, 3 wires minimum)
- **(Optional)** HDMI cable and monitor for graphics output

### Raspberry Pi 5 Specifications

- **SoC**: Broadcom BCM2712 (quad-core Cortex-A76 @ 2.4GHz)
- **GPU**: VideoCore VII
- **RAM**: 4GB or 8GB LPDDR4X-4267
- **I/O Controller**: RP1 (separate chip handling GPIO, USB, Ethernet)
- **Peripherals Base**: 0x1f00000000 (different from Pi 4!)
- **Boot Mode**: Loads kernel at 0x80000, starts in EL2

## Build Prerequisites

### Software Requirements

1. **Home Compiler** (already in `~/Code/home/`)
   ```bash
   cd ~/Code/home
   zig build
   ```

2. **ARM64 Cross-compilation Tools**
   ```bash
   # macOS
   brew install aarch64-elf-gcc

   # Ubuntu/Debian
   sudo apt install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu

   # Arch Linux
   sudo pacman -S aarch64-linux-gnu-gcc aarch64-linux-gnu-binutils
   ```

3. **Raspberry Pi Firmware Files**
   Download from: https://github.com/raspberrypi/firmware/tree/master/boot

   Required files:
   - `start4.elf` - GPU firmware
   - `fixup4.dat` - GPU memory configuration
   - `bcm2712-rpi-5-b.dtb` - Device tree binary for Pi 5

   Place these in: `~/Code/home-os/rpi5/`

## Building HomeOS for Raspberry Pi 5

### Quick Build

```bash
cd ~/Code/home-os
./scripts/build-rpi5.sh
```

The build script will:
1. ✅ Compile the Home kernel source to ARM64
2. ✅ Assemble the ARM64 boot code
3. ✅ Link with the Raspberry Pi 5 linker script
4. ✅ Create `home-kernel.img` binary
5. ✅ Prepare boot configuration files
6. ✅ Organize files for SD card deployment

### Build Output

```
build/rpi5/boot/
├── home-kernel.img      # HomeOS kernel (our OS!)
├── config.txt           # Bootloader configuration
├── cmdline.txt          # Kernel command line
├── start4.elf          # Raspberry Pi GPU firmware
├── fixup4.dat          # GPU memory config
└── bcm2712-rpi-5-b.dtb # Device tree for Pi 5
```

### Manual Build (for development)

If you need to build manually:

```bash
# 1. Assemble boot code
cd ~/Code/home-os
aarch64-linux-gnu-as ~/Code/home/packages/kernel/src/arm64/boot.s -o build/boot.o

# 2. Compile kernel (temporary Zig build until Home self-hosts)
cd ~/Code/home/packages/kernel
zig build -Dtarget=aarch64-freestanding -Doptimize=ReleaseSmall

# 3. Create kernel image
aarch64-linux-gnu-objcopy zig-out/bin/home-kernel.elf -O binary home-kernel.img

# 4. Copy to boot directory
cp home-kernel.img ~/Code/home-os/build/rpi5/boot/
```

## Preparing the SD Card

### 1. Format SD Card

**macOS:**
```bash
# Insert SD card, find the device (e.g., /dev/disk4)
diskutil list

# Unmount the disk
diskutil unmountDisk /dev/diskX

# Format as FAT32
sudo diskutil eraseDisk FAT32 HOMEOS /dev/diskX
```

**Linux:**
```bash
# Insert SD card, find the device (e.g., /dev/sdb)
lsblk

# Create FAT32 partition
sudo fdisk /dev/sdX
# (use 'd' to delete partitions, 'n' to create new, 't' to set type to 'c' (W95 FAT32 LBA), 'w' to write)

# Format partition
sudo mkfs.vfat -F 32 /dev/sdX1

# Mount it
sudo mkdir -p /mnt/homeos
sudo mount /dev/sdX1 /mnt/homeos
```

### 2. Copy Boot Files

```bash
# Copy all files from build directory to SD card
cp -r ~/Code/home-os/build/rpi5/boot/* /path/to/sd-card/

# Eject SD card safely
# macOS: diskutil eject /dev/diskX
# Linux: sudo umount /mnt/homeos
```

### 3. Verify Files

Your SD card should contain:
```
/
├── home-kernel.img      ← HomeOS kernel
├── config.txt           ← Boot configuration
├── cmdline.txt          ← Kernel parameters
├── start4.elf          ← Raspberry Pi firmware
├── fixup4.dat          ← GPU config
└── bcm2712-rpi-5-b.dtb ← Device tree
```

## Hardware Setup

### Serial Console Wiring

Connect your USB-to-Serial adapter to the Raspberry Pi GPIO pins:

```
USB-Serial Adapter     Raspberry Pi 5 GPIO
──────────────────     ──────────────────────
GND (Black)       →    Pin 6  (GND)
RX  (White)       →    Pin 8  (GPIO 14 - TXD)
TX  (Green)       →    Pin 10 (GPIO 15 - RXD)

DO NOT CONNECT VCC/5V - Power via USB-C only!
```

**GPIO Pinout Reference (Raspberry Pi 5):**
```
     3V3  (1) (2)  5V
   GPIO2  (3) (4)  5V
   GPIO3  (5) (6)  GND  ← Connect serial GND here
   GPIO4  (7) (8)  GPIO14 (TXD) ← Connect serial RX here
     GND  (9) (10) GPIO15 (RXD) ← Connect serial TX here
```

**⚠️ IMPORTANT:** Raspberry Pi GPIO uses 3.3V logic! Ensure your USB-to-serial adapter is set to 3.3V mode, NOT 5V!

## Testing HomeOS

### 1. Connect Serial Console

**macOS:**
```bash
# Find the serial device
ls /dev/tty.usb*

# Connect with screen
screen /dev/tty.usbserial-XXXXX 115200

# Or use minicom
brew install minicom
minicom -D /dev/tty.usbserial-XXXXX -b 115200
```

**Linux:**
```bash
# Find the serial device
ls /dev/ttyUSB*

# Connect with screen
screen /dev/ttyUSB0 115200

# Or use minicom
sudo apt install minicom
minicom -D /dev/ttyUSB0 -b 115200
```

### 2. Insert SD Card and Power On

1. Insert the prepared SD card into Raspberry Pi 5
2. Connect serial console (step 1)
3. Power on the Raspberry Pi 5 via USB-C
4. Watch the serial console for output

### 3. Expected Output

You should see:

```
HomeOS booting on Raspberry Pi 5...

╔════════════════════════════════════════╗
║     Home Operating System v0.1.0      ║
║   Built with Home Programming Lang    ║
║      Running on Raspberry Pi 5        ║
╚════════════════════════════════════════╝

=== Device Tree Information ===
Model: Raspberry Pi 5 Model B Rev 1.0
Memory regions:
  0x0000000000000000 - 0x0000000100000000 (4096 MB)
CPUs detected: 4

Blinking status LED...
LED blink test complete!
Entering idle loop...
```

The green activity LED on the board should blink 5 times!

## Troubleshooting

### No Serial Output

**Problem:** Nothing appears in serial console

**Solutions:**
1. Verify wiring (RX/TX are swapped correctly)
2. Check baud rate is 115200
3. Ensure USB-to-serial adapter is recognized
   ```bash
   # macOS
   ls /dev/tty.usb*

   # Linux
   dmesg | grep tty
   ```
4. Try a different serial terminal program
5. Check that UART is enabled in config.txt

### SD Card Not Recognized

**Problem:** Raspberry Pi doesn't boot from SD card

**Solutions:**
1. Ensure SD card is FAT32 formatted
2. Verify all firmware files are present
3. Check that files are in the root directory (not in a subdirectory)
4. Try a different SD card
5. Verify SD card works with Raspberry Pi OS first

### Kernel Doesn't Start

**Problem:** Firmware loads but kernel doesn't run

**Solutions:**
1. Check `config.txt` has correct kernel name (`home-kernel.img`)
2. Verify kernel was built for ARM64 (aarch64)
   ```bash
   file build/rpi5/boot/home-kernel.img
   # Should say: "data" or show ARM64 binary
   ```
3. Check linker script is using correct load address (0x80000)
4. Verify boot.s assembly code is correct

### Build Errors

**Problem:** Compilation fails

**Solutions:**
1. Ensure Home compiler is built:
   ```bash
   cd ~/Code/home
   zig build
   ```
2. Check ARM64 toolchain is installed:
   ```bash
   aarch64-linux-gnu-gcc --version
   ```
3. Verify all source files exist
4. Check for syntax errors in `.home` files

## Advanced Configuration

### Enabling Graphics Output

To use HDMI output instead of serial console, modify `config.txt`:

```ini
# Uncomment these lines:
hdmi_drive=2
hdmi_group=1
hdmi_mode=16  # 1920x1080 60Hz

# Increase GPU memory:
gpu_mem=128
```

### Overclocking (Use with Caution!)

⚠️ **Warning:** Overclocking may void warranty and cause instability!

```ini
# Add to config.txt:
over_voltage=6
arm_freq=2600
gpu_freq=800
```

### Multi-Core Boot

Currently, HomeOS boots only CPU core 0. To enable all 4 cores, you'll need to implement:

1. Secondary CPU startup via PSCI
2. Per-core stacks
3. Spinlocks and synchronization
4. Interrupt routing to all cores

See `~/Code/home/packages/kernel/src/arm64/arch.zig` for PSCI implementation.

### Debugging with JTAG

For low-level debugging, you can use a JTAG adapter:

1. Get a compatible JTAG adapter (e.g., Segger J-Link)
2. Connect to Raspberry Pi 5 JTAG pins (GPIO 22-27)
3. Use OpenOCD or J-Link GDB server
4. Debug with GDB:
   ```bash
   aarch64-linux-gnu-gdb build/rpi5/bin/home-kernel.elf
   target remote localhost:3333
   ```

## Development Workflow

### Iterative Development

1. Edit source files in `kernel/src/rpi5_main.home`
2. Build: `./scripts/build-rpi5.sh`
3. Copy only `home-kernel.img` to SD card:
   ```bash
   cp build/rpi5/boot/home-kernel.img /path/to/sd-card/
   ```
4. Eject, insert into Pi, test
5. Repeat

### Using Network Boot (Advanced)

To avoid constantly swapping SD cards:

1. Set up a TFTP server on your development machine
2. Configure Raspberry Pi for network boot
3. Kernel loads over network instead of SD card
4. Much faster iteration!

(Documentation for this coming soon)

## What Works

✅ **Currently Implemented:**
- ARM64 boot sequence (EL2 → EL1)
- Device tree parsing
- UART serial console (115200 baud)
- GPIO control (BCM2712)
- LED blinking
- Memory detection
- CPU core detection

## Roadmap

🚧 **Coming Soon:**
- Interrupt handling (GIC-400)
- Timer support (ARM Generic Timer)
- Memory management (page tables, allocator)
- Multi-core SMP support
- USB support (xHCI controller)
- Ethernet support (GENET)
- Graphics output (VC7 GPU)
- File system support

## Technical Details

### Boot Sequence

1. **GPU Bootloader** (stage 1)
   - Built into Raspberry Pi ROM
   - Loads `bootcode.bin` from SD card

2. **GPU Bootloader** (stage 2)
   - Loads `start4.elf` firmware
   - Initializes hardware

3. **Firmware** (`start4.elf`)
   - Reads `config.txt`
   - Loads device tree (`bcm2712-rpi-5-b.dtb`)
   - Loads kernel (`home-kernel.img`) to 0x80000
   - Starts CPU core 0 at 0x80000 in EL2 mode
   - Passes DTB address in `x0` register

4. **Boot Assembly** (`boot.s`)
   - Drops from EL2 to EL1
   - Sets up page tables
   - Enables MMU
   - Clears BSS
   - Sets up stack
   - Calls `kernel_main(dtb_addr)`

5. **Kernel Main** (`rpi5_main.home`)
   - Initializes serial console
   - Parses device tree
   - Initializes GPIO
   - Blinks LED
   - Enters idle loop

### Memory Map

```
Physical Address Range        Description
────────────────────────────  ─────────────────────────────
0x00000000 - 0x0003FFFF      GPU firmware (VideoCore)
0x00040000 - 0x0007FFFF      GPU memory
0x00080000 - 0x????????      Kernel (HomeOS loaded here)
0x40000000 - 0xFFFFFFFF      RAM (4GB or 8GB total)
0x1f00000000 - 0x1f00FFFFFF  Peripherals (via RP1 chip)
  └─ 0x1f00100000            GPIO registers
  └─ 0x1f00200000            UART0 (PL011)
```

### Device Tree

The device tree blob (DTB) contains all hardware information:
- Memory layout
- CPU configuration
- Peripheral addresses
- GPIO pin mappings
- Interrupt routing
- Clock frequencies

HomeOS uses the DTB parser from `~/Code/home/packages/dtb/` to discover and configure hardware automatically.

## References

- [Raspberry Pi 5 Documentation](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html)
- [BCM2712 Datasheet](https://datasheets.raspberrypi.com/bcm2712/bcm2712-peripherals.pdf)
- [ARM Cortex-A76 Technical Reference](https://developer.arm.com/documentation/100798/latest/)
- [Device Tree Specification](https://www.devicetree.org/specifications/)
- [Home Programming Language](~/Code/home/README.md)

## Support

For issues specific to Raspberry Pi 5 deployment:
- Check the [Troubleshooting](#troubleshooting) section above
- Review serial console output carefully
- Verify hardware connections
- Test with a known-good Raspberry Pi OS SD card first

## License

HomeOS is part of the Home Programming Language project.
