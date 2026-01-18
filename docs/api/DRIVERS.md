# Driver API Reference

This document provides the complete API reference for HomeOS device drivers.

## Overview

HomeOS includes 65+ device drivers written in the Home programming language. Each driver follows a consistent interface pattern and is located in `kernel/src/drivers/`.

## Driver Architecture

### Driver Module Structure

Every driver module follows this structure:

```home
struct DriverModule {
  name: [64]u8              // Driver name
  init_fn: fn(): u32        // Initialization function
  exit_fn: fn(): u32        // Cleanup function
  dependencies: [8]u32      // Required drivers
  priority: u32             // Loading priority
  loaded: u32               // Load status
}
```

### Driver Lifecycle

1. **Registration** - Driver registers with the kernel
2. **Initialization** - `init_fn()` called during boot
3. **Operation** - Driver handles hardware requests
4. **Shutdown** - `exit_fn()` called on unload

## Storage Drivers

### ATA/IDE Driver

Legacy ATA/IDE driver for PIO mode disk access.

**File:** `kernel/src/drivers/ata.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `ata_init` | `fn()` | Initialize ATA controller |
| `ata_read_sector` | `fn(drive: u32, lba: u64, buffer: u64): u32` | Read single sector |
| `ata_write_sector` | `fn(drive: u32, lba: u64, buffer: u64): u32` | Write single sector |
| `ata_read_sectors` | `fn(drive: u32, lba: u64, count: u32, buffer: u64): u32` | Read multiple sectors |
| `ata_write_sectors` | `fn(drive: u32, lba: u64, count: u32, buffer: u64): u32` | Write multiple sectors |
| `ata_get_device_count` | `fn(): u32` | Get number of devices |
| `ata_get_device_sectors` | `fn(drive: u32): u64` | Get device capacity |
| `ata_device_exists` | `fn(drive: u32): u32` | Check if device exists |

### AHCI Driver

Advanced Host Controller Interface for SATA drives.

**File:** `kernel/src/drivers/ahci.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `ahci_init` | `fn()` | Initialize AHCI controller |
| `ahci_read_sectors` | `fn(port: u32, lba: u64, count: u32, buffer: u64): u32` | Read sectors |
| `ahci_write_sectors` | `fn(port: u32, lba: u64, count: u32, buffer: u64): u32` | Write sectors |
| `ahci_flush` | `fn(port: u32): u32` | Flush cache to disk |
| `ahci_get_port_count` | `fn(): u32` | Get number of ports |
| `ahci_is_port_active` | `fn(port: u32): u32` | Check if port is active |
| `ahci_is_initialized` | `fn(): u32` | Check initialization status |

### NVMe Driver

Non-Volatile Memory Express for PCIe SSDs.

**File:** `kernel/src/drivers/nvme.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `nvme_init` | `fn()` | Initialize NVMe controller |
| `nvme_read` | `fn(lba: u64, count: u32, buffer: u64): u32` | Read blocks |
| `nvme_write` | `fn(lba: u64, count: u32, buffer: u64): u32` | Write blocks |
| `nvme_flush` | `fn(): u32` | Flush cache |
| `nvme_get_block_count` | `fn(): u64` | Get total blocks |
| `nvme_get_block_size` | `fn(): u32` | Get block size |
| `nvme_is_initialized` | `fn(): u32` | Check status |

### SD/MMC Driver

SD card and eMMC driver with DMA support.

**File:** `kernel/src/drivers/sdmmc.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `sdmmc_init` | `fn()` | Initialize driver |
| `sdmmc_register_controller` | `fn(base_addr: u64, use_dma: u32): u32` | Register controller |
| `sdmmc_init_card` | `fn(controller_id: u32): u32` | Initialize card |
| `sdmmc_read_blocks` | `fn(controller_id: u32, block: u64, count: u32, buffer: u64): u32` | Read blocks |
| `sdmmc_write_blocks` | `fn(controller_id: u32, block: u64, count: u32, buffer: u64): u32` | Write blocks |
| `sdmmc_get_capacity` | `fn(controller_id: u32): u64` | Get card capacity |
| `sdmmc_print_stats` | `fn()` | Print statistics |

