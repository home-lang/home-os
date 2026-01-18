# Device Drivers

HomeOS provides a comprehensive device driver framework built entirely in the Home programming language. The driver subsystem supports a wide range of hardware including block devices, network interfaces, input devices, and graphics adapters.

## Overview

The driver architecture in HomeOS follows a modular design:

- **Driver Core**: Registration, lifecycle management, and device model
- **Bus Drivers**: PCI, USB, and platform bus implementations
- **Class Drivers**: Block, network, character, and input device classes
- **Hardware Drivers**: Specific implementations for various devices

## Driver Model

### Driver Registration

```home
const Driver = struct {
    name: [64]u8,
    bus: *Bus,
    probe: fn (*Device) i32,
    remove: fn (*Device) void,
    suspend: fn (*Device) i32,
    resume: fn (*Device) i32,
    id_table: []const DeviceId,
    devices: DeviceList,
    next: ?*Driver
}

const Device = struct {
    name: [64]u8,
    driver: ?*Driver,
    bus: *Bus,
    parent: ?*Device,
    children: DeviceList,
    class: ?*DeviceClass,
    private_data: *anyopaque,
    power_state: PowerState,
    ref_count: u32
}

const DeviceId = struct {
    vendor_id: u16,
    device_id: u16,
    subvendor_id: u16,
    subdevice_id: u16,
    class: u32,
    class_mask: u32
}

// Global driver list
let registered_drivers: ?*Driver = null

export fn driver_register(driver: *Driver): i32 {
    // Validate driver
    if driver.probe == null {
        return -EINVAL
    }

    // Add to driver list
    driver.next = registered_drivers
    registered_drivers = driver

    // Probe all matching devices
    let bus = driver.bus
    for device in bus.devices {
        if driver_match(driver, device) {
            driver_probe(driver, device)
        }
    }

    return 0
}

export fn driver_unregister(driver: *Driver) {
    // Remove all devices
    for device in driver.devices {
        driver_remove(driver, device)
    }

    // Remove from driver list
    if registered_drivers == driver {
        registered_drivers = driver.next
    } else {
        let prev = registered_drivers
        while prev != null {
            if prev.next == driver {
                prev.next = driver.next
                break
            }
            prev = prev.next
        }
    }
}

fn driver_match(driver: *Driver, device: *Device): bool {
    for id in driver.id_table {
        if device_matches_id(device, id) {
            return true
        }
    }
    return false
}

fn driver_probe(driver: *Driver, device: *Device): i32 {
    let result = driver.probe(device)

    if result == 0 {
        device.driver = driver
        driver.devices.add(device)
    }

    return result
}
```

### Device Classes

```home
const DeviceClass = struct {
    name: [32]u8,
    devices: DeviceList,
    dev_release: fn (*Device) void,
    class_release: fn (*DeviceClass) void,
    dev_attrs: []const DeviceAttribute,
    next: ?*DeviceClass
}

const DeviceAttribute = struct {
    name: [32]u8,
    mode: u16,
    show: fn (*Device, []u8) isize,
    store: fn (*Device, []const u8) isize
}

let device_classes: ?*DeviceClass = null

export fn class_register(class: *DeviceClass): i32 {
    class.next = device_classes
    device_classes = class
    return 0
}

export fn device_create(class: *DeviceClass, parent: ?*Device, name: []const u8): ?*Device {
    let device = memory.allocate(Device) ?? return null

    device.* = Device{
        .name = undefined,
        .driver = null,
        .bus = null,
        .parent = parent,
        .children = DeviceList.init(),
        .class = class,
        .private_data = null,
        .power_state = PowerState.On,
        .ref_count = 1
    }

    @memcpy(&device.name, name.ptr, @min(name.len, 63))
    device.name[@min(name.len, 63)] = 0

    class.devices.add(device)

    if parent != null {
        parent.children.add(device)
    }

    return device
}
```

## PCI Bus

### PCI Enumeration

