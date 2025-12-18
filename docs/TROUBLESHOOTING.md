# home-os Troubleshooting Guide

Version 1.0 | December 2025

---

## Table of Contents

1. [Boot Problems](#boot-problems)
2. [Display Issues](#display-issues)
3. [Audio Problems](#audio-problems)
4. [Network Issues](#network-issues)
5. [Storage Problems](#storage-problems)
6. [Performance Issues](#performance-issues)
7. [Application Crashes](#application-crashes)
8. [Authentication Issues](#authentication-issues)
9. [Update Problems](#update-problems)
10. [Hardware Compatibility](#hardware-compatibility)
11. [Recovery Mode](#recovery-mode)
12. [Diagnostic Tools](#diagnostic-tools)

---

## Boot Problems

### System Won't Boot

**Symptoms:** Power on but no boot, black screen, or error messages.

**Solutions:**

1. **Check boot device order:**
   - Enter UEFI/BIOS (F2, Del, or Esc during POST)
   - Ensure correct disk is first in boot order

2. **Verify EFI boot entry:**
   ```bash
   # From live USB
   efibootmgr -v
   ```

3. **Repair bootloader:**
   ```bash
   # Boot from live USB
   sudo mount /dev/sda2 /mnt
   sudo mount /dev/sda1 /mnt/boot/efi
   sudo home-os-chroot /mnt
   bootctl install
   ```

4. **Check for disk errors:**
   ```bash
   sudo fsck /dev/sda2
   ```

### Kernel Panic

**Symptoms:** System halts with panic message.

**Solutions:**

1. **Boot previous kernel:**
   - At boot menu, select "Advanced Options"
   - Choose an older kernel version

2. **Add boot parameters:**
   - Press 'e' at boot menu
   - Add to kernel line: `acpi=off` or `nomodeset`

3. **Check RAM:**
   ```bash
   # From boot menu, select memory test
   memtest86+
   ```

### GRUB/Bootloader Errors

**"error: unknown filesystem":**
```bash
# Boot live USB
sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

**"error: file not found":**
```bash
# Reinstall kernel
sudo pkg install linux
sudo mkinitcpio -P
```

---

## Display Issues

### No Display Output

**Check:**
1. Monitor cable connected properly
2. Correct input source selected
3. Try different display port (HDMI, DP, VGA)

**Solutions:**

1. **Force video output:**
   - Add boot parameter: `video=HDMI-A-1:1920x1080@60`

2. **Disable KMS:**
   - Add boot parameter: `nomodeset`

3. **Install correct driver:**
   ```bash
   # Intel
   sudo pkg install intel-media-driver

   # AMD
   sudo pkg install mesa-vulkan-radeon

   # NVIDIA
   sudo pkg install nvidia-driver
   ```

### Wrong Resolution

**GUI Method:**
Settings > Display > Resolution

**Command Line:**
```bash
# List available modes
xrandr

# Set resolution
xrandr --output HDMI-1 --mode 1920x1080

# Make permanent
echo 'xrandr --output HDMI-1 --mode 1920x1080' >> ~/.config/autostart.sh
```

### Screen Tearing

**Intel:**
```bash
# /etc/X11/xorg.conf.d/20-intel.conf
Section "Device"
  Identifier "Intel"
  Driver "intel"
  Option "TearFree" "true"
EndSection
```

**AMD:**
```bash
# /etc/X11/xorg.conf.d/20-amdgpu.conf
Section "Device"
  Identifier "AMD"
  Driver "amdgpu"
  Option "TearFree" "true"
EndSection
```

### Multi-Monitor Issues

```bash
# Detect monitors
xrandr --auto

# Configure layout
xrandr --output HDMI-1 --right-of eDP-1

# Same content on both
xrandr --output HDMI-1 --same-as eDP-1
```

---

## Audio Problems

### No Sound

**Check:**
1. Volume not muted (in system tray and hardware)
2. Correct output device selected

**Solutions:**

1. **Verify audio devices:**
   ```bash
   aplay -l  # List playback devices
   arecord -l  # List recording devices
   ```

2. **Check if audio is muted:**
   ```bash
   amixer
   # Unmute
   amixer set Master unmute
   ```

3. **Restart audio service:**
   ```bash
   systemctl --user restart pulseaudio
   ```

4. **Check HDMI audio:**
   ```bash
   # List HDMI devices
   aplay -D plughw:0,3 /usr/share/sounds/test.wav
   ```

### Audio Crackling/Popping

**Adjust buffer:**
```bash
# /etc/pulse/daemon.conf
default-fragments = 8
default-fragment-size-msec = 5
```

**Restart PulseAudio:**
```bash
pulseaudio -k && pulseaudio --start
```

### Bluetooth Audio Issues

```bash
# Check Bluetooth service
systemctl status bluetooth

# Restart Bluetooth
sudo systemctl restart bluetooth

# Re-pair device
bluetoothctl
> remove XX:XX:XX:XX:XX:XX
> scan on
> pair XX:XX:XX:XX:XX:XX
> connect XX:XX:XX:XX:XX:XX
```

---

## Network Issues

### No Internet Connection

**Diagnose:**
```bash
# Check interface status
ip link

# Check IP address
ip addr

# Test connectivity
ping -c 3 8.8.8.8  # IP connectivity
ping -c 3 google.com  # DNS resolution
```

**Solutions:**

1. **Bring up interface:**
   ```bash
   sudo ip link set eth0 up
   sudo dhclient eth0
   ```

2. **Restart network:**
   ```bash
   sudo systemctl restart NetworkManager
   ```

3. **Check DNS:**
   ```bash
   cat /etc/resolv.conf
   # Add if empty:
   echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
   ```

### Wi-Fi Not Working

**Check wireless interface:**
```bash
iwconfig
rfkill list  # Check if blocked
```

**Unblock wireless:**
```bash
sudo rfkill unblock wifi
```

**Install firmware:**
```bash
sudo pkg install linux-firmware
```

**Scan and connect:**
```bash
nmcli device wifi list
nmcli device wifi connect "SSID" password "password"
```

### Slow Network

**Test speed:**
```bash
curl -o /dev/null http://speedtest.tele2.net/10MB.zip
```

**Check for issues:**
```bash
# Check for packet loss
ping -c 100 8.8.8.8 | tail -1

# Check MTU
ping -M do -s 1472 8.8.8.8
```

**Adjust MTU:**
```bash
sudo ip link set eth0 mtu 1400
```

### VPN Connection Issues

**WireGuard:**
```bash
# Check status
sudo wg show

# Restart interface
sudo wg-quick down wg0
sudo wg-quick up wg0

# Check logs
journalctl -u wg-quick@wg0
```

---

## Storage Problems

### Disk Full

**Find large files:**
```bash
du -h --max-depth=1 / 2>/dev/null | sort -hr | head -20
```

**Clean package cache:**
```bash
sudo pkg clean
```

**Clean logs:**
```bash
sudo journalctl --vacuum-size=100M
```

**Find and remove old kernels:**
```bash
pkg list installed | grep linux
sudo pkg remove linux-old-version
```

### Disk Not Mounting

**Check disk:**
```bash
lsblk
sudo fdisk -l
```

**Mount manually:**
```bash
sudo mkdir /mnt/disk
sudo mount /dev/sdb1 /mnt/disk
```

**Fix filesystem:**
```bash
sudo fsck -y /dev/sdb1
```

### Filesystem Errors

**Read-only filesystem:**
```bash
# Remount read-write
sudo mount -o remount,rw /

# If that fails, boot recovery and fsck
sudo fsck -y /dev/sda2
```

**Check SMART status:**
```bash
sudo smartctl -H /dev/sda
sudo smartctl -a /dev/sda  # Detailed info
```

### SSD Performance

**Enable TRIM:**
```bash
sudo systemctl enable fstrim.timer
sudo fstrim -v /
```

**Check alignment:**
```bash
sudo parted /dev/sda align-check optimal 1
```

---

## Performance Issues

### High CPU Usage

**Identify process:**
```bash
top -o %CPU
htop
```

**Kill runaway process:**
```bash
kill -9 PID
```

**Check for cryptocurrency miners:**
```bash
ps aux | grep -E 'miner|xmrig'
```

### High Memory Usage

**Check memory:**
```bash
free -h
```

**Identify memory hogs:**
```bash
ps aux --sort=-%mem | head -10
```

**Clear cache:**
```bash
sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
```

### System Freezes

**Check logs after recovery:**
```bash
journalctl -b -1  # Previous boot
dmesg | tail -100
```

**Common causes:**
1. GPU driver issues - try `nomodeset`
2. RAM problems - run memtest86+
3. Overheating - check temperatures

**Check temperature:**
```bash
sensors
```

### Slow Boot

**Analyze boot time:**
```bash
systemd-analyze
systemd-analyze blame
systemd-analyze critical-chain
```

**Disable slow services:**
```bash
sudo systemctl disable slow-service
```

---

## Application Crashes

### General Crash Debugging

**Get crash info:**
```bash
# Check for core dump
coredumpctl list

# View crash details
coredumpctl info

# Get backtrace
coredumpctl gdb
```

**Check application logs:**
```bash
journalctl -xe
~/.local/share/app-name/logs/
```

### Desktop Environment Crashes

**Reset desktop settings:**
```bash
mv ~/.config/home-desktop ~/.config/home-desktop.bak
```

**Start in safe mode:**
```bash
home-desktop --safe-mode
```

### Browser Crashes

**Clear cache:**
```bash
rm -rf ~/.cache/home-browser
```

**Reset profile:**
```bash
mv ~/.config/home-browser ~/.config/home-browser.bak
```

**Disable hardware acceleration:**
Settings > Advanced > Disable hardware acceleration

---

## Authentication Issues

### Forgot Password

**Reset user password:**
1. Boot to recovery mode
2. Select root shell
3. Run: `passwd username`
4. Enter new password
5. Reboot

### Account Locked

**Unlock account:**
```bash
sudo faillock --user username --reset
```

**Check lockout status:**
```bash
faillock --user username
```

### SSH Key Issues

**Fix permissions:**
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chmod 644 ~/.ssh/authorized_keys
```

**Debug SSH:**
```bash
ssh -vvv user@host
```

### Sudo Not Working

**Fix sudoers:**
1. Boot recovery mode
2. Mount filesystem read-write
3. Edit `/etc/sudoers`:
   ```
   username ALL=(ALL) ALL
   ```
4. Or add to wheel group:
   ```bash
   usermod -aG wheel username
   ```

---

## Update Problems

### Update Failed

**Check for lock:**
```bash
sudo rm /var/lib/pkg/db.lck
```

**Fix broken packages:**
```bash
sudo pkg fix
sudo pkg update --refresh
```

**Force reinstall:**
```bash
sudo pkg install --reinstall package-name
```

### Dependency Issues

**Check dependencies:**
```bash
pkg check package-name
```

**Resolve conflicts:**
```bash
sudo pkg remove conflicting-package
sudo pkg install desired-package
```

### Kernel Update Issues

**Rebuild initramfs:**
```bash
sudo mkinitcpio -P
```

**Boot old kernel:**
- Select from GRUB menu
- Or edit `/etc/default/grub`:
  ```
  GRUB_DEFAULT=saved
  ```

---

## Hardware Compatibility

### USB Device Not Recognized

**Check connection:**
```bash
lsusb
dmesg | tail -20
```

**Load driver:**
```bash
sudo modprobe module-name
```

### Touchpad Not Working

**Check input devices:**
```bash
xinput list
```

**Install driver:**
```bash
sudo pkg install libinput
```

**Enable touchpad:**
```bash
xinput enable "TouchPad Name"
```

### Webcam Not Working

**Check device:**
```bash
ls /dev/video*
v4l2-ctl --list-devices
```

**Test webcam:**
```bash
mpv av://v4l2:/dev/video0
```

### Printer Issues

**Install CUPS:**
```bash
sudo pkg install cups
sudo systemctl enable cups
sudo systemctl start cups
```

**Add printer:**
1. Open http://localhost:631
2. Administration > Add Printer
3. Select device and driver

---

## Recovery Mode

### Accessing Recovery

1. Hold Shift during boot (BIOS) or press Escape (UEFI)
2. Select "Advanced options"
3. Choose "Recovery mode"

### Recovery Options

- **Resume**: Continue to normal boot
- **Clean**: Try to clean up disk space
- **dpkg**: Repair broken packages
- **fsck**: Check filesystems
- **network**: Enable networking
- **root**: Drop to root shell
- **grub**: Update GRUB bootloader

### Using Live USB for Recovery

1. Boot from installation media
2. Select "Rescue mode" or open terminal
3. Mount system:
   ```bash
   sudo mount /dev/sda2 /mnt
   sudo mount /dev/sda1 /mnt/boot/efi
   sudo mount --bind /dev /mnt/dev
   sudo mount --bind /proc /mnt/proc
   sudo mount --bind /sys /mnt/sys
   ```
4. Chroot:
   ```bash
   sudo chroot /mnt
   ```
5. Fix issues, then exit and reboot

---

## Diagnostic Tools

### System Information

```bash
# Hardware summary
inxi -Fx

# CPU info
lscpu

# Memory info
free -h
cat /proc/meminfo

# Disk info
lsblk -f
df -h

# PCI devices
lspci

# USB devices
lsusb
```

### Log Analysis

```bash
# System journal
journalctl -xe

# Kernel messages
dmesg | less

# Boot messages
journalctl -b

# Service logs
journalctl -u service-name

# Follow logs
journalctl -f
```

### Network Diagnostics

```bash
# Interface status
ip addr
ip link

# Routing table
ip route

# DNS resolution
nslookup domain.com
dig domain.com

# Connection test
ping -c 5 target
traceroute target
mtr target

# Port check
ss -tuln
netstat -tuln
```

### Performance Analysis

```bash
# CPU usage
top
htop

# Memory analysis
vmstat 1
free -h

# Disk I/O
iotop
iostat -x 1

# Process tree
pstree

# System calls
strace -p PID
```

### Hardware Testing

```bash
# Memory test
memtest86+  # From boot menu

# Disk test
badblocks -v /dev/sda
smartctl -t short /dev/sda

# CPU stress test
stress --cpu 4 --timeout 60

# GPU test
glxinfo | grep "direct rendering"
glmark2
```

---

## Getting Further Help

If these solutions don't resolve your issue:

1. **Search documentation:**
   - https://home-os.org/docs

2. **Community forums:**
   - https://forum.home-os.org

3. **IRC Chat:**
   - #home-os on Libera.Chat

4. **File bug report:**
   - https://github.com/home-os/home-os/issues
   - Include: system info (`inxi -Fx`), logs, steps to reproduce

5. **Professional support:**
   - https://home-os.org/support

---

*Copyright 2025 home-os Project. Licensed under CC BY-SA 4.0.*
