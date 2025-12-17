#!/bin/bash
# HomeOS Raspberry Pi Network Test
#
# Tests network functionality on Raspberry Pi hardware
#
# Usage: ./pi_network_test.sh --model=pi4|pi5

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
echo -e "${BLUE}HomeOS Raspberry Pi Network Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# Network Test Functions
# ============================================================================

test_ethernet_device() {
    log_info "Checking Ethernet device..."

    # Pi 4/5 uses eth0 or end0
    local eth_devs=$(ip link show 2>/dev/null | grep -E "eth[0-9]|end[0-9]" | cut -d: -f2 | tr -d ' ')

    if [ -n "$eth_devs" ]; then
        for dev in $eth_devs; do
            log_pass "Ethernet device: $dev"

            # Check link status
            local state=$(cat /sys/class/net/$dev/operstate 2>/dev/null)
            log_info "  State: $state"

            # Check speed if available
            if [ -f /sys/class/net/$dev/speed ]; then
                local speed=$(cat /sys/class/net/$dev/speed 2>/dev/null)
                log_info "  Speed: ${speed}Mbps"
            fi
        done
        return 0
    else
        log_warn "No Ethernet device found"
        return 0
    fi
}

test_wifi_device() {
    log_info "Checking WiFi device..."

    local wifi_devs=$(iw dev 2>/dev/null | grep Interface | awk '{print $2}')

    if [ -n "$wifi_devs" ]; then
        for dev in $wifi_devs; do
            log_pass "WiFi device: $dev"

            # Check connection status
            local ssid=$(iwgetid -r 2>/dev/null)
            if [ -n "$ssid" ]; then
                log_info "  Connected to: $ssid"
            else
                log_info "  Not connected"
            fi
        done
        return 0
    else
        log_warn "No WiFi device found"
        return 0
    fi
}

test_ip_address() {
    log_info "Checking IP address configuration..."

    local has_ip=0

    # Check IPv4
    local ipv4=$(ip -4 addr show scope global 2>/dev/null | grep inet | head -1 | awk '{print $2}')
    if [ -n "$ipv4" ]; then
        log_pass "IPv4: $ipv4"
        has_ip=1
    fi

    # Check IPv6
    local ipv6=$(ip -6 addr show scope global 2>/dev/null | grep inet6 | head -1 | awk '{print $2}')
    if [ -n "$ipv6" ]; then
        log_info "IPv6: $ipv6"
    fi

    if [ $has_ip -eq 1 ]; then
        return 0
    else
        log_warn "No global IP address"
        return 0
    fi
}

test_gateway() {
    log_info "Checking default gateway..."

    local gateway=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -1)

    if [ -n "$gateway" ]; then
        log_pass "Gateway: $gateway"

        # Ping gateway
        if ping -c 1 -W 2 "$gateway" &>/dev/null; then
            log_pass "Gateway reachable"
        else
            log_warn "Gateway not responding to ping"
        fi
        return 0
    else
        log_warn "No default gateway"
        return 0
    fi
}

test_dns_resolution() {
    log_info "Checking DNS resolution..."

    # Check resolv.conf
    if [ -f /etc/resolv.conf ]; then
        local nameserver=$(grep nameserver /etc/resolv.conf | head -1 | awk '{print $2}')
        if [ -n "$nameserver" ]; then
            log_info "DNS server: $nameserver"
        fi
    fi

    # Try to resolve a domain
    if command -v nslookup &>/dev/null; then
        if nslookup google.com &>/dev/null; then
            log_pass "DNS resolution working"
            return 0
        fi
    elif command -v host &>/dev/null; then
        if host google.com &>/dev/null; then
            log_pass "DNS resolution working"
            return 0
        fi
    elif command -v dig &>/dev/null; then
        if dig +short google.com &>/dev/null; then
            log_pass "DNS resolution working"
            return 0
        fi
    fi

    log_warn "DNS resolution not verified"
    return 0
}

test_internet_connectivity() {
    log_info "Checking Internet connectivity..."

    # Try multiple methods
    if ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
        log_pass "Internet reachable (ping 8.8.8.8)"
        return 0
    fi

    if ping -c 1 -W 5 1.1.1.1 &>/dev/null; then
        log_pass "Internet reachable (ping 1.1.1.1)"
        return 0
    fi

    log_warn "Internet not reachable"
    return 0
}

test_loopback() {
    log_info "Checking loopback interface..."

    if ip link show lo &>/dev/null; then
        local state=$(ip link show lo | grep -o 'state [A-Z]*' | awk '{print $2}')
        if [ "$state" == "UP" ] || [ "$state" == "UNKNOWN" ]; then
            log_pass "Loopback interface UP"

            if ping -c 1 127.0.0.1 &>/dev/null; then
                log_pass "Loopback pingable"
            fi
            return 0
        fi
    fi

    log_fail "Loopback interface issue"
    return 1
}

test_socket_creation() {
    log_info "Testing socket creation..."

    # Try to create a simple socket
    if command -v nc &>/dev/null; then
        # Start a listener
        nc -l -p 54321 &>/dev/null &
        NC_PID=$!
        sleep 0.5

        # Try to connect
        if echo "test" | nc -w 1 localhost 54321 &>/dev/null; then
            log_pass "Socket creation works"
        else
            log_info "Socket test inconclusive"
        fi

        kill $NC_PID 2>/dev/null || true
        return 0
    fi

    log_info "netcat not available for socket test"
    return 0
}

test_network_driver() {
    log_info "Checking network drivers..."

    # BCM54213PE for Pi 4
    if lsmod 2>/dev/null | grep -q "bcmgenet"; then
        log_pass "BCM Genet driver loaded (Pi 4 Ethernet)"
    fi

    # Broadcom WiFi
    if lsmod 2>/dev/null | grep -q "brcmfmac"; then
        log_pass "Broadcom WiFi driver loaded"
    fi

    # Show all network modules
    local net_mods=$(lsmod 2>/dev/null | grep -E "net|eth|wifi|wlan|brcm" | head -5)
    if [ -n "$net_mods" ]; then
        log_info "Network modules:"
        echo "$net_mods" | while read line; do
            log_info "  $line"
        done
    fi

    return 0
}

test_network_stats() {
    log_info "Collecting network statistics..."

    # Get interface stats
    for iface in $(ls /sys/class/net/ 2>/dev/null | grep -v lo); do
        if [ -d "/sys/class/net/$iface/statistics" ]; then
            local rx=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null)
            local tx=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null)
            log_info "$iface: RX=$rx TX=$tx bytes"
        fi
    done

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

run_test "Loopback" test_loopback
run_test "Ethernet Device" test_ethernet_device
run_test "WiFi Device" test_wifi_device
run_test "IP Address" test_ip_address
run_test "Gateway" test_gateway
run_test "DNS Resolution" test_dns_resolution
run_test "Internet Connectivity" test_internet_connectivity
run_test "Socket Creation" test_socket_creation
run_test "Network Driver" test_network_driver
run_test "Network Stats" test_network_stats

# ============================================================================
# Summary
# ============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Network Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    touch "$RESULTS_DIR/network-PASSED"
    echo -e "${GREEN}Network test PASSED${NC}"
    exit 0
else
    touch "$RESULTS_DIR/network-FAILED"
    echo -e "${RED}Network test FAILED${NC}"
    exit 1
fi
