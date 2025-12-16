# home-os Driver Reference

This document is auto-generated from `kernel/src/drivers/*.home`.

## Overview

home-os includes drivers for various hardware devices. Each driver follows a consistent interface pattern.

## Driver Categories

### Storage Drivers

| Driver | File | Description |
|--------|------|-------------|
| sdmmc | `sdmmc.home` | home-os SD/MMC Driver with DMA Support |
| bcm_emmc | `bcm_emmc.home` | home-os BCM2711/BCM2712 EMMC2 Controller Driver |
| nvme | `nvme.home` | home-os NVMe Driver |
| ahci | `ahci.home` | home-os AHCI Driver |

### Network Drivers

| Driver | File | Description |
|--------|------|-------------|
| wifi | `wifi.home` | home-os WiFi Driver |
| cyw43455 | `cyw43455.home` | home-os Cypress CYW43455 WiFi/Bluetooth Driver |

### Display Drivers

| Driver | File | Description |
|--------|------|-------------|
| framebuffer | `framebuffer.home` | home-os Enhanced Framebuffer Driver |
| gpu | `gpu.home` | home-os GPU Driver |
| vga_graphics | `vga_graphics.home` | home-os VGA Graphics Mode Driver |

### Input Drivers

| Driver | File | Description |
|--------|------|-------------|
| keyboard | `keyboard.home` | home-os Kernel - PS/2 Keyboard Driver |
| mouse | `mouse.home` | home-os Mouse Driver |
| touchpad | `touchpad.home` | home-os Touchpad Driver |

### USB Drivers

| Driver | File | Description |
|--------|------|-------------|
| xhci | `xhci.home` | home-os XHCI Driver |
| uhci | `uhci.home` | home-os UHCI Driver |
| usb_xhci | `usb_xhci.home` | home-os xHCI (USB 3.0) Host Controller Driver |

### Serial Drivers

| Driver | File | Description |
|--------|------|-------------|
| serial | `serial.home` | home-os Serial Port Driver (Extended) |

### GPIO Drivers

| Driver | File | Description |
|--------|------|-------------|
| gpio | `gpio.home` | home-os GPIO (General Purpose Input/Output) Driver |

### Audio Drivers

| Driver | File | Description |
|--------|------|-------------|
| audio | `audio.home` | home-os Audio Driver |

### Other Drivers

| Driver | File | Description |
|--------|------|-------------|
| timer | `timer.home` | home-os Kernel - PIT (Programmable Interval Timer) Driver |
| watchdog | `watchdog.home` | home-os Watchdog Timer Driver |
| dma | `dma.home` | home-os DMA Controller |
| pci | `pci.home` | home-os PCI Driver |

## Driver Details

### Acpi

**File:** `kernel/src/drivers/acpi.home`

home-os ACPI Driver
Advanced Configuration and Power Interface

**Exported Functions:**

```
acpi_init()
acpi_shutdown()
acpi_reboot()
```

**Data Structures:** 2 defined

---

### Acpi Pm

**File:** `kernel/src/drivers/acpi_pm.home`

home-os Kernel - ACPI Power Management
Advanced Configuration and Power Interface for power management
ACPI sleep states

**Exported Functions:**

```
acpi_pm_init()
acpi_set_pstate(pstate: u32): u32
acpi_enter_cstate(cstate: u32)
acpi_suspend_to_ram(): u32
acpi_hibernate(): u32
acpi_shutdown()
acpi_get_temperature(): u32
acpi_get_battery_status(percentage_out: u64, charging_out: u64): u32
acpi_set_brightness(level: u32): u32
acpi_handle_lid_event(closed: u32)
acpi_handle_power_button()
acpi_get_current_pstate(): u32
acpi_get_sleep_state(): u32
```

**Constants:** 3 defined

---

### Ahci

**File:** `kernel/src/drivers/ahci.home`

home-os AHCI Driver
Advanced Host Controller Interface (SATA)
============================================================================

**Exported Functions:**

```
ahci_init()
ahci_read_sector(port: u32, lba: u64, buffer: u64): u32
ahci_read_sectors(port: u32, lba: u64, count: u32, buffer: u64): u32
ahci_write_sector(port: u32, lba: u64, buffer: u64): u32
ahci_write_sectors(port: u32, lba: u64, count: u32, buffer: u64): u32
ahci_flush(port: u32): u32
ahci_get_port_count(): u32
ahci_is_port_active(port: u32): u32
ahci_is_initialized(): u32
```

**Constants:** 45 defined

**Data Structures:** 6 defined

---

### Ata

**File:** `kernel/src/drivers/ata.home`

home-os Kernel - ATA/IDE Driver (PIO Mode)
Real implementation for disk I/O
============================================================================

**Exported Functions:**

```
ata_init()
ata_read_sector(drive: u32, lba: u64, buffer: u64): u32
ata_write_sector(drive: u32, lba: u64, buffer: u64): u32
ata_read_sectors(drive: u32, lba: u64, count: u32, buffer: u64): u32
ata_write_sectors(drive: u32, lba: u64, count: u32, buffer: u64): u32
ata_get_device_count(): u32
ata_get_device_sectors(drive: u32): u64
ata_device_exists(drive: u32): u32
```

**Constants:** 29 defined

**Data Structures:** 1 defined

---

### Audio

**File:** `kernel/src/drivers/audio.home`

home-os Audio Driver
AC97 and Intel HDA audio support with real hardware output
============================================================================

**Exported Functions:**

