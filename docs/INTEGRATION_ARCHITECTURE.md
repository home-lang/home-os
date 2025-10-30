# home-os Integration Architecture

## Seamless Library Integration Design

All integration code lives in **library files**, not in the kernel or applications. This creates clean separation of concerns and makes the system highly modular.

---

## Architecture Overview

```
home-os/
├── kernel/src/
│   ├── kernel.home                    # Core kernel (850+ lines)
│   ├── integration.home               # Main integration module
│   └── lib/                           # Integration libraries
│       ├── pantry_lib.home            # Pantry integration (~/Code/pantry)
│       ├── den_lib.home               # Den shell integration (~/Code/den)
│       └── craft_lib.home             # Craft UI integration (~/Code/craft)
```

---

## Integration Libraries

### 1. Pantry Library (`lib/pantry_lib.home`)

**Purpose:** Seamless integration with Pantry package manager from `~/Code/pantry`

**Features:**
- Package management (install, remove, update, list, search)
- Multi-source registry support (pkgx.sh, npm, GitHub)
- Environment management (create, activate, deactivate, list)
- Service management (start, stop, restart, status, list)
- Registry management (add, remove, list)
- Cache management

**Data Structures:**
- `Package` - Package metadata and installation info
- `Registry` - Registry configuration (pkgx, npm, GitHub, custom)
- `Environment` - Isolated project environments
- `Service` - Service configuration and state

**Key Functions:**
```home
pantry_init() -> u32
pantry_install(name, version) -> u32
pantry_remove(name) -> u32
pantry_update(name) -> u32
pantry_list() -> u32
pantry_search(query) -> u32
pantry_env_create(name, path) -> u32
pantry_env_activate(name) -> u32
pantry_service_start(name) -> u32
pantry_service_stop(name) -> u32
pantry_service_status(name) -> u32
```

**Integration Points:**
- Kernel VFS for file operations
- Network stack for registry queries
- Process management for service execution

---

### 2. Den Shell Library (`lib/den_lib.home`)

**Purpose:** Seamless integration with Den shell from `~/Code/den`

**Features:**
- Command execution (54 builtins + external commands)
- Environment variables (set, get, unset, export)
- Aliases (create, remove, expand)
- Command history (add, get, clear)
- Job control (add, remove, list, fg, bg)
- Pipeline support
- Redirection support (stdin, stdout, stderr)
- Shell state management (cwd, home, user, hostname)

**Data Structures:**
- `Command` - Parsed command with args and I/O
- `Alias` - Command aliases
- `HistoryEntry` - Command history with timestamps
- `Job` - Background job state
- `EnvVar` - Environment variables
- `ShellState` - Current shell state

**Key Functions:**
```home
den_init() -> u32
den_execute(command) -> u32
den_setenv(name, value) -> u32
den_getenv(name) -> u64
den_alias(name, value) -> u32
den_history_add(command, exit_code) -> u32
den_job_add(command, pid, background) -> u32
den_job_list() -> u32
den_get_cwd() -> u64
den_set_cwd(path) -> u32
```

**Integration Points:**
- Kernel syscalls for process execution
- VFS for file operations
- Process management for job control

---

### 3. Craft UI Library (`lib/craft_lib.home`)

**Purpose:** Seamless integration with Craft UI from `~/Code/craft`

**Features:**
- Window management (create, destroy, move, resize, focus, minimize, maximize)
- Widget system (buttons, labels, textboxes, listboxes, etc.)
- Desktop environment (wallpaper, icons, background)
- Notification system (show, dismiss, priority levels)
- Compositor (rendering, vsync, damage tracking)
- Event handling (mouse, keyboard, window events)

**Data Structures:**
- `Window` - Window metadata and state
- `Widget` - UI widget configuration
- `Desktop` - Desktop environment state
- `Notification` - Notification metadata

**Key Functions:**
```home
craft_init() -> u32
craft_window_create(x, y, width, height, title) -> u32
craft_window_destroy(window_id) -> u32
craft_window_move(window_id, x, y) -> u32
craft_window_resize(window_id, width, height) -> u32
craft_window_focus(window_id) -> u32
craft_widget_create(window_id, type, x, y, width, height, text) -> u32
craft_widget_set_text(widget_id, text) -> u32
craft_notification_show(title, message, priority, timeout) -> u32
craft_compositor_render() -> u32
```

**Integration Points:**
- Framebuffer for rendering
- Input devices for events
- GPU drivers for acceleration

---

## Main Integration Module (`integration.home`)

**Purpose:** Central integration point that ties all libraries together