```home
const PCI_CONFIG_ADDRESS = 0xCF8
const PCI_CONFIG_DATA = 0xCFC

const PciDevice = struct {
    bus: u8,
    slot: u8,
    func: u8,
    vendor_id: u16,
    device_id: u16,
    class_code: u8,
    subclass: u8,
    prog_if: u8,
    revision: u8,
    header_type: u8,
    bar: [6]u32,
    irq: u8,
    device: Device
}

export fn pci_init() {
    // Enumerate all PCI devices
    for bus in 0..256 {
        for slot in 0..32 {
            pci_check_device(@truncate(bus), @truncate(slot))
        }
    }
}

fn pci_check_device(bus: u8, slot: u8) {
    let vendor = pci_config_read_word(bus, slot, 0, 0)
    if vendor == 0xFFFF {
        return  // No device
    }

    let header_type = pci_config_read_byte(bus, slot, 0, 0x0E)

    if header_type & 0x80 != 0 {
        // Multi-function device
        for func in 0..8 {
            pci_check_function(bus, slot, @truncate(func))
        }
    } else {
        pci_check_function(bus, slot, 0)
    }
}

fn pci_check_function(bus: u8, slot: u8, func: u8) {
    let vendor = pci_config_read_word(bus, slot, func, 0)
    if vendor == 0xFFFF {
        return
    }

    let device_id = pci_config_read_word(bus, slot, func, 2)
    let class_code = pci_config_read_byte(bus, slot, func, 0x0B)
    let subclass = pci_config_read_byte(bus, slot, func, 0x0A)

    let pci_dev = memory.allocate(PciDevice) ?? return

    pci_dev.* = PciDevice{
        .bus = bus,
        .slot = slot,
        .func = func,
        .vendor_id = vendor,
        .device_id = device_id,
        .class_code = class_code,
        .subclass = subclass,
        .prog_if = pci_config_read_byte(bus, slot, func, 0x09),
        .revision = pci_config_read_byte(bus, slot, func, 0x08),
        .header_type = pci_config_read_byte(bus, slot, func, 0x0E) & 0x7F,
        .bar = undefined,
        .irq = pci_config_read_byte(bus, slot, func, 0x3C),
        .device = undefined
    }

    // Read BARs
    for i in 0..6 {
        pci_dev.bar[i] = pci_config_read_dword(bus, slot, func, 0x10 + i * 4)
    }

    // Register device
    pci_register_device(pci_dev)

    // Match with drivers
    for driver in registered_drivers {
        if driver.bus == &pci_bus and driver_match(driver, &pci_dev.device) {
            driver_probe(driver, &pci_dev.device)
            break
        }
    }
}

fn pci_config_read_dword(bus: u8, slot: u8, func: u8, offset: u8): u32 {
    let address: u32 = (1 << 31) |
        (@as(u32, bus) << 16) |
        (@as(u32, slot) << 11) |
        (@as(u32, func) << 8) |
        (offset & 0xFC)

    cpu.outl(PCI_CONFIG_ADDRESS, address)
    return cpu.inl(PCI_CONFIG_DATA)
}

fn pci_config_write_dword(bus: u8, slot: u8, func: u8, offset: u8, value: u32) {
    let address: u32 = (1 << 31) |
        (@as(u32, bus) << 16) |
        (@as(u32, slot) << 11) |
        (@as(u32, func) << 8) |
        (offset & 0xFC)

    cpu.outl(PCI_CONFIG_ADDRESS, address)
    cpu.outl(PCI_CONFIG_DATA, value)
}

export fn pci_enable_bus_master(dev: *PciDevice) {
    let cmd = pci_config_read_word(dev.bus, dev.slot, dev.func, 0x04)
    pci_config_write_word(dev.bus, dev.slot, dev.func, 0x04, cmd | 0x04)
}

export fn pci_enable_mmio(dev: *PciDevice) {
    let cmd = pci_config_read_word(dev.bus, dev.slot, dev.func, 0x04)
    pci_config_write_word(dev.bus, dev.slot, dev.func, 0x04, cmd | 0x02)
}
```

## Block Device Drivers

### Block Device Interface

