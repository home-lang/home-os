# Networking Stack

HomeOS implements a full TCP/IP networking stack from scratch in the Home programming language. The networking subsystem supports Ethernet, IPv4/IPv6, TCP, UDP, and higher-level protocols, providing a complete foundation for network applications.

## Overview

The networking stack in HomeOS follows a layered architecture:

- **Link Layer**: Ethernet frame handling and NIC drivers
- **Network Layer**: IP routing, ARP, ICMP
- **Transport Layer**: TCP and UDP protocols
- **Socket Layer**: BSD-compatible socket API

## Network Buffer Management

Efficient buffer management is crucial for network performance.

### Network Buffer Structure

```home
const NET_BUFFER_SIZE = 2048

const NetBuffer = struct {
    data: [NET_BUFFER_SIZE]u8,
    head: usize,
    tail: usize,
    len: usize,
    protocol: u16,
    device: *NetDevice,
    next: ?*NetBuffer,
    // Header pointers
    mac_header: usize,
    network_header: usize,
    transport_header: usize
}

// Buffer pool
const BUFFER_POOL_SIZE = 4096
let buffer_pool: [BUFFER_POOL_SIZE]NetBuffer = undefined
let free_buffers: ?*NetBuffer = null

export fn netbuf_init() {
    // Initialize buffer pool as free list
    for i in 0..BUFFER_POOL_SIZE - 1 {
        buffer_pool[i].next = &buffer_pool[i + 1]
    }
    buffer_pool[BUFFER_POOL_SIZE - 1].next = null
    free_buffers = &buffer_pool[0]
}

export fn netbuf_alloc(): ?*NetBuffer {
    if free_buffers == null {
        return null
    }

    let buf = free_buffers
    free_buffers = buf.next
    buf.next = null

    // Initialize buffer
    buf.head = 256  // Reserve space for headers
    buf.tail = 256
    buf.len = 0
    buf.mac_header = 0
    buf.network_header = 0
    buf.transport_header = 0

    return buf
}

export fn netbuf_free(buf: *NetBuffer) {
    buf.next = free_buffers
    free_buffers = buf
}

export fn netbuf_put(buf: *NetBuffer, len: usize): []u8 {
    let result = buf.data[buf.tail..buf.tail + len]
    buf.tail += len
    buf.len += len
    return result
}

export fn netbuf_push(buf: *NetBuffer, len: usize): []u8 {
    buf.head -= len
    buf.len += len
    return buf.data[buf.head..buf.head + len]
}

export fn netbuf_pull(buf: *NetBuffer, len: usize): []u8 {
    let result = buf.data[buf.head..buf.head + len]
    buf.head += len
    buf.len -= len
    return result
}
```

## Ethernet Layer

### Ethernet Frame Structure

```home
const ETH_ALEN = 6
const ETH_HLEN = 14

const EthernetHeader = packed struct {
    dest: [ETH_ALEN]u8,
    src: [ETH_ALEN]u8,
    ethertype: u16
}

const ETH_P_IP = 0x0800
const ETH_P_ARP = 0x0806
const ETH_P_IPV6 = 0x86DD

// Network device structure
const NetDevice = struct {
    name: [16]u8,
    mac_address: [6]u8,
    mtu: u32,
    flags: u32,
    ip_address: u32,
    netmask: u32,
    gateway: u32,
    ops: *NetDeviceOps,
    rx_queue: ?*NetBuffer,
    tx_queue: ?*NetBuffer,
    stats: NetDeviceStats
}

const NetDeviceOps = struct {
    open: fn (*NetDevice) i32,
    close: fn (*NetDevice) i32,
    start_xmit: fn (*NetDevice, *NetBuffer) i32,
    set_mac_address: fn (*NetDevice, [6]u8) i32
}

const NetDeviceStats = struct {
    rx_packets: u64,
    tx_packets: u64,
    rx_bytes: u64,
    tx_bytes: u64,
    rx_errors: u64,
    tx_errors: u64,
    rx_dropped: u64,
    tx_dropped: u64
}
```

### Ethernet Transmission and Reception

