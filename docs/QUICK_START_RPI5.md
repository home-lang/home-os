> **Status:** describes target behavior; see [IMPLEMENTATION_STATUS.md](../IMPLEMENTATION_STATUS.md) for current reality.

# Quick Start: HomeOS on Raspberry Pi 5

Get HomeOS running on your Raspberry Pi 5 in under 10 minutes!

## What You Need

- ✅ Raspberry Pi 5 (4GB or 8GB)
- ✅ MicroSD card (8GB+, Class 10)
- ✅ USB-to-Serial adapter (3.3V!)
- ✅ 3 jumper wires (female-to-female)
- ✅ USB-C power supply (5V/5A)

## Step 1: Download Firmware Files

Download these 3 files from https://github.com/raspberrypi/firmware/tree/master/boot

```bash
cd ~/Code/home-os/rpi5/
curl -L -O https://github.com/raspberrypi/firmware/raw/master/boot/start4.elf
curl -L -O https://github.com/raspberrypi/firmware/raw/master/boot/fixup4.dat
curl -L -O https://github.com/raspberrypi/firmware/raw/master/boot/bcm2712-rpi-5-b.dtb
```

## Step 2: Install ARM64 Toolchain

**macOS:**
```bash
brew install aarch64-elf-gcc
```

**Ubuntu/Debian:**
```bash
sudo apt install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu
```

**Arch Linux:**
```bash
sudo pacman -S aarch64-linux-gnu-gcc aarch64-linux-gnu-binutils
```

## Step 3: Build HomeOS

```bash
cd ~/Code/home-os
./scripts/build.sh rpi5
```

Expected output:
```
╔════════════════════════════════════════╗
║  Building HomeOS for Raspberry Pi 5   ║
╚════════════════════════════════════════╝

✅ Build complete!
```

## Step 4: Prepare SD Card

**macOS:**
```bash
# Find your SD card
diskutil list

# Format it (replace diskX with your SD card!)
diskutil unmountDisk /dev/diskX
sudo diskutil eraseDisk FAT32 HOMEOS /dev/diskX

# Copy files
cp -r ~/Code/home-os/build/rpi5/boot/* /Volumes/HOMEOS/

# Eject
diskutil eject /dev/diskX
```

**Linux:**
```bash
# Find your SD card
lsblk

# Format it (replace sdX with your SD card!)
sudo fdisk /dev/sdX  # Delete partitions (d), create new (n), type 'c', write (w)
sudo mkfs.vfat -F 32 /dev/sdX1

# Mount and copy
sudo mkdir -p /mnt/homeos
sudo mount /dev/sdX1 /mnt/homeos
sudo cp -r ~/Code/home-os/build/rpi5/boot/* /mnt/homeos/
sudo umount /mnt/homeos
```

## Step 5: Wire Serial Console

Connect your USB-to-Serial adapter:

```
USB-Serial     →    Raspberry Pi 5
─────────────────────────────────────
GND (Black)    →    Pin 6  (GND)
RX  (White)    →    Pin 8  (GPIO 14)
TX  (Green)    →    Pin 10 (GPIO 15)
```

**⚠️ DO NOT CONNECT VCC/5V PIN!**

## Step 6: Boot HomeOS!

1. Insert SD card into Raspberry Pi 5
2. Connect serial console:
   ```bash
   # macOS
   screen /dev/tty.usbserial-* 115200

   # Linux
   screen /dev/ttyUSB0 115200
   ```
3. Power on Raspberry Pi 5
4. Watch the magic happen! 🎉

Expected output:
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

The green LED on your Pi should blink 5 times! 🎊

## Troubleshooting

**Nothing in serial console?**
- Check wiring (RX ↔ TX are swapped)
- Verify baud rate is 115200
- Try different terminal: `minicom -D /dev/ttyUSB0 -b 115200`

**Pi doesn't boot?**
- Verify SD card is FAT32
- Check all 6 files are on SD card root
- Try a different SD card
- Test SD card with Raspberry Pi OS first

**Build failed?**
- Build Home compiler: `cd ~/Code/home && zig build`
- Check ARM toolchain: `aarch64-linux-gnu-gcc --version`

## Next Steps

- Read the full documentation: `docs/RASPBERRY_PI_5.md`
- Explore the kernel source: `kernel/src/rpi5_main.home`
- Add new features and experiment!
- Join the community and share your progress

## What Works Right Now

✅ Boots on Raspberry Pi 5 bare metal
✅ Serial console output
✅ Device tree parsing
✅ GPIO control
✅ LED blinking
✅ Memory detection

## Coming Soon

🚧 Interrupts and timers
🚧 Keyboard input
🚧 Display graphics
🚧 File system
🚧 Network support
🚧 Multi-core SMP

Enjoy building with HomeOS! 🏠