```home
const BlockDevice = struct {
    name: [32]u8,
    major: u16,
    minor: u16,
    sector_size: u32,
    total_sectors: u64,
    read_only: bool,
    ops: *BlockDeviceOps,
    queue: RequestQueue,
    private_data: *anyopaque,
    device: Device
}

const BlockDeviceOps = struct {
    open: fn (*BlockDevice) i32,
    release: fn (*BlockDevice) i32,
    read: fn (*BlockDevice, u64, u32, []u8) i32,
    write: fn (*BlockDevice, u64, u32, []const u8) i32,
    ioctl: fn (*BlockDevice, u32, usize) i32,
    getgeo: fn (*BlockDevice, *Geometry) i32
}

const Request = struct {
    type: RequestType,
    sector: u64,
    count: u32,
    buffer: []u8,
    callback: fn (*Request, i32) void,
    private_data: *anyopaque,
    next: ?*Request
}

const RequestType = enum {
    Read,
    Write,
    Flush,
    Discard
}

const RequestQueue = struct {
    head: ?*Request,
    tail: ?*Request,
    pending: u32
}

export fn block_device_register(bdev: *BlockDevice): i32 {
    // Assign major/minor numbers
    bdev.major = allocate_major()
    bdev.minor = 0

    // Create device node
    let dev = device_create(&block_class, null, bdev.name)
    if dev == null {
        return -ENOMEM
    }

    dev.private_data = bdev
    bdev.device = dev.*

    return 0
}

export fn submit_bio(bdev: *BlockDevice, req: *Request) {
    // Add to request queue
    if bdev.queue.tail != null {
        bdev.queue.tail.next = req
    } else {
        bdev.queue.head = req
    }
    bdev.queue.tail = req
    bdev.queue.pending += 1

    // Process queue
    process_request_queue(bdev)
}

fn process_request_queue(bdev: *BlockDevice) {
    while bdev.queue.head != null {
        let req = bdev.queue.head
        bdev.queue.head = req.next
        if bdev.queue.head == null {
            bdev.queue.tail = null
        }
        bdev.queue.pending -= 1

        let result = switch req.type {
            RequestType.Read => bdev.ops.read(bdev, req.sector, req.count, req.buffer),
            RequestType.Write => bdev.ops.write(bdev, req.sector, req.count, req.buffer),
            else => 0
        }

        if req.callback != null {
            req.callback(req, result)
        }
    }
}
```

### AHCI Driver (SATA)