### RAID Driver

Software RAID support.

**File:** `kernel/src/drivers/raid.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `raid_init` | `fn()` | Initialize RAID subsystem |
| `raid_create_array` | `fn(level: u32, disk_ids: u64, disk_count: u32, stripe_size: u32): u32` | Create array |
| `raid_read` | `fn(array_id: u32, offset: u64, buffer: u64, size: u32): u32` | Read from array |
| `raid_write` | `fn(array_id: u32, offset: u64, buffer: u64, size: u32): u32` | Write to array |
| `raid_get_status` | `fn(array_id: u32): u32` | Get array status |
| `raid_rebuild` | `fn(array_id: u32, failed_disk: u32, new_disk: u32): u32` | Rebuild array |

## Network Drivers

### WiFi Driver

IEEE 802.11 wireless driver.

**File:** `kernel/src/drivers/wifi.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `wifi_init` | `fn()` | Initialize WiFi |
| `wifi_scan` | `fn(): u32` | Scan for networks |
| `wifi_connect` | `fn(ssid: [*]u8, password: [*]u8): u32` | Connect to network |
| `wifi_disconnect` | `fn()` | Disconnect |
| `wifi_is_connected` | `fn(): u32` | Check connection |
| `wifi_get_rssi` | `fn(): i8` | Get signal strength |
| `wifi_set_mode` | `fn(mode: u32)` | Set operating mode |
| `wifi_get_network_count` | `fn(): u32` | Get scan results count |
| `wifi_get_network` | `fn(index: u32, ssid: [*]u8, signal: *i8, security: *u32): u32` | Get network info |
| `wifi_get_mac` | `fn(mac: [*]u8)` | Get MAC address |
| `wifi_set_tx_power` | `fn(power_dbm: u8)` | Set transmit power |
| `wifi_set_power_save` | `fn(enable: u32)` | Enable/disable power save |
| `wifi_transmit` | `fn(data: [*]u8, length: u32): u32` | Transmit packet |

### Bluetooth Driver

Bluetooth HCI driver.

**File:** `kernel/src/drivers/bluetooth.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `bluetooth_init` | `fn()` | Initialize Bluetooth |
| `bluetooth_enable` | `fn()` | Enable adapter |
| `bluetooth_disable` | `fn()` | Disable adapter |
| `bluetooth_scan` | `fn(): u32` | Scan for devices |
| `bluetooth_pair` | `fn(device_id: u32): u32` | Pair with device |
| `bluetooth_connect` | `fn(device_id: u32): u32` | Connect to device |
| `bluetooth_disconnect` | `fn(device_id: u32): u32` | Disconnect |
| `bluetooth_get_state` | `fn(): u32` | Get adapter state |
| `bluetooth_get_device_count` | `fn(): u32` | Get device count |
| `bluetooth_send` | `fn(device_id: u32, data: [*]u8, length: u32): u32` | Send data |

### VirtIO Net Driver

Paravirtualized network driver for VMs.

**File:** `kernel/src/drivers/virtio_net.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `virtio_net_init` | `fn()` | Initialize driver |
| `virtio_net_send` | `fn(data: u64, length: u32): u32` | Send packet |
| `virtio_net_receive` | `fn(buffer: u64, max_length: u32): u32` | Receive packet |

## Input Drivers

### Keyboard Driver

PS/2 and USB keyboard driver.

**File:** `kernel/src/drivers/keyboard.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `keyboard_init` | `fn()` | Initialize keyboard |
| `keyboard_getchar` | `fn(): u8` | Get character (blocking) |
| `keyboard_has_char` | `fn(): u32` | Check if char available |
| `keyboard_getline` | `fn(buffer: u64, max_len: u32): u32` | Read line |
| `keyboard_interrupt_handler` | `fn()` | IRQ handler |
| `keyboard_set_leds` | `fn(scroll: u32, num: u32, caps: u32)` | Set LED state |

### Mouse Driver

PS/2 mouse driver.

**File:** `kernel/src/drivers/mouse.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `mouse_init` | `fn()` | Initialize mouse |
| `mouse_interrupt_handler` | `fn()` | IRQ handler |
| `mouse_get_x` | `fn(): i32` | Get X position |
| `mouse_get_y` | `fn(): i32` | Get Y position |
| `mouse_get_buttons` | `fn(): u8` | Get button state |

