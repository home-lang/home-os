# home-os Frequently Asked Questions

Version 1.0 | December 2025

---

## Table of Contents

1. [General Questions](#general-questions)
2. [Installation](#installation)
3. [Hardware Support](#hardware-support)
4. [Software & Applications](#software--applications)
5. [Security & Privacy](#security--privacy)
6. [Development](#development)
7. [Troubleshooting](#troubleshooting)
8. [Community & Support](#community--support)

---

## General Questions

### What is home-os?

home-os is a modern operating system built from scratch using the Home programming language. It features a microkernel architecture with capability-based security, designed for desktops, servers, and embedded devices.

### Why another operating system?

home-os was created to:
- Demonstrate the capabilities of the Home programming language
- Explore modern OS design principles
- Provide a secure, efficient, and user-friendly alternative
- Serve as an educational resource for OS development

### What makes home-os different from Linux/Windows/macOS?

- **Home Language**: Built with a new systems programming language
- **Microkernel**: Minimal kernel with services in userspace for better security
- **Capability Security**: Fine-grained access control for all resources
- **Modern Design**: No legacy compatibility baggage
- **Integrated**: Designed as a cohesive system, not assembled from parts

### Is home-os free?

Yes, home-os is free and open source software released under the MIT license. You can use, modify, and distribute it freely.

### What architectures are supported?

- **x86_64**: Full support for Intel/AMD processors
- **ARM64**: Full support for Raspberry Pi 4/5, Apple Silicon, ARM servers
- **RISC-V**: Experimental support

### Can I use home-os as my daily driver?

home-os is functional for daily use but is still maturing. Consider your needs:
- General computing, web browsing, document editing: Ready
- Specialized professional software: May require alternatives
- Gaming: Limited support (native games and some emulation)

---

## Installation

### What are the minimum system requirements?

- CPU: 1 GHz 64-bit processor
- RAM: 512 MB
- Storage: 2 GB
- Display: VGA compatible

Recommended: 2 GHz dual-core, 2 GB RAM, 20 GB SSD

### Can I dual-boot with Windows/Linux/macOS?

Yes, home-os supports dual-booting:
- **Windows**: Shrink Windows partition, install home-os alongside
- **Linux**: Similar process, GRUB handles both
- **macOS**: Possible on Intel Macs, not supported on Apple Silicon

### Does home-os support UEFI Secure Boot?

Yes. During installation, Secure Boot must be disabled. After installation, you can enroll home-os keys and re-enable Secure Boot:
```bash
sudo secureboot-enroll
```

### Can I install home-os on a Raspberry Pi?

Yes, home-os fully supports:
- Raspberry Pi 4 (2GB+)
- Raspberry Pi 5
- Raspberry Pi 400
- Compute Module 4

Download the pre-built image and flash it to an SD card or USB drive.

### How long does installation take?

Typical installation times:
- SSD: 10-15 minutes
- HDD: 20-30 minutes
- SD card (Pi): 15-25 minutes

### Can I install without a GUI?

Yes, select "Server Installation" or use the text-based installer for headless systems.

---

## Hardware Support

### What graphics cards are supported?

- **Intel**: Full support (HD 4000 and newer)
- **AMD**: Full support (GCN 1.0 and newer)
- **NVIDIA**: Supported via nouveau (open source) or proprietary driver
- **ARM Mali**: Supported on ARM platforms

### Is my Wi-Fi card supported?

Most common Wi-Fi chipsets are supported:
- Intel Wireless
- Qualcomm Atheros
- Broadcom (with firmware)
- Realtek

Check compatibility: `lspci | grep -i wireless` or `lsusb | grep -i wireless`

### Does home-os support Bluetooth?

Yes, Bluetooth is fully supported including:
- Audio devices (headphones, speakers)
- Input devices (keyboards, mice)
- File transfer

### What about touchscreens and tablets?

Touchscreen support is included for:
- Multi-touch gestures
- Palm rejection
- Stylus/pen input (where hardware supports it)

### Are USB 3.0/Thunderbolt supported?

Yes, USB 3.0/3.1/3.2 and Thunderbolt 3/4 are fully supported.

### Can I use multiple monitors?

Yes, multi-monitor support is built-in:
- Different resolutions per monitor
- Configurable layouts (extend, mirror, single)
- Individual display settings

---

## Software & Applications

### What applications are included?

home-os includes:
- File Manager
- Terminal
- Text Editor (with syntax highlighting)
- Web Browser
- Calculator
- System Monitor
- Settings
- Media Player (with codec support)

### Can I run Linux applications?

home-os does not run Linux applications directly. However:
- Many applications have been ported natively
- A compatibility layer is in development

### Can I run Windows applications?

Native Windows applications are not supported. Alternatives:
- Use native home-os applications
- Run Windows in a virtual machine

### What package manager does home-os use?

home-os uses `pkg`, a fast and simple package manager:
```bash
pkg search name      # Search packages
pkg install name     # Install package
pkg remove name      # Remove package
pkg update           # Update database
pkg upgrade          # Upgrade packages
```

### How many packages are available?

The home-os repository contains 5,000+ packages including:
- Development tools
- Desktop applications
- Server software
- Libraries and frameworks

### Can I install packages from other sources?

Yes, you can:
- Add third-party repositories
- Build from source
- Install from local packages

### Is there an app store?

Yes, the Software Center provides a graphical interface for discovering and installing applications.

---

## Security & Privacy

### How secure is home-os?

home-os was designed with security as a primary goal:
- **Capability-based security**: Applications get only the permissions they need
- **Sandboxing**: Applications run isolated from each other
- **Memory safety**: Home language prevents common vulnerabilities
- **Secure boot**: Verified boot chain

### Does home-os collect telemetry?

No. home-os does not collect any user data or telemetry by default. Optional crash reporting can be enabled if you wish to help improve the system.

### How do I encrypt my disk?

During installation, select "Encrypt installation" and set a password. For existing systems:
```bash
sudo homefs-encrypt /dev/sda2
```

### Is the firewall enabled by default?

Yes, the firewall is enabled with sensible defaults:
- Incoming connections blocked (except SSH if enabled)
- Outgoing connections allowed
- Configurable via GUI or command line

### How do I report a security vulnerability?

Please report security vulnerabilities responsibly:
- Email: security@home-os.org
- Do not post publicly until patched
- We aim to respond within 48 hours

### Are security updates automatic?

By default, security updates are downloaded automatically and you're prompted to install them. Full automatic updates can be enabled in Settings > System > Updates.

---

## Development

### What programming languages can I use?

home-os supports development in:
- **Home**: Native systems language
- **C/C++**: Full toolchain included
- **Rust**: Available via package manager
- **Python**: Included by default
- **Go**: Available via package manager
- **JavaScript/Node.js**: Available via package manager

### Is there an SDK for developing applications?

Yes, the home-os SDK includes:
- UI framework
- System APIs
- Build tools
- Documentation
- Example applications

Install with: `pkg install home-sdk`

### Can I contribute to home-os?

Absolutely! Contributions are welcome:
- Code: https://github.com/home-os/home-os
- Documentation: https://github.com/home-os/docs
- Translations: https://translate.home-os.org
- Bug reports: https://github.com/home-os/home-os/issues

### How do I build home-os from source?

```bash
git clone https://github.com/home-os/home-os
cd home-os
./configure
make
sudo make install
```

Full build documentation: https://home-os.org/docs/building

### What IDE support is available?

- **VS Code**: Extension with syntax highlighting and debugging
- **Home IDE**: Native IDE for home-os development
- **Vim/Neovim**: Syntax files available
- **Emacs**: Major mode available

---

## Troubleshooting

### My system won't boot after an update

1. At the boot menu, select "Advanced options"
2. Choose a previous kernel version
3. Boot and rollback the update:
   ```bash
   sudo pkg rollback
   ```

### I forgot my password

1. Boot to recovery mode
2. Select "root shell"
3. Reset password: `passwd username`
4. Reboot

### Applications are crashing frequently

1. Check for updates: `sudo pkg upgrade`
2. Reset application settings:
   ```bash
   mv ~/.config/app-name ~/.config/app-name.bak
   ```
3. Check logs: `journalctl -xe`

### The desktop is slow or laggy

1. Check available disk space: `df -h`
2. Check memory: `free -h`
3. Disable desktop effects: Settings > Appearance > Disable effects
4. Check for runaway processes: `top`

### Sound isn't working

1. Check volume is unmuted
2. Verify correct output device in Settings > Sound
3. Restart audio: `systemctl --user restart pulseaudio`

### Wi-Fi isn't connecting

1. Check Wi-Fi is enabled: `nmcli radio wifi`
2. Enable if off: `nmcli radio wifi on`
3. List networks: `nmcli device wifi list`
4. Connect: `nmcli device wifi connect "SSID" password "pass"`

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for comprehensive solutions.

---

## Community & Support

### Where can I get help?

- **Documentation**: https://home-os.org/docs
- **Forums**: https://forum.home-os.org
- **IRC**: #home-os on Libera.Chat
- **Discord**: https://discord.gg/home-os
- **Reddit**: r/homeos

### Is there professional support?

Yes, professional support options are available:
- Email support
- Priority bug fixes
- Training and consulting
- Custom development

Contact: support@home-os.org

### How often are updates released?

- **Security updates**: As needed (immediate for critical)
- **Bug fixes**: Weekly
- **Feature updates**: Monthly
- **Major releases**: Annually

### What is the release schedule?

home-os follows a predictable release schedule:
- LTS releases every 2 years (5-year support)
- Regular releases every 6 months (9-month support)

### How do I report bugs?

1. Check if already reported: https://github.com/home-os/home-os/issues
2. Gather information:
   - System info: `inxi -Fx`
   - Logs: `journalctl -xe`
   - Steps to reproduce
3. File report with template

### Can I request features?

Yes! Feature requests are welcome:
- Forum: Feature Request category
- GitHub: Issue with "enhancement" label
- Voting on existing requests helps prioritize

### Where can I find the roadmap?

The development roadmap is maintained at:
- https://home-os.org/roadmap
- TODO.md in the repository

### How can I stay updated on home-os news?

- Blog: https://home-os.org/blog
- Newsletter: Subscribe on website
- Twitter/X: @homeos
- Mastodon: @homeos@fosstodon.org

---

## More Questions?

If your question wasn't answered here:

1. Search the documentation: https://home-os.org/docs
2. Ask on the forums: https://forum.home-os.org
3. Join IRC/Discord for real-time help
4. File an issue if you think it's a bug

---

*Copyright 2025 home-os Project. Licensed under CC BY-SA 4.0.*