```home
const AHCI_CLASS = 0x01
const AHCI_SUBCLASS = 0x06
const AHCI_PROG_IF = 0x01

const AhciHba = packed struct {
    cap: u32,
    ghc: u32,
    is: u32,
    pi: u32,
    vs: u32,
    ccc_ctl: u32,
    ccc_ports: u32,
    em_loc: u32,
    em_ctl: u32,
    cap2: u32,
    bohc: u32,
    reserved: [212]u8,
    vendor: [96]u8,
    ports: [32]AhciPort
}

const AhciPort = packed struct {
    clb: u64,
    fb: u64,
    is: u32,
    ie: u32,
    cmd: u32,
    reserved0: u32,
    tfd: u32,
    sig: u32,
    ssts: u32,
    sctl: u32,
    serr: u32,
    sact: u32,
    ci: u32,
    sntf: u32,
    fbs: u32,
    reserved1: [44]u8,
    vendor: [16]u8
}

const AhciDriver = struct {
    pci_dev: *PciDevice,
    hba: *volatile AhciHba,
    ports: [32]?*AhciDisk,
    driver: Driver
}

const AhciDisk = struct {
    port_num: u8,
    ahci: *AhciDriver,
    port: *volatile AhciPort,
    cmd_list: *AhciCommandList,
    fis: *AhciFis,
    block_dev: BlockDevice
}

export fn ahci_probe(device: *Device): i32 {
    let pci_dev: *PciDevice = @fieldParentPtr("device", device)

    // Enable bus master and MMIO
    pci_enable_bus_master(pci_dev)
    pci_enable_mmio(pci_dev)

    // Map ABAR (BAR5)
    let abar = pci_dev.bar[5] & ~0xFFF
    let hba: *volatile AhciHba = @ptrFromInt(map_mmio(abar, 0x1100))

    // Allocate driver state
    let ahci = memory.allocate(AhciDriver) ?? return -ENOMEM

    ahci.pci_dev = pci_dev
    ahci.hba = hba

    // Enable AHCI mode
    hba.ghc |= (1 << 31)

    // Reset HBA
    hba.ghc |= 1
    while (hba.ghc & 1) != 0 {}

    // Re-enable AHCI
    hba.ghc |= (1 << 31)

    // Probe ports
    let pi = hba.pi
    for i in 0..32 {
        if (pi & (1 << i)) != 0 {
            ahci_probe_port(ahci, @truncate(i))
        }
    }

    device.private_data = ahci
    return 0
}

fn ahci_probe_port(ahci: *AhciDriver, port_num: u8) {
    let port = &ahci.hba.ports[port_num]

    // Check device presence
    let ssts = port.ssts
    let det = ssts & 0xF
    let ipm = (ssts >> 8) & 0xF

    if det != 3 or ipm != 1 {
        return  // No device
    }

    // Check signature
    let sig = port.sig
    if sig != 0x00000101 {
        return  // Not SATA disk
    }

    // Allocate disk structure
    let disk = memory.allocate(AhciDisk) ?? return

    disk.port_num = port_num
    disk.ahci = ahci
    disk.port = port

    // Allocate command list and FIS
    disk.cmd_list = memory.allocate_dma(AhciCommandList) ?? {
        memory.free(disk)
        return
    }
    disk.fis = memory.allocate_dma(AhciFis) ?? {
        memory.free_dma(disk.cmd_list)
        memory.free(disk)
        return
    }

    // Set up port
    ahci_port_stop(port)

    port.clb = @intFromPtr(disk.cmd_list)
    port.fb = @intFromPtr(disk.fis)

    ahci_port_start(port)

    // Identify device
    ahci_identify(disk)

    // Register block device
    disk.block_dev = BlockDevice{
        .name = undefined,
        .sector_size = 512,
        .total_sectors = disk.total_sectors,
        .read_only = false,
        .ops = &ahci_block_ops,
        .queue = RequestQueue{},
        .private_data = disk
    }

    format_device_name(&disk.block_dev.name, "sd", ahci.disk_count)
    ahci.disk_count += 1

    block_device_register(&disk.block_dev)
    ahci.ports[port_num] = disk
}

fn ahci_read(bdev: *BlockDevice, sector: u64, count: u32, buf: []u8): i32 {
    let disk: *AhciDisk = @ptrCast(bdev.private_data)
    let port = disk.port

    // Build command
    let slot = ahci_find_cmd_slot(disk)
    if slot < 0 {
        return -EBUSY
    }

    let cmd_header = &disk.cmd_list.headers[slot]
    cmd_header.cfl = @sizeOf(FisRegH2D) / 4
    cmd_header.w = 0  // Read
    cmd_header.prdtl = 1

    let cmd_table = disk.cmd_list.tables[slot]
    let fis: *FisRegH2D = @ptrCast(&cmd_table.cfis)

    fis.fis_type = FIS_TYPE_REG_H2D
    fis.c = 1
    fis.command = ATA_CMD_READ_DMA_EX
    fis.lba0 = @truncate(sector)
    fis.lba1 = @truncate(sector >> 8)
    fis.lba2 = @truncate(sector >> 16)
    fis.device = 1 << 6  // LBA mode
    fis.lba3 = @truncate(sector >> 24)
    fis.lba4 = @truncate(sector >> 32)
    fis.lba5 = @truncate(sector >> 40)
    fis.countl = @truncate(count)
    fis.counth = @truncate(count >> 8)

    // Set up PRDT
    cmd_table.prdt[0].dba = @intFromPtr(buf.ptr)
    cmd_table.prdt[0].dbc = count * 512 - 1
    cmd_table.prdt[0].i = 1

    // Issue command
    port.ci = 1 << slot

    // Wait for completion
    while (port.ci & (1 << slot)) != 0 {
        if (port.is & (1 << 30)) != 0 {
            return -EIO  // Task file error
        }
    }

    return 0
}
```

## Network Drivers

### Network Device Interface

