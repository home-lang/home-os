# home-os Installation Guide

Version 1.0 | December 2025

---

## Table of Contents

1. [Overview](#overview)
2. [System Requirements](#system-requirements)
3. [Preparing Installation Media](#preparing-installation-media)
4. [Boot Configuration](#boot-configuration)
5. [Installation Process](#installation-process)
6. [Post-Installation](#post-installation)
7. [Dual Boot Setup](#dual-boot-setup)
8. [Virtual Machine Installation](#virtual-machine-installation)
9. [Raspberry Pi Installation](#raspberry-pi-installation)
10. [Server Installation](#server-installation)
11. [Troubleshooting](#troubleshooting)

---

## Overview

This guide covers installing home-os on various hardware configurations. home-os supports three main architectures:

- **x86_64**: Standard desktop and server computers
- **ARM64**: Raspberry Pi 4/5, Apple Silicon, and ARM servers
- **RISC-V**: Experimental support for RISC-V boards

### Installation Methods

1. **Graphical Installer**: Recommended for desktop installations
2. **Text-based Installer**: For servers or systems without graphics
3. **Automated Installation**: For bulk deployments using preseed files

---

## System Requirements

### Minimum Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 1 GHz 64-bit | 2 GHz dual-core 64-bit |
| RAM | 512 MB | 2 GB |
| Storage | 2 GB | 20 GB SSD |
| Display | VGA | 1280x720 |
| Network | Optional | Ethernet or Wi-Fi |

### Supported Hardware

**CPU:**
- Intel Core (2nd gen or newer)
- AMD Ryzen/EPYC
- Apple M1/M2/M3
- Raspberry Pi 4/5 (Cortex-A76)
- RISC-V (SiFive, StarFive)

**Graphics:**
- Intel integrated (HD 4000+)
- AMD Radeon (GCN 1.0+)
- NVIDIA (with nouveau or proprietary driver)
- ARM Mali
- Software rendering fallback

**Storage:**
- SATA SSD/HDD
- NVMe SSD
- USB drives
- SD cards (for embedded)

---

## Preparing Installation Media

### Download

Download the appropriate ISO image from https://home-os.org/download:

- `home-os-x86_64.iso` - Standard PC/Mac
- `home-os-arm64.iso` - ARM64 systems
- `home-os-rpi.img.xz` - Raspberry Pi (pre-built image)

**Verify download:**
```bash
sha256sum home-os-x86_64.iso
# Compare with checksum on download page
```

### Create USB Installation Media

**Linux/macOS:**
```bash
# Find your USB drive
lsblk  # Linux
diskutil list  # macOS

# Write image (replace /dev/sdX with your drive)
sudo dd if=home-os-x86_64.iso of=/dev/sdX bs=4M status=progress
sync
```

**Windows:**

Use [Rufus](https://rufus.ie) or [balenaEtcher](https://etcher.io):
1. Insert USB drive (8GB minimum)
2. Select the home-os ISO
3. Select your USB drive
4. Click Write/Flash

### Create DVD Installation Media

```bash
# Linux
cdrecord -v dev=/dev/sr0 home-os-x86_64.iso

# macOS
hdiutil burn home-os-x86_64.iso
```

---

## Boot Configuration

### UEFI Systems (Recommended)

1. Enter UEFI setup (usually F2, Del, or Esc during boot)
2. Navigate to Boot settings
3. Enable UEFI boot mode
4. Disable Secure Boot (or enroll home-os keys)
5. Set USB/DVD as first boot device
6. Save and exit

### Legacy BIOS Systems

1. Enter BIOS setup
2. Set boot order to USB/DVD first
3. Disable Fast Boot if present
4. Save and exit

### Secure Boot

home-os supports Secure Boot when properly configured:

1. Disable Secure Boot for installation
2. After installation, enroll home-os keys:
   ```
   sudo secureboot-enroll
   ```
3. Re-enable Secure Boot in UEFI

---

## Installation Process

### Starting the Installer

1. Boot from installation media
2. Select "Install home-os" from boot menu
3. Wait for installer to load

### Step 1: Language and Keyboard

1. Select your preferred language
2. Choose keyboard layout
3. Test keyboard in the text field
4. Click Continue

### Step 2: Installation Type

Choose one:

- **Standard Installation**: Full desktop with common applications
- **Minimal Installation**: Core system only
- **Server Installation**: No GUI, server packages

Options:
- [ ] Download updates during installation
- [ ] Install third-party drivers

### Step 3: Disk Setup

**Automatic (Recommended):**
1. Select target disk
2. Choose partitioning scheme:
   - Use entire disk (erases all data)
   - Install alongside existing OS (dual boot)
3. Review partition plan
4. Click Install Now

**Manual Partitioning:**
1. Select "Manual partitioning"
2. Create partition table (GPT recommended)
3. Create partitions:

| Mount Point | Type | Size | Notes |
|-------------|------|------|-------|
| /boot/efi | FAT32 | 512 MB | EFI System Partition |
| /boot | ext4 | 1 GB | Boot files |
| swap | swap | RAM size | Up to 8 GB |
| / | HomeFS | 20+ GB | Root filesystem |
| /home | HomeFS | Remaining | User data (optional) |

4. Select bootloader location
5. Click Install Now

**Encryption:**
1. Check "Encrypt installation"
2. Enter encryption password
3. Confirm password
4. Remember: password required every boot

### Step 4: Timezone

1. Click on map or search for city
2. Verify timezone is correct
3. Click Continue

### Step 5: User Account

1. Enter your full name
2. Choose username (lowercase, no spaces)
3. Set computer name (hostname)
4. Create password (8+ characters)
5. Choose login options:
   - Require password to log in
   - Auto-login
6. Click Continue

### Step 6: Installation

The installer will now:
1. Create partitions
2. Format filesystems
3. Install base system
4. Install selected packages
5. Configure bootloader
6. Set up user account

This typically takes 10-30 minutes depending on hardware.

### Step 7: Complete

1. Remove installation media when prompted
2. Click "Restart Now"
3. System will boot into home-os

---

## Post-Installation

### First Boot Setup

1. Log in with your username and password
2. Complete the welcome wizard
3. Connect to network if not done
4. Check for updates:
   ```
   sudo pkg update && sudo pkg upgrade
   ```

### Install Additional Software

**Package manager:**
```bash
pkg search application-name
sudo pkg install application-name
```

**Common packages:**
```bash
# Development tools
sudo pkg install build-essential git

# Media playback
sudo pkg install multimedia-codecs

# Office suite
sudo pkg install home-office
```

### Hardware Drivers

Most drivers are included. For proprietary drivers:

**NVIDIA:**
```bash
sudo pkg install nvidia-driver
sudo reboot
```

**Wireless adapters:**
```bash
sudo pkg install linux-firmware-nonfree
```

### Configure Firewall

The firewall is enabled by default. Verify:
```bash
sudo firewall status
```

Allow specific ports:
```bash
sudo firewall allow 22/tcp  # SSH
sudo firewall allow 80/tcp  # HTTP
```

---

## Dual Boot Setup

### Windows + home-os

1. **From Windows:**
   - Open Disk Management
   - Shrink Windows partition (40GB+ recommended)
   - Leave space unallocated

2. **Install home-os:**
   - Boot from installation media
   - Select "Install alongside Windows"
   - Installer will use unallocated space
   - Complete installation normally

3. **Boot Menu:**
   - GRUB will show both OS options
   - Select with arrow keys

### macOS + home-os

1. **Resize APFS:**
   - Open Disk Utility
   - Select internal drive
   - Click Partition
   - Add partition, format as FAT32 (placeholder)

2. **Install home-os:**
   - Boot from USB (hold Option key)
   - Select home-os installer
   - Install to created partition

3. **Boot Selection:**
   - Hold Option at boot
   - Select desired OS

---

## Virtual Machine Installation

### VirtualBox

1. Create new VM:
   - Type: Linux
   - Version: Other Linux (64-bit)
   - RAM: 2048 MB minimum
   - Create VDI disk: 20 GB

2. Configure VM:
   - System > Enable EFI
   - Display > 64 MB video memory
   - Storage > Attach home-os ISO

3. Install normally

### VMware

1. Create new VM:
   - Other Linux 5.x 64-bit
   - 2 GB RAM, 20 GB disk

2. Edit VM settings:
   - Enable UEFI boot
   - Mount ISO

3. Install normally

### QEMU/KVM

```bash
# Create disk
qemu-img create -f qcow2 home-os.qcow2 20G

# Install
qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -smp 2 \
  -bios /usr/share/ovmf/OVMF.fd \
  -hda home-os.qcow2 \
  -cdrom home-os-x86_64.iso \
  -boot d

# After installation, boot without ISO
qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -smp 2 \
  -bios /usr/share/ovmf/OVMF.fd \
  -hda home-os.qcow2
```

---

## Raspberry Pi Installation

### Supported Models

- Raspberry Pi 4 (2GB+)
- Raspberry Pi 5
- Raspberry Pi 400
- Compute Module 4

### Direct Image Write

1. Download `home-os-rpi.img.xz`
2. Extract and write to SD card:
   ```bash
   xz -d home-os-rpi.img.xz
   sudo dd if=home-os-rpi.img of=/dev/sdX bs=4M status=progress
   ```

3. Insert SD card and power on

### First Boot

1. System will resize partition automatically
2. Create user account when prompted
3. Configure Wi-Fi if needed
4. Update system:
   ```
   sudo pkg upgrade
   ```

### Boot from USB/SSD

1. Update Pi firmware:
   ```
   sudo rpi-eeprom-update -a
   ```

2. Set boot order in raspi-config

3. Write image to USB/SSD instead of SD card

See [RASPBERRY_PI_5.md](RASPBERRY_PI_5.md) for detailed Pi-specific information.

---

## Server Installation

### Text-Based Installation

1. Boot from installation media
2. Select "Install home-os (Text Mode)"
3. Follow prompts to configure:
   - Network (DHCP or static)
   - Disk partitioning
   - Timezone
   - User account
   - Package selection: Server

### Automated Installation

Create a preseed file `preseed.cfg`:

```
# Locale
locale=en_US.UTF-8
keyboard=us
timezone=UTC

# Network
network=dhcp
hostname=server01

# Disk
disk=/dev/sda
partition=auto
encrypt=no

# User
username=admin
password_hash=$6$...

# Packages
packages=server,ssh

# Bootloader
bootloader=/dev/sda
```

Boot with preseed:
```
home-os preseed=http://server/preseed.cfg
```

### Headless Installation via SSH

1. Boot installation media
2. At boot menu, press Tab
3. Add: `inst.sshd`
4. Find IP: Check DHCP server or router
5. Connect: `ssh installer@ip-address`
6. Complete installation remotely

---

## Troubleshooting

### Boot Issues

**"No bootable device found":**
- Check boot order in UEFI/BIOS
- Verify installation media is properly written
- Try different USB port

**Black screen after boot:**
- Add `nomodeset` to boot parameters
- Try safe graphics mode

**Stuck at boot logo:**
- Check for disk errors
- Boot in recovery mode

### Installation Issues

**"Cannot create partition table":**
- Disk may be in use
- Try secure erase first
- Check for disk errors

**"Installation failed":**
- Check system requirements
- Verify ISO checksum
- Try different installation media

**Slow installation:**
- USB 2.0 ports are slower
- Use USB 3.0 if available
- Disable download updates option

### Post-Installation Issues

**No network:**
```bash
ip link  # Check interfaces
sudo dhclient eth0  # Request DHCP
```

**No display after updates:**
```bash
# Boot to recovery mode
sudo pkg remove nvidia-driver
sudo pkg install nvidia-driver
```

**Cannot log in:**
- Boot recovery mode
- Reset password:
  ```
  passwd username
  ```

### Getting Help

- Check logs: `journalctl -xb`
- Boot messages: `dmesg | less`
- Community forum: https://forum.home-os.org
- IRC: #home-os on Libera.Chat
- Bug tracker: https://github.com/home-os/home-os/issues

---

*Copyright 2025 home-os Project. Licensed under CC BY-SA 4.0.*
