#!/bin/bash
# HomeOS Raspberry Pi Storage Test
#
# Tests storage functionality on Raspberry Pi hardware
#
# Usage: ./pi_storage_test.sh --model=pi4|pi5

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
RESULTS_DIR="$PROJECT_ROOT/test-results"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PI_MODEL="pi4"

while [[ $# -gt 0 ]]; do
    case $1 in
        --model=*) PI_MODEL="${1#*=}"; shift ;;
        *) shift ;;
    esac
done

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

mkdir -p "$RESULTS_DIR"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}HomeOS Raspberry Pi Storage Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# Storage Test Functions
# ============================================================================

test_sd_card() {
    log_info "Checking SD card..."

    if [ -b /dev/mmcblk0 ]; then
        log_pass "SD card device: /dev/mmcblk0"

        # Get SD card info
        local size=$(lsblk -b -d -n -o SIZE /dev/mmcblk0 2>/dev/null)
        local size_gb=$((size / 1024 / 1024 / 1024))
        log_info "Size: ${size_gb}GB"

        # List partitions
        local parts=$(lsblk -n /dev/mmcblk0 | wc -l)
        log_info "Partitions: $((parts - 1))"

        return 0
    else
        log_warn "SD card not found at /dev/mmcblk0"
        return 0
    fi
}

test_boot_partition() {
    log_info "Checking boot partition..."

    local boot_mounts=(
        "/boot"
        "/boot/firmware"
    )

    for mount in "${boot_mounts[@]}"; do
        if mountpoint -q "$mount" 2>/dev/null; then
            log_pass "Boot partition mounted: $mount"

            # Check for kernel
            if [ -f "$mount/kernel8.img" ]; then
                log_pass "kernel8.img found"
            elif [ -f "$mount/kernel.img" ]; then
                log_info "kernel.img found"
            fi

            # Check for config
            if [ -f "$mount/config.txt" ]; then
                log_pass "config.txt found"
            fi

            return 0
        fi
    done

    log_warn "Boot partition not mounted"
    return 0
}

test_root_filesystem() {
    log_info "Checking root filesystem..."

    local root_dev=$(findmnt -n -o SOURCE / 2>/dev/null)
    local root_fs=$(findmnt -n -o FSTYPE / 2>/dev/null)

    if [ -n "$root_dev" ]; then
        log_pass "Root: $root_dev ($root_fs)"

        # Check available space
        local avail=$(df -h / | tail -1 | awk '{print $4}')
        log_info "Available space: $avail"

        return 0
    else
        log_fail "Cannot determine root filesystem"
        return 1
    fi
}

test_usb_storage() {
    log_info "Checking USB storage..."

    local usb_devs=$(lsblk -d -n -o NAME,TRAN 2>/dev/null | grep usb | awk '{print $1}')

    if [ -n "$usb_devs" ]; then
        for dev in $usb_devs; do
            log_pass "USB storage: /dev/$dev"

            local size=$(lsblk -b -d -n -o SIZE /dev/$dev 2>/dev/null)
            local size_gb=$((size / 1024 / 1024 / 1024))
            log_info "  Size: ${size_gb}GB"
        done
        return 0
    else
        log_info "No USB storage devices"
        return 0
    fi
}

test_nvme() {
    log_info "Checking NVMe storage..."

    if [ -b /dev/nvme0n1 ]; then
        log_pass "NVMe device: /dev/nvme0n1"

        if command -v nvme &>/dev/null; then
            local model=$(nvme list 2>/dev/null | grep nvme0n1 | awk '{print $3}')
            log_info "Model: $model"
        fi

        return 0
    else
        log_info "No NVMe storage (Pi 5 with HAT+ required)"
        return 0
    fi
}

