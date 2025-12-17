#!/bin/bash
# HomeOS Pointer Safety Migration Script
# Helps identify and migrate unsafe pointer patterns to use ptr_safety wrappers
#
# Usage: ./scripts/migrate-ptr-safety.sh [--report] [--check FILE]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KERNEL_SRC="$PROJECT_ROOT/kernel/src"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Pattern definitions
UNSAFE_PATTERNS=(
    "@ptrFromInt"
    "@intFromPtr"
    "@bitCast"
    "\\*volatile"
)

# Safety wrapper functions
SAFE_FUNCTIONS=(
    "ptr_safety.ptr_is_null"
    "ptr_safety.ptr_safe_read"
    "ptr_safety.ptr_safe_write"
    "ptr_safety.ptr_check_range"
    "ptr_safety.ptr_is_kernel"
    "ptr_safety.ptr_is_user"
    "ptr_safety.ptr_is_page_aligned"
    "ptr_safety.ptr_safe_memcpy"
    "ptr_safety.ptr_safe_memset"
    "ptr_copy_from_user"
    "ptr_copy_to_user"
)

# Files that have been migrated (don't need warnings)
MIGRATED_FILES=(
    "kernel/src/sys/syscall.home"
    "kernel/src/vmm.home"
    "kernel/src/security/ptr_safety.home"
    "kernel/src/security/ptr_migrate.home"
)

# High-priority files to migrate
HIGH_PRIORITY_FILES=(
    "kernel/src/pmm.home"
    "kernel/src/heap.home"
    "kernel/src/core/process.home"
    "kernel/src/core/filesystem.home"
    "kernel/src/core/memory.home"
    "kernel/src/net/socket.home"
    "kernel/src/net/tcp.home"
)

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if file has ptr_safety import
has_safety_import() {
    local file="$1"
    grep -q "import.*ptr_safety" "$file" 2>/dev/null
}

# Count unsafe patterns in a file
count_unsafe_patterns() {
    local file="$1"
    local count=0

    for pattern in "${UNSAFE_PATTERNS[@]}"; do
        local matches=$(grep -c "$pattern" "$file" 2>/dev/null || echo 0)
        count=$((count + matches))
    done

    echo $count
}

# Check if file uses safety wrappers
uses_safety_wrappers() {
    local file="$1"

    for func in "${SAFE_FUNCTIONS[@]}"; do
        if grep -q "$func" "$file" 2>/dev/null; then
            return 0
        fi
    done

    return 1
}

# Generate migration report
generate_report() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}HomeOS Pointer Safety Migration Report${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local total_files=0
    local migrated_count=0
    local needs_migration=0
    local total_unsafe=0

    log_info "Scanning kernel source files..."
    echo ""

    # Find all .home files
    while IFS= read -r file; do
        local rel_path="${file#$PROJECT_ROOT/}"
        total_files=$((total_files + 1))

        # Skip already migrated files
        local is_migrated=0
        for migrated in "${MIGRATED_FILES[@]}"; do
            if [[ "$rel_path" == "$migrated" ]]; then
                is_migrated=1
                break
            fi
        done

        local unsafe_count=$(count_unsafe_patterns "$file")
        total_unsafe=$((total_unsafe + unsafe_count))

        if [[ $is_migrated -eq 1 ]]; then
            migrated_count=$((migrated_count + 1))
            echo -e "${GREEN}✓${NC} $rel_path (migrated, $unsafe_count patterns)"
        elif [[ $unsafe_count -gt 0 ]]; then
            needs_migration=$((needs_migration + 1))

            # Check if it's high priority
            local is_high_priority=0
            for hp in "${HIGH_PRIORITY_FILES[@]}"; do
                if [[ "$rel_path" == "$hp" ]]; then
                    is_high_priority=1
                    break
                fi
            done

            if [[ $is_high_priority -eq 1 ]]; then
                echo -e "${RED}✗${NC} $rel_path (HIGH PRIORITY: $unsafe_count unsafe patterns)"
            else
                echo -e "${YELLOW}○${NC} $rel_path ($unsafe_count unsafe patterns)"
            fi
        fi
    done < <(find "$KERNEL_SRC" -name "*.home" -type f | sort)

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "Total kernel source files: $total_files"
    echo "Files migrated: $migrated_count"
    echo "Files needing migration: $needs_migration"
    echo "Total unsafe patterns found: $total_unsafe"
    echo ""

    # List high priority files
    echo -e "${YELLOW}High Priority Files:${NC}"
    for hp in "${HIGH_PRIORITY_FILES[@]}"; do
        local file="$PROJECT_ROOT/$hp"
        if [[ -f "$file" ]]; then
            local count=$(count_unsafe_patterns "$file")
            if has_safety_import "$file"; then
                echo -e "  ${GREEN}✓${NC} $hp (has import, $count patterns)"
            else
                echo -e "  ${RED}✗${NC} $hp (needs import, $count patterns)"
            fi
        fi
    done

    echo ""
    echo -e "${BLUE}Migration Checklist:${NC}"
    echo "1. Add 'import ptr_safety from \"./security/ptr_safety.home\"'"
    echo "2. Replace @ptrFromInt with validated access patterns"
    echo "3. Use ptr_safe_read/write for user-space data"
    echo "4. Add ptr_check_range before buffer operations"
    echo "5. Use ptr_copy_from_user/ptr_copy_to_user for syscalls"
    echo ""
}

# Check a specific file
check_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        exit 1
    fi

    echo -e "${BLUE}Checking: $file${NC}"
    echo ""

    local unsafe_count=$(count_unsafe_patterns "$file")

    if has_safety_import "$file"; then
        log_success "Has ptr_safety import"
    else
        log_warning "Missing ptr_safety import"
    fi

    if uses_safety_wrappers "$file"; then
        log_success "Uses safety wrapper functions"
    else
        log_warning "Does not use safety wrapper functions"
    fi

    echo ""
    echo "Unsafe patterns found: $unsafe_count"
    echo ""

    if [[ $unsafe_count -gt 0 ]]; then
        echo -e "${YELLOW}Unsafe pattern locations:${NC}"
        for pattern in "${UNSAFE_PATTERNS[@]}"; do
            grep -n "$pattern" "$file" 2>/dev/null | head -20 || true
        done
    fi
}

# Print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --report       Generate full migration report"
    echo "  --check FILE   Check a specific file for unsafe patterns"
    echo "  --high         List high-priority files needing migration"
    echo "  --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --report"
    echo "  $0 --check kernel/src/pmm.home"
}

# Main
case "${1:-}" in
    --report)
        generate_report
        ;;
    --check)
        if [[ -z "${2:-}" ]]; then
            log_error "Please specify a file to check"
            exit 1
        fi
        check_file "$2"
        ;;
    --high)
        echo -e "${BLUE}High Priority Files for Migration:${NC}"
        echo ""
        for hp in "${HIGH_PRIORITY_FILES[@]}"; do
            local file="$PROJECT_ROOT/$hp"
            if [[ -f "$file" ]]; then
                local count=$(count_unsafe_patterns "$file")
                echo "$hp: $count unsafe patterns"
            fi
        done
        ;;
    --help|"")
        print_usage
        ;;
    *)
        log_error "Unknown option: $1"
        print_usage
        exit 1
        ;;
esac
