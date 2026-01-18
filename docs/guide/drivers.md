# Device Drivers

HomeOS includes 65+ device drivers covering storage, networking, input, USB, graphics, and peripherals.

## Driver Categories

| Category | Count | Description |
|----------|-------|-------------|
| Storage | 10 | Disk and flash storage |
| Network | 8 | Ethernet, WiFi, Bluetooth |
| Input | 6 | Keyboard, mouse, touch |
| USB | 6 | Host controllers and hubs |
| Display | 6 | VGA, framebuffer, GPU |
| Audio | 4 | Sound cards and mixers |
| Serial | 3 | UART and console |
| GPIO/Peripherals | 8 | I2C, SPI, PWM, sensors |
| System | 10 | PCI, ACPI, timers, power |
| Security | 4 | TPM, fingerprint, smartcard |

## Storage Drivers

### ATA/IDE

Legacy ATA/IDE driver for PIO mode disk access.

```home
ata_init()
ata_read_sector(drive, lba, buffer)
ata_write_sector(drive, lba, buffer)
ata_read_sectors(drive, lba, count, buffer)
ata_get_device_count()
```

**Location:** `kernel/src/drivers/ata.home`

### AHCI

Advanced Host Controller Interface for modern SATA drives.

```home
ahci_init()
ahci_read_sectors(port, lba, count, buffer)
ahci_write_sectors(port, lba, count, buffer)
ahci_flush(port)
ahci_get_port_count()
ahci_is_port_active(port)
```

**Location:** `kernel/src/drivers/ahci.home`

### NVMe

Non-Volatile Memory Express for PCIe SSDs.

```home
nvme_init()
nvme_read(lba, count, buffer)
nvme_write(lba, count, buffer)
nvme_flush()
nvme_get_block_count()
nvme_get_block_size()
```

**Location:** `kernel/src/drivers/nvme.home`

### SD/MMC

SD card and eMMC driver with DMA support.

```home
sdmmc_init()
sdmmc_register_controller(base_addr, use_dma)
sdmmc_init_card(controller_id)
sdmmc_read_blocks(controller_id, block, count, buffer)
sdmmc_write_blocks(controller_id, block, count, buffer)
sdmmc_get_capacity(controller_id)
```

**Location:** `kernel/src/drivers/sdmmc.home`

### BCM eMMC

Broadcom eMMC controller for Raspberry Pi 4/5.

**Location:** `kernel/src/drivers/bcm_emmc.home`

### RAID

Software RAID support for multiple disks.

```home
raid_init()
raid_create_array(level, disk_ids, disk_count, stripe_size)
raid_read(array_id, offset, buffer, size)
raid_write(array_id, offset, buffer, size)
raid_get_status(array_id)
raid_rebuild(array_id, failed_disk, new_disk)
```

**Supported levels:** RAID 0, 1, 5, 6, 10

**Location:** `kernel/src/drivers/raid.home`

## Network Drivers

### E1000

Intel E1000 Gigabit Ethernet for VMs and servers.

**Location:** `kernel/src/drivers/e1000.home`

### RTL8139

Realtek RTL8139 10/100 Ethernet.

**Location:** `kernel/src/drivers/rtl8139.home`

### VirtIO Net

Paravirtualized networking for VMs.

```home
virtio_net_init()
virtio_net_send(data, length)
virtio_net_receive(buffer, max_length)
```

**Location:** `kernel/src/drivers/virtio_net.home`

### WiFi

IEEE 802.11 wireless with WPA2/WPA3 support.

```home
wifi_init()
wifi_scan()
wifi_connect(ssid, password)
wifi_disconnect()
wifi_is_connected()
wifi_get_rssi()
wifi_set_mode(mode)
wifi_get_mac(mac_buffer)
wifi_set_power_save(enable)
```

**Location:** `kernel/src/drivers/wifi.home`

### CYW43455

Cypress CYW43455 WiFi/Bluetooth for Raspberry Pi 4/5.

```home
wifi_enable()
wifi_connect(ssid, ssid_len, passphrase, passphrase_len, security)
wifi_is_connected()
bt_enable(mode)
bt_is_enabled()
```

**Location:** `kernel/src/drivers/cyw43455.home`

### Bluetooth

Bluetooth HCI and profiles.

```home
bluetooth_init()
bluetooth_enable()
bluetooth_scan()
bluetooth_pair(device_id)
bluetooth_connect(device_id)
bluetooth_send(device_id, data, length)
bluetooth_get_state()
```

**Location:** `kernel/src/drivers/bluetooth.home`

## Input Drivers

### Keyboard

PS/2 keyboard with USB HID support.

```home
keyboard_init()
keyboard_getchar()
keyboard_has_char()
keyboard_getline(buffer, max_len)
keyboard_set_leds(scroll, num, caps)
```

**Location:** `kernel/src/drivers/keyboard.home`