test_disk_io() {
    log_info "Testing disk I/O performance..."

    local test_file="/tmp/home-os-io-test"

    # Write test
    log_info "Write test (1MB)..."
    local write_start=$(date +%s%N)
    dd if=/dev/zero of="$test_file" bs=1M count=1 conv=fdatasync 2>/dev/null
    local write_end=$(date +%s%N)

    local write_time=$(( (write_end - write_start) / 1000000 ))
    if [ $write_time -gt 0 ]; then
        local write_speed=$((1000 / write_time))
        log_info "Write: ${write_speed}MB/s (${write_time}ms)"
    fi

    # Read test
    log_info "Read test (1MB)..."
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

    local read_start=$(date +%s%N)
    dd if="$test_file" of=/dev/null bs=1M count=1 2>/dev/null
    local read_end=$(date +%s%N)

    local read_time=$(( (read_end - read_start) / 1000000 ))
    if [ $read_time -gt 0 ]; then
        local read_speed=$((1000 / read_time))
        log_info "Read: ${read_speed}MB/s (${read_time}ms)"
    fi

    rm -f "$test_file"
    log_pass "I/O test completed"
    return 0
}

test_filesystem_ops() {
    log_info "Testing filesystem operations..."

    local test_dir="/tmp/home-os-fs-test"
    mkdir -p "$test_dir"

    # Create files
    for i in {1..10}; do
        echo "test $i" > "$test_dir/file$i.txt"
    done

    # Count files
    local count=$(ls "$test_dir" | wc -l)
    if [ $count -eq 10 ]; then
        log_pass "File creation: $count files"
    else
        log_fail "File creation: expected 10, got $count"
        rm -rf "$test_dir"
        return 1
    fi

    # Read files
    local content=$(cat "$test_dir/file5.txt")
    if [ "$content" == "test 5" ]; then
        log_pass "File read correct"
    fi

    # Rename file
    mv "$test_dir/file1.txt" "$test_dir/renamed.txt"
    if [ -f "$test_dir/renamed.txt" ]; then
        log_pass "File rename works"
    fi

    # Delete files
    rm -rf "$test_dir"
    if [ ! -d "$test_dir" ]; then
        log_pass "File deletion works"
    fi

    return 0
}

test_symlinks() {
    log_info "Testing symbolic links..."

    local test_dir="/tmp/home-os-symlink-test"
    mkdir -p "$test_dir"

    echo "target content" > "$test_dir/target.txt"
    ln -sf "$test_dir/target.txt" "$test_dir/link.txt"

    if [ -L "$test_dir/link.txt" ]; then
        local content=$(cat "$test_dir/link.txt")
        if [ "$content" == "target content" ]; then
            log_pass "Symbolic links work"
            rm -rf "$test_dir"
            return 0
        fi
    fi

    log_fail "Symbolic link issue"
    rm -rf "$test_dir"
    return 1
}

test_mounts() {
    log_info "Listing mount points..."

    mount | head -10 | while read line; do
        log_info "  $line"
    done

    local mount_count=$(mount | wc -l)
    log_info "Total mounts: $mount_count"

    return 0
}

test_tmpfs() {
    log_info "Checking tmpfs..."

    if mountpoint -q /tmp 2>/dev/null; then
        local fs_type=$(findmnt -n -o FSTYPE /tmp 2>/dev/null)
        if [ "$fs_type" == "tmpfs" ]; then
            log_pass "/tmp is tmpfs"
        else
            log_info "/tmp is $fs_type"
        fi
    fi

    if mountpoint -q /run 2>/dev/null; then
        log_pass "/run mounted"
    fi

    return 0
}

# ============================================================================
# Run Tests
# ============================================================================

run_test() {
    local name="$1"
    local func="$2"

    echo ""
    if $func; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

run_test "SD Card" test_sd_card
run_test "Boot Partition" test_boot_partition
run_test "Root Filesystem" test_root_filesystem
run_test "USB Storage" test_usb_storage
run_test "NVMe" test_nvme
run_test "Disk I/O" test_disk_io
run_test "Filesystem Ops" test_filesystem_ops
run_test "Symlinks" test_symlinks
run_test "Mounts" test_mounts
run_test "Tmpfs" test_tmpfs

# ============================================================================
# Summary
# ============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Storage Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    touch "$RESULTS_DIR/storage-PASSED"
    echo -e "${GREEN}Storage test PASSED${NC}"
    exit 0
else
    touch "$RESULTS_DIR/storage-FAILED"
    echo -e "${RED}Storage test FAILED${NC}"
    exit 1
fi