### Touchpad Driver

Touchpad with gesture support.

**File:** `kernel/src/drivers/touchpad.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `touchpad_init` | `fn()` | Initialize touchpad |
| `touchpad_enable` | `fn()` | Enable touchpad |
| `touchpad_disable` | `fn()` | Disable touchpad |
| `touchpad_get_x` | `fn(): u32` | Get X position |
| `touchpad_get_y` | `fn(): u32` | Get Y position |
| `touchpad_get_buttons` | `fn(): u8` | Get button state |
| `touchpad_get_last_gesture` | `fn(): u32` | Get last gesture |
| `touchpad_set_sensitivity` | `fn(sensitivity: u8)` | Set sensitivity |

## USB Drivers

### XHCI Driver

USB 3.0 host controller driver.

**File:** `kernel/src/drivers/xhci.home`, `kernel/src/drivers/usb_xhci.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `xhci_init` | `fn(base_addr: u64): u32` | Initialize controller |
| `xhci_start` | `fn(): u32` | Start controller |
| `xhci_stop` | `fn()` | Stop controller |
| `xhci_handle_port_change` | `fn(port_num: u32)` | Handle port change |
| `xhci_control_transfer` | `fn(slot_id: u8, request_type: u8, request: u8, value: u16, index: u16, data: u64, length: u16): u32` | Control transfer |
| `xhci_bulk_transfer` | `fn(slot_id: u8, endpoint: u8, data: u64, length: u32, direction: u8): u32` | Bulk transfer |

### USB Hub Driver

USB hub support.

**File:** `kernel/src/drivers/usb_hub.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `usb_hub_init` | `fn()` | Initialize hub driver |
| `usb_hub_register` | `fn(device: u64, ports: u32): u32` | Register hub |
| `usb_hub_port_reset` | `fn(hub_id: u32, port: u32)` | Reset port |
| `usb_hub_enumerate_ports` | `fn(hub_id: u32)` | Enumerate ports |

## Display Drivers

### Framebuffer Driver

Enhanced framebuffer up to 4K.

**File:** `kernel/src/drivers/framebuffer.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `fb_init` | `fn(addr: u64, width: u32, height: u32, bpp: u32, format: u32): u32` | Initialize framebuffer |
| `fb_enable_double_buffer` | `fn(back_addr: u64): u32` | Enable double buffering |
| `fb_swap_buffers` | `fn(): u32` | Swap buffers |
| `fb_put_pixel` | `fn(x: u32, y: u32, color: u32)` | Draw pixel |
| `fb_get_pixel` | `fn(x: u32, y: u32): u32` | Get pixel color |
| `fb_fill_rect` | `fn(x: u32, y: u32, width: u32, height: u32, color: u32)` | Fill rectangle |
| `fb_clear` | `fn(color: u32)` | Clear screen |
| `fb_draw_line` | `fn(x0: u32, y0: u32, x1: u32, y1: u32, color: u32)` | Draw line |
| `fb_draw_circle` | `fn(cx: u32, cy: u32, radius: u32, color: u32)` | Draw circle |
| `fb_draw_string` | `fn(x: u32, y: u32, text: *u8, fg_color: u32, bg_color: u32)` | Draw text |

### Framebuffer Console Driver

Text console with font rendering.

