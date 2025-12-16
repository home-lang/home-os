# Raspberry Pi 5 Hardware Compatibility Matrix

Complete hardware support matrix for home-os on the Raspberry Pi 5 (BCM2712 SoC).

**Last Updated:** December 16, 2025
**Target Platform:** Raspberry Pi 5 (4GB / 8GB models)

## Overview

The Raspberry Pi 5 uses the BCM2712 SoC with the RP1 I/O controller (connected via PCIe). This architecture differs significantly from Pi 4 and requires specific driver support.

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

## Hardware Support Matrix

### Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Fully supported and tested |
| ⚠️ | Partial support / In progress |
| ❌ | Not yet implemented |
| 🔧 | Requires configuration |
| N/A | Not applicable to Pi 5 |

---

## Core System

| Component | Status | Driver/Module | Notes |
|-----------|--------|---------------|-------|
| **CPU (Cortex-A76 x4)** | ✅ | `arch/arm64/` | 2.4 GHz, ARMv8.2-A |
| **Memory (4GB/8GB)** | ✅ | `mm/` | LPDDR4X-4267 |
| **Device Tree** | ✅ | `arch/arm64/devicetree.home` | BCM2712 DTB parsing |
| **Exception Handling** | ✅ | `arch/arm64/exception.home` | EL1/EL0 |
| **Timer (ARM Generic)** | ✅ | `drivers/timer.home` | CNTVCT_EL0 |
| **GIC-400 Interrupts** | ✅ | `arch/arm64/gic.home` | Interrupt controller |
| **SMP (4 cores)** | ✅ | `core/smp.home` | PSCI boot |

---

## USB

| Component | Status | Driver/Module | Notes |
|-----------|--------|---------------|-------|
| **USB 3.0 Controller** | ✅ | `drivers/xhci.home` | 2x USB 3.0 ports (5 Gbps) |
| **USB 2.0 Controller** | ✅ | `drivers/xhci.home` | 2x USB 2.0 ports |
| **USB Hub Support** | ✅ | `drivers/usb_hub.home` | External hubs |
| **USB Mass Storage** | ✅ | `drivers/usb.home` | Flash drives, HDD |
| **USB Keyboard** | ✅ | `drivers/keyboard.home` | HID class |
| **USB Mouse** | ✅ | `drivers/mouse.home` | HID class |
| **USB Ethernet** | ⚠️ | `drivers/usb.home` | Partial (RTL8152) |
| **USB WiFi Adapter** | ⚠️ | - | Limited support |
| **USB Audio** | ❌ | - | Planned |
| **USB Webcam** | ❌ | `drivers/camera.home` | UVC planned |

### USB Testing

```bash
# Test USB enumeration
./tests/integration/test_usb.sh

# Expected output:
# USB 3.0: 2 ports detected (xHCI)
# USB 2.0: 2 ports detected (xHCI)
```

---

## PCIe

| Component | Status | Driver/Module | Notes |
|-----------|--------|---------------|-------|
| **PCIe Controller** | ✅ | `drivers/pci.home` | Gen 2.0 x1 external |
| **PCIe Extended Caps** | ⚠️ | `drivers/pcie_extended.home` | Basic support |
| **NVMe SSD** | ✅ | `drivers/nvme.home` | Full support via PCIe |
| **SATA Controller** | ✅ | `drivers/ahci.home` | Via PCIe adapter |
| **USB 3.0 Card** | ⚠️ | `drivers/xhci.home` | Most cards work |
| **Network Card** | ⚠️ | - | Intel/Realtek limited |
| **GPU (external)** | ❌ | - | Not planned |

### NVMe Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Sequential Read | 400+ MB/s | PCIe Gen 2.0 x1 limited |
| Sequential Write | 350+ MB/s | |
| Random 4K Read | 40,000+ IOPS | |
| Random 4K Write | 35,000+ IOPS | |

---

## Storage

| Component | Status | Driver/Module | Notes |
|-----------|--------|---------------|-------|
| **SD Card (SDIO)** | ✅ | `drivers/bcm_emmc.home` | Via BCM2712 |
| **SD UHS-I (SDR104)** | ✅ | `drivers/sdmmc_highspeed.home` | 104 MB/s max |
| **eMMC (boot)** | ⚠️ | `drivers/bcm_emmc.home` | Limited testing |
| **NVMe via PCIe** | ✅ | `drivers/nvme.home` | Recommended |
| **USB Storage** | ✅ | `drivers/usb.home` | Full support |

### SD Card Performance Targets

| Speed Mode | Read | Write | Status |
|------------|------|-------|--------|
| DS (25 MHz) | 12.5 MB/s | 12.5 MB/s | ✅ |
| HS (50 MHz) | 25 MB/s | 25 MB/s | ✅ |
| SDR50 (100 MHz) | 50 MB/s | 50 MB/s | ✅ |
| SDR104 (208 MHz) | 104 MB/s | 104 MB/s | ✅ |
| DDR50 (50 MHz) | 50 MB/s | 50 MB/s | ✅ |

---

## Display / Video

