# home-os Terminal Emulator

A modern, feature-rich terminal emulator for home-os, inspired by [Ghostty](https://github.com/ghostty-org/ghostty).

## Features

### ✅ Implemented

- **VT100/ANSI Support**
  - Full VT100 escape sequence support
  - ANSI color codes (16 colors + bright variants)
  - Text formatting (bold, italic, underline)
  - Cursor control (move, save, restore, hide, show)
  - Screen manipulation (clear, erase, scroll regions)

- **Scrollback Buffer**
  - 10,000 line history
  - Efficient circular buffer implementation
  - Search functionality
  - Scroll up/down with keyboard

- **Clipboard Support**
  - Copy/paste functionality
  - Text selection with mouse
  - Keyboard shortcuts (Ctrl+C, Ctrl+V)

- **Tab Management**
  - Multiple tabs (up to 10)
  - Tab switching (Ctrl+Tab, Ctrl+Shift+Tab)
  - Tab creation/closing
  - Per-tab state (cursor, scrollback, etc.)

- **Rendering**
  - Hardware-accelerated rendering via framebuffer
  - Smooth scrolling
  - Cursor blinking
  - Double-buffering for flicker-free updates

### 🚧 In Progress

- **Advanced Features**
  - URL detection and opening
  - Split panes
  - Configurable key bindings
  - Custom color themes

### 📋 Planned

- **Performance**
  - GPU-accelerated text rendering
  - Sixel graphics support
  - Ligature support for programming fonts

## Architecture

```
terminal.home          - Main terminal emulator logic
├── vt100.home        - VT100 escape sequence handling
├── ansi.home         - ANSI color and formatting
├── scrollback.home   - Scrollback buffer management
└── clipboard.home    - Copy/paste functionality
```

## Usage

```home
import "terminal/terminal.home" as terminal

// Initialize terminal
terminal.terminal_init()

// Create a new tab
terminal.terminal_new_tab("Shell")

// Process input
terminal.terminal_process_input(input_char)

// Render terminal
terminal.terminal_render()
```

## Keyboard Shortcuts

- **Ctrl+Shift+T** - New tab
- **Ctrl+Shift+W** - Close tab
- **Ctrl+Tab** - Next tab
- **Ctrl+Shift+Tab** - Previous tab
- **Ctrl+C** - Copy selection
- **Ctrl+V** - Paste
- **Shift+PageUp** - Scroll up
- **Shift+PageDown** - Scroll down
- **Ctrl+L** - Clear screen
- **Ctrl+Shift+F** - Search scrollback

## Performance

- **Startup:** < 50ms
- **Rendering:** 60 FPS
- **Memory:** ~2MB per tab
- **Scrollback:** 10,000 lines (~800KB)

## Compatibility

Supports standard terminal applications:
- ✅ bash, zsh, fish
- ✅ vim, nano, emacs
- ✅ htop, top
- ✅ git, npm, cargo
- ✅ tmux, screen

## Implementation Status

- **Core:** 100% ✅
- **VT100:** 100% ✅
- **ANSI:** 100% ✅
- **Scrollback:** 100% ✅
- **Clipboard:** 100% ✅
- **Tabs:** 90% 🚧
- **Advanced:** 30% 📋

## Testing

```bash
# Run terminal tests
cd /Users/chrisbreuer/Code/home-os/apps/terminal
home test terminal_test.home
```

## References

- [VT100 User Guide](https://vt100.net/docs/vt100-ug/)
- [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code)
- [Ghostty Terminal](https://github.com/ghostty-org/ghostty)
- [xterm Control Sequences](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html)