```
audio_init()
audio_init_hda(base_addr: u64): u32
audio_play(samples: u64, count: u32): u32
audio_start(): u32
audio_stop(): u32
audio_set_volume(volume: u8)
audio_get_volume(): u8
audio_set_sample_rate(rate: u32): u32
audio_get_sample_rate(): u32
audio_get_buffer_status(): u32
audio_is_playing(): u32
audio_irq_handler()
```

**Constants:** 39 defined

**Data Structures:** 3 defined

---

### Backlight

**File:** `kernel/src/drivers/backlight.home`

home-os Backlight Driver
Screen brightness control

**Exported Functions:**

```
backlight_init()
backlight_set_brightness(brightness: u32)
backlight_get_brightness(): u32
backlight_increase()
backlight_decrease()
```

**Constants:** 1 defined

---

### Battery

**File:** `kernel/src/drivers/battery.home`

home-os Battery Driver
Laptop battery monitoring

**Exported Functions:**

```
battery_init()
battery_update()
battery_get_capacity(): u32
battery_get_status(): u32
battery_is_charging(): u32
battery_get_time_remaining(): u32
```

**Constants:** 3 defined

**Data Structures:** 1 defined

---

### Bcm Emmc

**File:** `kernel/src/drivers/bcm_emmc.home`

home-os BCM2711/BCM2712 EMMC2 Controller Driver
Broadcom SD/MMC host controller for Raspberry Pi 4/5
SDHCI-compatible controller with DMA support

**Exported Functions:**

```
```

**Constants:** 72 defined

**Data Structures:** 1 defined

---

### Bluetooth

**File:** `kernel/src/drivers/bluetooth.home`

home-os Bluetooth Driver
Bluetooth HCI and profile support
Bluetooth states

**Exported Functions:**

```
bluetooth_init()
bluetooth_enable()
bluetooth_disable()
bluetooth_scan(): u32
bluetooth_pair(device_id: u32): u32
bluetooth_connect(device_id: u32): u32
bluetooth_disconnect(device_id: u32): u32
bluetooth_get_state(): u32
bluetooth_get_device_count(): u32
bluetooth_get_device(index: u32, address: [*]u8, name: [*]u8, rssi: *i8): u32
bluetooth_send(device_id: u32, data: [*]u8, length: u32): u32
bluetooth_get_stats(tx_pkts: *u64, rx_pkts: *u64, errors: *u32)
```

**Constants:** 69 defined

**Data Structures:** 6 defined

---

### Bluetooth Hci

**File:** `kernel/src/drivers/bluetooth_hci.home`

home-os Kernel - Bluetooth HCI (Host Controller Interface)
Bluetooth stack with HCI, L2CAP, RFCOMM, and profiles
HCI packet types

**Exported Functions:**

```
bluetooth_hci_init()
bluetooth_inquiry(duration_sec: u8): u32
bluetooth_connect(bd_addr: u64): u32
bluetooth_get_device_count(): u32
bluetooth_get_device(index: u32, bd_addr_out: u64, name_out: u64): u32
```

**Constants:** 15 defined

**Data Structures:** 2 defined

---

### Buzzer

**File:** `kernel/src/drivers/buzzer.home`

home-os PC Speaker/Buzzer
System beep

**Exported Functions:**

```
buzzer_init()
buzzer_beep(frequency: u32, duration_ms: u32)
buzzer_play_tone(frequency: u32)
```

**Constants:** 1 defined

---

### Camera

**File:** `kernel/src/drivers/camera.home`

home-os Camera Driver
Webcam support

**Exported Functions:**

```
camera_init()
camera_start()
camera_stop()
camera_capture(buffer: u64): u32
camera_set_resolution(width: u32, height: u32)
```

**Constants:** 2 defined

**Data Structures:** 1 defined

---

### Cdrom

**File:** `kernel/src/drivers/cdrom.home`

home-os CD-ROM Driver
ATAPI CD-ROM support

**Exported Functions:**

```
cdrom_init()
cdrom_read_sector(lba: u32, buffer: u64): u32
cdrom_eject()
```

**Constants:** 3 defined

---

### Cyw43455

**File:** `kernel/src/drivers/cyw43455.home`

home-os Cypress CYW43455 WiFi/Bluetooth Driver
Integrated 802.11ac WiFi and Bluetooth 5.0 for Raspberry Pi 4/5
SDIO interface for WiFi, UART for Bluetooth

**Exported Functions:**

```
wifi_enable(): u32
wifi_disable(): u32
wifi_connect(ssid: *u8, ssid_len: u32, passphrase: *u8, passphrase_len: u32, security: u32): u32
wifi_disconnect(): u32
wifi_is_connected(): u32
wifi_get_rssi(): i32
bt_enable(mode: u32): u32
bt_disable(): u32
bt_is_enabled(): u32
```

**Constants:** 30 defined

**Data Structures:** 4 defined

---

### Dma

**File:** `kernel/src/drivers/dma.home`

home-os DMA Controller
Direct Memory Access

**Exported Functions:**

```
dma_init()
dma_allocate_channel(): u32
dma_free_channel(channel: u32)
dma_setup_transfer(channel: u32, buffer: u64, size: u32, mode: u8)
dma_start_transfer(channel: u32)
```

**Constants:** 3 defined

**Data Structures:** 1 defined

---

### E1000

**File:** `kernel/src/drivers/e1000.home`

home-os Kernel - Intel E1000 Network Driver
Real implementation for network I/O
============================================================================

**Exported Functions:**

```
```

**Constants:** 3 defined

**Data Structures:** 2 defined

---

### Ehci

