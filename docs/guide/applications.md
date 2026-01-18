# Built-in Applications

HomeOS includes a suite of built-in applications for everyday computing tasks.

## Application Overview

| Application | Description | Status |
|------------|-------------|--------|
| Terminal | VT100/ANSI terminal emulator | Complete |
| Shell (hsh) | Command-line shell | Complete |
| File Manager | Graphical file browser | Complete |
| Text Editor | Code editor with syntax highlighting | Complete |
| System Monitor | Resource monitoring | Complete |
| Calculator | Scientific calculator | Complete |
| Browser | Web browser | In Development |
| Media Player | Audio/video playback | In Development |

## Terminal

A modern, feature-rich terminal emulator inspired by Ghostty.

### Features

- **VT100/ANSI Support** - Full escape sequence handling
- **ANSI Colors** - 16 colors plus bright variants
- **Text Formatting** - Bold, italic, underline
- **Scrollback Buffer** - 10,000 line history with search
- **Tab Support** - Up to 10 tabs
- **Clipboard** - Copy/paste with mouse selection
- **Hardware Acceleration** - 60 FPS rendering

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Ctrl+Shift+T | New tab |
| Ctrl+Shift+W | Close tab |
| Ctrl+Tab | Next tab |
| Ctrl+Shift+Tab | Previous tab |
| Ctrl+C | Copy selection |
| Ctrl+V | Paste |
| Shift+PageUp | Scroll up |
| Shift+PageDown | Scroll down |
| Ctrl+L | Clear screen |
| Ctrl+Shift+F | Search scrollback |

### Performance

- **Startup:** < 50ms
- **Rendering:** 60 FPS
- **Memory:** ~2MB per tab
- **Scrollback:** 10,000 lines (~800KB)

### Compatibility

Works with standard terminal applications:
- bash, zsh, fish
- vim, nano, emacs
- htop, top
- git, npm, cargo
- tmux, screen

**Location:** `apps/terminal/`

## Shell (hsh)

The Home Shell provides command-line access to the system.

### Features

- **Tab Completion** - Commands, paths, arguments
- **Command History** - Persistent across sessions
- **Aliases** - User-defined shortcuts
- **Environment Variables** - Full support
- **Job Control** - Background processes
- **Scripting** - Shell script support
- **Pipelines** - Command chaining with `|`
- **Redirections** - Input/output redirection

### Built-in Commands

| Command | Description |
|---------|-------------|
| `cd` | Change directory |
| `pwd` | Print working directory |
| `echo` | Print text |
| `export` | Set environment variable |
| `alias` | Define alias |
| `history` | Show command history |
| `jobs` | List background jobs |
| `fg` | Bring job to foreground |
| `bg` | Send job to background |
| `exit` | Exit shell |

### Configuration

Configuration file: `~/.hshrc`

```bash
# Example .hshrc
alias ll='ls -la'
alias gs='git status'
export PATH="$HOME/bin:$PATH"
export EDITOR=vim
```

**Location:** `apps/shell.home`

## File Manager

A graphical file browser with full file operations.

### Features

- **Navigation** - Click folders, address bar, back/forward
- **Views** - Icon view, list view, column view
- **Operations** - Copy, cut, paste, delete, rename
- **Search** - Find files by name with wildcards
- **Previews** - Image thumbnails, text preview
- **Drives** - Mount and access storage devices
- **Bookmarks** - Quick access to folders
- **Permissions** - View and modify file permissions

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Ctrl+C | Copy |
| Ctrl+X | Cut |
| Ctrl+V | Paste |
| Delete | Move to trash |
| Shift+Delete | Permanent delete |
| F2 | Rename |
| Ctrl+Shift+N | New folder |
| Ctrl+F | Search |
| Ctrl+H | Show hidden files |

### File Operations

```home
// File manager operations API
filemanager_copy(src, dest)
filemanager_move(src, dest)
filemanager_delete(path)
filemanager_rename(path, new_name)
filemanager_mkdir(path)
filemanager_get_properties(path, &props)
```

**Location:** `apps/filemanager.home`, `apps/filemanager_ops.home`, `apps/filemanager_preview.home`

## Text Editor

A lightweight code editor with modern features.

### Features

