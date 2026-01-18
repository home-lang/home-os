# Networking Stack

HomeOS implements a comprehensive networking stack with 20+ protocols, from low-level TCP/IP to application protocols like HTTP and WebSocket.

## Protocol Stack

```
┌─────────────────────────────────────┐
│       Application Layer             │
│  HTTP, WebSocket, MQTT, CoAP, DNS   │
├─────────────────────────────────────┤
│       Security Layer                │
│        TLS 1.2/1.3                  │
├─────────────────────────────────────┤
│       Transport Layer               │
│         TCP, UDP                    │
├─────────────────────────────────────┤
│       Network Layer                 │
│      IPv4, IPv6, ICMP               │
├─────────────────────────────────────┤
│       Link Layer                    │
│     Ethernet, ARP, DHCP             │
├─────────────────────────────────────┤
│       Device Drivers                │
│  E1000, RTL8139, VirtIO, WiFi, BT   │
└─────────────────────────────────────┘
```

## Supported Protocols

| Protocol | Layer | Status | Description |
|----------|-------|--------|-------------|
| TCP | Transport | Complete | Reliable stream protocol |
| UDP | Transport | Complete | Datagram protocol |
| IPv4 | Network | Complete | Internet Protocol v4 |
| IPv6 | Network | Partial | Internet Protocol v6 |
| ICMP | Network | Complete | Ping, errors |
| ARP | Link | Complete | Address resolution |
| DHCP | Application | Complete | Dynamic IP configuration |
| DNS | Application | Complete | Domain name resolution |
| HTTP/1.1 | Application | Complete | Web protocol |
| HTTPS | Application | Complete | Secure HTTP (via TLS) |
| WebSocket | Application | Complete | Full-duplex communication |
| TLS 1.2/1.3 | Security | Complete | Transport security |
| MQTT | Application | Complete | IoT messaging |
| CoAP | Application | Complete | Constrained devices |
| NFS | Application | Partial | Network file system |
| SMB/CIFS | Application | Partial | Windows file sharing |
| NFC | Link | Basic | Near-field communication |

## Core Protocols

### TCP/IP

The TCP implementation follows RFC 793 with modern extensions.

**Features:**
- Full state machine (11 states)
- Three-way handshake
- Four-way termination
- Sliding window flow control
- Retransmission with exponential backoff
- Congestion control (slow start, congestion avoidance)
- Nagle's algorithm (optional)
- Keep-alive support
- TCP options (MSS, window scale, timestamps)

**Location:** `kernel/src/net/tcp.home`

**API:**
```home
// Create connection
let fd = tcp_connect(ip_address, port)

// Listen for connections
let listen_fd = tcp_listen(port, backlog)
let client_fd = tcp_accept(listen_fd)

// Send/receive data
tcp_send(fd, data, length)
tcp_recv(fd, buffer, max_length)

// Close connection
tcp_close(fd)
```

### UDP

Connectionless datagram protocol for low-latency communication.

**Features:**
- No connection overhead
- Broadcast/multicast support
- Checksum validation

**Location:** `kernel/src/net/udp.home`

**API:**
```home
let fd = udp_socket()
udp_bind(fd, port)
udp_sendto(fd, data, length, dest_ip, dest_port)
udp_recvfrom(fd, buffer, max_length, &src_ip, &src_port)
udp_close(fd)
```

### ICMP

Internet Control Message Protocol for diagnostics.

**Features:**
- Echo request/reply (ping)
- Destination unreachable
- Time exceeded
- Redirect messages

**Location:** `kernel/src/net/icmp.home`

### ARP

Address Resolution Protocol for IP-to-MAC mapping.

**Features:**
- ARP cache with TTL
- Gratuitous ARP support
- ARP request/reply

**Location:** `kernel/src/net/arp.home`

## Application Protocols

### DNS

Domain name resolution with caching.

**Features:**
- UDP-based resolution
- 64-entry TTL-aware cache
- Multiple nameserver support
- `/etc/resolv.conf` parsing
- Search domain support
- Retry with fallback servers

**Location:** `kernel/src/net/dns.home`

**API:**
```home
let ip = dns_resolve("example.com")
let ip_cached = dns_resolve_cached("example.com")
dns_load_resolv_conf()
```

### DHCP

Dynamic Host Configuration Protocol for automatic network configuration.

**Features:**
- DHCP discover/offer/request/ack
- Lease management
- Router and DNS server discovery
- Renewal and rebinding

**Location:** `kernel/src/net/dhcp.home`

**API:**
```home
dhcp_init()
let lease = dhcp_discover("eth0")
dhcp_renew(lease)
dhcp_release(lease)
```

### HTTP/HTTPS

HTTP/1.1 client and server implementation.

**Features:**
- GET, POST, PUT, DELETE methods
- Chunked transfer encoding
- Keep-alive connections
- HTTPS via TLS integration

**Location:** `kernel/src/net/http.home`

**API:**
```home
struct HTTPResponse {
  status_code: u32
  headers: *u8
  body: *u8
  body_length: u32
}

// Client API
http_get(url, &response)
http_post(url, body, &response)
https_get(url, &response)
https_post(url, body, &response)
```

### WebSocket

Full-duplex communication over HTTP upgrade (RFC 6455).

**Features:**
- Text and binary frames
- Ping/pong heartbeat
- Frame masking (client-side)
- Fragmentation support
- Automatic reconnection

**Location:** `kernel/src/net/websocket.home`

**API:**
```home
let fd = ws_connect("wss://example.com/socket")
ws_send_text(fd, "Hello, World!")
ws_send_binary(fd, data, length)
ws_recv(fd, &message)
ws_close(fd, 1000)  // Normal closure
```

