# home-os User Manual

Version 1.0 | December 2025

---

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Desktop Environment](#desktop-environment)
4. [File Management](#file-management)
5. [Applications](#applications)
6. [System Configuration](#system-configuration)
7. [Networking](#networking)
8. [Security](#security)
9. [Accessibility](#accessibility)
10. [Keyboard Shortcuts](#keyboard-shortcuts)
11. [Command Line](#command-line)
12. [Advanced Topics](#advanced-topics)

---

## Introduction

Welcome to home-os, a modern operating system built from the ground up using the Home programming language. home-os provides a secure, efficient, and user-friendly computing environment suitable for desktop use, server deployments, and embedded systems.

### Key Features

- **Modern Architecture**: Microkernel design with capability-based security
- **Native Applications**: File manager, terminal, text editor, web browser, and more
- **Hardware Support**: Wide range of hardware including x86_64, ARM64, and RISC-V
- **Security First**: Sandboxed applications, secure boot, and encryption support
- **Accessibility**: Built-in screen reader, magnifier, and high contrast themes
- **Internationalization**: Support for multiple languages and locales

### System Requirements

**Minimum:**
- CPU: 1 GHz 64-bit processor
- RAM: 512 MB
- Storage: 2 GB
- Display: VGA compatible

**Recommended:**
- CPU: 2 GHz dual-core 64-bit processor
- RAM: 2 GB or more
- Storage: 20 GB SSD
- Display: 1280x720 or higher

---

## Getting Started

### First Boot

When you first boot home-os, you'll be greeted by the login screen. Enter your username and password created during installation.

### Desktop Overview

The home-os desktop consists of:

- **Panel**: Located at the top, contains application launcher, system tray, and clock
- **Desktop**: Main workspace for windows and icons
- **Dock** (optional): Quick access to frequently used applications

### User Account

Your user home directory is located at `/home/username/`. This is where your personal files, documents, and application settings are stored.

Standard directories in your home:
- `Documents/` - Personal documents
- `Downloads/` - Downloaded files
- `Pictures/` - Images and photos
- `Music/` - Audio files
- `Videos/` - Video files
- `Desktop/` - Files shown on desktop

---

## Desktop Environment

### Window Management

**Moving Windows:**
- Click and drag the title bar

**Resizing Windows:**
- Drag window edges or corners

**Window Controls:**
- Minimize: Click the minimize button or press `Super+H`
- Maximize: Click the maximize button or press `Super+Up`
- Close: Click the X button or press `Alt+F4`

**Window Snapping:**
- Drag to screen edge to snap to half screen
- `Super+Left`: Snap to left half
- `Super+Right`: Snap to right half

### Workspaces

home-os supports multiple virtual workspaces to organize your windows.

- `Super+1-9`: Switch to workspace 1-9
- `Super+Shift+1-9`: Move current window to workspace 1-9
- `Super+Tab`: Workspace overview

### Themes

Customize your desktop appearance in Settings > Appearance:

- Light theme
- Dark theme
- Custom accent colors
- Icon themes
- Cursor themes

---

## File Management

### File Manager

The File Manager provides a graphical interface for managing your files.

**Navigation:**
- Click folders to open them
- Use the address bar to type paths directly
- Back/Forward buttons for navigation history
- Up button to go to parent directory

**File Operations:**
- Copy: `Ctrl+C`
- Cut: `Ctrl+X`
- Paste: `Ctrl+V`
- Delete: `Delete` (moves to Trash)
- Permanent Delete: `Shift+Delete`
- Rename: `F2`
- New Folder: `Ctrl+Shift+N`

**Views:**
- Icon view: Large icons with names
- List view: Detailed file information
- Column view: Hierarchical browsing

**Search:**
- Press `Ctrl+F` to search
- Supports wildcards (`*` and `?`)
- Filter by file type, date, or size

### Drives and Devices

Connected storage devices appear in the sidebar. Click to mount and access.

Safely remove devices by right-clicking and selecting "Eject" before physically disconnecting.

---

## Applications

### Terminal

The Terminal provides command-line access to the system.

**Basic Usage:**
- Type commands and press Enter to execute
- `Tab` for auto-completion
- `Ctrl+C` to cancel current command
- `Ctrl+D` to close terminal

**Tabs and Panes:**
- `Ctrl+Shift+T`: New tab
- `Ctrl+Shift+D`: Split pane
- `Ctrl+Page Up/Down`: Switch tabs

### Text Editor

A lightweight editor for text files and code.

**Features:**
- Syntax highlighting for 50+ languages
- Line numbers
- Search and replace (`Ctrl+H`)
- Multiple cursors (`Ctrl+Click`)
- Code folding

### Web Browser

home-os includes a secure web browser.

**Navigation:**
- Address bar for URLs and searches
- Bookmarks bar for saved sites
- Tab support for multiple pages

**Privacy:**
- Built-in ad blocker
- Tracking protection
- Private browsing mode (`Ctrl+Shift+N`)

### Calculator

A versatile calculator supporting:
- Basic arithmetic
- Scientific functions
- Programmer mode (hex, binary, octal)
- Unit conversions

### System Monitor

View system resource usage:
- CPU usage per core
- Memory usage
- Disk I/O
- Network traffic
- Process list with resource consumption

---

## System Configuration

### Settings Application

Access Settings from the application menu or by running `settings` in terminal.

**Categories:**

**Appearance:**
- Theme selection
- Wallpaper
- Fonts
- Icon size

**Display:**
- Resolution
- Refresh rate
- Multi-monitor configuration
- Night light

**Sound:**
- Output device selection
- Input device selection
- Volume levels
- Sound effects

**Network:**
- Wi-Fi configuration
- Ethernet settings
- VPN connections
- Proxy settings

**Users:**
- User account management
- Password change
- Profile picture
- Login options

**Date & Time:**
- Timezone
- Manual or automatic time
- Date format
- Clock display

**Language & Region:**
- System language
- Regional formats
- Keyboard layout
- Input methods

**Privacy:**
- Location services
- Camera access
- Microphone access
- Application permissions

**Power:**
- Sleep settings
- Power button behavior
- Battery settings (laptops)
- Performance mode

---

## Networking

### Wi-Fi

1. Click the network icon in the system tray
2. Select a Wi-Fi network
3. Enter the password
4. Click Connect

**Saved Networks:**
- Right-click a saved network to forget or modify settings

### Wired Network

Wired connections are configured automatically via DHCP by default.

For static configuration:
1. Open Settings > Network
2. Click the gear icon next to your connection
3. Select Manual in IPv4 settings
4. Enter IP address, netmask, gateway, and DNS

### VPN

home-os supports WireGuard VPN connections:

1. Open Settings > Network > VPN
2. Click Add VPN
3. Import configuration file or enter settings manually
4. Click Save

To connect, toggle the VPN switch in network settings or system tray.

### SSH

**Connecting to remote systems:**
```
ssh username@hostname
```

**SSH keys:**
- Generate: `ssh-keygen`
- Keys stored in `~/.ssh/`
- Copy public key to remote: `ssh-copy-id user@host`

---

## Security

### Firewall

home-os includes a built-in firewall enabled by default.

**Command line management:**
```
sudo firewall status
sudo firewall allow 22/tcp
sudo firewall deny 80/tcp
sudo firewall list
```

**GUI:** Settings > Security > Firewall

### Disk Encryption

If you enabled encryption during installation, your disk is encrypted using HomeFS encryption.

**Encryption status:**
```
encryption-status /dev/sda2
```

### Application Sandboxing

Applications run in sandboxes with limited permissions by default. When an application needs additional permissions, you'll be prompted.

**View permissions:**
Settings > Applications > [App Name] > Permissions

### Updates

Keep your system secure with regular updates:

**Check for updates:**
```
sudo update check
```

**Install updates:**
```
sudo update install
```

**Automatic updates:**
Settings > System > Updates > Enable automatic updates

---

## Accessibility

home-os includes comprehensive accessibility features.

### Screen Reader

Enable: Settings > Accessibility > Screen Reader

**Controls:**
- `Super+S`: Toggle screen reader
- `Ctrl`: Stop speaking
- Arrow keys: Navigate
- `Tab`: Next element

### Magnifier

Enable: Settings > Accessibility > Magnifier

**Controls:**
- `Super+Plus`: Zoom in
- `Super+Minus`: Zoom out
- `Super+0`: Reset zoom
- Mouse follows cursor

### High Contrast

Enable: Settings > Accessibility > High Contrast

Themes available:
- High Contrast Light
- High Contrast Dark
- Inverted colors
- Custom contrast settings

### Keyboard Accessibility

Enable: Settings > Accessibility > Keyboard

**Sticky Keys:**
- Press modifier keys sequentially instead of together
- Double-press to lock

**Slow Keys:**
- Requires keys to be held briefly before registering

**Bounce Keys:**
- Ignores rapid repeated key presses

### Mouse Keys

Enable: Settings > Accessibility > Mouse

Control mouse pointer using the numeric keypad.

---

## Keyboard Shortcuts

### System

| Shortcut | Action |
|----------|--------|
| `Super` | Open application launcher |
| `Super+L` | Lock screen |
| `Super+D` | Show desktop |
| `Alt+Tab` | Switch windows |
| `Super+Tab` | Workspace overview |
| `Print` | Screenshot |
| `Ctrl+Alt+Delete` | System menu |

### Window Management

| Shortcut | Action |
|----------|--------|
| `Alt+F4` | Close window |
| `Super+H` | Minimize window |
| `Super+Up` | Maximize window |
| `Super+Down` | Restore/minimize |
| `Super+Left` | Snap left |
| `Super+Right` | Snap right |
| `Alt+F7` | Move window |
| `Alt+F8` | Resize window |

### Applications

| Shortcut | Action |
|----------|--------|
| `Ctrl+Q` | Quit application |
| `Ctrl+W` | Close tab/window |
| `Ctrl+N` | New window |
| `Ctrl+T` | New tab |
| `Ctrl+S` | Save |
| `Ctrl+Z` | Undo |
| `Ctrl+Y` | Redo |
| `Ctrl+A` | Select all |
| `Ctrl+F` | Find |

### Terminal

| Shortcut | Action |
|----------|--------|
| `Ctrl+Shift+C` | Copy |
| `Ctrl+Shift+V` | Paste |
| `Ctrl+Shift+T` | New tab |
| `Ctrl+Shift+W` | Close tab |
| `Ctrl+L` | Clear screen |
| `Ctrl+R` | Search history |

---

## Command Line

### Basic Commands

**File Operations:**
```
ls          # List files
cd dir      # Change directory
pwd         # Print working directory
cp src dst  # Copy file
mv src dst  # Move/rename file
rm file     # Remove file
mkdir dir   # Create directory
```

**System Information:**
```
uname -a    # System information
uptime      # System uptime
free        # Memory usage
df -h       # Disk usage
top         # Process monitor
```

**Package Management:**
```
pkg search name     # Search packages
pkg install name    # Install package
pkg remove name     # Remove package
pkg update          # Update package list
pkg upgrade         # Upgrade packages
```

### Shell Features

home-os uses `hsh` (Home Shell) as the default shell.

**Features:**
- Tab completion
- Command history (`history` command)
- Aliases (`alias ll='ls -la'`)
- Environment variables
- Scripting support

**Configuration:** `~/.hshrc`

---

## Advanced Topics

### System Services

List services:
```
service list
```

Start/stop services:
```
sudo service start sshd
sudo service stop sshd
sudo service restart sshd
```

Enable/disable at boot:
```
sudo service enable sshd
sudo service disable sshd
```

### System Logs

View system logs:
```
journalctl                    # All logs
journalctl -f                 # Follow logs
journalctl -u service-name    # Service logs
journalctl --since today      # Today's logs
```

### Backup and Restore

**Create backup:**
```
backup create --dest /mnt/backup
```

**Restore backup:**
```
backup restore --source /mnt/backup
```

### Performance Tuning

**Power profiles:**
```
power-profile list
power-profile set performance
power-profile set balanced
power-profile set powersave
```

**Process priority:**
```
nice -n 10 command    # Lower priority
renice -n -5 -p PID   # Change priority
```

### Troubleshooting Boot Issues

**Recovery mode:**
- Hold Shift during boot to access boot menu
- Select "Recovery Mode"

**Single user mode:**
- Add `single` to kernel parameters in bootloader

**View boot logs:**
```
journalctl -b    # Current boot
journalctl -b -1 # Previous boot
```

---

## Getting Help

**Man pages:**
```
man command-name
```

**Built-in help:**
```
command --help
```

**Online resources:**
- Official documentation: https://home-os.org/docs
- Community forum: https://forum.home-os.org
- Bug reports: https://github.com/home-os/home-os/issues

---

*Copyright 2025 home-os Project. This documentation is licensed under CC BY-SA 4.0.*
