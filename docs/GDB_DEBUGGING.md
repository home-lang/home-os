# GDB Remote Debugging Guide

This document describes how to use GDB for remote debugging of home-os kernel on both x86-64 and ARM64 (Raspberry Pi) platforms.

## Overview

home-os includes a built-in GDB remote stub that implements the GDB Remote Serial Protocol (RSP). This allows you to:

- Set breakpoints and watchpoints
- Single-step through code
- Inspect and modify registers
- Read and write memory
- Debug kernel panics and exceptions

## Architecture Support

The GDB stub is integrated into the exception handling paths for both supported architectures:

| Architecture | Exception Integration | Serial Port |
|--------------|----------------------|-------------|
| x86-64 | IDT vectors 0-31 | COM1 (0x3F8) |
| ARM64 | EL1 exception vectors | UART0 (PL011) |

## Source Files

- `kernel/src/debug/gdb.home` - Core GDB RSP implementation
- `kernel/src/debug/gdb_exception_hooks.home` - Architecture-specific exception integration

## Quick Start

### 1. Enable GDB Support in Kernel

The GDB stub is compiled into the kernel by default. To enable it at runtime:

```c
// In kernel initialization code
gdb_hooks_init(ARCH_ARM64);  // or ARCH_X86_64
gdb_hooks_enable();
```

### 2. Connect from Host Machine

#### For Raspberry Pi (UART over USB)

```bash
# Identify the serial device
ls /dev/tty.usbserial*  # macOS
ls /dev/ttyUSB*         # Linux

# Connect GDB
arm-none-eabi-gdb kernel.elf
(gdb) target remote /dev/ttyUSB0
```

#### For x86-64 (QEMU)

```bash
# Start QEMU with serial redirection
qemu-system-x86_64 -kernel kernel.bin -serial tcp::1234,server,nowait

# Connect GDB
gdb kernel.elf
(gdb) target remote localhost:1234
```

#### For x86-64 (Real Hardware via Serial)

```bash
# Connect using USB-to-serial adapter
gdb kernel.elf
(gdb) target remote /dev/ttyUSB0
(gdb) set serial baud 115200
```

## GDB Commands

### Basic Commands

```gdb
# Connect to target
target remote <device>

# Continue execution
continue
c

# Single step (instruction)
stepi
si

# Single step (source line)
step
s

# Set breakpoint
break *0xFFFF800000100000
break kernel_main

# Remove breakpoint
delete 1

# List breakpoints
info breakpoints

# Print registers
info registers

# Print specific register
print $rip    # x86-64
print $pc     # ARM64

# Examine memory
x/10x 0xFFFF800000100000
x/10i $pc
```

### Advanced Commands

```gdb
# Set watchpoint (break on memory write)
watch *0xFFFF800000200000

# Set read watchpoint
rwatch *0xFFFF800000200000

# Set access watchpoint (read or write)
awatch *0xFFFF800000200000

# Modify register
set $rax = 0x1234

# Write memory
set *0xFFFF800000100000 = 0xDEADBEEF

# Backtrace
backtrace
bt

# Switch to frame
frame 2

# Disassemble
disassemble
disassemble /m   # with source
```

## Exception Handling

When an exception occurs and GDB is enabled, the kernel will:

1. Save all registers to the exception frame
2. Convert the exception to a Unix signal number
3. Send a stop packet to GDB (`S05` for SIGTRAP)
4. Wait for GDB commands

### Signal Mapping

