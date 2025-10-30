# Installing HomeOS on Raspberry Pi 5

This guide walks you through installing HomeOS on a Raspberry Pi 5, including hardware requirements, preparation steps, and boot configuration.

## Hardware Requirements

### Minimum Requirements

- **Raspberry Pi 5** (4GB or 8GB RAM model)
- **MicroSD card** (16GB minimum, 32GB+ recommended, Class 10 or UHS-I)
- **USB-C Power Supply** (5V/5A, 27W official Raspberry Pi power supply recommended)
- **USB keyboard** (for initial setup)
- **HDMI display** (micro HDMI to HDMI cable required)

### Optional Hardware

- **NVMe SSD** (M.2 2230 or 2242 via PCIe HAT for faster boot and storage)
- **Ethernet cable** (Gigabit Ethernet supported via BCM54213S PHY)
- **Active cooling** (heatsink or fan recommended for sustained workloads)
- **USB mouse** (for graphical environment)

## Supported Features

HomeOS on Raspberry Pi 5 supports:

- ✅ **BCM2712 SoC** (Quad-core ARM Cortex-A76 @ 2.4GHz)
- ✅ **RP1 I/O Controller** (PCIe-connected southbridge for GPIO, UART, SPI, I2C, PWM)
- ✅ **PCIe Gen 2.0** (for NVMe SSDs and expansion)
- ✅ **Video Core VII GPU** (Vulkan 1.2, OpenGL ES 3.1)
- ✅ **Gigabit Ethernet** (BCM54213S PHY)
- ✅ **UART Console** (115200 baud, 8N1 via GPIO pins 14/15)
- ✅ **GPIO** (28 pins via RP1)
- ✅ **USB 3.0** (2x USB 3.0 ports, 2x USB 2.0 ports)

## Prerequisites

### Tools Required

- Computer with SD card reader (Linux, macOS, or Windows)
- `dd` or balenaEtcher for writing images
- Serial console adapter (optional, for debugging)

### Download HomeOS Image

```bash
# Download the latest Raspberry Pi 5 image
curl -LO https://releases.home-os.dev/rpi5/home-os-rpi5-latest.img.xz

# Verify checksum
curl -LO https://releases.home-os.dev/rpi5/home-os-rpi5-latest.img.xz.sha256
sha256sum -c home-os-rpi5-latest.img.xz.sha256
```

## Installation Steps

### 1. Prepare the SD Card

#### On Linux/macOS

```bash
# Extract the image
xz -d home-os-rpi5-latest.img.xz

# Identify your SD card device (be careful!)
lsblk  # or diskutil list on macOS

# Write the image (replace /dev/sdX with your SD card device)
sudo dd if=home-os-rpi5-latest.img of=/dev/sdX bs=4M status=progress conv=fsync

# On macOS, use:
sudo dd if=home-os-rpi5-latest.img of=/dev/rdiskX bs=4m
```

#### On Windows

