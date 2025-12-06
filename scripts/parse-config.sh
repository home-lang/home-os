#!/bin/bash
# HomeOS Build Configuration Parser
# Parses kernel/build.config and generates build flags

set -e

CONFIG_FILE="${1:-kernel/build.config}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Parse configuration file
parse_config() {
    local key="$1"
    grep "^${key}=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' '
}

# Generate Home compiler defines
generate_defines() {
    echo "# Auto-generated build defines"
    echo "# From: $CONFIG_FILE"
    echo ""

    # Profile
    local profile=$(parse_config "PROFILE")
    echo "const BUILD_PROFILE: []const u8 = \"${profile:-desktop}\";"

    # Target architecture
    local arch=$(parse_config "TARGET_ARCH")
    case "$arch" in
        x86-64)
            echo "const BUILD_ARCH_X86_64: bool = true;"
            echo "const BUILD_ARCH_ARM64: bool = false;"
            ;;
        rpi3|rpi4|rpi5|arm64)
            echo "const BUILD_ARCH_X86_64: bool = false;"
            echo "const BUILD_ARCH_ARM64: bool = true;"
            ;;
        *)
            echo "const BUILD_ARCH_X86_64: bool = true;"
            echo "const BUILD_ARCH_ARM64: bool = false;"
            ;;
    esac

    echo ""
    echo "// Memory Management"
    [ "$(parse_config FEATURE_MM_ZRAM)" = "yes" ] && echo "const FEATURE_MM_ZRAM: bool = true;" || echo "const FEATURE_MM_ZRAM: bool = false;"
    [ "$(parse_config FEATURE_MM_SLAB)" = "yes" ] && echo "const FEATURE_MM_SLAB: bool = true;" || echo "const FEATURE_MM_SLAB: bool = false;"
    [ "$(parse_config FEATURE_MM_SWAP)" = "yes" ] && echo "const FEATURE_MM_SWAP: bool = true;" || echo "const FEATURE_MM_SWAP: bool = false;"
    [ "$(parse_config FEATURE_MM_MEMCG)" = "yes" ] && echo "const FEATURE_MM_MEMCG: bool = true;" || echo "const FEATURE_MM_MEMCG: bool = false;"
    [ "$(parse_config FEATURE_MM_HUGEPAGES)" = "yes" ] && echo "const FEATURE_MM_HUGEPAGES: bool = true;" || echo "const FEATURE_MM_HUGEPAGES: bool = false;"

    echo ""
    echo "// Security"
    [ "$(parse_config FEATURE_SEC_CAPABILITIES)" = "yes" ] && echo "const FEATURE_SEC_CAPABILITIES: bool = true;" || echo "const FEATURE_SEC_CAPABILITIES: bool = false;"
    [ "$(parse_config FEATURE_SEC_SECCOMP)" = "yes" ] && echo "const FEATURE_SEC_SECCOMP: bool = true;" || echo "const FEATURE_SEC_SECCOMP: bool = false;"
    [ "$(parse_config FEATURE_SEC_AUDIT)" = "yes" ] && echo "const FEATURE_SEC_AUDIT: bool = true;" || echo "const FEATURE_SEC_AUDIT: bool = false;"
    [ "$(parse_config FEATURE_SEC_SMEP_SMAP)" = "yes" ] && echo "const FEATURE_SEC_SMEP_SMAP: bool = true;" || echo "const FEATURE_SEC_SMEP_SMAP: bool = false;"
    [ "$(parse_config FEATURE_SEC_KASAN)" = "yes" ] && echo "const FEATURE_SEC_KASAN: bool = true;" || echo "const FEATURE_SEC_KASAN: bool = false;"

    echo ""
    echo "// Networking"
    [ "$(parse_config FEATURE_NET_TCP)" = "yes" ] && echo "const FEATURE_NET_TCP: bool = true;" || echo "const FEATURE_NET_TCP: bool = false;"
    [ "$(parse_config FEATURE_NET_UDP)" = "yes" ] && echo "const FEATURE_NET_UDP: bool = true;" || echo "const FEATURE_NET_UDP: bool = false;"
    [ "$(parse_config FEATURE_NET_DNS)" = "yes" ] && echo "const FEATURE_NET_DNS: bool = true;" || echo "const FEATURE_NET_DNS: bool = false;"
    [ "$(parse_config FEATURE_NET_HTTP)" = "yes" ] && echo "const FEATURE_NET_HTTP: bool = true;" || echo "const FEATURE_NET_HTTP: bool = false;"
    [ "$(parse_config FEATURE_NET_TLS)" = "yes" ] && echo "const FEATURE_NET_TLS: bool = true;" || echo "const FEATURE_NET_TLS: bool = false;"
    [ "$(parse_config FEATURE_NET_IPV6)" = "yes" ] && echo "const FEATURE_NET_IPV6: bool = true;" || echo "const FEATURE_NET_IPV6: bool = false;"

    echo ""
    echo "// File Systems"
    [ "$(parse_config FEATURE_FS_FAT32)" = "yes" ] && echo "const FEATURE_FS_FAT32: bool = true;" || echo "const FEATURE_FS_FAT32: bool = false;"
    [ "$(parse_config FEATURE_FS_EXT2)" = "yes" ] && echo "const FEATURE_FS_EXT2: bool = true;" || echo "const FEATURE_FS_EXT2: bool = false;"
    [ "$(parse_config FEATURE_FS_BTRFS)" = "yes" ] && echo "const FEATURE_FS_BTRFS: bool = true;" || echo "const FEATURE_FS_BTRFS: bool = false;"
    [ "$(parse_config FEATURE_FS_NTFS)" = "yes" ] && echo "const FEATURE_FS_NTFS: bool = true;" || echo "const FEATURE_FS_NTFS: bool = false;"

    echo ""
    echo "// GUI"
    [ "$(parse_config FEATURE_GUI_CRAFT)" = "yes" ] && echo "const FEATURE_GUI_CRAFT: bool = true;" || echo "const FEATURE_GUI_CRAFT: bool = false;"
    [ "$(parse_config FEATURE_GUI_COMPOSITOR)" = "yes" ] && echo "const FEATURE_GUI_COMPOSITOR: bool = true;" || echo "const FEATURE_GUI_COMPOSITOR: bool = false;"
    [ "$(parse_config FEATURE_GUI_VULKAN)" = "yes" ] && echo "const FEATURE_GUI_VULKAN: bool = true;" || echo "const FEATURE_GUI_VULKAN: bool = false;"
    [ "$(parse_config FEATURE_GUI_OPENGL)" = "yes" ] && echo "const FEATURE_GUI_OPENGL: bool = true;" || echo "const FEATURE_GUI_OPENGL: bool = false;"

    echo ""
    echo "// Build Settings"
    local target_ram=$(parse_config "TARGET_RAM_MB")
    local target_boot=$(parse_config "TARGET_BOOT_MS")
    echo "const TARGET_RAM_MB: u32 = ${target_ram:-256};"
    echo "const TARGET_BOOT_MS: u32 = ${target_boot:-3000};"
}

# Generate summary
print_summary() {
    echo ""
    echo "=== Build Configuration Summary ==="
    echo ""
    echo "Profile:    $(parse_config PROFILE)"
    echo "Target:     $(parse_config TARGET_ARCH)"
    echo "Optimize:   $(parse_config OPTIMIZE)"
    echo ""

    echo "Features enabled:"

    # Count enabled features
    local count=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^FEATURE_.*=yes$ ]]; then
            count=$((count + 1))
            feature=$(echo "$line" | sed 's/FEATURE_//' | sed 's/=yes//')
            echo "  + $feature"
        fi
    done < "$CONFIG_FILE"

    echo ""
    echo "Total features: $count"
    echo ""
}

# Main
case "${2:-}" in
    --defines)
        generate_defines
        ;;
    --summary)
        print_summary
        ;;
    *)
        print_summary
        ;;
esac
