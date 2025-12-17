# HomeOS Hardware-in-the-Loop Testing

This directory contains hardware test scripts for running CI tests on actual Raspberry Pi hardware.

## Overview

Hardware-in-the-loop (HIL) testing allows us to verify that HomeOS works correctly on real Raspberry Pi hardware, catching issues that may not appear in emulation.

## Supported Hardware

- **Raspberry Pi 4 Model B** (Primary target)
  - 1GB, 2GB, 4GB, or 8GB RAM variants
  - BCM2711 SoC (Cortex-A72)

- **Raspberry Pi 5** (Latest target)
  - 4GB or 8GB RAM variants
  - BCM2712 SoC (Cortex-A76)
  - PCIe support for NVMe HAT+

## Test Scripts

### Boot Test (`pi_boot_test.sh`)

Tests kernel boot sequence and basic system initialization.

```bash
./pi_boot_test.sh --model=pi4 --timeout=120

# Options:
#   --model=pi4|pi5    Pi model being tested
#   --timeout=SECONDS  Boot timeout (default: 120)
#   --serial=DEVICE    Serial port device (default: /dev/ttyUSB0)
```

**Tests performed:**
- Kernel image existence
- Boot configuration (config.txt)
- Memory configuration
- CPU initialization
- GPU memory allocation
- Serial output capture
- Framebuffer availability
- Device enumeration
- Temperature monitoring

### GPIO Test (`pi_gpio_test.sh`)

Tests GPIO functionality and peripheral buses.

```bash
./pi_gpio_test.sh --model=pi4 [--loopback]

# Options:
#   --model=pi4|pi5    Pi model being tested
#   --loopback         Enable loopback test (requires GPIO17-GPIO27 jumper)
```

**Tests performed:**
- GPIO sysfs interface
- GPIO memory access (/dev/gpiomem)
- GPIO character device (libgpiod)
- GPIO export/unexport
- GPIO output toggling
- GPIO input reading
- Loopback test (optional)
- I2C bus availability
- SPI bus availability

### Display Test (`pi_display_test.sh`)

Tests framebuffer and display output.

```bash
./pi_display_test.sh --model=pi4
```

**Tests performed:**
- Framebuffer device existence
- Framebuffer properties (resolution, depth)
- Framebuffer write access
- DRM device enumeration
- HDMI connection status
- Display resolution detection
- GPU information
- Framebuffer screenshot capture
- Compositor readiness check

### Network Test (`pi_network_test.sh`)

Tests network functionality.

```bash
./pi_network_test.sh --model=pi4
```

**Tests performed:**
- Loopback interface
- Ethernet device detection
- WiFi device detection
- IP address configuration
- Default gateway
- DNS resolution
- Internet connectivity
- Socket creation
- Network driver modules
- Network statistics

### Storage Test (`pi_storage_test.sh`)

Tests storage devices and filesystem operations.

```bash
./pi_storage_test.sh --model=pi4
```

**Tests performed:**
- SD card detection
- Boot partition mounting
- Root filesystem check
- USB storage detection
- NVMe detection (Pi 5)
- Disk I/O performance
- Filesystem operations (create/read/write/delete)
- Symbolic links
- Mount point enumeration
- Tmpfs availability

### Stress Test (`pi_stress_test.sh`)

Runs comprehensive stress tests to verify stability.

```bash
./pi_stress_test.sh --model=pi4 --duration=300

# Options:
#   --model=pi4|pi5      Pi model being tested
#   --duration=SECONDS   Test duration (default: 60)
```

**Tests performed:**
- CPU stress (all cores at 100%)
- Memory stress (allocation/deallocation)
- I/O stress (read/write cycles)
- Mixed workload stress
- Thermal monitoring
- Throttle detection

## Setting Up a Pi Test Runner

### Requirements

1. A Raspberry Pi 4 or 5 running Raspberry Pi OS (64-bit)
2. GitHub self-hosted runner installed
3. Serial connection (optional, for boot logging)

### Installation

1. **Install GitHub Actions Runner:**

```bash
# Create runner directory
mkdir ~/actions-runner && cd ~/actions-runner

# Download runner (check for latest version)
curl -o actions-runner-linux-arm64-2.311.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-arm64-2.311.0.tar.gz

# Extract
tar xzf ./actions-runner-linux-arm64-2.311.0.tar.gz

# Configure
./config.sh --url https://github.com/YOUR_ORG/home-os --token YOUR_TOKEN

# Install as service
sudo ./svc.sh install
sudo ./svc.sh start
```

2. **Add labels to the runner:**

In GitHub repository settings, add labels:
- `self-hosted`
- `pi4` or `pi5` (depending on hardware)
- `arm64`

3. **Install required packages:**

```bash
sudo apt-get update
sudo apt-get install -y \
  i2c-tools \
  spi-tools \
  gpiod \
  fbset \
  bc \
  iw \
  wireless-tools \
  net-tools
```

4. **Enable interfaces:**

```bash
# Enable I2C
sudo raspi-config nonint do_i2c 0

# Enable SPI
sudo raspi-config nonint do_spi 0

# Enable serial
sudo raspi-config nonint do_serial 0
```

5. **Set up permissions:**

```bash
# Add runner user to required groups
sudo usermod -aG gpio,i2c,spi,video $USER
```

### Test SD Card Setup (Optional)

For complete boot testing, you can set up a secondary SD card or USB drive:

1. Create a small FAT32 partition for /boot
2. Create an ext4 partition for root filesystem
3. Deploy HomeOS kernel to the boot partition
4. Configure TFTP/PXE for network boot testing

## CI Integration

The GitHub Actions workflow (`.github/workflows/pi-hardware-test.yml`) automatically:

1. Builds the ARM64 kernel
2. Uploads boot files as artifacts
3. Deploys to test hardware
4. Runs the test suite
5. Collects and uploads results

### Manual Trigger

You can manually trigger hardware tests:

```bash
gh workflow run pi-hardware-test.yml \
  -f test_suite=full \
  -f pi_model=pi4
```

### Test Suite Options

- `full` - Run all tests
- `boot` - Boot test only
- `gpio` - GPIO test only
- `display` - Display test only
- `network` - Network test only
- `storage` - Storage test only
- `stress` - Stress test only

## Interpreting Results

### Success Criteria

- All tests pass (exit code 0)
- Temperature stays below 80°C during stress
- No throttling detected (throttle=0x0)
- Network connectivity verified
- Storage I/O operations complete

### Common Issues

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| Temperature throttling | Inadequate cooling | Add heatsink/fan |
| GPIO test failures | Interface not enabled | Enable in raspi-config |
| Network test failures | No connection | Check cables/WiFi |
| Display test skipped | Headless mode | Normal for CI runners |
| Boot timeout | Kernel issue | Check serial output |

## Adding New Tests

1. Create a new script in `tests/hardware/`
2. Follow the existing naming convention: `pi_<category>_test.sh`
3. Use the common logging functions
4. Write results to `$RESULTS_DIR`
5. Create `PASSED` or `FAILED` marker file
6. Add to the CI workflow if needed

## Test Results

Results are stored in `test-results/` directory:

```
test-results/
├── boot.log           # Serial/boot output
├── PASSED or FAILED   # Overall result marker
├── stress_monitor.log # Temperature/frequency log
├── fb_capture.raw     # Framebuffer screenshot
└── *.log              # Individual test logs
```