```home
export fn eth_send(dev: *NetDevice, buf: *NetBuffer, dest: [6]u8, protocol: u16): i32 {
    // Push Ethernet header
    let hdr_data = netbuf_push(buf, ETH_HLEN)
    let hdr: *EthernetHeader = @ptrCast(hdr_data.ptr)

    @memcpy(&hdr.dest, &dest, 6)
    @memcpy(&hdr.src, &dev.mac_address, 6)
    hdr.ethertype = htons(protocol)

    buf.mac_header = buf.head
    buf.device = dev

    // Queue for transmission
    return dev.ops.start_xmit(dev, buf)
}

export fn eth_receive(dev: *NetDevice, buf: *NetBuffer) {
    buf.mac_header = buf.head

    // Parse Ethernet header
    let hdr_data = netbuf_pull(buf, ETH_HLEN)
    let hdr: *EthernetHeader = @ptrCast(hdr_data.ptr)

    let protocol = ntohs(hdr.ethertype)
    buf.protocol = protocol
    buf.network_header = buf.head

    dev.stats.rx_packets += 1
    dev.stats.rx_bytes += buf.len + ETH_HLEN

    // Dispatch to protocol handler
    switch protocol {
        ETH_P_IP => ip_receive(buf),
        ETH_P_ARP => arp_receive(buf),
        ETH_P_IPV6 => ipv6_receive(buf),
        else => {
            // Unknown protocol
            netbuf_free(buf)
        }
    }
}
```

## ARP Protocol

```home
const ARP_HLEN = 28

const ArpHeader = packed struct {
    hardware_type: u16,
    protocol_type: u16,
    hardware_len: u8,
    protocol_len: u8,
    operation: u16,
    sender_mac: [6]u8,
    sender_ip: u32,
    target_mac: [6]u8,
    target_ip: u32
}

const ARP_REQUEST = 1
const ARP_REPLY = 2

// ARP cache
const ARP_CACHE_SIZE = 256
const ArpEntry = struct {
    ip_address: u32,
    mac_address: [6]u8,
    timestamp: u64,
    state: ArpState,
    waiting: ?*NetBuffer
}

const ArpState = enum {
    Free,
    Pending,
    Valid
}

let arp_cache: [ARP_CACHE_SIZE]ArpEntry = undefined

export fn arp_init() {
    for i in 0..ARP_CACHE_SIZE {
        arp_cache[i].state = ArpState.Free
    }
}

export fn arp_receive(buf: *NetBuffer) {
    let hdr: *ArpHeader = @ptrCast(&buf.data[buf.network_header])

    if ntohs(hdr.hardware_type) != 1 or ntohs(hdr.protocol_type) != ETH_P_IP {
        netbuf_free(buf)
        return
    }

    let op = ntohs(hdr.operation)
    let sender_ip = ntohl(hdr.sender_ip)

    // Update ARP cache with sender info
    arp_update_cache(sender_ip, hdr.sender_mac)

    if op == ARP_REQUEST {
        // Check if request is for us
        let dev = buf.device
        if ntohl(hdr.target_ip) == dev.ip_address {
            arp_send_reply(dev, hdr.sender_ip, hdr.sender_mac)
        }
    }

    netbuf_free(buf)
}

fn arp_send_reply(dev: *NetDevice, target_ip: u32, target_mac: [6]u8) {
    let buf = netbuf_alloc() ?? return

    let hdr_data = netbuf_put(buf, ARP_HLEN)
    let hdr: *ArpHeader = @ptrCast(hdr_data.ptr)

    hdr.hardware_type = htons(1)
    hdr.protocol_type = htons(ETH_P_IP)
    hdr.hardware_len = 6
    hdr.protocol_len = 4
    hdr.operation = htons(ARP_REPLY)
    @memcpy(&hdr.sender_mac, &dev.mac_address, 6)
    hdr.sender_ip = htonl(dev.ip_address)
    @memcpy(&hdr.target_mac, &target_mac, 6)
    hdr.target_ip = htonl(target_ip)

    eth_send(dev, buf, target_mac, ETH_P_ARP)
}

export fn arp_resolve(dev: *NetDevice, ip: u32, buf: *NetBuffer): bool {
    // Check cache first
    for entry in &arp_cache {
        if entry.state == ArpState.Valid and entry.ip_address == ip {
            return true
        }
    }

    // Send ARP request
    let req = netbuf_alloc() ?? return false

    let hdr_data = netbuf_put(req, ARP_HLEN)
    let hdr: *ArpHeader = @ptrCast(hdr_data.ptr)

    hdr.hardware_type = htons(1)
    hdr.protocol_type = htons(ETH_P_IP)
    hdr.hardware_len = 6
    hdr.protocol_len = 4
    hdr.operation = htons(ARP_REQUEST)
    @memcpy(&hdr.sender_mac, &dev.mac_address, 6)
    hdr.sender_ip = htonl(dev.ip_address)
    @memset(&hdr.target_mac, 0, 6)
    hdr.target_ip = htonl(ip)

    let broadcast = [_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF }
    eth_send(dev, req, broadcast, ETH_P_ARP)

    // Queue packet waiting for ARP
    let entry = arp_find_or_create_entry(ip)
    entry.state = ArpState.Pending
    buf.next = entry.waiting
    entry.waiting = buf

    return false
}
```