**File:** `kernel/src/drivers/ehci.home`

home-os EHCI Driver
Enhanced Host Controller Interface (USB 2.0)
============================================================================

**Exported Functions:**

```
ehci_init()
ehci_control_transfer(address: u8, request_type: u8, request: u8, value: u16, index: u16, data: u64, length: u16): u32
ehci_bulk_transfer(address: u8, endpoint: u8, data: u64, length: u32, direction: u8): u32
ehci_is_initialized(): u32
```

**Constants:** 46 defined

**Data Structures:** 3 defined

---

### Fb Console

**File:** `kernel/src/drivers/fb_console.home`

home-os Framebuffer Console with Font Rendering
VT100-compatible terminal emulator with PSF font support
Provides graphical text console output

**Exported Functions:**

```
fb_console_init(): u32
fb_console_putchar(ch: u8)
fb_console_write(str: *u8)
fb_console_clear()
fb_console_refresh()
fb_console_set_cursor_visible(visible: u32)
fb_console_get_cursor_x(): u32
fb_console_get_cursor_y(): u32
fb_console_enable_status_line(enable: u32)
fb_console_set_status(text: u64)
fb_console_partial_refresh()
fb_console_blink_cursor()
fb_console_update_cursor()
fb_console_get_stats(chars_out: u64, scrolls_out: u64, clears_out: u64)
fb_console_print_stats()
fb_console_set_mode(mode: u32)
fb_console_get_mode(): u32
fb_console_save_screen()
fb_console_restore_screen()
fb_console_set_theme(theme: u32)
```

**Constants:** 31 defined

**Data Structures:** 2 defined

---

### Fingerprint

**File:** `kernel/src/drivers/fingerprint.home`

home-os Fingerprint Scanner
Biometric authentication

**Exported Functions:**

```
fingerprint_init()
fingerprint_enroll(user_id: u32): u32
fingerprint_verify(): u32
fingerprint_delete(fp_id: u32)
```

**Constants:** 1 defined

**Data Structures:** 1 defined

---

### Floppy

**File:** `kernel/src/drivers/floppy.home`

home-os Floppy Disk Driver
Legacy floppy controller

**Exported Functions:**

```
floppy_init()
floppy_read_sector(track: u8, head: u8, sector: u8, buffer: u64): u32
floppy_write_sector(track: u8, head: u8, sector: u8, buffer: u64): u32
```

**Constants:** 8 defined

---

### Framebuffer

**File:** `kernel/src/drivers/framebuffer.home`

home-os Enhanced Framebuffer Driver
Supports up to 4K (3840x2160) resolution with multiple pixel formats
Optimized for Raspberry Pi 5 and LG 27UP850-W monitor

**Exported Functions:**

```
fb_init(addr: u64, width: u32, height: u32, bpp: u32, format: u32): u32
fb_enable_double_buffer(back_addr: u64): u32
fb_swap_buffers(): u32
fb_put_pixel(x: u32, y: u32, color: u32)
fb_get_pixel(x: u32, y: u32): u32
fb_fill_rect(x: u32, y: u32, width: u32, height: u32, color: u32)
fb_clear(color: u32)
fb_draw_hline(x: u32, y: u32, width: u32, color: u32)
fb_draw_vline(x: u32, y: u32, height: u32, color: u32)
fb_draw_rect(x: u32, y: u32, width: u32, height: u32, color: u32)
fb_draw_line(x0: u32, y0: u32, x1: u32, y1: u32, color: u32)
fb_draw_circle(cx: u32, cy: u32, radius: u32, color: u32)
fb_fill_circle(cx: u32, cy: u32, radius: u32, color: u32)
fb_blit(src_addr: u64, src_width: u32, src_height: u32,
fb_blit_alpha(src_addr: u64, src_width: u32, src_height: u32,
fb_draw_char(x: u32, y: u32, ch: u8, fg_color: u32, bg_color: u32)
fb_draw_string(x: u32, y: u32, text: *u8, fg_color: u32, bg_color: u32)
fb_console_write(text: *u8)
fb_console_putchar(ch: u8)
fb_console_set_colors(fg: u32, bg: u32)
```

**Constants:** 6 defined

**Data Structures:** 3 defined

---

### Gamepad

**File:** `kernel/src/drivers/gamepad.home`

home-os Gamepad Driver
USB/Bluetooth gamepad support

**Exported Functions:**

```
gamepad_init()
gamepad_connect(id: u32)
gamepad_disconnect(id: u32)
gamepad_get_buttons(id: u32): u16
gamepad_get_axis_x(id: u32): i16
gamepad_get_axis_y(id: u32): i16
gamepad_is_connected(id: u32): u32
```

**Constants:** 7 defined

**Data Structures:** 1 defined

---

### Gpio

**File:** `kernel/src/drivers/gpio.home`

home-os GPIO (General Purpose Input/Output) Driver
Full-featured GPIO with interrupts, PWM, debouncing
GPIO controller types

**Exported Functions:**