**File:** `kernel/src/drivers/fb_console.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `fb_console_init` | `fn(): u32` | Initialize console |
| `fb_console_putchar` | `fn(ch: u8)` | Print character |
| `fb_console_write` | `fn(str: *u8)` | Print string |
| `fb_console_clear` | `fn()` | Clear console |
| `fb_console_set_cursor_visible` | `fn(visible: u32)` | Show/hide cursor |
| `fb_console_set_theme` | `fn(theme: u32)` | Set color theme |

### GPU Driver

Software GPU with 2D/3D rendering.

**File:** `kernel/src/drivers/gpu.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `gpu_init` | `fn(): i32` | Initialize GPU |
| `gpu_init_with_mode` | `fn(width: u32, height: u32, bpp: u32): i32` | Initialize with mode |
| `gpu_shutdown` | `fn()` | Shutdown GPU |
| `gpu_clear` | `fn(color: u32)` | Clear screen |
| `gpu_draw_pixel` | `fn(x: i32, y: i32, color: u32)` | Draw pixel |
| `gpu_draw_line` | `fn(x0: i32, y0: i32, x1: i32, y1: i32, color: u32)` | Draw line |
| `gpu_fill_rect` | `fn(x: i32, y: i32, width: u32, height: u32, color: u32)` | Fill rectangle |
| `gpu_draw_circle` | `fn(cx: i32, cy: i32, radius: u32, color: u32)` | Draw circle |
| `gpu_fill_triangle` | `fn(x0: i32, y0: i32, x1: i32, y1: i32, x2: i32, y2: i32, color: u32)` | Fill triangle |
| `gpu_enable_depth_test` | `fn()` | Enable depth testing |

## GPIO/Peripheral Drivers

### GPIO Driver

General Purpose I/O driver.

**File:** `kernel/src/drivers/gpio.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `gpio_init` | `fn(): u32` | Initialize GPIO |
| `gpio_register_controller` | `fn(ctrl_type: u8, base_addr: u64, num_pins: u32, irq: u8): u32` | Register controller |
| `gpio_request` | `fn(controller: u32, pin: u32): u32` | Request pin |
| `gpio_free` | `fn(handle: u32)` | Release pin |
| `gpio_set_mode` | `fn(handle: u32, mode: u8)` | Set pin mode |
| `gpio_write` | `fn(handle: u32, value: u8)` | Write to pin |
| `gpio_read` | `fn(handle: u32): u8` | Read from pin |
| `gpio_toggle` | `fn(handle: u32)` | Toggle pin |
| `gpio_enable_interrupt` | `fn(handle: u32, mode: u8, callback: u64, user_data: u64)` | Enable interrupt |
| `gpio_pwm_configure` | `fn(handle: u32, frequency: u32): u32` | Configure PWM |
| `gpio_pwm_set_duty` | `fn(pwm_handle: u32, duty: u16)` | Set PWM duty cycle |

### SPI Driver

Serial Peripheral Interface driver.

**File:** `kernel/src/drivers/spi.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `spi_init` | `fn(): u32` | Initialize SPI |
| `spi_register_controller` | `fn(ctrl_type: u8, base_addr: u64, irq: u8, num_cs: u8): u32` | Register controller |
| `spi_register_device` | `fn(controller: u32, cs: u8, mode: u8, speed_hz: u32): u32` | Register device |
| `spi_transfer` | `fn(handle: u32, tx_data: u64, rx_data: u64, length: u32): u32` | Full duplex transfer |
| `spi_write` | `fn(handle: u32, data: u64, length: u32): u32` | Write data |
| `spi_read` | `fn(handle: u32, buffer: u64, length: u32): u32` | Read data |

### PWM Driver

Pulse Width Modulation driver.

**File:** `kernel/src/drivers/pwm.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `pwm_init` | `fn()` | Initialize PWM |
| `pwm_set_frequency` | `fn(channel: u32, frequency: u32)` | Set frequency |
| `pwm_set_duty_cycle` | `fn(channel: u32, duty: u32)` | Set duty cycle |
| `pwm_enable` | `fn(channel: u32)` | Enable channel |
| `pwm_disable` | `fn(channel: u32)` | Disable channel |

## System Drivers

### Timer Driver

Programmable Interval Timer driver.

**File:** `kernel/src/drivers/timer.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `timer_init` | `fn(frequency: u32)` | Initialize timer |
| `timer_get_ticks` | `fn(): u64` | Get tick count |
| `timer_get_milliseconds` | `fn(): u64` | Get milliseconds |
| `timer_sleep_ms` | `fn(milliseconds: u64)` | Sleep for milliseconds |
| `timer_delay_us` | `fn(microseconds: u64)` | Delay for microseconds |
| `timer_measure_start` | `fn(): u64` | Start measurement |
| `timer_measure_ms` | `fn(start_tick: u64): u64` | Get elapsed ms |

