# Raspberry Pi 5 Guide

Complete guide for deploying HomeOS on the Raspberry Pi 5 with full hardware support.

## Hardware Specifications

### Raspberry Pi 5

| Component | Specification |
|-----------|---------------|
| SoC | Broadcom BCM2712 |
| CPU | Quad-core Cortex-A76 @ 2.4GHz |
| GPU | VideoCore VII |
| RAM | 4GB or 8GB LPDDR4X-4267 |
| I/O Controller | RP1 (separate chip via PCIe) |
| Peripherals Base | 0x1f00000000 |
| Boot Mode | Kernel at 0x80000, starts in EL2 |

### Pi 5 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      BCM2712 SoC                                │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────────┐   │
│  │ Cortex-A76 x4 │  │ VideoCore VII │  │   Memory          │   │
│  │   @ 2.4 GHz   │  │     GPU       │  │  LPDDR4X-4267     │   │
│  └───────────────┘  └───────────────┘  │  4GB or 8GB       │   │
│                                        └───────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    PCIe 2.0 x4                          │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         RP1 Southbridge                         │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │  GPIO   │ │  UART   │ │   SPI   │ │   I2C   │ │   PWM   │   │
│  │ 28 pins │ │  x6     │ │   x6    │ │   x6    │ │   x4    │   │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘   │
│  ┌─────────┐ ┌─────────┐ ┌─────────────────────────────────┐   │
│  │  USB 3  │ │ USB 2.0 │ │     Gigabit Ethernet            │   │
│  │  x2     │ │   x2    │ │     (RGMII via RP1)             │   │
│  └─────────┘ └─────────┘ └─────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

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

## Hardware Support Matrix

### Legend

| Symbol | Meaning |
|--------|---------|
| Fully supported | |
| Partial/In progress | |
| Not yet implemented | |

### Core System

| Component | Status | Driver/Module |
|-----------|--------|---------------|
| CPU (Cortex-A76 x4) | Supported | `arch/arm64/` |
| Memory (4GB/8GB) | Supported | `mm/` |
| Device Tree | Supported | `arch/arm64/devicetree.home` |
| Exception Handling | Supported | `arch/arm64/exception.home` |
| Timer (ARM Generic) | Supported | `drivers/timer.home` |
| GIC-400 Interrupts | Supported | `arch/arm64/gic.home` |
| SMP (4 cores) | Supported | `core/smp.home` |

### USB

| Component | Status | Notes |
|-----------|--------|-------|
| USB 3.0 Controller | Supported | 2x USB 3.0 ports (5 Gbps) |
| USB 2.0 Controller | Supported | 2x USB 2.0 ports |
| USB Hub Support | Supported | External hubs |
| USB Mass Storage | Supported | Flash drives, HDD |
| USB Keyboard | Supported | HID class |
| USB Mouse | Supported | HID class |
| USB Ethernet | Partial | RTL8152 |
| USB Audio | Planned | - |

### Storage

| Component | Status | Notes |
|-----------|--------|-------|
| SD Card (SDIO) | Supported | Via BCM2712 |
| SD UHS-I (SDR104) | Supported | 104 MB/s max |
| NVMe via PCIe | Supported | Recommended |
| USB Storage | Supported | Full support |

### Display

| Component | Status | Notes |
|-----------|--------|-------|
| HDMI 0 (4Kp60) | Supported | Micro HDMI |
| HDMI 1 (4Kp60) | Supported | Micro HDMI |
| Dual Display | Partial | WIP |
| 4K @ 60Hz | Supported | Both ports |
| Framebuffer Console | Supported | Text mode |
| GPU Acceleration | Partial | VideoCore VII basic |

### Network

| Component | Status | Notes |
|-----------|--------|-------|
| Gigabit Ethernet | Supported | Native via RP1 |
| WiFi (on-board) | Partial | RP1 integration WIP |
| Bluetooth 5.0 | Partial | Basic pairing |
| TCP/IP Stack | Supported | Full implementation |
| TLS 1.2/1.3 | Supported | AES-GCM |

### GPIO/Peripherals