```
gpio_init(): u32
gpio_register_controller(ctrl_type: u8, base_addr: u64, num_pins: u32, irq: u8): u32
gpio_request(controller: u32, pin: u32): u32
gpio_free(handle: u32)
gpio_set_mode(handle: u32, mode: u8)
gpio_set_pull(handle: u32, pull: u8)
gpio_set_drive(handle: u32, drive: u8)
gpio_set_slew(handle: u32, slew: u8)
gpio_write(handle: u32, value: u8)
gpio_read(handle: u32): u8
gpio_toggle(handle: u32)
gpio_enable_interrupt(handle: u32, mode: u8, callback: u64, user_data: u64)
gpio_disable_interrupt(handle: u32)
gpio_set_debounce(handle: u32, debounce_ms: u32)
gpio_irq_handler(controller: u32)
gpio_pwm_configure(handle: u32, frequency: u32): u32
gpio_pwm_set_duty(pwm_handle: u32, duty: u16)
gpio_pwm_set_frequency(pwm_handle: u32, frequency: u32)
gpio_pwm_enable(pwm_handle: u32)
gpio_pwm_disable(pwm_handle: u32)
```

**Constants:** 20 defined

**Data Structures:** 4 defined

---

### Gpu

**File:** `kernel/src/drivers/gpu.home`

home-os GPU Driver
Full software rasterizer implementation
Display configuration

**Exported Functions:**

```
gpu_init(): i32
gpu_init_with_mode(width: u32, height: u32, bpp: u32): i32
gpu_shutdown()
gpu_set_clip_rect(x: i32, y: i32, width: u32, height: u32)
gpu_disable_clipping()
gpu_enable_clipping()
gpu_draw_pixel(x: i32, y: i32, color: u32)
gpu_enable_depth_test()
gpu_disable_depth_test()
gpu_clear(color: u32)
gpu_clear_rect(x: i32, y: i32, width: u32, height: u32, color: u32)
gpu_draw_line(x0: i32, y0: i32, x1: i32, y1: i32, color: u32)
gpu_draw_line_aa(x0: i32, y0: i32, x1: i32, y1: i32, color: u32)
gpu_draw_rect(x: i32, y: i32, width: u32, height: u32, color: u32)
gpu_fill_rect(x: i32, y: i32, width: u32, height: u32, color: u32)
gpu_fill_rounded_rect(x: i32, y: i32, width: u32, height: u32, radius: u32, color: u32)
gpu_draw_circle(cx: i32, cy: i32, radius: u32, color: u32)
gpu_fill_circle(cx: i32, cy: i32, radius: u32, color: u32)
gpu_draw_triangle(x0: i32, y0: i32, x1: i32, y1: i32, x2: i32, y2: i32, color: u32)
gpu_fill_triangle(x0: i32, y0: i32, x1: i32, y1: i32, x2: i32, y2: i32, color: u32)
```

**Constants:** 25 defined

**Data Structures:** 8 defined

---

### Hwmon

**File:** `kernel/src/drivers/hwmon.home`

home-os Hardware Monitoring
Temperature, voltage, fan sensors

**Exported Functions:**

```
hwmon_init()
hwmon_register_sensor(type: u32, name: u64): u32
hwmon_read_sensor(sensor_id: u32): u32
hwmon_get_sensor_count(): u32
```

**Constants:** 4 defined

**Data Structures:** 1 defined

---

### I2c

**File:** `kernel/src/drivers/i2c.home`

home-os I2C (Inter-Integrated Circuit) Driver
Full-featured I2C/SMBus controller with multiple bus support
I2C controller types

**Exported Functions:**

```
```

**Constants:** 31 defined

**Data Structures:** 4 defined

---

### Keyboard

**File:** `kernel/src/drivers/keyboard.home`

home-os Kernel - PS/2 Keyboard Driver
Real implementation for keyboard input
============================================================================

**Exported Functions:**

```
keyboard_init()
keyboard_getchar(): u8
keyboard_has_char(): u32
keyboard_getline(buffer: u64, max_len: u32): u32
keyboard_interrupt_handler()
keyboard_set_leds(scroll_lock: u32, num_lock: u32, caps_lock_led: u32)
```

**Constants:** 23 defined

---

### Led

**File:** `kernel/src/drivers/led.home`

home-os LED Driver
LED control (keyboard, case, RGB)

**Exported Functions:**

```
led_init()
led_register(id: u32): u32
led_set_state(led_id: u32, state: u32)
led_set_brightness(led_id: u32, brightness: u8)
led_set_color(led_id: u32, r: u8, g: u8, b: u8)
led_blink(led_id: u32, interval_ms: u32)
```

**Constants:** 5 defined

**Data Structures:** 1 defined

---

### Lg Monitor

**File:** `kernel/src/drivers/lg_monitor.home`

home-os LG Monitor Support
Specific support for LG 27UP850-W and similar 4K monitors
Handles EDID parsing, optimal mode selection, and calibration

**Exported Functions:**

```
lg_detect(port: u32): u32
lg_set_resolution(width: u32, height: u32, refresh: u32): u32
lg_set_profile(profile_name: u32): u32
lg_enable_hdr(enabled: u32): u32
lg_get_brightness(): u32
lg_set_brightness(level: u32): u32
lg_get_supported_resolutions(): u32
lg_print_info()
```

**Constants:** 4 defined

**Data Structures:** 4 defined

---

### Lid

**File:** `kernel/src/drivers/lid.home`

home-os Lid Switch Driver
Laptop lid detection

**Exported Functions:**

```
lid_init()
lid_register_callback(callback: u64)
lid_interrupt_handler()
lid_get_state(): u32
lid_is_closed(): u32
```

**Constants:** 2 defined

---

### Mouse

**File:** `kernel/src/drivers/mouse.home`

home-os Mouse Driver
PS/2 mouse support

**Exported Functions:**

```
mouse_init()
mouse_interrupt_handler()
mouse_get_x(): i32
mouse_get_y(): i32
mouse_get_buttons(): u8
```

**Constants:** 3 defined

---

### Msi