| Exception | x86-64 Vector | ARM64 ESR EC | GDB Signal |
|-----------|---------------|--------------|------------|
| Divide Error | 0 (#DE) | - | SIGFPE (8) |
| Debug | 1 (#DB) | 0x32-0x33 | SIGTRAP (5) |
| Breakpoint | 3 (#BP) | 0x3C (BRK) | SIGTRAP (5) |
| Invalid Opcode | 6 (#UD) | 0x0E | SIGILL (4) |
| Page Fault | 14 (#PF) | 0x20-0x25 | SIGSEGV (11) |
| Alignment | 17 (#AC) | 0x22, 0x26 | SIGBUS (7) |

## Raspberry Pi Specific Setup

### Hardware Connections

The Raspberry Pi uses UART0 (GPIO 14/15) for GDB communication:

```
Pi GPIO 14 (TXD) --> USB-Serial RX
Pi GPIO 15 (RXD) <-- USB-Serial TX
Pi GND -----------> USB-Serial GND
```

### UART Configuration

Default settings:
- Baud rate: 115200
- Data bits: 8
- Parity: None
- Stop bits: 1
- Flow control: None

### config.txt Settings

Ensure UART is enabled in `config.txt`:

```
enable_uart=1
uart_2ndstage=1
```

### Pi 4/5 Considerations

On Pi 4 and Pi 5, the default UART is different:

```
# Pi 4: Use mini UART or configure PL011
dtoverlay=disable-bt
# or
dtoverlay=miniuart-bt

# Pi 5: Use dedicated debug UART
dtparam=uart0=on
```

## Debugging Kernel Panics

When a kernel panic occurs:

1. The panic handler will call into GDB if enabled
2. GDB receives a SIGABRT (6) signal
3. You can inspect the state at the time of panic

```gdb
(gdb) target remote /dev/ttyUSB0
Remote debugging using /dev/ttyUSB0
0xffff800000105432 in panic_handler () at kernel/src/debug/panic.home:123
(gdb) backtrace
#0  0xffff800000105432 in panic_handler ()
#1  0xffff800000104000 in page_fault_handler ()
#2  0xffff800000103800 in exception_entry ()
(gdb) info registers
...
```

## Breakpoint Types

### Software Breakpoints

Software breakpoints replace the instruction at the target address with a breakpoint instruction:

| Architecture | Instruction | Opcode |
|--------------|-------------|--------|
| x86-64 | INT3 | 0xCC |
| ARM64 | BRK #0 | 0xD4200000 |

```gdb
break *0xFFFF800000100000
```

### Hardware Breakpoints

Hardware breakpoints use CPU debug registers (limited quantity):

| Architecture | Max Breakpoints | Max Watchpoints |
|--------------|-----------------|-----------------|
| x86-64 | 4 | 4 |
| ARM64 | 6 (typical) | 4 (typical) |

```gdb
hbreak *0xFFFF800000100000
```

## Single-Step Support

### x86-64

Single-stepping uses the Trap Flag (TF) in RFLAGS. When TF=1, the CPU generates a #DB exception after each instruction.

### ARM64

Single-stepping uses the Software Step (SS) bit in MDSCR_EL1. When enabled, generates an exception after each instruction.

## Troubleshooting

### No Response from Target

1. Check serial cable connections
2. Verify baud rate matches (115200)
3. Ensure GDB stub is enabled in kernel
4. Check that target is waiting for connection

### Checksum Errors

```
Ignoring packet error, continuing...
```

Possible causes:
- Electrical noise on serial line
- Baud rate mismatch
- Flow control issues

Solutions:
- Use shorter cables
- Add decoupling capacitors
- Verify settings match on both ends

### Breakpoint Not Hitting

1. Verify address is correct
2. Check if code is actually executed
3. For hardware breakpoints, check limit not exceeded
4. Ensure breakpoint is in executable memory

### Registers Show Garbage

- Context may not be valid yet
- Exception frame may be corrupted
- Check stack alignment

## Performance Considerations

- GDB communication is slow (115200 baud)
- Breakpoints add latency
- Single-stepping is very slow
- Consider using conditional breakpoints sparingly

## Integration with IDEs

### VS Code

Add to `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug home-os",
      "type": "cppdbg",
      "request": "launch",
      "program": "${workspaceFolder}/kernel.elf",
      "miDebuggerPath": "arm-none-eabi-gdb",
      "miDebuggerServerAddress": "/dev/ttyUSB0",
      "setupCommands": [
        { "text": "set architecture aarch64" }
      ]
    }
  ]
}
```

### CLion

1. Create a Remote GDB Server configuration
2. Set debugger to appropriate GDB (arm-none-eabi-gdb or gdb)
3. Set symbol file to kernel.elf
4. Set target remote args to serial device

## API Reference

### Initialization

```c
// Initialize GDB hooks for architecture
// arch: ARCH_X86_64 or ARCH_ARM64
u32 gdb_hooks_init(u32 arch);

// Enable GDB debugging
void gdb_hooks_enable();

// Disable GDB debugging
void gdb_hooks_disable();
```

### Breakpoint Management

```c
// Insert breakpoint at address
u32 gdb_hooks_insert_breakpoint(u64 addr);

// Remove breakpoint from address
u32 gdb_hooks_remove_breakpoint(u64 addr);
```

### Single-Step Control

```c
// Enable single-step mode
void gdb_hooks_enable_single_step();

// Disable single-step mode
void gdb_hooks_disable_single_step();
```

### Register Access

```c
// Get register by GDB register number
u64 gdb_hooks_get_register(u32 reg_num);

// Set register by GDB register number
void gdb_hooks_set_register(u32 reg_num, u64 value);
```

## Further Reading

- [GDB Remote Serial Protocol](https://sourceware.org/gdb/onlinedocs/gdb/Remote-Protocol.html)
- [ARM Architecture Reference Manual](https://developer.arm.com/documentation/ddi0487/latest)
- [Intel 64 and IA-32 Architectures Software Developer's Manual](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html)