| Component | Status | Driver/Module | Notes |
|-----------|--------|---------------|-------|
| **HDMI 0 (4Kp60)** | ✅ | `drivers/framebuffer.home` | Micro HDMI |
| **HDMI 1 (4Kp60)** | ✅ | `drivers/framebuffer.home` | Micro HDMI |
| **Dual Display** | ⚠️ | `drivers/framebuffer.home` | WIP |
| **4K @ 60Hz** | ✅ | - | Both ports |
| **4K @ 120Hz** | ❌ | - | Hardware limit |
| **HDR** | ❌ | - | Not planned |
| **Framebuffer Console** | ✅ | `drivers/fb_console.home` | Text mode |
| **GPU Acceleration** | ⚠️ | `drivers/gpu.home` | VideoCore VII basic |
| **Vulkan** | ❌ | - | Planned (v3dv) |
| **OpenGL ES** | ❌ | - | Planned |
| **DSI Display** | ❌ | - | Not yet |
| **Camera (CSI)** | ❌ | `drivers/camera.home` | Planned |

### Display Modes Tested

| Resolution | Refresh | Color Depth | Status |
|------------|---------|-------------|--------|
| 1920x1080 | 60 Hz | 32-bit | ✅ |
| 2560x1440 | 60 Hz | 32-bit | ✅ |
| 3840x2160 | 30 Hz | 32-bit | ✅ |
| 3840x2160 | 60 Hz | 32-bit | ✅ |

---

## Network

| Component | Status | Driver/Module | Notes |
|-----------|--------|---------------|-------|
| **Gigabit Ethernet** | ✅ | `net/tcp.home`, RP1 | Native via RP1 |
| **WiFi (on-board)** | ⚠️ | `drivers/wifi.home` | RP1 integration WIP |
| **Bluetooth 5.0** | ⚠️ | `drivers/bluetooth.home` | Basic pairing |
| **BLE** | ⚠️ | `drivers/bluetooth_hci.home` | Scanning works |
| **TCP/IP Stack** | ✅ | `net/tcp.home` | Full implementation |
| **UDP** | ✅ | `net/udp.home` | Full implementation |
| **DHCP** | ✅ | `net/dhcp.home` | Client |
| **DNS** | ✅ | `net/dns.home` | Resolver with cache |
| **TLS 1.2/1.3** | ✅ | `net/tls.home` | AES-GCM |
| **HTTP/HTTPS** | ✅ | `net/http.home` | Client/Server |
| **WebSocket** | ✅ | `net/websocket.home` | RFC 6455 |

### Network Performance Targets

| Metric | Target | Status |
|--------|--------|--------|
| Ethernet TX | 940 Mbps | ✅ |
| Ethernet RX | 940 Mbps | ✅ |
| WiFi TX | 100 Mbps | ⚠️ |
| WiFi RX | 100 Mbps | ⚠️ |
| Ping Latency | < 1ms (local) | ✅ |

---

## GPIO / Peripherals

| Component | Status | Driver/Module | Notes |
|-----------|--------|---------------|-------|
| **GPIO (28 pins)** | ✅ | `drivers/gpio.home` | Via RP1 |
| **UART (6 channels)** | ✅ | `drivers/serial.home` | Via RP1 |
| **SPI (6 channels)** | ✅ | `drivers/spi.home` | Via RP1 |
| **I2C (6 channels)** | ✅ | `drivers/i2c.home` | Via RP1 |
| **PWM (4 channels)** | ✅ | `drivers/pwm.home` | Via RP1 |
| **1-Wire** | ⚠️ | - | GPIO bitbang |
| **Fan Control (PWM)** | ✅ | `drivers/pwm.home` | Active cooler |
| **Power Button** | ✅ | - | Via PMIC |
| **RTC (external)** | ✅ | `drivers/rtc.home` | I2C RTC modules |
| **ADC** | ❌ | - | Not on Pi 5 |

### GPIO Pin Mapping

```
Pin  │ Function     │ Status
─────┼──────────────┼────────
 2,3 │ I2C1 SDA/SCL │ ✅
 4   │ GPCLK0       │ ✅
 7   │ SPI0 CE1     │ ✅
 8   │ SPI0 CE0     │ ✅
 9   │ SPI0 MISO    │ ✅
10   │ SPI0 MOSI    │ ✅
11   │ SPI0 SCLK    │ ✅
14   │ UART TX      │ ✅
15   │ UART RX      │ ✅
17   │ GPIO17       │ ✅
18   │ PWM0         │ ✅
22   │ GPIO22       │ ✅
23   │ GPIO23       │ ✅
24   │ GPIO24       │ ✅
25   │ GPIO25       │ ✅
27   │ GPIO27       │ ✅
```

---

## Audio

| Component | Status | Driver/Module | Notes |
|-----------|--------|---------------|-------|
| **HDMI Audio** | ⚠️ | `drivers/audio.home` | Basic output |
| **3.5mm Jack** | ❌ | - | Not on Pi 5 |
| **USB Audio** | ❌ | `drivers/audio.home` | Planned |
| **I2S** | ⚠️ | `drivers/audio.home` | DAC HATs |
| **Bluetooth Audio** | ❌ | - | Planned |

