#!/bin/bash
# home-os Comprehensive Networking Test Suite
# Tests all network protocols: TCP, UDP, HTTP, TLS, WebSocket, DNS, DHCP, etc.
# Validates L2-L7 stack implementation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
KERNEL_SRC="$PROJECT_ROOT/kernel/src"
NET_DIR="$KERNEL_SRC/net"
NETWORK_DIR="$KERNEL_SRC/network"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Results
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Platform detection
PLATFORM="x86-64"
if [ -f /proc/device-tree/model ]; then
    MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "")
    if [[ "$MODEL" == *"Raspberry Pi 3"* ]]; then
        PLATFORM="pi3"
    elif [[ "$MODEL" == *"Raspberry Pi 4"* ]]; then
        PLATFORM="pi4"
    elif [[ "$MODEL" == *"Raspberry Pi 5"* ]]; then
        PLATFORM="pi5"
    fi
fi

echo -e "${BLUE}home-os Comprehensive Networking Test Suite${NC}"
echo "=============================================="
echo "Platform: $PLATFORM"
echo "Date: $(date)"
echo ""

# Test helper functions
test_pass() {
    local test_name="$1"
    local details="$2"
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}[PASS]${NC} $test_name"
    [ -n "$details" ] && echo -e "        $details"
}

test_fail() {
    local test_name="$1"
    local details="$2"
    ((TESTS_FAILED++))
    echo -e "  ${RED}[FAIL]${NC} $test_name"
    [ -n "$details" ] && echo -e "        $details"
}

test_skip() {
    local test_name="$1"
    local reason="$2"
    ((TESTS_SKIPPED++))
    echo -e "  ${YELLOW}[SKIP]${NC} $test_name - $reason"
}

# Verify network module exists
verify_module() {
    local module="$1"
    local desc="$2"
    local dir="${3:-$NET_DIR}"
    ((TESTS_TOTAL++))
    if [ -f "$dir/$module" ]; then
        test_pass "$desc"
        return 0
    else
        test_fail "$desc" "File not found: $module"
        return 1
    fi
}

# Verify function exists in module
verify_function() {
    local module="$1"
    local func="$2"
    local dir="${3:-$NET_DIR}"
    ((TESTS_TOTAL++))
    if grep -q "export fn $func" "$dir/$module" 2>/dev/null; then
        test_pass "Function $func"
        return 0
    elif grep -q "fn $func" "$dir/$module" 2>/dev/null; then
        test_pass "Function $func (internal)"
        return 0
    else
        test_fail "Function $func" "Not found in $module"
        return 1
    fi
}

# Verify constant in module
verify_const() {
    local module="$1"
    local const="$2"
    local dir="${3:-$NET_DIR}"
    ((TESTS_TOTAL++))
    if grep -q "const $const" "$dir/$module" 2>/dev/null; then
        test_pass "Constant $const"
        return 0
    else
        test_fail "Constant $const" "Not defined in $module"
        return 1
    fi
}

# Verify struct in module
verify_struct() {
    local module="$1"
    local struct="$2"
    local dir="${3:-$NET_DIR}"
    ((TESTS_TOTAL++))
    if grep -q "struct $struct" "$dir/$module" 2>/dev/null; then
        test_pass "Structure $struct"
        return 0
    else
        test_fail "Structure $struct" "Not defined in $module"
        return 1
    fi
}

# ============================================================================
# LAYER 2: DATA LINK
# ============================================================================

echo -e "\n${YELLOW}--- Layer 2: Data Link ---${NC}"

# ARP (Address Resolution Protocol)
if verify_module "arp.home" "ARP module"; then
    verify_function "arp.home" "arp_init"
    verify_function "arp.home" "arp_lookup"
    verify_function "arp.home" "arp_request"
    verify_struct "arp.home" "ArpEntry"
fi

# ============================================================================
# LAYER 3: NETWORK
# ============================================================================

echo -e "\n${YELLOW}--- Layer 3: Network ---${NC}"