**Features:**
- Unified initialization (`init_all_integrations()`)
- System call wrappers for all integrated libraries
- Integrated workflows (e.g., install package + notify)

**System Calls:**

**Pantry:**
- `sys_pantry_install(name, version)`
- `sys_pantry_remove(name)`
- `sys_pantry_update(name)`
- `sys_pantry_list()`
- `sys_pantry_search(query)`
- `sys_pantry_env_create(name, path)`
- `sys_pantry_env_activate(name)`
- `sys_pantry_service_start(name)`
- `sys_pantry_service_stop(name)`
- `sys_pantry_service_status(name)`

**Den Shell:**
- `sys_shell_execute(command)`
- `sys_shell_setenv(name, value)`
- `sys_shell_getenv(name)`
- `sys_shell_alias(name, value)`
- `sys_shell_history_add(command, exit_code)`
- `sys_shell_job_add(command, pid, background)`
- `sys_shell_job_list()`
- `sys_shell_get_cwd()`
- `sys_shell_set_cwd(path)`

**Craft UI:**
- `sys_ui_window_create(x, y, width, height, title)`
- `sys_ui_window_destroy(window_id)`
- `sys_ui_window_move(window_id, x, y)`
- `sys_ui_window_resize(window_id, width, height)`
- `sys_ui_window_focus(window_id)`
- `sys_ui_widget_create(window_id, type, x, y, width, height, text)`
- `sys_ui_widget_set_text(widget_id, text)`
- `sys_ui_notification_show(title, message, priority, timeout)`
- `sys_ui_compositor_render()`

**Integrated Workflows:**
- `install_package_with_notification(name, version)` - Install + UI notification
- `execute_command_with_history(command)` - Execute + history tracking
- `start_service_with_notification(service_name)` - Start service + UI notification

---

## Design Principles

### 1. **All Integration Code in Libraries**
- No integration logic in kernel core
- No integration logic in applications
- Clean separation of concerns

### 2. **Seamless Integration**
- Libraries handle all complexity
- Simple, clean APIs for kernel and apps
- Automatic state management

### 3. **External Library References**
- Pantry: `~/Code/pantry` (TypeScript/Bun package manager)
- Den: `~/Code/den` (Zig shell with 54 builtins)
- Craft: `~/Code/craft` (GPU-accelerated UI framework)

### 4. **Modular Architecture**
- Each library is independent
- Can be enabled/disabled at compile time
- Easy to add new integrations

### 5. **Type Safety**
- All data structures are strongly typed
- No void pointers or unsafe casts
- Memory-safe operations

---

## Usage Examples

### Example 1: Install Package with Notification

```home
import "integration.home" as sys

// Install package and show notification
sys.install_package_with_notification("nodejs", "20.0.0")
```

### Example 2: Execute Shell Command

```home
import "integration.home" as sys

// Execute command and track in history
sys.execute_command_with_history("ls -la /home")
```

### Example 3: Create UI Window

```home
import "integration.home" as sys

// Create window with widgets
var win_id: u32 = sys.sys_ui_window_create(100, 100, 800, 600, "My App")
var btn_id: u32 = sys.sys_ui_widget_create(win_id, 0, 10, 10, 100, 30, "Click Me")
```

### Example 4: Start Service

```home
import "integration.home" as sys

// Start PostgreSQL and notify
sys.start_service_with_notification("postgresql")
```

---

## Benefits

### For Kernel Developers
- Clean kernel code without integration complexity
- Easy to understand and maintain
- Modular design allows selective integration

### For Application Developers
- Simple, clean APIs
- No need to understand integration details
- Consistent interface across all libraries

### For System Integrators
- All integration logic in one place
- Easy to update external libraries
- Clear separation of concerns

---

## Future Enhancements

### Planned Features
- [ ] Hot-reload of libraries
- [ ] Plugin system for custom integrations
- [ ] IPC between integrated libraries
- [ ] Shared memory optimization
- [ ] Async/await support for library calls

### Potential Integrations
- [ ] Bun runtime integration
- [ ] LLVM/Clang toolchain
- [ ] Git version control
- [ ] Docker container support
- [ ] WebAssembly runtime

---

## File Statistics

- **pantry_lib.home:** ~400 lines (package manager integration)
- **den_lib.home:** ~500 lines (shell integration)
- **craft_lib.home:** ~400 lines (UI integration)
- **integration.home:** ~150 lines (main integration module)
- **Total:** ~1,450 lines of integration code

All integration logic is in libraries, keeping the kernel clean and focused!

---

*Integration Architecture - October 29, 2025*  
*Seamless integration with Pantry, Den, and Craft*  
*All integration code lives in libraries!*