## IP Layer

### IPv4 Implementation

```home
const IP_HLEN = 20

const IpHeader = packed struct {
    version_ihl: u8,
    tos: u8,
    total_length: u16,
    identification: u16,
    flags_fragment: u16,
    ttl: u8,
    protocol: u8,
    checksum: u16,
    src_addr: u32,
    dest_addr: u32
}

const IPPROTO_ICMP = 1
const IPPROTO_TCP = 6
const IPPROTO_UDP = 17

export fn ip_send(buf: *NetBuffer, dest: u32, protocol: u8): i32 {
    let dev = route_lookup(dest)
    if dev == null {
        netbuf_free(buf)
        return -ENETUNREACH
    }

    // Push IP header
    let hdr_data = netbuf_push(buf, IP_HLEN)
    let hdr: *IpHeader = @ptrCast(hdr_data.ptr)

    hdr.version_ihl = 0x45  // IPv4, 20 byte header
    hdr.tos = 0
    hdr.total_length = htons(buf.len)
    hdr.identification = htons(get_next_ip_id())
    hdr.flags_fragment = 0
    hdr.ttl = 64
    hdr.protocol = protocol
    hdr.checksum = 0
    hdr.src_addr = htonl(dev.ip_address)
    hdr.dest_addr = htonl(dest)

    // Calculate checksum
    hdr.checksum = ip_checksum(hdr_data)

    buf.network_header = buf.head

    // Resolve next hop MAC address
    let next_hop = if is_local_network(dev, dest) {
        dest
    } else {
        dev.gateway
    }

    // Get destination MAC from ARP cache
    let entry = arp_lookup(next_hop)
    if entry == null or entry.state != ArpState.Valid {
        // Need ARP resolution
        if !arp_resolve(dev, next_hop, buf) {
            return 0  // Packet queued for ARP
        }
    }

    return eth_send(dev, buf, entry.mac_address, ETH_P_IP)
}

export fn ip_receive(buf: *NetBuffer) {
    let hdr: *IpHeader = @ptrCast(&buf.data[buf.network_header])

    // Validate header
    let version = (hdr.version_ihl >> 4) & 0xF
    let ihl = (hdr.version_ihl & 0xF) * 4

    if version != 4 {
        netbuf_free(buf)
        return
    }

    // Verify checksum
    if ip_checksum(buf.data[buf.network_header..buf.network_header + ihl]) != 0 {
        netbuf_free(buf)
        return
    }

    // Skip IP header
    netbuf_pull(buf, ihl)
    buf.transport_header = buf.head

    // Dispatch to transport protocol
    switch hdr.protocol {
        IPPROTO_ICMP => icmp_receive(buf, hdr),
        IPPROTO_TCP => tcp_receive(buf, hdr),
        IPPROTO_UDP => udp_receive(buf, hdr),
        else => netbuf_free(buf)
    }
}

fn ip_checksum(data: []const u8): u16 {
    let sum: u32 = 0

    var i: usize = 0
    while i < data.len - 1 {
        sum += (@as(u16, data[i]) << 8) | data[i + 1]
        i += 2
    }

    if data.len % 2 == 1 {
        sum += @as(u16, data[data.len - 1]) << 8
    }

    while sum >> 16 != 0 {
        sum = (sum & 0xFFFF) + (sum >> 16)
    }

    return ~@truncate(sum)
}
```

## TCP Protocol

### TCP Structures