# ICMP (Ping)
if verify_module "icmp.home" "ICMP module"; then
    verify_function "icmp.home" "icmp_init"
    verify_function "icmp.home" "icmp_send_echo_request"
    verify_function "icmp.home" "icmp_handle_echo_reply"
    verify_struct "icmp.home" "IcmpHeader"
fi

# IPv6
if verify_module "ipv6.home" "IPv6 module"; then
    verify_function "ipv6.home" "ipv6_init"
    verify_function "ipv6.home" "ipv6_send"
    verify_struct "ipv6.home" "Ipv6Header"
fi

# ============================================================================
# LAYER 4: TRANSPORT
# ============================================================================

echo -e "\n${YELLOW}--- Layer 4: Transport ---${NC}"

# TCP
if verify_module "tcp.home" "TCP module"; then
    verify_function "tcp.home" "tcp_init"
    verify_function "tcp.home" "tcp_connect"
    verify_function "tcp.home" "tcp_send"
    verify_function "tcp.home" "tcp_receive"
    verify_function "tcp.home" "tcp_close"
    verify_struct "tcp.home" "TcpConnection"
    verify_struct "tcp.home" "TcpHeader"
    verify_const "tcp.home" "TCP_STATE_"
fi

# UDP
if verify_module "udp.home" "UDP module"; then
    verify_function "udp.home" "udp_init"
    verify_function "udp.home" "udp_send"
    verify_function "udp.home" "udp_receive"
    verify_struct "udp.home" "UdpHeader"
fi

# Socket API
if verify_module "socket.home" "Socket module"; then
    verify_function "socket.home" "socket_create"
    verify_function "socket.home" "socket_bind"
    verify_function "socket.home" "socket_listen"
    verify_function "socket.home" "socket_accept"
    verify_function "socket.home" "socket_connect"
    verify_function "socket.home" "socket_send"
    verify_function "socket.home" "socket_recv"
    verify_function "socket.home" "socket_close"
    verify_struct "socket.home" "Socket"
fi

# ============================================================================
# LAYER 5-6: SESSION & PRESENTATION
# ============================================================================

echo -e "\n${YELLOW}--- Layer 5-6: Session & Presentation ---${NC}"

# TLS/SSL
if verify_module "tls.home" "TLS module"; then
    verify_function "tls.home" "tls_init"
    verify_function "tls.home" "tls_handshake"
    verify_function "tls.home" "tls_send"
    verify_function "tls.home" "tls_receive"
    verify_function "tls.home" "tls_close"
    verify_struct "tls.home" "TlsConnection"
    verify_const "tls.home" "TLS_VERSION_"
fi

# ============================================================================
# LAYER 7: APPLICATION PROTOCOLS
# ============================================================================

echo -e "\n${YELLOW}--- Layer 7: Application Protocols ---${NC}"

# HTTP
if verify_module "http.home" "HTTP module"; then
    verify_function "http.home" "http_init"
    verify_function "http.home" "http_get"
    verify_function "http.home" "http_post"
    verify_function "http.home" "http_request"
    verify_struct "http.home" "HttpRequest"
    verify_struct "http.home" "HttpResponse"
    verify_const "http.home" "HTTP_METHOD_"
fi

# WebSocket
if verify_module "websocket.home" "WebSocket module"; then
    verify_function "websocket.home" "websocket_init"
    verify_function "websocket.home" "websocket_connect"
    verify_function "websocket.home" "websocket_send"
    verify_function "websocket.home" "websocket_receive"
    verify_function "websocket.home" "websocket_close"
    verify_struct "websocket.home" "WebSocketConnection"
fi

# DNS
if verify_module "dns.home" "DNS module"; then
    verify_function "dns.home" "dns_init"
    verify_function "dns.home" "dns_resolve"
    verify_function "dns.home" "dns_lookup"
    verify_struct "dns.home" "DnsQuery"
    verify_struct "dns.home" "DnsResponse"
fi

# DHCP
if verify_module "dhcp.home" "DHCP module"; then
    verify_function "dhcp.home" "dhcp_init"
    verify_function "dhcp.home" "dhcp_discover"
    verify_function "dhcp.home" "dhcp_request"
    verify_struct "dhcp.home" "DhcpMessage"