| Component | Status | Notes |
|-----------|--------|-------|
| GPIO (28 pins) | Supported | Via RP1 |
| UART (6 channels) | Supported | Via RP1 |
| SPI (6 channels) | Supported | Via RP1 |
| I2C (6 channels) | Supported | Via RP1 |
| PWM (4 channels) | Supported | Via RP1 |
| Fan Control (PWM) | Supported | Active cooler |
| Power Button | Supported | Via PMIC |

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

## Building for Pi 5

### Quick Build

```bash
cd ~/Code/home-os
./scripts/build.sh rpi5
```

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

## SD Card Setup

### Preparing the SD Card

1. **Format as FAT32**

   **macOS:**
   ```bash
   diskutil list                    # Find your SD card
   diskutil unmountDisk /dev/diskX
   sudo diskutil eraseDisk FAT32 HOMEOS /dev/diskX
   ```

   **Linux:**
   ```bash
   lsblk                           # Find your SD card
   sudo mkfs.vfat -F 32 /dev/sdX1
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

3. **Copy Files to SD Card**

   ```bash
   cp -r build/rpi5/boot/* /path/to/sd-card/
   ```

4. **Eject Safely**

   ```bash
   # macOS
   diskutil eject /dev/diskX

   # Linux
   sudo umount /mnt/homeos
   ```

## Connecting to Serial Console

### macOS

```bash
ls /dev/tty.usb*                           # Find the serial device
screen /dev/tty.usbserial-XXXXX 115200     # Connect at 115200 baud
```

### Linux

```bash
ls /dev/ttyUSB*                            # Find the serial device
screen /dev/ttyUSB0 115200                 # Connect at 115200 baud
```

### Exit Serial Console

- **screen:** Press `Ctrl+A` then `K`, then `Y` to confirm
- **minicom:** Press `Ctrl+A` then `X`

## First Boot

### Boot Sequence

1. Insert the prepared SD card into Raspberry Pi 5
2. Connect serial console
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

## Performance Targets

### Storage Performance

| Speed Mode | Read | Write |
|------------|------|-------|
| SD DS (25 MHz) | 12.5 MB/s | 12.5 MB/s |
| SD HS (50 MHz) | 25 MB/s | 25 MB/s |
| SD SDR50 (100 MHz) | 50 MB/s | 50 MB/s |
| SD SDR104 (208 MHz) | 104 MB/s | 104 MB/s |
| NVMe (PCIe Gen 2.0) | 400+ MB/s | 350+ MB/s |

### Network Performance

| Metric | Target |
|--------|--------|
| Ethernet TX | 940 Mbps |
| Ethernet RX | 940 Mbps |
| WiFi TX | 100 Mbps |
| Ping Latency (local) | < 1ms |

### Thermal Targets

| State | Temperature | Action |
|-------|-------------|--------|
| Normal | < 60C | Full speed |
| Warm | 60-70C | Fan speed up |
| Hot | 70-80C | Throttle begins |
| Critical | > 85C | Emergency throttle |

## Troubleshooting

### No Serial Output

1. Verify wiring (RX/TX are swapped correctly)
2. Check baud rate is 115200
3. Ensure USB-to-serial adapter is recognized
4. Check that UART is enabled in config.txt

### SD Card Not Recognized

1. Ensure SD card is FAT32 formatted
2. Verify all firmware files are present
3. Check that files are in the root directory
4. Try a different SD card

### Kernel Doesn't Start

1. Check `config.txt` has correct kernel name
2. Verify kernel was built for ARM64
3. Check linker script uses correct load address (0x80000)

### Build Errors

1. Ensure Home compiler is built
2. Check ARM64 toolchain is installed
3. Verify all source files exist

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

To enable all 4 cores:

1. Implement secondary CPU startup via PSCI
2. Set up per-core stacks
3. Add spinlocks and synchronization
4. Configure interrupt routing to all cores

## References

- [Raspberry Pi 5 Documentation](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html)
- [BCM2712 Datasheet](https://datasheets.raspberrypi.com/bcm2712/bcm2712-peripherals.pdf)
- [RP1 Peripherals](https://datasheets.raspberrypi.com/rp1/rp1-peripherals.pdf)
- [ARM Cortex-A76 Technical Reference](https://developer.arm.com/documentation/100798/latest/)
- [Device Tree Specification](https://www.devicetree.org/specifications/)
- [Home Programming Language](https://home-language.org/home/)
