# Raspberry Pi 5 Guide

Complete guide for deploying HomeOS on the Raspberry Pi 5.

## Hardware Specifications

### Raspberry Pi 5

| Component | Specification |
|-----------|---------------|
| SoC | Broadcom BCM2712 |
| CPU | Quad-core Cortex-A76 @ 2.4GHz |
| GPU | VideoCore VII |
| RAM | 4GB or 8GB LPDDR4X-4267 |
| I/O Controller | RP1 (separate chip) |
| Peripherals Base | 0x1f00000000 |
| Boot Mode | Kernel at 0x80000, starts in EL2 |

### Hardware Requirements

**Required:**
- Raspberry Pi 5 (4GB or 8GB RAM model)
- MicroSD card (8GB minimum, Class 10 recommended)
- USB-to-Serial adapter (3.3V logic levels)
  - FTDI FT232RL or similar
  - Must support 3.3V logic levels
- Power supply (5V/5A USB-C for Pi 5)
- Jumper wires (female-to-female, 3 wires minimum)

**Optional:**
- HDMI cable and monitor
- USB keyboard and mouse
- Network cable
- Case with cooling

## Serial Console Setup

### Wiring Diagram

Connect your USB-to-Serial adapter to the Raspberry Pi GPIO pins:

```
USB-Serial Adapter     Raspberry Pi 5 GPIO
──────────────────     ──────────────────────
GND (Black)       →    Pin 6  (GND)
RX  (White)       →    Pin 8  (GPIO 14 - TXD)
TX  (Green)       →    Pin 10 (GPIO 15 - RXD)

DO NOT CONNECT VCC/5V - Power via USB-C only!
```

### GPIO Pinout Reference

```
     3V3  (1) (2)  5V
   GPIO2  (3) (4)  5V
   GPIO3  (5) (6)  GND  ← Connect serial GND here
   GPIO4  (7) (8)  GPIO14 (TXD) ← Connect serial RX here
     GND  (9) (10) GPIO15 (RXD) ← Connect serial TX here
  GPIO17 (11) (12) GPIO18
  GPIO27 (13) (14) GND
  GPIO22 (15) (16) GPIO23
     3V3 (17) (18) GPIO24
  GPIO10 (19) (20) GND
   GPIO9 (21) (22) GPIO25
  GPIO11 (23) (24) GPIO8
     GND (25) (26) GPIO7
   GPIO0 (27) (28) GPIO1
   GPIO5 (29) (30) GND
   GPIO6 (31) (32) GPIO12
  GPIO13 (33) (34) GND
  GPIO19 (35) (36) GPIO16
  GPIO26 (37) (38) GPIO20
     GND (39) (40) GPIO21
```

**Warning:** Raspberry Pi GPIO uses 3.3V logic. Ensure your USB-to-serial adapter is set to 3.3V mode, NOT 5V. Using 5V may damage your Raspberry Pi.

## SD Card Setup

### Preparing the SD Card

1. **Format as FAT32**

   **macOS:**
   ```bash
   # Find your SD card
   diskutil list

   # Unmount and format
   diskutil unmountDisk /dev/diskX
   sudo diskutil eraseDisk FAT32 HOMEOS /dev/diskX
   ```

   **Linux:**
   ```bash
   # Find your SD card
   lsblk

   # Partition and format
   sudo fdisk /dev/sdX
   # Use 'n' for new partition, 't' then 'c' for FAT32 LBA, 'w' to write

   sudo mkfs.vfat -F 32 /dev/sdX1

   # Mount
   sudo mkdir -p /mnt/homeos
   sudo mount /dev/sdX1 /mnt/homeos
   ```

2. **Download Raspberry Pi Firmware**

   ```bash
   cd ~/Code/home-os/rpi5/
   curl -L -O https://github.com/raspberrypi/firmware/raw/master/boot/start4.elf
   curl -L -O https://github.com/raspberrypi/firmware/raw/master/boot/fixup4.dat
   curl -L -O https://github.com/raspberrypi/firmware/raw/master/boot/bcm2712-rpi-5-b.dtb
   ```