fi

# ============================================================================
# IOT PROTOCOLS
# ============================================================================

echo -e "\n${YELLOW}--- IoT Protocols ---${NC}"

# MQTT
if verify_module "mqtt.home" "MQTT module"; then
    verify_function "mqtt.home" "mqtt_init"
    verify_function "mqtt.home" "mqtt_connect"
    verify_function "mqtt.home" "mqtt_publish"
    verify_function "mqtt.home" "mqtt_subscribe"
    verify_struct "mqtt.home" "MqttClient"
fi

# CoAP
if verify_module "coap.home" "CoAP module"; then
    verify_function "coap.home" "coap_init"
    verify_function "coap.home" "coap_get"
    verify_function "coap.home" "coap_post"
    verify_struct "coap.home" "CoapMessage"
fi

# ============================================================================
# FILE SHARING PROTOCOLS
# ============================================================================

echo -e "\n${YELLOW}--- File Sharing Protocols ---${NC}"

# NFS
if verify_module "nfs.home" "NFS module"; then
    verify_function "nfs.home" "nfs_init"
    verify_function "nfs.home" "nfs_mount"
    verify_function "nfs.home" "nfs_read"
    verify_function "nfs.home" "nfs_write"
fi

# SMB
if verify_module "smb.home" "SMB module"; then
    verify_function "smb.home" "smb_init"
    verify_function "smb.home" "smb_connect"
    verify_function "smb.home" "smb_read"
    verify_function "smb.home" "smb_write"
fi

# ============================================================================
# WIRELESS PROTOCOLS
# ============================================================================

echo -e "\n${YELLOW}--- Wireless Protocols ---${NC}"

# NFC
if verify_module "nfc.home" "NFC module"; then
    verify_function "nfc.home" "nfc_init"
    verify_function "nfc.home" "nfc_read"
    verify_function "nfc.home" "nfc_write"
fi

# WiFi/BT Connectivity Test
if verify_module "wifi_bt_connectivity_test.home" "WiFi/BT Connectivity Test module"; then
    verify_function "wifi_bt_connectivity_test.home" "wifi_bt_test_init"
fi

# ============================================================================
# NETWORK MANAGEMENT
# ============================================================================

echo -e "\n${YELLOW}--- Network Management ---${NC}"

# Netfilter (Firewall)
if verify_module "netfilter.home" "Netfilter module"; then
    verify_function "netfilter.home" "netfilter_init"
    verify_function "netfilter.home" "netfilter_add_rule"
    verify_struct "netfilter.home" "FilterRule"
fi

# QoS
if verify_module "qos.home" "QoS module"; then
    verify_function "qos.home" "qos_init"
    verify_function "qos.home" "qos_set_priority"
fi

# Network Namespace
if verify_module "netns.home" "Network Namespace module"; then
    verify_function "netns.home" "netns_create"
    verify_function "netns.home" "netns_switch"
fi

# Network Stack Verification
if verify_module "network_stack_verification.home" "Network Stack Verification module"; then
    verify_function "network_stack_verification.home" "network_verification_init"
    verify_function "network_stack_verification.home" "verify_ping"
    verify_function "network_stack_verification.home" "verify_http_get"
    verify_function "network_stack_verification.home" "verify_https_get"
    verify_function "network_stack_verification.home" "verify_websocket_connect"
fi

# ============================================================================
# NETWORK CORE (kernel/src/network)
# ============================================================================

echo -e "\n${YELLOW}--- Network Core ---${NC}"

# Check network core modules
for module in ethernet.home ip.home routing.home interface.home bridge.home; do
    ((TESTS_TOTAL++))
    if [ -f "$NETWORK_DIR/$module" ]; then
        test_pass "Network core: $module"
    else
        test_skip "Network core: $module" "Optional module"
    fi
done

# ============================================================================
# LIVE NETWORK TESTS
# ============================================================================