```home
const NetDevice = struct {
    name: [16]u8,
    mac_address: [6]u8,
    mtu: u32,
    flags: u32,
    state: NetDeviceState,
    ops: *NetDeviceOps,
    stats: NetDeviceStats,
    rx_queue: NetBufferQueue,
    tx_queue: NetBufferQueue,
    private_data: *anyopaque,
    device: Device
}

const NetDeviceOps = struct {
    open: fn (*NetDevice) i32,
    stop: fn (*NetDevice) i32,
    start_xmit: fn (*NetDevice, *NetBuffer) i32,
    set_mac_address: fn (*NetDevice, [6]u8) i32,
    set_rx_mode: fn (*NetDevice) void,
    get_stats: fn (*NetDevice) *NetDeviceStats
}

const NetDeviceState = enum {
    Down,
    Up,
    Running
}

export fn netdev_register(dev: *NetDevice): i32 {
    // Create device node
    let node = device_create(&net_class, null, dev.name)
    if node == null {
        return -ENOMEM
    }

    node.private_data = dev
    dev.device = node.*

    // Add to network device list
    netdev_list_add(dev)

    return 0
}

export fn netdev_open(dev: *NetDevice): i32 {
    if dev.state != NetDeviceState.Down {
        return -EBUSY
    }

    let result = dev.ops.open(dev)
    if result < 0 {
        return result
    }

    dev.state = NetDeviceState.Up
    return 0
}

export fn netif_rx(buf: *NetBuffer) {
    let dev = buf.device

    dev.stats.rx_packets += 1
    dev.stats.rx_bytes += buf.len

    // Pass to network stack
    eth_receive(dev, buf)
}
```

### Intel E1000 Driver