3. **Build HomeOS**

   ```bash
   cd ~/Code/home-os
   ./scripts/build-rpi5.sh
   ```

4. **Copy Files to SD Card**

   ```bash
   cp -r build/rpi5/boot/* /path/to/sd-card/
   ```

5. **Verify SD Card Contents**

   ```
   /
   ├── home-kernel.img      # HomeOS kernel
   ├── config.txt           # Boot configuration
   ├── cmdline.txt          # Kernel parameters
   ├── start4.elf          # Raspberry Pi firmware
   ├── fixup4.dat          # GPU config
   └── bcm2712-rpi-5-b.dtb # Device tree
   ```

6. **Eject Safely**

   ```bash
   # macOS
   diskutil eject /dev/diskX

   # Linux
   sudo umount /mnt/homeos
   ```

## Connecting to Serial Console

### macOS

```bash
# Find the serial device
ls /dev/tty.usb*

# Connect with screen (115200 baud)
screen /dev/tty.usbserial-XXXXX 115200

# Or use minicom
brew install minicom
minicom -D /dev/tty.usbserial-XXXXX -b 115200
```

### Linux

```bash
# Find the serial device
ls /dev/ttyUSB*

# Connect with screen
screen /dev/ttyUSB0 115200

# Or use minicom
sudo apt install minicom
minicom -D /dev/ttyUSB0 -b 115200
```

### Exit Serial Console

- **screen:** Press `Ctrl+A` then `K`, then `Y` to confirm
- **minicom:** Press `Ctrl+A` then `X`

## First Boot

### Boot Sequence

1. Insert the prepared SD card into Raspberry Pi 5
2. Connect serial console (see above)
3. Power on the Raspberry Pi 5 via USB-C
4. Watch the serial console for output

### Expected Output

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

The green activity LED on the board should blink 5 times.

## Boot Configuration

### config.txt

The `config.txt` file configures the Raspberry Pi bootloader:

```ini
# HomeOS Boot Configuration

# ARM 64-bit mode
arm_64bit=1

# Kernel filename
kernel=home-kernel.img

# Enable UART for serial console
enable_uart=1

# Disable splash screen
disable_splash=1

# GPU memory (minimal for text mode)
gpu_mem=16

# Optional: Enable HDMI
# hdmi_drive=2
# hdmi_group=1
# hdmi_mode=16
```

### cmdline.txt

Kernel command line parameters:

```
console=serial0,115200 root=/dev/mmcblk0p2 rootwait
```

## GPIO Access

HomeOS provides full GPIO access for hardware projects.

### GPIO API

```home
// Initialize GPIO
gpio_init()

// Request a GPIO pin
let handle = gpio_request(BCM2712_GPIO, pin_number)

// Set pin mode
gpio_set_mode(handle, GPIO_MODE_OUTPUT)  // or GPIO_MODE_INPUT

// Write to pin
gpio_write(handle, 1)  // HIGH
gpio_write(handle, 0)  // LOW

// Read from pin
let value = gpio_read(handle)

// Toggle pin
gpio_toggle(handle)

// Enable interrupt
gpio_enable_interrupt(handle, GPIO_EDGE_RISING, callback, user_data)

// Configure PWM
let pwm_handle = gpio_pwm_configure(handle, frequency)
gpio_pwm_set_duty(pwm_handle, duty_cycle)
gpio_pwm_enable(pwm_handle)
```

### LED Blink Example

```home
// Blink the activity LED
fn blink_led() {
  let led = gpio_request(BCM2712_GPIO, 42)  // Activity LED
  gpio_set_mode(led, GPIO_MODE_OUTPUT)

  for i in 0..5 {
    gpio_write(led, 1)
    timer_sleep_ms(200)
    gpio_write(led, 0)
    timer_sleep_ms(200)
  }
}
```

## Memory Map

### Physical Memory Layout

