#!/bin/bash
# home-os Documentation Generator
# Auto-generates syscall and driver reference documentation from .home sources
# Usage: ./scripts/generate-docs.sh [--syscalls] [--drivers] [--all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KERNEL_SRC="$PROJECT_ROOT/kernel/src"
DOCS_DIR="$PROJECT_ROOT/docs/api"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create docs directory if it doesn't exist
mkdir -p "$DOCS_DIR"

echo -e "${BLUE}home-os Documentation Generator${NC}"
echo "=================================="
echo ""

# ============================================================================
# SYSCALL DOCUMENTATION GENERATOR
# ============================================================================

generate_syscall_docs() {
    echo -e "${YELLOW}Generating syscall documentation...${NC}"

    local SYSCALL_FILE="$KERNEL_SRC/sys/syscall.home"
    local OUTPUT_FILE="$DOCS_DIR/SYSCALLS.md"

    if [ ! -f "$SYSCALL_FILE" ]; then
        echo -e "${RED}Error: syscall.home not found${NC}"
        return 1
    fi

    cat > "$OUTPUT_FILE" << 'HEADER'
# home-os System Call Reference

This document is auto-generated from `kernel/src/sys/syscall.home`.

## Overview

home-os provides a POSIX-compatible system call interface. System calls are the primary interface between user-space applications and the kernel.

## Syscall Calling Convention

### x86-64
- Syscall number: `RAX`
- Arguments: `RDI`, `RSI`, `RDX`, `R10`, `R8`, `R9`
- Return value: `RAX`
- Instruction: `syscall`

### ARM64
- Syscall number: `X8`
- Arguments: `X0`, `X1`, `X2`, `X3`, `X4`, `X5`
- Return value: `X0`
- Instruction: `svc #0`

## System Call Table

| Number | Name | Description |
|--------|------|-------------|
HEADER

    # Extract syscall definitions
    grep -E "^(export )?const SYS_[A-Z_]+:" "$SYSCALL_FILE" 2>/dev/null | \
    while read -r line; do
        # Parse: const SYS_NAME: u32 = NUMBER
        name=$(echo "$line" | grep -oE "SYS_[A-Z_]+" | head -1)
        number=$(echo "$line" | grep -oE "= [0-9]+" | grep -oE "[0-9]+")

        if [ -n "$name" ] && [ -n "$number" ]; then
            # Convert SYS_READ to read
            friendly_name=$(echo "$name" | sed 's/^SYS_//' | tr '[:upper:]' '[:lower:]')
            echo "| $number | $friendly_name | \`$name\` |" >> "$OUTPUT_FILE"
        fi
    done

    # Add syscall categories
    cat >> "$OUTPUT_FILE" << 'CATEGORIES'

## Syscall Categories

### Process Management
- `fork` - Create a child process
- `exec` - Execute a program
- `exit` - Terminate the calling process
- `wait` / `waitpid` - Wait for a child process
- `getpid` / `getppid` - Get process/parent process ID
- `kill` - Send a signal to a process

### File Operations
- `open` - Open a file
- `close` - Close a file descriptor
- `read` - Read from a file descriptor
- `write` - Write to a file descriptor
- `lseek` - Reposition file offset
- `stat` / `fstat` / `lstat` - Get file status
- `unlink` - Delete a file
- `rename` - Rename a file
- `mkdir` / `rmdir` - Create/remove directory

### File Descriptor Operations
- `dup` / `dup2` / `dup3` - Duplicate file descriptor
- `pipe` / `pipe2` - Create a pipe
- `fcntl` - File control operations
- `ioctl` - Device control operations

### Memory Management
- `mmap` - Map files or devices into memory
- `munmap` - Unmap memory
- `mprotect` - Set memory protection
- `brk` / `sbrk` - Change data segment size

### Network Operations
- `socket` - Create a socket
- `bind` - Bind a socket to an address
- `listen` - Listen for connections
- `accept` - Accept a connection
- `connect` - Connect to a remote socket
- `send` / `recv` - Send/receive data
- `sendto` / `recvfrom` - Send/receive datagrams

### Signal Handling
- `sigaction` - Set signal handler
- `sigprocmask` - Block/unblock signals
- `sigpending` - Get pending signals
- `sigsuspend` - Wait for a signal

### Time Operations
- `gettimeofday` - Get current time
- `clock_gettime` - Get clock time
- `nanosleep` - High-resolution sleep

### System Information
- `uname` - Get system information
- `getrlimit` / `setrlimit` - Get/set resource limits
- `sysinfo` - Get system statistics

## Error Codes

All syscalls return -1 on error and set `errno`:

| Code | Name | Description |
|------|------|-------------|
| 1 | EPERM | Operation not permitted |
| 2 | ENOENT | No such file or directory |
| 3 | ESRCH | No such process |
| 4 | EINTR | Interrupted system call |
| 5 | EIO | I/O error |
| 9 | EBADF | Bad file descriptor |
| 11 | EAGAIN | Resource temporarily unavailable |
| 12 | ENOMEM | Out of memory |
| 13 | EACCES | Permission denied |
| 14 | EFAULT | Bad address |
| 17 | EEXIST | File exists |
| 22 | EINVAL | Invalid argument |
| 28 | ENOSPC | No space left on device |

CATEGORIES

    local count=$(grep -c "^| [0-9]" "$OUTPUT_FILE" 2>/dev/null || echo "0")
    echo -e "${GREEN}Generated syscall docs: $OUTPUT_FILE ($count syscalls)${NC}"
}