## Security

### TLS 1.2/1.3

Transport Layer Security for encrypted communication.

**Cipher Suites:**
- TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
- TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
- TLS 1.3 cipher suites

**Features:**
- ECDHE key exchange
- AES-GCM encryption (128/256-bit)
- Certificate validation
- SNI (Server Name Indication)
- Session resumption
- Audit logging for security events

**Location:** `kernel/src/net/tls.home`

**API:**
```home
let tls_fd = tls_connect(tcp_fd, hostname)
tls_send(tls_fd, data, length)
tls_recv(tls_fd, buffer, max_length)
tls_close(tls_fd)
```

### Netfilter (Firewall)

Packet filtering and firewall functionality.

**Features:**
- INPUT, OUTPUT, FORWARD chains
- ACCEPT, DROP, REJECT actions
- IP/port-based filtering
- Protocol filtering (TCP, UDP, ICMP)
- Connection tracking (stateful)
- Audit logging

**Location:** `kernel/src/net/netfilter.home`

**API:**
```home
netfilter_add_rule(chain, &rule)
netfilter_delete_rule(chain, rule_id)
netfilter_set_policy(chain, policy)
netfilter_list_rules(chain)
```

**Example rules:**
```home
// Allow SSH
let rule = FilterRule {
  protocol: PROTO_TCP
  dest_port: 22
  action: ACTION_ACCEPT
}
netfilter_add_rule(CHAIN_INPUT, &rule)

// Drop all other incoming
netfilter_set_policy(CHAIN_INPUT, ACTION_DROP)
```

## IoT Protocols

### MQTT

Message Queuing Telemetry Transport for IoT.

**Features:**
- Publish/subscribe model
- QoS levels 0, 1, 2
- Retained messages
- Last will and testament
- Keep-alive heartbeat

**Location:** `kernel/src/net/mqtt.home`

**API:**
```home
let client = mqtt_connect(broker_host, broker_port)
mqtt_subscribe(client, "sensors/temperature", qos_1)
mqtt_publish(client, "sensors/temperature", "25.5", qos_1)
mqtt_recv(client, &message)
mqtt_disconnect(client)
```

### CoAP

Constrained Application Protocol for resource-limited devices.

**Features:**
- RESTful design
- UDP-based
- Observe pattern
- Block transfers
- Resource discovery

**Location:** `kernel/src/net/coap.home`

**API:**
```home
let client = coap_client_init()
coap_get(client, "coap://device/sensor", &response)
coap_put(client, "coap://device/led", "on")
coap_observe(client, "coap://device/sensor", callback)
```

## Network Configuration

### Static Configuration

```bash
# Set IP address
ifconfig eth0 192.168.1.100 netmask 255.255.255.0

# Set gateway
route add default gw 192.168.1.1

# Set DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

### DHCP Configuration

```bash
# Start DHCP client
dhclient eth0

# Check assigned address
ifconfig eth0
```

### WiFi Configuration

```home
wifi_init()
wifi_scan()
wifi_connect(ssid, password)
wifi_is_connected()
wifi_get_rssi()
wifi_disconnect()
```

## Socket API

HomeOS provides a POSIX-compatible socket API.

### Socket Types

```home
const SOCK_STREAM: u32 = 1   // TCP
const SOCK_DGRAM: u32 = 2    // UDP
const SOCK_RAW: u32 = 3      // Raw IP

const AF_INET: u32 = 2       // IPv4
const AF_INET6: u32 = 10     // IPv6
```

### Socket Operations

```home
// Create socket
let fd = socket(AF_INET, SOCK_STREAM, 0)

// Bind to address
let addr = sockaddr_in {
  sin_family: AF_INET
  sin_port: htons(8080)
  sin_addr: INADDR_ANY
}
bind(fd, &addr, sizeof(addr))

// Listen and accept
listen(fd, 10)
let client_fd = accept(fd, &client_addr, &addr_len)

// Connect (client)
connect(fd, &server_addr, sizeof(addr))

// Send/receive
send(fd, data, length, 0)
recv(fd, buffer, max_length, 0)

// Close
close(fd)
```

## Performance Metrics

### Throughput Targets

| Metric | Pi 3 | Pi 4 | Pi 5 | x86-64 |
|--------|------|------|------|--------|
| Ethernet TX | 95 Mbps | 940 Mbps | 940 Mbps | 1 Gbps |
| Ethernet RX | 95 Mbps | 940 Mbps | 940 Mbps | 1 Gbps |
| WiFi TX | 50 Mbps | 100 Mbps | 100 Mbps | N/A |
| TCP Throughput | 90% line rate | 90% line rate | 90% line rate | 90% line rate |

### Latency Targets

| Metric | Target |
|--------|--------|
| TCP connect (local) | < 1ms |
| DNS resolution (cached) | < 100us |
| TLS handshake | < 100ms |
| Ping RTT (local) | < 1ms |

## Quality of Service (QoS)

HomeOS supports traffic prioritization.

**Features:**
- Traffic classification
- Priority queuing
- Rate limiting
- DSCP marking

**Location:** `kernel/src/net/qos.home`

## Network Namespaces

Container-style network isolation.

**Features:**
- Isolated network stacks
- Virtual interfaces
- Inter-namespace routing

**Location:** `kernel/src/net/netns.home`

## Related Documentation

- [Driver Reference](/guide/drivers) - Network drivers
- [Raspberry Pi 5](/guide/rpi5) - Pi 5 networking
- [System Calls](/api/syscalls) - Network syscalls