```
Address Range                Description
────────────────────────────  ─────────────────────────────
0x00000000 - 0x0003FFFF      GPU firmware (VideoCore)
0x00040000 - 0x0007FFFF      GPU memory
0x00080000 - 0x????????      Kernel (HomeOS loaded here)
0x40000000 - 0xFFFFFFFF      RAM (4GB or 8GB total)
0x1f00000000 - 0x1f00FFFFFF  Peripherals (via RP1 chip)
  └─ 0x1f00100000            GPIO registers
  └─ 0x1f00200000            UART0 (PL011)
```

### Memory Budget

| Component | Budget |
|-----------|--------|
| Kernel | < 128MB |
| Framebuffer | 32MB (for 4K) |
| GPU | 16MB minimum |
| User space | Remaining |

## Troubleshooting

### No Serial Output

**Solutions:**
1. Verify wiring (RX/TX are swapped correctly)
2. Check baud rate is 115200
3. Ensure USB-to-serial adapter is recognized:
   ```bash
   # macOS
   ls /dev/tty.usb*

   # Linux
   dmesg | grep tty
   ```
4. Try a different serial terminal program
5. Check that UART is enabled in config.txt

### SD Card Not Recognized

**Solutions:**
1. Ensure SD card is FAT32 formatted
2. Verify all firmware files are present
3. Check that files are in the root directory (not in a subdirectory)
4. Try a different SD card
5. Verify SD card works with Raspberry Pi OS first

### Kernel Doesn't Start

**Solutions:**
1. Check `config.txt` has correct kernel name (`home-kernel.img`)
2. Verify kernel was built for ARM64:
   ```bash
   file build/rpi5/boot/home-kernel.img
   # Should say: "data" or show ARM64 binary
   ```
3. Check linker script uses correct load address (0x80000)
4. Verify boot.s assembly code is correct

### Build Errors

**Solutions:**
1. Ensure Home compiler is built:
   ```bash
   cd ~/Code/home
   zig build
   ```
2. Check ARM64 toolchain is installed:
   ```bash
   aarch64-linux-gnu-gcc --version
   # or
   aarch64-elf-gcc --version
   ```
3. Verify all source files exist
4. Check for syntax errors in `.home` files

## Advanced Configuration

### Enabling Graphics Output

Modify `config.txt`:

```ini
# Enable HDMI
hdmi_drive=2
hdmi_group=1
hdmi_mode=16  # 1920x1080 60Hz

# Increase GPU memory
gpu_mem=128
```

### Multi-Core Boot

To enable all 4 cores (advanced):

1. Implement secondary CPU startup via PSCI
2. Set up per-core stacks
3. Add spinlocks and synchronization
4. Configure interrupt routing to all cores

See `~/Code/home/packages/kernel/src/arm64/arch.zig` for PSCI implementation.

### JTAG Debugging

For low-level debugging:

1. Get a compatible JTAG adapter (e.g., Segger J-Link)
2. Connect to Raspberry Pi 5 JTAG pins (GPIO 22-27)
3. Use OpenOCD or J-Link GDB server:
   ```bash
   aarch64-linux-gnu-gdb build/rpi5/bin/home-kernel.elf
   target remote localhost:3333
   ```

### Network Boot (TFTP)

To avoid SD card swapping:

1. Set up TFTP server on your development machine
2. Configure Raspberry Pi for network boot
3. Kernel loads over network
4. Much faster iteration

## What Works

**Currently Implemented:**
- ARM64 boot sequence (EL2 to EL1)
- Device tree parsing
- UART serial console (115200 baud)
- GPIO control (BCM2712)
- LED blinking
- Memory detection
- CPU core detection

## Roadmap

**Coming Soon:**
- GIC-600 interrupt handling
- ARM Generic Timer
- Memory management (page tables, allocator)
- Multi-core SMP support
- USB support (xHCI via RP1)
- Ethernet support (GENET)
- Graphics output (VideoCore VII)
- File system support

## References

- [Raspberry Pi 5 Documentation](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html)
- [BCM2712 Datasheet](https://datasheets.raspberrypi.com/bcm2712/bcm2712-peripherals.pdf)
- [ARM Cortex-A76 Technical Reference](https://developer.arm.com/documentation/100798/latest/)
- [Device Tree Specification](https://www.devicetree.org/specifications/)
- [Home Programming Language](/home/)