**File:** `kernel/src/drivers/msi.home`

home-os MSI/MSI-X
Message Signaled Interrupts

**Exported Functions:**

```
msi_init()
msi_enable(device: u64, vector: u32): u32
msix_enable(device: u64, vectors: u32): u32
```

**Constants:** 2 defined

**Data Structures:** 1 defined

---

### Nvdimm

**File:** `kernel/src/drivers/nvdimm.home`

home-os NVDIMM Driver
Non-Volatile DIMM support

**Exported Functions:**

```
nvdimm_init()
nvdimm_read(offset: u64, buffer: u64, size: u64): u64
nvdimm_write(offset: u64, buffer: u64, size: u64): u64
nvdimm_flush(offset: u64, size: u64)
```

**Constants:** 1 defined

---

### Nvme

**File:** `kernel/src/drivers/nvme.home`

home-os NVMe Driver
Non-Volatile Memory Express (PCIe SSDs)
============================================================================

**Exported Functions:**

```
nvme_init()
nvme_read(lba: u64, count: u32, buffer: u64): u32
nvme_write(lba: u64, count: u32, buffer: u64): u32
nvme_flush(): u32
nvme_get_block_count(): u64
nvme_get_block_size(): u32
nvme_is_initialized(): u32
```

**Constants:** 26 defined

**Data Structures:** 5 defined

---

### Pci

**File:** `kernel/src/drivers/pci.home`

home-os PCI Driver
PCI device enumeration

**Exported Functions:**

```
pci_init()
pci_get_device_count(): u32
pci_get_device(index: u32): u64
pci_find_device(vendor: u16, device: u16): u64
```

**Constants:** 2 defined

**Data Structures:** 1 defined

---

### Pcie Extended

**File:** `kernel/src/drivers/pcie_extended.home`

home-os PCIe Extended Capabilities
Advanced PCIe features including AER, SRIOV, TLP Processing, and more
Extended Capability IDs (PCIe Extended Config Space at 0x100+)

**Exported Functions:**

```
pcie_find_ext_capability(bus: u32, dev: u32, func: u32, cap_id: u16): u32
pcie_extended_init()
pcie_register_device(bus: u32, dev: u32, func: u32): u32
pcie_enable_aer(device_idx: u32): u32
pcie_read_aer_status(device_idx: u32, uncorr: *u32, corr: *u32): u32
pcie_clear_aer_errors(device_idx: u32)
pcie_read_serial_number(device_idx: u32): u64
pcie_enable_sriov(device_idx: u32, num_vfs: u16): u32
pcie_disable_sriov(device_idx: u32): u32
pcie_get_vf_count(device_idx: u32): u16
pcie_enable_ltr(device_idx: u32): u32
pcie_get_ltr_max(device_idx: u32, snoop: *u16, nosnoop: *u16): u32
pcie_enable_ptm(device_idx: u32): u32
pcie_aer_interrupt_handler()
pcie_get_device_info(device_idx: u32, bus: *u32, dev: *u32, func: *u32, caps: *u32): u32
pcie_set_ecam_base(base: u64)
```

**Constants:** 98 defined

**Data Structures:** 1 defined

---

### Printer

**File:** `kernel/src/drivers/printer.home`

home-os Printer Driver
Print support

**Exported Functions:**

```
printer_init()
printer_submit_job(pages: u32, copies: u32): u32
printer_get_status(): u32
printer_cancel_job(job_id: u32)
```

**Constants:** 3 defined

**Data Structures:** 1 defined

---

### Pwm

**File:** `kernel/src/drivers/pwm.home`

home-os PWM Driver
Pulse Width Modulation

**Exported Functions:**

```
pwm_init()
pwm_set_frequency(channel: u32, frequency: u32)
pwm_set_duty_cycle(channel: u32, duty: u32)
pwm_enable(channel: u32)
pwm_disable(channel: u32)
```

**Constants:** 3 defined

---

### Raid

**File:** `kernel/src/drivers/raid.home`

home-os Kernel - RAID Controller Support
Software RAID and hardware RAID controller drivers
RAID levels

**Exported Functions:**

```
raid_init()
raid_create_array(level: u32, disk_ids: u64, disk_count: u32, stripe_size: u32): u32
raid_read(array_id: u32, offset: u64, buffer: u64, size: u32): u32
raid_write(array_id: u32, offset: u64, buffer: u64, size: u32): u32
raid_get_status(array_id: u32): u32
raid_rebuild(array_id: u32, failed_disk: u32, new_disk: u32): u32
```

**Constants:** 2 defined

**Data Structures:** 2 defined

---

### Ramdisk

**File:** `kernel/src/drivers/ramdisk.home`

home-os RAM Disk Driver
In-memory block device

**Exported Functions:**

```
ramdisk_init()
ramdisk_read(sector: u32, buffer: u64): u32
ramdisk_write(sector: u32, buffer: u64): u32
ramdisk_get_size(): u32
```

**Constants:** 2 defined

---

### Rtc

**File:** `kernel/src/drivers/rtc.home`

home-os RTC (Real-Time Clock) Driver
CMOS RTC support

**Exported Functions:**

```
rtc_init()
rtc_get_second(): u8
rtc_get_minute(): u8
rtc_get_hour(): u8
rtc_get_day(): u8
rtc_get_month(): u8
rtc_get_year(): u16
rtc_get_timestamp(): u64
```

**Constants:** 2 defined

---

### Rtl8139

**File:** `kernel/src/drivers/rtl8139.home`

home-os Realtek RTL8139 Network Driver
RTL8139 Ethernet controller