```home
const TCP_HLEN = 20

const TcpHeader = packed struct {
    src_port: u16,
    dest_port: u16,
    seq_num: u32,
    ack_num: u32,
    data_offset_flags: u16,
    window: u16,
    checksum: u16,
    urgent_ptr: u16
}

const TCP_FIN = 0x01
const TCP_SYN = 0x02
const TCP_RST = 0x04
const TCP_PSH = 0x08
const TCP_ACK = 0x10
const TCP_URG = 0x20

const TcpState = enum {
    Closed,
    Listen,
    SynSent,
    SynReceived,
    Established,
    FinWait1,
    FinWait2,
    CloseWait,
    Closing,
    LastAck,
    TimeWait
}

const TcpConnection = struct {
    state: TcpState,
    local_addr: u32,
    local_port: u16,
    remote_addr: u32,
    remote_port: u16,
    send_next: u32,
    send_unack: u32,
    send_window: u16,
    recv_next: u32,
    recv_window: u16,
    send_buffer: RingBuffer,
    recv_buffer: RingBuffer,
    retransmit_queue: ?*NetBuffer,
    socket: *Socket
}

// Connection table
const MAX_TCP_CONNECTIONS = 1024
let tcp_connections: [MAX_TCP_CONNECTIONS]TcpConnection = undefined
```

### TCP State Machine

```home
export fn tcp_receive(buf: *NetBuffer, ip_hdr: *IpHeader) {
    let hdr: *TcpHeader = @ptrCast(&buf.data[buf.transport_header])

    let src_port = ntohs(hdr.src_port)
    let dest_port = ntohs(hdr.dest_port)
    let src_addr = ntohl(ip_hdr.src_addr)
    let dest_addr = ntohl(ip_hdr.dest_addr)

    // Find connection
    let conn = tcp_find_connection(dest_addr, dest_port, src_addr, src_port)

    if conn == null {
        // Check for listening socket
        let listen = tcp_find_listener(dest_port)
        if listen != null and get_tcp_flags(hdr) & TCP_SYN != 0 {
            tcp_handle_syn(listen, buf, ip_hdr)
            return
        }

        // Send RST
        tcp_send_rst(buf, ip_hdr)
        netbuf_free(buf)
        return
    }

    // Process based on state
    switch conn.state {
        TcpState.SynSent => tcp_state_syn_sent(conn, buf, hdr),
        TcpState.SynReceived => tcp_state_syn_received(conn, buf, hdr),
        TcpState.Established => tcp_state_established(conn, buf, hdr),
        TcpState.FinWait1 => tcp_state_fin_wait1(conn, buf, hdr),
        TcpState.FinWait2 => tcp_state_fin_wait2(conn, buf, hdr),
        TcpState.CloseWait => tcp_state_close_wait(conn, buf, hdr),
        TcpState.Closing => tcp_state_closing(conn, buf, hdr),
        TcpState.LastAck => tcp_state_last_ack(conn, buf, hdr),
        TcpState.TimeWait => tcp_state_time_wait(conn, buf, hdr),
        else => netbuf_free(buf)
    }
}

fn tcp_state_established(conn: *TcpConnection, buf: *NetBuffer, hdr: *TcpHeader) {
    let flags = get_tcp_flags(hdr)
    let seq = ntohl(hdr.seq_num)
    let ack = ntohl(hdr.ack_num)

    // Check ACK
    if flags & TCP_ACK != 0 {
        tcp_process_ack(conn, ack)
    }

    // Process data
    let data_offset = ((hdr.data_offset_flags >> 12) & 0xF) * 4
    let data_len = buf.len - data_offset

    if data_len > 0 and seq == conn.recv_next {
        // In-order data
        let data = buf.data[buf.transport_header + data_offset..buf.transport_header + data_offset + data_len]
        conn.recv_buffer.write(data)
        conn.recv_next += data_len

        // Send ACK
        tcp_send_ack(conn)

        // Wake up reading socket
        socket_wake_readers(conn.socket)
    }

    // Check FIN
    if flags & TCP_FIN != 0 {
        conn.recv_next += 1
        conn.state = TcpState.CloseWait
        tcp_send_ack(conn)
        socket_wake_readers(conn.socket)
    }

    netbuf_free(buf)
}

export fn tcp_connect(conn: *TcpConnection, dest_addr: u32, dest_port: u16): i32 {
    conn.remote_addr = dest_addr
    conn.remote_port = dest_port
    conn.send_next = get_initial_seq_num()
    conn.send_unack = conn.send_next
    conn.recv_window = 65535
    conn.state = TcpState.SynSent

    // Send SYN
    tcp_send_syn(conn)

    // Wait for connection
    while conn.state == TcpState.SynSent {
        schedule()
    }

    if conn.state != TcpState.Established {
        return -ECONNREFUSED
    }

    return 0
}

fn tcp_send_syn(conn: *TcpConnection) {
    let buf = netbuf_alloc() ?? return

    let hdr_data = netbuf_put(buf, TCP_HLEN)
    let hdr: *TcpHeader = @ptrCast(hdr_data.ptr)

    hdr.src_port = htons(conn.local_port)
    hdr.dest_port = htons(conn.remote_port)
    hdr.seq_num = htonl(conn.send_next)
    hdr.ack_num = 0
    hdr.data_offset_flags = htons((5 << 12) | TCP_SYN)
    hdr.window = htons(conn.recv_window)
    hdr.checksum = 0
    hdr.urgent_ptr = 0

    hdr.checksum = tcp_checksum(buf, conn.local_addr, conn.remote_addr)

    conn.send_next += 1

    ip_send(buf, conn.remote_addr, IPPROTO_TCP)
}

fn tcp_send_ack(conn: *TcpConnection) {
    let buf = netbuf_alloc() ?? return

    let hdr_data = netbuf_put(buf, TCP_HLEN)
    let hdr: *TcpHeader = @ptrCast(hdr_data.ptr)

    hdr.src_port = htons(conn.local_port)
    hdr.dest_port = htons(conn.remote_port)
    hdr.seq_num = htonl(conn.send_next)
    hdr.ack_num = htonl(conn.recv_next)
    hdr.data_offset_flags = htons((5 << 12) | TCP_ACK)
    hdr.window = htons(conn.recv_window)
    hdr.checksum = 0
    hdr.urgent_ptr = 0

    hdr.checksum = tcp_checksum(buf, conn.local_addr, conn.remote_addr)

    ip_send(buf, conn.remote_addr, IPPROTO_TCP)
}
```