### Mouse

PS/2 mouse driver.

```home
mouse_init()
mouse_get_x()
mouse_get_y()
mouse_get_buttons()
```

**Location:** `kernel/src/drivers/mouse.home`

### Touchpad

PS/2 and I2C touchpad with gestures.

```home
touchpad_init()
touchpad_enable()
touchpad_get_x()
touchpad_get_y()
touchpad_get_buttons()
touchpad_get_last_gesture()
touchpad_set_sensitivity(level)
```

**Location:** `kernel/src/drivers/touchpad.home`

### Touchscreen

Multi-touch touchscreen support.

```home
touchscreen_init()
touchscreen_update()
touchscreen_get_point(index)
touchscreen_get_count()
```

**Location:** `kernel/src/drivers/touchscreen.home`

### Gamepad

USB/Bluetooth gamepad support.

```home
gamepad_init()
gamepad_get_buttons(id)
gamepad_get_axis_x(id)
gamepad_get_axis_y(id)
gamepad_is_connected(id)
```

**Location:** `kernel/src/drivers/gamepad.home`

## USB Drivers

### UHCI

Universal Host Controller Interface (USB 1.1).

```home
uhci_init()
uhci_control_transfer(address, request_type, request, value, index, data, length)
uhci_bulk_transfer(address, endpoint, data, length, direction)
```

**Location:** `kernel/src/drivers/uhci.home`

### EHCI

Enhanced Host Controller Interface (USB 2.0).

```home
ehci_init()
ehci_control_transfer(address, request_type, request, value, index, data, length)
ehci_bulk_transfer(address, endpoint, data, length, direction)
```

**Location:** `kernel/src/drivers/ehci.home`

### XHCI

eXtensible Host Controller Interface (USB 3.0+).

```home
xhci_init(base_addr)
xhci_start()
xhci_stop()
xhci_handle_port_change(port_num)
xhci_control_transfer(slot_id, request_type, request, value, index, data, length)
xhci_bulk_transfer(slot_id, endpoint, data, length, direction)
```

**Location:** `kernel/src/drivers/xhci.home`, `kernel/src/drivers/usb_xhci.home`

### USB Hub

USB hub enumeration and management.

```home
usb_hub_init()
usb_hub_register(device, ports)
usb_hub_port_reset(hub_id, port)
usb_hub_enumerate_ports(hub_id)
```

**Location:** `kernel/src/drivers/usb_hub.home`

## Display Drivers

### VGA Text

VGA text mode (80x25).

**Location:** `kernel/src/vga.home`

### VGA Graphics

VGA graphics mode (320x200 256-color).

```home
vga_graphics_init()
vga_put_pixel(x, y, color)
vga_fill_screen(color)
vga_draw_rect(x, y, width, height, color)
vga_draw_line(x1, y1, x2, y2, color)
vga_set_palette(index, r, g, b)
```

**Location:** `kernel/src/drivers/vga_graphics.home`

### Framebuffer

Enhanced framebuffer up to 4K resolution.

```home
fb_init(addr, width, height, bpp, format)
fb_enable_double_buffer(back_addr)
fb_swap_buffers()
fb_put_pixel(x, y, color)
fb_fill_rect(x, y, width, height, color)
fb_clear(color)
fb_draw_line(x0, y0, x1, y1, color)
fb_draw_circle(cx, cy, radius, color)
fb_draw_string(x, y, text, fg_color, bg_color)
```

**Location:** `kernel/src/drivers/framebuffer.home`

### Framebuffer Console

Text console with font rendering.

```home
fb_console_init()
fb_console_putchar(ch)
fb_console_write(str)
fb_console_clear()
fb_console_set_cursor_visible(visible)
fb_console_set_theme(theme)
```

**Location:** `kernel/src/drivers/fb_console.home`

### GPU

Software GPU with 2D/3D rendering.

```home
gpu_init()
gpu_clear(color)
gpu_draw_pixel(x, y, color)
gpu_draw_line(x0, y0, x1, y1, color)
gpu_fill_rect(x, y, width, height, color)
gpu_draw_circle(cx, cy, radius, color)
gpu_fill_triangle(x0, y0, x1, y1, x2, y2, color)
gpu_enable_depth_test()
```

**Location:** `kernel/src/drivers/gpu.home`

## Audio Drivers

### Audio (AC97/HDA)

AC97 and Intel HDA audio.

```home
audio_init()
audio_play(samples, count)
audio_start()
audio_stop()
audio_set_volume(volume)
audio_set_sample_rate(rate)
audio_is_playing()
```

**Location:** `kernel/src/drivers/audio.home`

### Sound System

Multi-channel sound mixer.

```home
sound_init()
sound_play(channel, samples, length, frequency)
sound_stop(channel)
sound_set_volume(channel, volume)
sound_set_pan(channel, pan)
```