1. Download and install [balenaEtcher](https://www.balena.io/etcher/)
2. Select the `home-os-rpi5-latest.img.xz` file
3. Select your SD card
4. Click "Flash!"

### 2. Configure Boot Settings (Optional)

Mount the boot partition and edit `config.txt`:

```bash
# Mount the boot partition
sudo mount /dev/sdX1 /mnt

# Edit config.txt
sudo nano /mnt/config.txt
```

Add or modify these settings:

```ini
# Enable UART console (GPIO 14/15)
enable_uart=1

# Set CPU frequency (default: 2400MHz)
arm_freq=2400

# GPU memory allocation (MB)
gpu_mem=256

# Enable PCIe Gen 2.0 (for NVMe)
dtparam=pciex1

# Enable I2C, SPI (if needed)
dtparam=i2c_arm=on
dtparam=spi=on

# Overclock settings (optional, use with caution)
# over_voltage=6
# arm_freq=2600
```

Unmount the partition:

```bash
sudo umount /mnt
```

### 3. Boot HomeOS

1. **Insert the SD card** into your Raspberry Pi 5
2. **Connect peripherals** (keyboard, display, ethernet/WiFi)
3. **Connect power** - the Pi will automatically boot

#### Expected Boot Sequence

```text
[RPI5] Initializing Raspberry Pi 5...
[RPI5] Initializing PCIe Gen 2.0...
[RPI5] PCIe link established
[RPI5] Initializing RP1 southbridge...
[RPI5] RP1 initialized
[RPI5] UART initialized
[RPI5] GPIO initialized via RP1
[RPI5] Initializing Gigabit Ethernet (BCM54213S)...
[RPI5] Ethernet initialized
[RPI5] Initialization complete
[KERNEL] HomeOS kernel started
```

### 4. First Boot Setup

On first boot, you'll be prompted to:

1. Set root password
2. Configure network (Ethernet auto-configures via DHCP)
3. Set timezone
4. Create user account

## Advanced Configuration

### Installing to NVMe SSD

For better performance, install HomeOS to an NVMe SSD:

1. **Attach NVMe HAT** to your Raspberry Pi 5
2. **Boot from SD card** with NVMe attached
3. **Clone to NVMe**:
   ```bash
   # Identify NVMe device
   lsblk
   
   # Clone SD card to NVMe
   sudo dd if=/dev/mmcblk0 of=/dev/nvme0n1 bs=4M status=progress conv=fsync
   
   # Update boot configuration
   sudo home-os-config set-boot-device nvme
   ```
4. **Reboot** - system will boot from NVMe

### Serial Console Access

Connect a USB-to-TTL serial adapter to GPIO pins:

- **GPIO 14 (TXD)** → RX on adapter
- **GPIO 15 (RXD)** → TX on adapter
- **GND** → GND on adapter

Connect with 115200 baud, 8N1:

```bash
screen /dev/ttyUSB0 115200
# or
minicom -D /dev/ttyUSB0 -b 115200
```

### GPIO Access

GPIO pins are accessible via the RP1 I/O controller:

```bash
# Export GPIO pin
echo 23 > /sys/class/gpio/export

# Set as output
echo out > /sys/class/gpio/gpio23/direction

# Set high
echo 1 > /sys/class/gpio/gpio23/value
```

### Monitoring System Health

```bash
# Check CPU temperature
home-os-status temp

# Check CPU frequency
home-os-status freq

# Check memory usage
home-os-status mem

# View system logs
journalctl -f
```

## Troubleshooting

### Pi Won't Boot

- **Check power supply** - Pi 5 requires 5V/5A (27W)
- **Verify SD card** - try re-flashing the image
- **Check HDMI connection** - use the HDMI0 port (closest to USB-C power)
- **Enable UART console** - connect serial adapter to see boot messages

### No Network Connectivity

```bash
# Check Ethernet link
ip link show eth0

# Request DHCP address
sudo dhclient eth0

# Check routing
ip route
```

### NVMe Not Detected

- Ensure PCIe is enabled in `config.txt`: `dtparam=pciex1`
- Check NVMe HAT is properly seated
- Verify NVMe detection: `lspci` and `lsblk`

### Performance Issues

- Check CPU temperature: `home-os-status temp`
- Add active cooling if temperature > 70°C
- Verify CPU frequency: `home-os-status freq`
- Check for thermal throttling: `vcgencmd get_throttled`

## Building from Source

To build HomeOS kernel for Raspberry Pi 5:

```bash
# Clone repository
git clone https://github.com/home-os/home-os.git
cd home-os

# Install dependencies
./scripts/install-deps.sh

# Build for Raspberry Pi 5
make ARCH=arm64 BOARD=rpi5

# Create bootable image
./scripts/create-image.sh rpi5

# Flash to SD card
sudo dd if=build/home-os-rpi5.img of=/dev/sdX bs=4M status=progress
```

## Additional Resources

- **HomeOS Documentation**: <https://docs.home-os.dev>
- **Raspberry Pi 5 Datasheet**: <https://datasheets.raspberrypi.com/rpi5/>
- **BCM2712 Technical Reference**: <https://datasheets.raspberrypi.com/bcm2712/>
- **Community Forum**: <https://forum.home-os.dev>
- **GitHub Issues**: <https://github.com/home-os/home-os/issues>

## Support

For help and support:

- **Documentation**: <https://docs.home-os.dev>
- **Community Chat**: <https://chat.home-os.dev>
- **Bug Reports**: <https://github.com/home-os/home-os/issues>
- **Email**: support@home-os.dev

## License

HomeOS is open source software. See LICENSE file for details.