# ============================================================================
# DRIVER DOCUMENTATION GENERATOR
# ============================================================================

generate_driver_docs() {
    echo -e "${YELLOW}Generating driver documentation...${NC}"

    local DRIVERS_DIR="$KERNEL_SRC/drivers"
    local OUTPUT_FILE="$DOCS_DIR/DRIVERS.md"

    if [ ! -d "$DRIVERS_DIR" ]; then
        echo -e "${RED}Error: drivers directory not found${NC}"
        return 1
    fi

    cat > "$OUTPUT_FILE" << 'HEADER'
# home-os Driver Reference

This document is auto-generated from `kernel/src/drivers/*.home`.

## Overview

home-os includes drivers for various hardware devices. Each driver follows a consistent interface pattern.

## Driver Categories

HEADER

    # Process each category of drivers
    local categories=(
        "Storage:sdmmc bcm_emmc nvme ahci"
        "Network:wifi ethernet cyw43455"
        "Display:framebuffer gpu vga_graphics hdmi"
        "Input:keyboard mouse touchpad"
        "USB:xhci uhci usb_xhci"
        "Serial:serial uart"
        "GPIO:gpio"
        "Audio:audio"
        "Other:timer watchdog dma pci"
    )

    for category_def in "${categories[@]}"; do
        IFS=':' read -r category drivers <<< "$category_def"

        echo "### $category Drivers" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "| Driver | File | Description |" >> "$OUTPUT_FILE"
        echo "|--------|------|-------------|" >> "$OUTPUT_FILE"

        for driver in $drivers; do
            local driver_file="$DRIVERS_DIR/${driver}.home"
            if [ -f "$driver_file" ]; then
                # Extract first comment line as description
                local desc=$(head -5 "$driver_file" | grep -E "^// " | head -1 | sed 's/^\/\/ //')
                [ -z "$desc" ] && desc="$driver driver"
                echo "| $driver | \`${driver}.home\` | $desc |" >> "$OUTPUT_FILE"
            fi
        done

        echo "" >> "$OUTPUT_FILE"
    done

    # Generate detailed documentation for each driver
    cat >> "$OUTPUT_FILE" << 'DETAILS'
## Driver Details

DETAILS

    for driver_file in "$DRIVERS_DIR"/*.home; do
        [ -f "$driver_file" ] || continue

        local basename=$(basename "$driver_file" .home)
        local title=$(echo "$basename" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

        echo "### $title" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "**File:** \`kernel/src/drivers/${basename}.home\`" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"

        # Extract description from file header
        local desc=$(head -10 "$driver_file" | grep -E "^// " | head -3 | sed 's/^\/\/ //')
        if [ -n "$desc" ]; then
            echo "$desc" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi

        # Extract exported functions
        echo "**Exported Functions:**" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo '```' >> "$OUTPUT_FILE"
        grep -E "^export fn [a-z_]+\(" "$driver_file" 2>/dev/null | \
            sed 's/export fn //' | \
            sed 's/ {$//' | \
            head -20 >> "$OUTPUT_FILE" || echo "// No exported functions found" >> "$OUTPUT_FILE"
        echo '```' >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"

        # Extract constants
        local const_count=$(grep -cE "^(export )?const [A-Z_]+:" "$driver_file" 2>/dev/null | tr -d '\n' || echo "0")
        const_count=${const_count:-0}
        if [ "$const_count" -gt 0 ] 2>/dev/null; then
            echo "**Constants:** $const_count defined" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi

        # Extract structs
        local struct_count=$(grep -cE "^(export )?struct [A-Z]" "$driver_file" 2>/dev/null | tr -d '\n' || echo "0")
        struct_count=${struct_count:-0}
        if [ "$struct_count" -gt 0 ] 2>/dev/null; then
            echo "**Data Structures:** $struct_count defined" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi

        echo "---" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    done

    local count=$(ls -1 "$DRIVERS_DIR"/*.home 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${GREEN}Generated driver docs: $OUTPUT_FILE ($count drivers)${NC}"
}

# ============================================================================
# MODULE INDEX GENERATOR
# ============================================================================

generate_module_index() {
    echo -e "${YELLOW}Generating module index...${NC}"

    local OUTPUT_FILE="$DOCS_DIR/MODULE_INDEX.md"

    cat > "$OUTPUT_FILE" << 'HEADER'
# home-os Kernel Module Index

This document is auto-generated from the kernel source tree.

## Module Organization

HEADER

    # List all directories and their module counts
    for dir in "$KERNEL_SRC"/*/; do
        [ -d "$dir" ] || continue

        local dirname=$(basename "$dir")
        local count=$(find "$dir" -name "*.home" -type f 2>/dev/null | wc -l | tr -d ' ')

        if [ "$count" -gt 0 ]; then
            echo "### $dirname ($count modules)" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"

            # List modules in this directory
            echo "| Module | Description |" >> "$OUTPUT_FILE"
            echo "|--------|-------------|" >> "$OUTPUT_FILE"

            for module in "$dir"*.home; do
                [ -f "$module" ] || continue
                local name=$(basename "$module" .home)
                local desc=$(head -3 "$module" | grep -E "^// " | head -1 | sed 's/^\/\/ //' | cut -c1-60)
                [ -z "$desc" ] && desc="-"
                echo "| \`$name\` | $desc |" >> "$OUTPUT_FILE"
            done

            echo "" >> "$OUTPUT_FILE"
        fi
    done

    # Statistics
    local total_modules=$(find "$KERNEL_SRC" -name "*.home" -type f 2>/dev/null | wc -l | tr -d ' ')
    local total_lines=$(find "$KERNEL_SRC" -name "*.home" -type f -exec cat {} \; 2>/dev/null | wc -l | tr -d ' ')

    cat >> "$OUTPUT_FILE" << STATS

## Statistics

- **Total Modules:** $total_modules
- **Total Lines of Code:** $total_lines
- **Average Lines per Module:** $((total_lines / total_modules))

## Build Information

Generated on: $(date '+%Y-%m-%d %H:%M:%S')
STATS

    echo -e "${GREEN}Generated module index: $OUTPUT_FILE${NC}"
}