**Location:** `kernel/src/drivers/sound.home`

## GPIO/Peripheral Drivers

### GPIO

General Purpose I/O with interrupts and PWM.

```home
gpio_init()
gpio_request(controller, pin)
gpio_set_mode(handle, mode)
gpio_write(handle, value)
gpio_read(handle)
gpio_toggle(handle)
gpio_enable_interrupt(handle, mode, callback, user_data)
gpio_pwm_configure(handle, frequency)
gpio_pwm_set_duty(pwm_handle, duty)
```

**Location:** `kernel/src/drivers/gpio.home`

### I2C

Inter-Integrated Circuit bus.

**Location:** `kernel/src/drivers/i2c.home`

### SPI

Serial Peripheral Interface.

```home
spi_init()
spi_register_device(controller, cs, mode, speed_hz)
spi_transfer(handle, tx_data, rx_data, length)
spi_write(handle, data, length)
spi_read(handle, buffer, length)
```

**Location:** `kernel/src/drivers/spi.home`

### PWM

Pulse Width Modulation.

```home
pwm_init()
pwm_set_frequency(channel, frequency)
pwm_set_duty_cycle(channel, duty)
pwm_enable(channel)
pwm_disable(channel)
```

**Location:** `kernel/src/drivers/pwm.home`

### Sensors

Accelerometer, gyroscope, magnetometer.

```home
sensors_init()
sensors_register(type)
sensors_enable(sensor_id)
sensors_read(sensor_id)
```

**Location:** `kernel/src/drivers/sensors.home`

## System Drivers

### PCI

PCI device enumeration.

```home
pci_init()
pci_get_device_count()
pci_get_device(index)
pci_find_device(vendor, device)
```

**Location:** `kernel/src/drivers/pci.home`

### ACPI

Advanced Configuration and Power Interface.

```home
acpi_init()
acpi_shutdown()
acpi_reboot()
acpi_suspend_to_ram()
acpi_get_temperature()
acpi_get_battery_status(percentage_out, charging_out)
```

**Location:** `kernel/src/drivers/acpi.home`, `kernel/src/drivers/acpi_pm.home`

### Timer (PIT)

Programmable Interval Timer.

```home
timer_init(frequency)
timer_get_ticks()
timer_get_milliseconds()
timer_sleep_ms(milliseconds)
timer_delay_us(microseconds)
```

**Location:** `kernel/src/drivers/timer.home`

### RTC

Real-Time Clock.

```home
rtc_init()
rtc_get_second()
rtc_get_minute()
rtc_get_hour()
rtc_get_day()
rtc_get_month()
rtc_get_year()
rtc_get_timestamp()
```

**Location:** `kernel/src/drivers/rtc.home`

### Watchdog

Hardware watchdog timer.

```home
watchdog_init()
watchdog_enable()
watchdog_disable()
watchdog_kick()
watchdog_set_timeout(seconds)
watchdog_get_remaining()
```

**Location:** `kernel/src/drivers/watchdog.home`

### DMA

Direct Memory Access controller.

```home
dma_init()
dma_allocate_channel()
dma_free_channel(channel)
dma_setup_transfer(channel, buffer, size, mode)
dma_start_transfer(channel)
```

**Location:** `kernel/src/drivers/dma.home`

## Security Drivers

### TPM

Trusted Platform Module.

```home
tpm_init()
tpm_extend_pcr(pcr, hash)
tpm_get_random(buffer, size)
tpm_seal_data(data, size, sealed)
tpm_unseal_data(sealed, size, data)
```

**Location:** `kernel/src/drivers/tpm.home`

### Fingerprint

Fingerprint scanner.

```home
fingerprint_init()
fingerprint_enroll(user_id)
fingerprint_verify()
fingerprint_delete(fp_id)
```

**Location:** `kernel/src/drivers/fingerprint.home`

### Smartcard

ISO 7816 smart card reader.

```home
smartcard_init()
smartcard_detect()
smartcard_power_on()
smartcard_transmit(command, cmd_len, response, resp_len)
```

**Location:** `kernel/src/drivers/smartcard.home`

## Driver Development

### Driver Structure

```home
struct DriverModule {
  name: [64]u8
  init_fn: fn(): u32
  exit_fn: fn(): u32
  dependencies: [8]u32
  priority: u32
  loaded: u32
}
```

### Best Practices

1. **Use the Home language** - All drivers must be written in Home
2. **Handle errors gracefully** - Return error codes, don't panic
3. **Use interrupt handlers** - Avoid polling when possible
4. **Document hardware registers** - Use constants for register offsets
5. **Test on real hardware** - QEMU may behave differently

## Related Documentation

- [Architecture](/guide/architecture) - Driver loading
- [Raspberry Pi 5](/guide/rpi5) - Pi 5 hardware support
- [Driver API Reference](/api/drivers) - Full driver API