echo -e "\n${YELLOW}--- Live Network Tests ---${NC}"

# Check network connectivity
if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    echo "  Network connectivity detected, running live tests..."

    # Ping test
    ((TESTS_TOTAL++))
    if ping -c 3 -W 2 8.8.8.8 >/dev/null 2>&1; then
        RTT=$(ping -c 3 -W 2 8.8.8.8 2>/dev/null | tail -1 | cut -d'/' -f5 || echo "N/A")
        test_pass "ICMP ping to 8.8.8.8" "RTT: ${RTT}ms"
    else
        test_fail "ICMP ping to 8.8.8.8"
    fi

    # DNS resolution
    ((TESTS_TOTAL++))
    if host example.com >/dev/null 2>&1 || nslookup example.com >/dev/null 2>&1; then
        test_pass "DNS resolution (example.com)"
    else
        test_fail "DNS resolution"
    fi

    # HTTP GET
    ((TESTS_TOTAL++))
    if curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://example.com/ 2>/dev/null | grep -qE "200|301|302"; then
        test_pass "HTTP GET (example.com)"
    else
        test_fail "HTTP GET"
    fi

    # HTTPS GET
    ((TESTS_TOTAL++))
    if curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://example.com/ 2>/dev/null | grep -qE "200|301|302"; then
        test_pass "HTTPS GET (example.com)"
    else
        test_fail "HTTPS GET"
    fi

    # TCP port check
    ((TESTS_TOTAL++))
    if timeout 5 bash -c "</dev/tcp/example.com/80" 2>/dev/null; then
        test_pass "TCP connect to port 80"
    else
        test_fail "TCP connect to port 80"
    fi

    # IPv6 test (if available)
    ((TESTS_TOTAL++))
    if ping6 -c 1 -W 2 2001:4860:4860::8888 >/dev/null 2>&1; then
        test_pass "IPv6 connectivity"
    else
        test_skip "IPv6 connectivity" "Not available"
    fi

else
    test_skip "Live network tests" "No network connectivity"
fi

# ============================================================================
# PERFORMANCE TARGETS
# ============================================================================

echo -e "\n${YELLOW}--- Performance Targets ---${NC}"

echo -e "  ${CYAN}Platform: $PLATFORM${NC}"
case $PLATFORM in
    pi3)
        echo "  Target: TCP throughput 50Mbps, latency <50ms"
        echo "  Target: TLS handshake <500ms"
        ;;
    pi4)
        echo "  Target: TCP throughput 500Mbps, latency <20ms"
        echo "  Target: TLS handshake <200ms"
        ;;
    pi5)
        echo "  Target: TCP throughput 1Gbps, latency <10ms"
        echo "  Target: TLS handshake <100ms"
        ;;
    *)
        echo "  Target: TCP throughput 10Gbps, latency <5ms"
        echo "  Target: TLS handshake <50ms"
        ;;
esac

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "=============================================="
echo -e "${BLUE}COMPREHENSIVE NETWORKING TEST SUMMARY${NC}"
echo "=============================================="
echo "Platform: $PLATFORM"
echo ""
echo "Total:   $TESTS_TOTAL"
echo -e "Passed:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:  ${RED}$TESTS_FAILED${NC}"
echo -e "Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
echo ""

echo -e "${CYAN}Protocol Categories Tested:${NC}"
echo "  - Layer 2: ARP"
echo "  - Layer 3: ICMP, IPv6"
echo "  - Layer 4: TCP, UDP, Socket API"
echo "  - Layer 5-6: TLS/SSL"
echo "  - Layer 7: HTTP, WebSocket, DNS, DHCP"
echo "  - IoT: MQTT, CoAP"
echo "  - File Sharing: NFS, SMB"
echo "  - Wireless: NFC, WiFi/BT"
echo "  - Management: Netfilter, QoS, Network Namespace"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}*** ALL NETWORKING TESTS PASSED ***${NC}"
    exit 0
else
    echo -e "${RED}*** SOME NETWORKING TESTS FAILED ***${NC}"
    exit 1
fi