- **Syntax Highlighting** - 50+ languages
- **Line Numbers** - Configurable display
- **Search/Replace** - With regex support
- **Multiple Cursors** - Edit multiple locations
- **Code Folding** - Collapse sections
- **Auto-indent** - Smart indentation
- **Bracket Matching** - Highlight pairs
- **Word Wrap** - Optional line wrapping

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Ctrl+S | Save |
| Ctrl+O | Open |
| Ctrl+N | New file |
| Ctrl+W | Close file |
| Ctrl+F | Find |
| Ctrl+H | Find and replace |
| Ctrl+G | Go to line |
| Ctrl+Z | Undo |
| Ctrl+Y | Redo |
| Ctrl+D | Duplicate line |
| Ctrl+/ | Toggle comment |
| Ctrl+Click | Add cursor |

### Supported Languages

Syntax highlighting for:
- Home, Zig, Rust, C, C++
- JavaScript, TypeScript
- Python, Ruby, Go
- HTML, CSS, JSON, YAML
- Markdown, Shell
- And 40+ more

**Location:** `apps/editor.home`, `apps/editor/`

## System Monitor

Real-time system resource monitoring.

### Features

- **CPU Usage** - Per-core utilization
- **Memory** - Used, free, cached, swap
- **Disk I/O** - Read/write throughput
- **Network** - Traffic per interface
- **Process List** - CPU, memory per process
- **Graphs** - Historical data visualization

### Views

1. **Overview** - All resources at a glance
2. **Processes** - Detailed process list
3. **Resources** - Graphs over time
4. **Filesystems** - Disk usage
5. **Network** - Interface statistics

### Process Management

- Sort by CPU, memory, or name
- Kill processes
- Change priority (nice)
- View process tree

**Location:** `apps/sysmon.home`, `apps/sysmon_display.home`

## Calculator

A versatile calculator with multiple modes.

### Modes

1. **Basic** - Standard arithmetic
2. **Scientific** - Trigonometry, logarithms
3. **Programmer** - Hex, binary, octal
4. **Unit Conversion** - Length, weight, temperature

### Operations

**Basic:**
- Addition, subtraction
- Multiplication, division
- Percentage

**Scientific:**
- sin, cos, tan (and inverses)
- log, ln, exp
- Powers, roots
- Factorial
- Constants (pi, e)

**Programmer:**
- AND, OR, XOR, NOT
- Shift left/right
- Base conversion (hex, dec, oct, bin)

**Location:** `apps/calculator.home`

## Browser

A secure web browser (in development).

### Features

- **Navigation** - Address bar, tabs
- **Bookmarks** - Save and organize
- **History** - Browsing history
- **Privacy** - Ad blocker, tracking protection
- **Private Mode** - No history saved

### Security

- Sandboxed rendering
- HTTPS enforcement
- Certificate validation
- XSS protection

**Location:** `apps/browser.home`

## Media Player

Audio and video playback (in development).

### Supported Formats

**Audio:**
- MP3, WAV, FLAC
- OGG, AAC

**Video:**
- MP4, AVI, MKV
- WebM

### Features

- Playlist management
- Equalizer
- Visualizations
- Album art display

**Location:** `apps/media_player.home`, `apps/music.home`

## Additional Applications

### Clock

Display current time with world clocks.

**Location:** `apps/clock.home`

### Paint

Simple image editor.

**Location:** `apps/paint.home`

### Task Manager

Process and service management.

**Location:** `apps/taskmanager.home`

### Smart Home Dashboard

IoT device control panel.

**Location:** `apps/smart_home_dashboard.home`

### Network Test

Network diagnostic tools.

**Location:** `apps/nettest.home`

### Benchmark

System performance testing.

**Location:** `apps/benchmark.home`

## Desktop Environment

HomeOS includes a full desktop environment.

### Components

- **Window Manager** - Window decorations, snapping
- **Panel** - Application launcher, system tray
- **Desktop** - Icons, wallpaper
- **Theme Manager** - Light/dark themes

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Super | Open launcher |
| Super+D | Show desktop |
| Super+L | Lock screen |
| Alt+Tab | Switch windows |
| Super+Left | Snap left |
| Super+Right | Snap right |
| Super+Up | Maximize |
| Alt+F4 | Close window |

### Themes

- Light theme
- Dark theme
- High contrast
- Custom themes

**Location:** `apps/desktop/`

## Games

HomeOS includes sample games.

**Location:** `apps/games/`

## Related Documentation

- [User Manual](/os/USER_MANUAL) - Complete user guide
- [Development](/os/guide/development) - Writing applications
- [Architecture](/os/guide/architecture) - System integration