**Exported Functions:**

```
```

**Constants:** 3 defined

---

### Scanner

**File:** `kernel/src/drivers/scanner.home`

home-os Scanner Driver
USB and parallel port scanner support with SANE-like interface
============================================================================

**Exported Functions:**

```
scanner_init()
scanner_init_usb(address: u8, ep_in: u8, ep_out: u8): u32
scanner_init_parallel(base: u16): u32
scanner_set_dpi(dpi: u32): u32
scanner_get_dpi(): u32
scanner_set_mode(mode: u32): u32
scanner_get_mode(): u32
scanner_set_area(x: u32, y: u32, width: u32, height: u32): u32
scanner_set_brightness(brightness: i32): u32
scanner_set_contrast(contrast: i32): u32
scanner_set_gamma(gamma: u32): u32
scanner_get_image_size(): u32
scanner_scan(buffer: u64, width: u32, height: u32): u32
scanner_abort()
scanner_get_status(): u32
scanner_get_progress(): u32
scanner_set_progress_callback(callback: fn(u32, u32))
scanner_get_info(info: *ScannerInfo)
scanner_get_max_width(): u32
scanner_get_max_height(): u32
```

**Constants:** 37 defined

**Data Structures:** 2 defined

---

### Sdmmc

**File:** `kernel/src/drivers/sdmmc.home`

home-os SD/MMC Driver with DMA Support
Generic SD/MMC/SDIO controller driver for Raspberry Pi and other platforms
Supports DMA, high-speed modes, and multi-block transfers

**Exported Functions:**

```
sdmmc_init()
sdmmc_register_controller(base_addr: u64, use_dma: u32): u32
sdmmc_init_card(controller_id: u32): u32
sdmmc_read_blocks(controller_id: u32, block: u64, count: u32, buffer: u64): u32
sdmmc_write_blocks(controller_id: u32, block: u64, count: u32, buffer: u64): u32
sdmmc_get_capacity(controller_id: u32): u64
sdmmc_print_stats()
```

**Constants:** 17 defined

**Data Structures:** 1 defined

---

### Sdmmc Highspeed

**File:** `kernel/src/drivers/sdmmc_highspeed.home`

home-os SD/MMC High-Speed Mode Verification
Tests and validates SDR50, SDR104, DDR50 modes and error corner cases
For BCM2711 (Pi 4) and BCM2712 (Pi 5) SD/eMMC controllers

**Exported Functions:**

```
sdmmc_highspeed_init()
sdmmc_highspeed_attach(ctrl_id: u32): u32
sdmmc_highspeed_set_mode(hs_id: u32, mode: u32): u32
sdmmc_highspeed_verify(hs_id: u32): u32
sdmmc_highspeed_print_status(hs_id: u32)
sdmmc_highspeed_retune(hs_id: u32): u32
```

**Constants:** 31 defined

**Data Structures:** 3 defined

---

### Sdmmc Tuning

**File:** `kernel/src/drivers/sdmmc_tuning.home`

home-os SD/MMC Tuning Module
Configurable request queues, DMA burst sizes, and error handling
Optimized for SD card wear leveling and latency

**Exported Functions:**

```
sdmmc_tuning_init()
sdmmc_tuning_attach(ctrl_id: u32, profile_id: u32): u32
sdmmc_tuning_set_profile(tuning_id: u32, profile_id: u32): u32
sdmmc_tuning_get_burst_size(tuning_id: u32): u32
sdmmc_tuning_get_queue_depth(tuning_id: u32): u32
sdmmc_tuning_record_error(tuning_id: u32, error_type: u32, block: u64, timestamp: u64)
sdmmc_tuning_record_success(tuning_id: u32)
sdmmc_tuning_track_write(tuning_id: u32, block: u64, count: u32, timestamp: u64)
sdmmc_tuning_get_retry_delay(tuning_id: u32, attempt: u32): u32
sdmmc_tuning_should_reset(tuning_id: u32): u32
sdmmc_tuning_update_latency(tuning_id: u32, req_type: u32, latency_us: u64)
sdmmc_tuning_print_stats(tuning_id: u32)
sdmmc_tuning_proc_read(buffer: *u8, size: u32): u32
```

**Constants:** 22 defined

**Data Structures:** 6 defined

---

### Sensors

**File:** `kernel/src/drivers/sensors.home`

home-os Sensor Framework
Accelerometer, gyroscope, magnetometer

**Exported Functions:**

```
sensors_init()
sensors_register(type: u32): u32
sensors_enable(sensor_id: u32)
sensors_disable(sensor_id: u32)
sensors_read(sensor_id: u32): u64
```

**Constants:** 6 defined

**Data Structures:** 2 defined

---

### Serial

**File:** `kernel/src/drivers/serial.home`

home-os Serial Port Driver (Extended)
Full serial port implementation with buffering

**Exported Functions:**

```
serial_init_extended()
serial_interrupt_handler()
serial_available(): u32
serial_read_char(): u8
serial_read_line(buffer: u64, max_len: u32): u32
```

**Constants:** 1 defined

---

### Smartcard

**File:** `kernel/src/drivers/smartcard.home`

home-os Smart Card Reader
ISO 7816 smart card support

**Exported Functions:**

```
smartcard_init()
smartcard_detect(): u32
smartcard_power_on(): u32
smartcard_power_off()
smartcard_transmit(command: u64, cmd_len: u32, response: u64, resp_len: u32): u32
```

---

### Sound

**File:** `kernel/src/drivers/sound.home`