## Socket API

### Socket Structures

```home
const SocketType = enum {
    Stream,
    Datagram,
    Raw
}

const Socket = struct {
    type: SocketType,
    protocol: u8,
    state: SocketState,
    local_addr: u32,
    local_port: u16,
    remote_addr: u32,
    remote_port: u16,
    recv_queue: ?*NetBuffer,
    send_queue: ?*NetBuffer,
    blocked_readers: ProcessQueue,
    blocked_writers: ProcessQueue,
    tcp_conn: ?*TcpConnection,
    options: SocketOptions
}

const SocketState = enum {
    Unbound,
    Bound,
    Listening,
    Connected,
    Closed
}

const SocketOptions = struct {
    reuse_addr: bool,
    keep_alive: bool,
    no_delay: bool,
    recv_timeout: u32,
    send_timeout: u32,
    recv_buf_size: u32,
    send_buf_size: u32
}
```

### Socket System Calls

```home
export fn sys_socket(domain: i32, sock_type: i32, protocol: i32): i32 {
    let proc = get_current_process()

    // Allocate socket
    let socket = memory.allocate(Socket) ?? return -ENOMEM

    socket.* = Socket{
        .type = @enumFromInt(sock_type),
        .protocol = @truncate(protocol),
        .state = SocketState.Unbound,
        .local_addr = 0,
        .local_port = 0,
        .remote_addr = 0,
        .remote_port = 0,
        .recv_queue = null,
        .send_queue = null,
        .blocked_readers = ProcessQueue.init(),
        .blocked_writers = ProcessQueue.init(),
        .tcp_conn = null,
        .options = SocketOptions{}
    }

    // Allocate file descriptor
    let fd = allocate_fd(proc)
    if fd < 0 {
        memory.free(socket)
        return -EMFILE
    }

    // Create file for socket
    let file = create_socket_file(socket)
    proc.open_files[fd] = file

    return fd
}

export fn sys_bind(fd: i32, addr: *SockAddr, addrlen: u32): i32 {
    let socket = get_socket_from_fd(fd) ?? return -EBADF

    if socket.state != SocketState.Unbound {
        return -EINVAL
    }

    let in_addr: *SockAddrIn = @ptrCast(addr)
    socket.local_addr = ntohl(in_addr.addr)
    socket.local_port = ntohs(in_addr.port)
    socket.state = SocketState.Bound

    return 0
}

export fn sys_listen(fd: i32, backlog: i32): i32 {
    let socket = get_socket_from_fd(fd) ?? return -EBADF

    if socket.type != SocketType.Stream {
        return -EOPNOTSUPP
    }

    if socket.state != SocketState.Bound {
        return -EINVAL
    }

    socket.state = SocketState.Listening

    // Create TCP listener
    let listener = tcp_create_listener(socket.local_port, backlog)
    socket.tcp_conn = listener

    return 0
}

export fn sys_accept(fd: i32, addr: *SockAddr, addrlen: *u32): i32 {
    let socket = get_socket_from_fd(fd) ?? return -EBADF

    if socket.state != SocketState.Listening {
        return -EINVAL
    }

    // Wait for connection
    let conn = tcp_accept(socket.tcp_conn)
    if conn == null {
        return -EAGAIN
    }

    // Create new socket for connection
    let new_socket = memory.allocate(Socket) ?? return -ENOMEM
    new_socket.* = Socket{
        .type = SocketType.Stream,
        .protocol = IPPROTO_TCP,
        .state = SocketState.Connected,
        .local_addr = conn.local_addr,
        .local_port = conn.local_port,
        .remote_addr = conn.remote_addr,
        .remote_port = conn.remote_port,
        .tcp_conn = conn
    }

    // Fill in remote address
    let in_addr: *SockAddrIn = @ptrCast(addr)
    in_addr.family = AF_INET
    in_addr.port = htons(conn.remote_port)
    in_addr.addr = htonl(conn.remote_addr)
    addrlen.* = @sizeOf(SockAddrIn)

    // Allocate fd
    let proc = get_current_process()
    let new_fd = allocate_fd(proc)
    proc.open_files[new_fd] = create_socket_file(new_socket)

    return new_fd
}

export fn sys_connect(fd: i32, addr: *SockAddr, addrlen: u32): i32 {
    let socket = get_socket_from_fd(fd) ?? return -EBADF

    if socket.type != SocketType.Stream {
        return -EOPNOTSUPP
    }

    let in_addr: *SockAddrIn = @ptrCast(addr)

    // Allocate local port if needed
    if socket.local_port == 0 {
        socket.local_port = allocate_ephemeral_port()
        socket.local_addr = get_local_address_for(ntohl(in_addr.addr))
    }

    // Create TCP connection
    let conn = tcp_alloc_connection()
    if conn == null {
        return -ENOMEM
    }

    conn.local_addr = socket.local_addr
    conn.local_port = socket.local_port
    conn.socket = socket
    socket.tcp_conn = conn

    // Initiate connection
    let result = tcp_connect(conn, ntohl(in_addr.addr), ntohs(in_addr.port))
    if result < 0 {
        tcp_free_connection(conn)
        socket.tcp_conn = null
        return result
    }

    socket.state = SocketState.Connected
    socket.remote_addr = ntohl(in_addr.addr)
    socket.remote_port = ntohs(in_addr.port)

    return 0
}

export fn sys_send(fd: i32, buf: []const u8, flags: u32): isize {
    let socket = get_socket_from_fd(fd) ?? return -EBADF

    if socket.state != SocketState.Connected {
        return -ENOTCONN
    }

    return tcp_send_data(socket.tcp_conn, buf)
}

export fn sys_recv(fd: i32, buf: []u8, flags: u32): isize {
    let socket = get_socket_from_fd(fd) ?? return -EBADF

    if socket.state != SocketState.Connected {
        return -ENOTCONN
    }

    return tcp_recv_data(socket.tcp_conn, buf, flags)
}
```

## Summary

HomeOS networking provides:

- **Full TCP/IP Stack**: Ethernet, IP, TCP, UDP implementations
- **Buffer Management**: Efficient network buffer pool with zero-copy where possible
- **ARP Protocol**: Address resolution with caching
- **TCP State Machine**: Complete connection handling with retransmission
- **Socket API**: BSD-compatible interface for applications
- **Routing**: Basic IP routing with gateway support

All networking code is written in the Home programming language, using packed structs for protocol headers and efficient byte order conversion functions.