```home
const E1000_VENDOR_ID = 0x8086
const E1000_DEVICE_ID = 0x100E

const E1000_CTRL = 0x0000
const E1000_STATUS = 0x0008
const E1000_EECD = 0x0010
const E1000_EERD = 0x0014
const E1000_ICR = 0x00C0
const E1000_IMS = 0x00D0
const E1000_IMC = 0x00D8
const E1000_RCTL = 0x0100
const E1000_TCTL = 0x0400
const E1000_RDBAL = 0x2800
const E1000_RDBAH = 0x2804
const E1000_RDLEN = 0x2808
const E1000_RDH = 0x2810
const E1000_RDT = 0x2818
const E1000_TDBAL = 0x3800
const E1000_TDBAH = 0x3804
const E1000_TDLEN = 0x3808
const E1000_TDH = 0x3810
const E1000_TDT = 0x3818
const E1000_RAL = 0x5400
const E1000_RAH = 0x5404

const E1000_NUM_RX_DESC = 32
const E1000_NUM_TX_DESC = 32

const E1000RxDesc = packed struct {
    addr: u64,
    length: u16,
    checksum: u16,
    status: u8,
    errors: u8,
    special: u16
}

const E1000TxDesc = packed struct {
    addr: u64,
    length: u16,
    cso: u8,
    cmd: u8,
    status: u8,
    css: u8,
    special: u16
}

const E1000Device = struct {
    pci_dev: *PciDevice,
    mmio_base: usize,
    rx_descs: *[E1000_NUM_RX_DESC]E1000RxDesc,
    tx_descs: *[E1000_NUM_TX_DESC]E1000TxDesc,
    rx_buffers: [E1000_NUM_RX_DESC]*NetBuffer,
    tx_buffers: [E1000_NUM_TX_DESC]?*NetBuffer,
    rx_cur: u32,
    tx_cur: u32,
    net_dev: NetDevice
}

export fn e1000_probe(device: *Device): i32 {
    let pci_dev: *PciDevice = @fieldParentPtr("device", device)

    // Enable bus master and MMIO
    pci_enable_bus_master(pci_dev)
    pci_enable_mmio(pci_dev)

    // Map MMIO region
    let bar0 = pci_dev.bar[0] & ~0xF
    let mmio = map_mmio(bar0, 0x20000)

    // Allocate device
    let e1000 = memory.allocate(E1000Device) ?? return -ENOMEM

    e1000.pci_dev = pci_dev
    e1000.mmio_base = mmio

    // Reset device
    e1000_write(e1000, E1000_CTRL, 0x04000000)
    sleep_ms(10)
    e1000_write(e1000, E1000_CTRL, 0x00000000)

    // Read MAC address
    e1000_read_mac(e1000)

    // Allocate descriptor rings
    e1000.rx_descs = memory.allocate_dma([E1000_NUM_RX_DESC]E1000RxDesc) ?? {
        memory.free(e1000)
        return -ENOMEM
    }

    e1000.tx_descs = memory.allocate_dma([E1000_NUM_TX_DESC]E1000TxDesc) ?? {
        memory.free_dma(e1000.rx_descs)
        memory.free(e1000)
        return -ENOMEM
    }

    // Initialize receive descriptors
    for i in 0..E1000_NUM_RX_DESC {
        let buf = netbuf_alloc() ?? {
            // Cleanup
            return -ENOMEM
        }
        e1000.rx_buffers[i] = buf
        e1000.rx_descs[i].addr = @intFromPtr(&buf.data)
        e1000.rx_descs[i].status = 0
    }

    // Set up receive ring
    e1000_write(e1000, E1000_RDBAL, @truncate(@intFromPtr(e1000.rx_descs)))
    e1000_write(e1000, E1000_RDBAH, @truncate(@intFromPtr(e1000.rx_descs) >> 32))
    e1000_write(e1000, E1000_RDLEN, E1000_NUM_RX_DESC * @sizeOf(E1000RxDesc))
    e1000_write(e1000, E1000_RDH, 0)
    e1000_write(e1000, E1000_RDT, E1000_NUM_RX_DESC - 1)

    // Set up transmit ring
    e1000_write(e1000, E1000_TDBAL, @truncate(@intFromPtr(e1000.tx_descs)))
    e1000_write(e1000, E1000_TDBAH, @truncate(@intFromPtr(e1000.tx_descs) >> 32))
    e1000_write(e1000, E1000_TDLEN, E1000_NUM_TX_DESC * @sizeOf(E1000TxDesc))
    e1000_write(e1000, E1000_TDH, 0)
    e1000_write(e1000, E1000_TDT, 0)

    // Configure MAC address
    e1000_write(e1000, E1000_RAL, e1000.net_dev.mac_address[0..4].*)
    e1000_write(e1000, E1000_RAH, e1000.net_dev.mac_address[4..6].* | (1 << 31))

    // Enable receive and transmit
    e1000_write(e1000, E1000_RCTL, 0x0801801E)  // Enable, broadcast, 2K buffers
    e1000_write(e1000, E1000_TCTL, 0x0004010A)  // Enable, pad short packets

    // Enable interrupts
    e1000_write(e1000, E1000_IMS, 0x1F6DC)

    // Register network device
    e1000.net_dev = NetDevice{
        .name = "eth0",
        .mtu = 1500,
        .flags = 0,
        .state = NetDeviceState.Down,
        .ops = &e1000_netdev_ops,
        .private_data = e1000
    }

    netdev_register(&e1000.net_dev)

    // Register interrupt handler
    register_irq(pci_dev.irq, e1000_interrupt, e1000)

    device.private_data = e1000
    return 0
}

fn e1000_interrupt(ctx: *anyopaque) {
    let e1000: *E1000Device = @ptrCast(ctx)

    let icr = e1000_read(e1000, E1000_ICR)

    if (icr & 0x80) != 0 {
        // Receive interrupt
        e1000_rx_poll(e1000)
    }

    if (icr & 0x02) != 0 {
        // Transmit interrupt
        e1000_tx_clean(e1000)
    }
}

fn e1000_rx_poll(e1000: *E1000Device) {
    while e1000.rx_descs[e1000.rx_cur].status & 1 != 0 {
        let desc = &e1000.rx_descs[e1000.rx_cur]
        let buf = e1000.rx_buffers[e1000.rx_cur]

        // Set buffer length
        buf.len = desc.length
        buf.device = &e1000.net_dev

        // Pass to network stack
        netif_rx(buf)

        // Allocate new buffer
        let new_buf = netbuf_alloc() ?? break
        e1000.rx_buffers[e1000.rx_cur] = new_buf
        desc.addr = @intFromPtr(&new_buf.data)
        desc.status = 0

        // Update tail
        let old_cur = e1000.rx_cur
        e1000.rx_cur = (e1000.rx_cur + 1) % E1000_NUM_RX_DESC
        e1000_write(e1000, E1000_RDT, old_cur)
    }
}

fn e1000_start_xmit(dev: *NetDevice, buf: *NetBuffer): i32 {
    let e1000: *E1000Device = @ptrCast(dev.private_data)

    let desc = &e1000.tx_descs[e1000.tx_cur]

    desc.addr = @intFromPtr(&buf.data[buf.head])
    desc.length = @truncate(buf.len)
    desc.cmd = 0x0B  // EOP, IFCS, RS
    desc.status = 0

    e1000.tx_buffers[e1000.tx_cur] = buf
    e1000.tx_cur = (e1000.tx_cur + 1) % E1000_NUM_TX_DESC

    e1000_write(e1000, E1000_TDT, e1000.tx_cur)

    dev.stats.tx_packets += 1
    dev.stats.tx_bytes += buf.len

    return 0
}
```