home-os Sound System
Advanced sound driver

**Exported Functions:**

```
sound_init()
sound_play(channel: u32, samples: u64, length: u32, frequency: u32)
sound_stop(channel: u32)
sound_set_volume(channel: u32, volume: u8)
sound_set_pan(channel: u32, pan: u8)
sound_is_playing(channel: u32): u32
```

**Constants:** 1 defined

**Data Structures:** 1 defined

---

### Spi

**File:** `kernel/src/drivers/spi.home`

home-os SPI (Serial Peripheral Interface) Driver
Full-featured SPI controller with multiple bus and DMA support
SPI controller types

**Exported Functions:**

```
spi_init(): u32
spi_register_controller(ctrl_type: u8, base_addr: u64, irq: u8, num_cs: u8): u32
spi_register_device(controller: u32, cs: u8, mode: u8, speed_hz: u32): u32
spi_unregister_device(handle: u32)
spi_set_mode(handle: u32, mode: u8)
spi_set_speed(handle: u32, speed_hz: u32)
spi_set_bits_per_word(handle: u32, bits: u8)
spi_set_bit_order(handle: u32, order: u8)
spi_transfer(handle: u32, tx_data: u64, rx_data: u64, length: u32): u32
spi_write(handle: u32, data: u64, length: u32): u32
spi_read(handle: u32, buffer: u64, length: u32): u32
spi_write_then_read(handle: u32, tx_data: u64, tx_len: u32, rx_data: u64, rx_len: u32): u32
spi_write_byte(handle: u32, data: u8): u32
spi_read_byte(handle: u32): u8
spi_transfer_byte(handle: u32, data: u8): u8
spi_write_word(handle: u32, data: u16): u32
spi_read_word(handle: u32): u16
spi_write_reg(handle: u32, reg: u8, data: u8): u32
spi_read_reg(handle: u32, reg: u8): u8
spi_multi_transfer(handle: u32, transfers: u64, num_transfers: u32): u32
```

**Constants:** 44 defined

**Data Structures:** 4 defined

---

### Timer

**File:** `kernel/src/drivers/timer.home`

home-os Kernel - PIT (Programmable Interval Timer) Driver
Real implementation for system timing
============================================================================

**Exported Functions:**

```
timer_init(frequency: u32)
timer_interrupt_handler()
timer_set_wakeup_callback(callback: fn(u32) void)
timer_cancel_sleeper(process_id: u32): u32
timer_sleep_with_pid(process_id: u32, milliseconds: u64): u32
timer_get_remaining(process_id: u32): u64
timer_get_ticks(): u64
timer_get_seconds(): u64
timer_get_milliseconds(): u64
timer_sleep_ticks(ticks: u64)
timer_sleep_ms(milliseconds: u64)
timer_sleep_seconds(seconds: u64)
timer_register_sleeper(process_id: u32, wake_tick: u64): u32
timer_delay_ticks(ticks: u64)
timer_delay_ms(milliseconds: u64)
timer_delay_us(microseconds: u64)
timer_measure_start(): u64
timer_measure_end(start_tick: u64): u64
timer_measure_ms(start_tick: u64): u64
timer_watchdog_enable(timeout_ms: u64, callback: u64)
```

**Constants:** 8 defined

**Data Structures:** 1 defined

---

### Touchpad

**File:** `kernel/src/drivers/touchpad.home`

home-os Touchpad Driver
PS/2 and I2C touchpad support with multi-touch gestures
============================================================================

**Exported Functions:**

```
touchpad_irq_handler()
touchpad_init()
touchpad_enable()
touchpad_disable()
touchpad_set_mode(mode: u32)
touchpad_get_x(): u32
touchpad_get_y(): u32
touchpad_get_pressure(): u32
touchpad_get_dx(): i32
touchpad_get_dy(): i32
touchpad_get_buttons(): u8
touchpad_get_touch_count(): u32
touchpad_enable_gestures()
touchpad_disable_gestures()
touchpad_get_last_gesture(): u32
touchpad_set_sensitivity(sensitivity: u8)
touchpad_get_bounds(min_x: *u32, max_x: *u32, min_y: *u32, max_y: *u32)
touchpad_is_enabled(): u32
touchpad_get_type(): u32
```

**Constants:** 52 defined

---

### Touchscreen

**File:** `kernel/src/drivers/touchscreen.home`

home-os Touchscreen Driver
Multi-touch support

**Exported Functions:**

```
touchscreen_init()
touchscreen_update()
touchscreen_get_point(index: u32): u64
touchscreen_get_count(): u32
```

**Constants:** 1 defined

**Data Structures:** 1 defined

---

### Tpm

**File:** `kernel/src/drivers/tpm.home`

home-os TPM Driver
Trusted Platform Module

**Exported Functions:**

```
tpm_init()
tpm_extend_pcr(pcr: u32, hash: u64): u32
tpm_get_random(buffer: u64, size: u32): u32
tpm_seal_data(data: u64, size: u32, sealed: u64): u32
tpm_unseal_data(sealed: u64, size: u32, data: u64): u32
```

**Constants:** 4 defined

---

### Uhci

**File:** `kernel/src/drivers/uhci.home`

home-os UHCI Driver
Universal Host Controller Interface (USB 1.1)
============================================================================

**Exported Functions:**

```
uhci_init()
uhci_control_transfer(address: u8, request_type: u8, request: u8, value: u16, index: u16, data: u64, length: u16): u32
uhci_bulk_transfer(address: u8, endpoint: u8, data: u64, length: u32, direction: u8): u32
uhci_is_initialized(): u32
```