# ============================================================================
# API REFERENCE GENERATOR
# ============================================================================

generate_api_reference() {
    echo -e "${YELLOW}Generating API reference...${NC}"

    local OUTPUT_FILE="$DOCS_DIR/API_REFERENCE.md"

    cat > "$OUTPUT_FILE" << 'HEADER'
# home-os Kernel API Reference

This document is auto-generated from exported functions in the kernel source.

## Core APIs

HEADER

    # Process core modules
    local core_modules=(
        "core/foundation:Foundation - Basic kernel utilities"
        "core/memory:Memory - Memory management"
        "core/process:Process - Process management"
        "core/filesystem:Filesystem - VFS operations"
        "sys/syscall:Syscall - System call interface"
        "sys/signal:Signal - Signal handling"
    )

    for module_def in "${core_modules[@]}"; do
        IFS=':' read -r module_path desc <<< "$module_def"
        local module_file="$KERNEL_SRC/${module_path}.home"

        if [ -f "$module_file" ]; then
            local name=$(basename "$module_path")
            echo "### $desc" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo "**File:** \`kernel/src/${module_path}.home\`" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"

            # Extract exported functions
            echo "**Functions:**" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo '```c' >> "$OUTPUT_FILE"
            grep -E "^export fn [a-z_]+\(" "$module_file" 2>/dev/null | \
                sed 's/export fn //' | \
                sed 's/ {$/;/' | \
                head -30 >> "$OUTPUT_FILE" || echo "// No exported functions" >> "$OUTPUT_FILE"
            echo '```' >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
    done

    echo -e "${GREEN}Generated API reference: $OUTPUT_FILE${NC}"
}

# ============================================================================
# MAIN
# ============================================================================

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --syscalls    Generate syscall documentation"
    echo "  --drivers     Generate driver documentation"
    echo "  --index       Generate module index"
    echo "  --api         Generate API reference"
    echo "  --all         Generate all documentation"
    echo "  --help        Show this help message"
    echo ""
    echo "Output directory: $DOCS_DIR"
}

main() {
    local do_syscalls=0
    local do_drivers=0
    local do_index=0
    local do_api=0

    # Parse arguments
    if [ $# -eq 0 ]; then
        do_syscalls=1
        do_drivers=1
        do_index=1
        do_api=1
    else
        for arg in "$@"; do
            case $arg in
                --syscalls) do_syscalls=1 ;;
                --drivers) do_drivers=1 ;;
                --index) do_index=1 ;;
                --api) do_api=1 ;;
                --all)
                    do_syscalls=1
                    do_drivers=1
                    do_index=1
                    do_api=1
                    ;;
                --help)
                    show_help
                    exit 0
                    ;;
                *)
                    echo -e "${RED}Unknown option: $arg${NC}"
                    show_help
                    exit 1
                    ;;
            esac
        done
    fi

    echo "Output directory: $DOCS_DIR"
    echo ""

    [ $do_syscalls -eq 1 ] && generate_syscall_docs
    [ $do_drivers -eq 1 ] && generate_driver_docs
    [ $do_index -eq 1 ] && generate_module_index
    [ $do_api -eq 1 ] && generate_api_reference

    echo ""
    echo -e "${GREEN}Documentation generation complete!${NC}"
    echo ""
    echo "Generated files:"
    ls -la "$DOCS_DIR"/*.md 2>/dev/null || echo "No files generated"
}

main "$@"