### RTC Driver

Real-Time Clock driver.

**File:** `kernel/src/drivers/rtc.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `rtc_init` | `fn()` | Initialize RTC |
| `rtc_get_second` | `fn(): u8` | Get seconds |
| `rtc_get_minute` | `fn(): u8` | Get minutes |
| `rtc_get_hour` | `fn(): u8` | Get hours |
| `rtc_get_day` | `fn(): u8` | Get day |
| `rtc_get_month` | `fn(): u8` | Get month |
| `rtc_get_year` | `fn(): u16` | Get year |
| `rtc_get_timestamp` | `fn(): u64` | Get Unix timestamp |

### Watchdog Driver

Hardware watchdog timer driver.

**File:** `kernel/src/drivers/watchdog.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `watchdog_init` | `fn()` | Initialize watchdog |
| `watchdog_enable` | `fn()` | Enable watchdog |
| `watchdog_disable` | `fn()` | Disable watchdog |
| `watchdog_kick` | `fn()` | Reset watchdog timer |
| `watchdog_set_timeout` | `fn(seconds: u32): u32` | Set timeout |
| `watchdog_get_remaining` | `fn(): u32` | Get remaining time |
| `watchdog_is_enabled` | `fn(): u32` | Check if enabled |

### ACPI Driver

Advanced Configuration and Power Interface.

**File:** `kernel/src/drivers/acpi.home`, `kernel/src/drivers/acpi_pm.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `acpi_init` | `fn()` | Initialize ACPI |
| `acpi_shutdown` | `fn()` | Power off system |
| `acpi_reboot` | `fn()` | Reboot system |
| `acpi_suspend_to_ram` | `fn(): u32` | Suspend to RAM |
| `acpi_get_temperature` | `fn(): u32` | Get CPU temperature |
| `acpi_get_battery_status` | `fn(percentage_out: u64, charging_out: u64): u32` | Get battery status |
| `acpi_set_brightness` | `fn(level: u32): u32` | Set screen brightness |

### PCI Driver

PCI device enumeration.

**File:** `kernel/src/drivers/pci.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `pci_init` | `fn()` | Initialize PCI |
| `pci_get_device_count` | `fn(): u32` | Get device count |
| `pci_get_device` | `fn(index: u32): u64` | Get device info |
| `pci_find_device` | `fn(vendor: u16, device: u16): u64` | Find specific device |

## Audio Drivers

### Audio Driver

AC97 and Intel HDA audio.

**File:** `kernel/src/drivers/audio.home`

| Function | Signature | Description |
|----------|-----------|-------------|
| `audio_init` | `fn()` | Initialize audio |
| `audio_play` | `fn(samples: u64, count: u32): u32` | Play samples |
| `audio_start` | `fn(): u32` | Start playback |
| `audio_stop` | `fn(): u32` | Stop playback |
| `audio_set_volume` | `fn(volume: u8)` | Set volume |
| `audio_get_volume` | `fn(): u8` | Get volume |
| `audio_set_sample_rate` | `fn(rate: u32): u32` | Set sample rate |
| `audio_is_playing` | `fn(): u32` | Check if playing |

## Best Practices

### Error Handling

All driver functions should return error codes:

```home
const SUCCESS: u32 = 0
const ERROR_INVALID_PARAM: u32 = 1
const ERROR_NOT_INITIALIZED: u32 = 2
const ERROR_TIMEOUT: u32 = 3
const ERROR_HARDWARE: u32 = 4
```

### Interrupt Handling

Use interrupt handlers instead of polling:

```home
fn my_irq_handler() {
  // Handle interrupt
  // Acknowledge interrupt
}
```

### Resource Management

Always clean up resources:

```home
fn driver_exit(): u32 {
  // Free DMA buffers
  // Disable interrupts
  // Release I/O ports
  return SUCCESS
}
```

## Related Documentation

- [Drivers Guide](/guide/drivers) - Driver overview
- [Architecture](/guide/architecture) - Kernel integration
- [System Calls](/api/syscalls) - User-space API