**Constants:** 42 defined

**Data Structures:** 3 defined

---

### Usb

**File:** `kernel/src/drivers/usb.home`

home-os USB Driver (UHCI/EHCI/XHCI)
Basic USB support
USB device descriptor

**Exported Functions:**

```
usb_init()
usb_enumerate(): u32
usb_get_device(index: u32): u64
usb_send_control(device: u8, request: u8, value: u16, index: u16, data: u64, length: u16): u32
usb_bulk_transfer(device: u8, endpoint: u8, data: u64, length: u32): u32
```

**Data Structures:** 1 defined

---

### Usb Hub

**File:** `kernel/src/drivers/usb_hub.home`

home-os USB Hub
USB hub support

**Exported Functions:**

```
usb_hub_init()
usb_hub_register(device: u64, ports: u32): u32
usb_hub_port_reset(hub_id: u32, port: u32)
usb_hub_enumerate_ports(hub_id: u32)
```

**Constants:** 1 defined

**Data Structures:** 1 defined

---

### Usb Xhci

**File:** `kernel/src/drivers/usb_xhci.home`

home-os xHCI (USB 3.0) Host Controller Driver
Supports both Pi 5 (via RP1) and Pi 4 (VL805)
Implements USB 3.0 xHCI specification

**Exported Functions:**

```
xhci_init(base_addr: u64): u32
xhci_start(): u32
xhci_stop()
xhci_handle_port_change(port_num: u32)
xhci_print_info()
xhci_print_stats()
```

**Constants:** 44 defined

**Data Structures:** 4 defined

---

### Vga Graphics

**File:** `kernel/src/drivers/vga_graphics.home`

home-os VGA Graphics Mode Driver
320x200 256-color mode

**Exported Functions:**

```
vga_graphics_init()
vga_put_pixel(x: u32, y: u32, color: u8)
vga_fill_screen(color: u8)
vga_draw_rect(x: u32, y: u32, width: u32, height: u32, color: u8)
vga_draw_line(x1: u32, y1: u32, x2: u32, y2: u32, color: u8)
vga_set_palette(index: u8, r: u8, g: u8, b: u8)
```

**Constants:** 3 defined

---

### Virtio

**File:** `kernel/src/drivers/virtio.home`

home-os Kernel - Virtio Drivers
Paravirtualized I/O drivers for running as a VM guest
Virtio device types

**Exported Functions:**

```
virtio_init()
virtio_net_init(dev_id: u32): u32
virtio_blk_init(dev_id: u32): u32
virtio_gpu_init(dev_id: u32): u32
virtio_get_device_count(): u32
virtio_get_device_type(dev_id: u32): u32
```

**Constants:** 16 defined

**Data Structures:** 5 defined

---

### Virtio Net

**File:** `kernel/src/drivers/virtio_net.home`

home-os VirtIO Network Driver
Virtualization-optimized networking

**Exported Functions:**

```
virtio_net_init()
virtio_net_send(data: u64, length: u32): u32
virtio_net_receive(buffer: u64, max_length: u32): u32
```

**Constants:** 3 defined

**Data Structures:** 1 defined

---

### Watchdog

**File:** `kernel/src/drivers/watchdog.home`

home-os Watchdog Timer Driver
Hardware watchdog support with multiple backends
============================================================================

**Exported Functions:**

```
watchdog_trigger_reset()
watchdog_init()
watchdog_init_tco(base: u16): u32
watchdog_enable()
watchdog_disable()
watchdog_kick()
watchdog_set_timeout(seconds: u32): u32
watchdog_get_timeout(): u32
watchdog_get_remaining(): u32
watchdog_is_enabled(): u32
watchdog_get_type(): u32
watchdog_set_pre_reset_callback(callback: fn())
watchdog_tick()
watchdog_caused_reboot(): u32
watchdog_clear_status()
watchdog_emergency_stop()
```

**Constants:** 22 defined

---

### Wifi

**File:** `kernel/src/drivers/wifi.home`

home-os WiFi Driver
IEEE 802.11 wireless network support with WPA2/WPA3
WiFi operating modes

**Exported Functions:**

```
wifi_init()
wifi_scan(): u32
wifi_connect(ssid: [*]u8, password: [*]u8): u32
wifi_disconnect()
wifi_is_connected(): u32
wifi_get_rssi(): i8
wifi_set_mode(mode: u32)
wifi_get_network_count(): u32
wifi_get_network(index: u32, ssid: [*]u8, signal: *i8, security: *u32): u32
wifi_get_mac(mac: [*]u8)
wifi_set_tx_power(power_dbm: u8)
wifi_set_power_save(enable: u32)
wifi_get_stats(tx_packets: *u64, rx_packets: *u64, tx_bytes: *u64, rx_bytes: *u64)
wifi_interrupt_handler()
wifi_transmit(data: [*]u8, length: u32): u32
```

**Constants:** 49 defined

**Data Structures:** 7 defined

---

### Xhci

**File:** `kernel/src/drivers/xhci.home`

home-os XHCI Driver
eXtensible Host Controller Interface (USB 3.0+)
============================================================================

**Exported Functions:**

```
xhci_init()
xhci_control_transfer(slot_id: u8, request_type: u8, request: u8, value: u16, index: u16, data: u64, length: u16): u32
xhci_bulk_transfer(slot_id: u8, endpoint: u8, data: u64, length: u32, direction: u8): u32
xhci_is_initialized(): u32
```

**Constants:** 39 defined

**Data Structures:** 7 defined

---