---

## Power Management

| Component | Status | Driver/Module | Notes |
|-----------|--------|---------------|-------|
| **PMIC (DA9091)** | ⚠️ | `power/pm.home` | Basic control |
| **CPU DVFS** | ✅ | `power/cpufreq.home` | 1.5-2.4 GHz |
| **Thermal Throttle** | ✅ | `power/thermal.home` | 80°C throttle |
| **Suspend/Resume** | ❌ | - | Not implemented |
| **Power Button** | ✅ | - | Shutdown/reboot |
| **USB Power Control** | ⚠️ | - | Per-port WIP |
| **Fan Control** | ✅ | `drivers/pwm.home` | PWM-based |

### Thermal Targets

| State | Temperature | Action |
|-------|-------------|--------|
| Normal | < 60°C | Full speed |
| Warm | 60-70°C | Fan speed up |
| Hot | 70-80°C | Throttle begins |
| Critical | > 85°C | Emergency throttle |

---

## Camera / MIPI

| Component | Status | Driver/Module | Notes |
|-----------|--------|---------------|-------|
| **CSI-2 Port (2-lane)** | ❌ | `drivers/camera.home` | Planned |
| **CSI-2 Port (4-lane)** | ❌ | - | Planned |
| **Camera Module 3** | ❌ | - | Planned |
| **Camera Module 2** | ❌ | - | Planned |
| **HQ Camera** | ❌ | - | Planned |
| **libcamera** | ❌ | - | Planned |

---

## HAT / Add-on Boards

| Component | Status | Notes |
|-----------|--------|-------|
| **HAT EEPROM Detection** | ⚠️ | I2C ID EEPROM |
| **PoE+ HAT** | ⚠️ | Power delivery works |
| **Sense HAT** | ⚠️ | Basic I2C sensors |
| **Touch Display HAT** | ❌ | DSI not supported |
| **AI Accelerator HAT** | ❌ | Coral TPU planned |
| **NVMe HAT** | ✅ | PCIe NVMe |

---

## Real-Time Clock

| Component | Status | Driver/Module | Notes |
|-----------|--------|---------------|-------|
| **On-board RTC** | ✅ | Built into Pi 5 | Battery backup |
| **DS3231 (I2C)** | ✅ | `drivers/rtc.home` | External module |
| **PCF8523 (I2C)** | ✅ | `drivers/rtc.home` | External module |

---

## Security

| Component | Status | Driver/Module | Notes |
|-----------|--------|---------------|-------|
| **Secure Boot** | ❌ | - | Not implemented |
| **TPM 2.0 (I2C)** | ⚠️ | `drivers/tpm.home` | External module |
| **Hardware RNG** | ✅ | - | BCM2712 TRNG |
| **Crypto Accel** | ⚠️ | - | AES/SHA limited |

---

## Testing Procedures

### Quick Hardware Test

```bash
# Run full hardware verification
./tests/hardware/test_pi5_matrix.sh

# Individual component tests
./tests/hardware/test_usb.sh
./tests/hardware/test_pcie.sh
./tests/hardware/test_gpio.sh
./tests/hardware/test_network.sh
```

### Performance Benchmarks

```bash
# Run Pi 5 benchmarks
./scripts/build-unified.sh --target=rpi5 --test

# Expected results:
# Boot time: < 2.0s to shell
# SD read: > 90 MB/s (SDR104)
# NVMe read: > 400 MB/s
# Network: > 900 Mbps
```

---

## Known Issues

### Critical

1. **WiFi driver incomplete** - Connection drops after extended use
2. **Camera CSI not implemented** - No camera support yet

### Medium

1. **Dual HDMI audio** - Only one audio output at a time
2. **USB 3.0 power** - Some high-power devices may not work
3. **Bluetooth audio** - Not yet implemented

### Low

1. **GPIO edge detection** - May miss fast edges
2. **PWM jitter** - Minor jitter at high frequencies

---

## Roadmap

### Q1 2026
- [ ] Complete WiFi driver (RP1 integration)
- [ ] Camera CSI support
- [ ] USB audio class driver

### Q2 2026
- [ ] Vulkan support (VideoCore VII)
- [ ] Bluetooth audio
- [ ] Dual display support

### Q3 2026
- [ ] Hardware video decode
- [ ] Secure boot
- [ ] Full HAT ecosystem support

---

## References

- [BCM2712 Datasheet](https://datasheets.raspberrypi.com/bcm2712/bcm2712-peripherals.pdf)
- [RP1 Peripherals](https://datasheets.raspberrypi.com/rp1/rp1-peripherals.pdf)
- [Pi 5 Product Brief](https://datasheets.raspberrypi.com/rpi5/raspberry-pi-5-product-brief.pdf)
- [home-os ARM64 Architecture](../adr/0002-kernel-architecture.md)

---

## Contributing

To add hardware support or report issues:

1. Check the [issue tracker](https://github.com/home-os/issues)
2. Run the hardware test suite
3. Submit detailed hardware info with your PR/issue