## Input Drivers

### PS/2 Keyboard Driver

```home
const PS2_DATA = 0x60
const PS2_STATUS = 0x64
const PS2_CMD = 0x64

const KeyboardState = struct {
    shift: bool,
    ctrl: bool,
    alt: bool,
    capslock: bool,
    numlock: bool
}

let keyboard_state = KeyboardState{}
let keyboard_buffer: RingBuffer(256, u8) = undefined

const scancode_map = [_]u8{
    0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 8,
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',
    0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`',
    0, '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0,
    '*', 0, ' '
    // ... more keycodes
}

export fn keyboard_init() {
    // Flush output buffer
    while (cpu.inb(PS2_STATUS) & 1) != 0 {
        cpu.inb(PS2_DATA)
    }

    // Enable keyboard
    ps2_send_command(0xAE)

    // Set scancode set 1
    ps2_send_data(0xF0)
    ps2_send_data(0x01)

    // Enable scanning
    ps2_send_data(0xF4)

    // Register IRQ
    register_irq(1, keyboard_interrupt, null)
}

fn keyboard_interrupt(ctx: *anyopaque) {
    let scancode = cpu.inb(PS2_DATA)

    if scancode & 0x80 != 0 {
        // Key release
        let key = scancode & 0x7F
        switch key {
            0x2A, 0x36 => keyboard_state.shift = false,
            0x1D => keyboard_state.ctrl = false,
            0x38 => keyboard_state.alt = false,
            else => {}
        }
    } else {
        // Key press
        switch scancode {
            0x2A, 0x36 => keyboard_state.shift = true,
            0x1D => keyboard_state.ctrl = true,
            0x38 => keyboard_state.alt = true,
            0x3A => keyboard_state.capslock = !keyboard_state.capslock,
            else => {
                let char = translate_scancode(scancode)
                if char != 0 {
                    keyboard_buffer.write(char)
                    wake_readers(&keyboard_wait_queue)
                }
            }
        }
    }
}

fn translate_scancode(scancode: u8): u8 {
    if scancode >= scancode_map.len {
        return 0
    }

    var char = scancode_map[scancode]

    if char >= 'a' and char <= 'z' {
        let should_upper = keyboard_state.shift != keyboard_state.capslock
        if should_upper {
            char -= 32
        }
    } else if keyboard_state.shift {
        char = shift_map[scancode]
    }

    return char
}

export fn keyboard_read(buf: []u8): isize {
    let read: usize = 0

    while read < buf.len {
        if keyboard_buffer.is_empty() {
            if read > 0 {
                break
            }
            // Block waiting for input
            let proc = get_current_process()
            proc.state = ProcessState.Blocked
            keyboard_wait_queue.add(proc)
            schedule()
            continue
        }

        buf[read] = keyboard_buffer.read()
        read += 1
    }

    return read
}
```

## Summary

HomeOS device drivers provide:

- **Driver Model**: Registration, probing, and lifecycle management
- **PCI Support**: Full enumeration and configuration access
- **Block Devices**: Request queue based I/O with AHCI/SATA support
- **Network Devices**: Ethernet with Intel E1000 driver
- **Input Devices**: PS/2 keyboard with scancode translation
- **Interrupt Handling**: IRQ registration and handler dispatch

All driver code is written in the Home programming language, using packed structs for hardware registers and MMIO access for device communication.
