# Custom Drivers

This guide covers developing custom device drivers for HomeOS using the Home programming language. You'll learn how to create drivers that integrate with the kernel's driver framework, handle interrupts, and communicate with hardware.

## Overview

Writing a custom driver for HomeOS involves:

- **Driver Structure**: Implementing the required interfaces
- **Device Registration**: Registering with the appropriate bus and class
- **Hardware Access**: Using MMIO, port I/O, and DMA
- **Interrupt Handling**: Setting up and responding to hardware interrupts
- **Power Management**: Implementing suspend/resume functionality

## Driver Template

### Basic Driver Structure

```home
import kernel/module
import kernel/driver
import kernel/pci
import kernel/memory
import kernel/interrupt

// Module info
const module_info = ModuleInfo{
    .name = "my_driver",
    .version = "1.0.0",
    .author = "Your Name",
    .description = "My custom driver",
    .license = "MIT"
}

// Device IDs supported by this driver
const device_ids = [_]PciDeviceId{
    PciDeviceId{
        .vendor = 0x1234,
        .device = 0x5678,
        .subvendor = PCI_ANY_ID,
        .subdevice = PCI_ANY_ID
    },
    // Terminator
    PciDeviceId{}
}

// Driver operations
const my_driver = PciDriver{
    .name = "my_driver",
    .id_table = &device_ids,
    .probe = my_probe,
    .remove = my_remove,
    .suspend = my_suspend,
    .resume = my_resume
}

// Per-device state
const MyDevice = struct {
    pci_dev: *PciDevice,
    mmio_base: *volatile u8,
    irq: u32,
    dma_buffer: DmaBuffer,
    // Driver-specific state
    tx_ring: TxRing,
    rx_ring: RxRing,
    stats: DeviceStats
}

export fn module_init(): i32 {
    kernel_log("my_driver: initializing\n")
    return pci_register_driver(&my_driver)
}

export fn module_exit() {
    kernel_log("my_driver: exiting\n")
    pci_unregister_driver(&my_driver)
}

comptime {
    module.register_init(module_init)
    module.register_exit(module_exit)
    module.set_info(&module_info)
}
```

### Probe and Remove

```home
fn my_probe(pci_dev: *PciDevice): i32 {
    kernel_log("my_driver: probing device {}:{}\n", pci_dev.vendor_id, pci_dev.device_id)

    // Enable device
    let result = pci_enable_device(pci_dev)
    if result < 0 {
        return result
    }

    // Request MMIO region
    result = pci_request_regions(pci_dev, "my_driver")
    if result < 0 {
        pci_disable_device(pci_dev)
        return result
    }

    // Enable bus mastering for DMA
    pci_set_master(pci_dev)

    // Allocate device state
    let dev = memory.allocate(MyDevice) ?? {
        pci_release_regions(pci_dev)
        pci_disable_device(pci_dev)
        return -ENOMEM
    }

    dev.pci_dev = pci_dev

    // Map MMIO registers
    let bar0 = pci_resource_start(pci_dev, 0)
    let bar0_len = pci_resource_len(pci_dev, 0)

    dev.mmio_base = ioremap(bar0, bar0_len)
    if dev.mmio_base == null {
        memory.free(dev)
        pci_release_regions(pci_dev)
        pci_disable_device(pci_dev)
        return -ENOMEM
    }

    // Initialize hardware
    result = my_hw_init(dev)
    if result < 0 {
        iounmap(dev.mmio_base)
        memory.free(dev)
        pci_release_regions(pci_dev)
        pci_disable_device(pci_dev)
        return result
    }

    // Request IRQ
    dev.irq = pci_dev.irq
    result = request_irq(dev.irq, my_interrupt_handler, IRQF_SHARED, "my_driver", dev)
    if result < 0 {
        my_hw_cleanup(dev)
        iounmap(dev.mmio_base)
        memory.free(dev)
        pci_release_regions(pci_dev)
        pci_disable_device(pci_dev)
        return result
    }

    // Allocate DMA buffers
    result = my_alloc_dma_buffers(dev)
    if result < 0 {
        free_irq(dev.irq, dev)
        my_hw_cleanup(dev)
        iounmap(dev.mmio_base)
        memory.free(dev)
        pci_release_regions(pci_dev)
        pci_disable_device(pci_dev)
        return result
    }

    // Store device state
    pci_set_drvdata(pci_dev, dev)

    // Register with subsystem (e.g., network, block, etc.)
    result = register_with_subsystem(dev)
    if result < 0 {
        my_free_dma_buffers(dev)
        free_irq(dev.irq, dev)
        my_hw_cleanup(dev)
        iounmap(dev.mmio_base)
        memory.free(dev)
        pci_release_regions(pci_dev)
        pci_disable_device(pci_dev)
        return result
    }

    kernel_log("my_driver: device initialized successfully\n")
    return 0
}

fn my_remove(pci_dev: *PciDevice) {
    let dev: *MyDevice = pci_get_drvdata(pci_dev)

    unregister_from_subsystem(dev)
    my_free_dma_buffers(dev)
    free_irq(dev.irq, dev)
    my_hw_cleanup(dev)
    iounmap(dev.mmio_base)
    memory.free(dev)
    pci_release_regions(pci_dev)
    pci_disable_device(pci_dev)

    kernel_log("my_driver: device removed\n")
}
```

## Hardware Access

### MMIO (Memory-Mapped I/O)

```home
// MMIO read/write functions
fn mmio_read32(dev: *MyDevice, offset: usize): u32 {
    let addr: *volatile u32 = @ptrFromInt(@intFromPtr(dev.mmio_base) + offset)
    return addr.*
}

fn mmio_write32(dev: *MyDevice, offset: usize, value: u32) {
    let addr: *volatile u32 = @ptrFromInt(@intFromPtr(dev.mmio_base) + offset)
    addr.* = value
}

fn mmio_read64(dev: *MyDevice, offset: usize): u64 {
    let addr: *volatile u64 = @ptrFromInt(@intFromPtr(dev.mmio_base) + offset)
    return addr.*
}

fn mmio_write64(dev: *MyDevice, offset: usize, value: u64) {
    let addr: *volatile u64 = @ptrFromInt(@intFromPtr(dev.mmio_base) + offset)
    addr.* = value
}

// Register definitions
const REG_CONTROL = 0x00
const REG_STATUS = 0x04
const REG_INTERRUPT = 0x08
const REG_DATA = 0x10

// Control register bits
const CTRL_ENABLE = 1 << 0
const CTRL_RESET = 1 << 1
const CTRL_INT_ENABLE = 1 << 2

// Status register bits
const STATUS_READY = 1 << 0
const STATUS_BUSY = 1 << 1
const STATUS_ERROR = 1 << 2

fn my_hw_init(dev: *MyDevice): i32 {
    // Reset device
    mmio_write32(dev, REG_CONTROL, CTRL_RESET)

    // Wait for reset to complete
    var timeout: u32 = 1000
    while timeout > 0 {
        if (mmio_read32(dev, REG_STATUS) & STATUS_READY) != 0 {
            break
        }
        udelay(10)
        timeout -= 1
    }

    if timeout == 0 {
        kernel_log("my_driver: reset timeout\n")
        return -ETIMEDOUT
    }

    // Enable device and interrupts
    mmio_write32(dev, REG_CONTROL, CTRL_ENABLE | CTRL_INT_ENABLE)

    return 0
}

fn my_hw_cleanup(dev: *MyDevice) {
    // Disable device
    mmio_write32(dev, REG_CONTROL, 0)
}
```

### Port I/O

```home
import kernel/cpu

// For legacy devices using I/O ports
fn port_read8(port: u16): u8 {
    return cpu.inb(port)
}

fn port_write8(port: u16, value: u8) {
    cpu.outb(port, value)
}

fn port_read16(port: u16): u16 {
    return cpu.inw(port)
}

fn port_write16(port: u16, value: u16) {
    cpu.outw(port, value)
}

fn port_read32(port: u16): u32 {
    return cpu.inl(port)
}

fn port_write32(port: u16, value: u32) {
    cpu.outl(port, value)
}

// Example: Legacy device initialization
fn legacy_hw_init(io_base: u16): i32 {
    // Write to control register
    port_write8(io_base + 0x00, 0x01)

    // Read status
    let status = port_read8(io_base + 0x01)
    if (status & 0x80) == 0 {
        return -EIO
    }

    return 0
}
```

## DMA Operations

### DMA Buffer Allocation

```home
const DmaBuffer = struct {
    cpu_addr: *anyopaque,
    dma_addr: u64,
    size: usize
}

fn dma_alloc_coherent(dev: *PciDevice, size: usize): ?DmaBuffer {
    // Allocate physically contiguous memory
    let pages = (size + PAGE_SIZE - 1) / PAGE_SIZE
    let phys = memory.allocate_contiguous_frames(pages) ?? return null

    let virt = ioremap(phys, size)
    if virt == null {
        memory.free_contiguous_frames(phys, pages)
        return null
    }

    return DmaBuffer{
        .cpu_addr = virt,
        .dma_addr = phys,
        .size = size
    }
}

fn dma_free_coherent(dev: *PciDevice, buf: DmaBuffer) {
    iounmap(buf.cpu_addr)
    let pages = (buf.size + PAGE_SIZE - 1) / PAGE_SIZE
    memory.free_contiguous_frames(buf.dma_addr, pages)
}

fn my_alloc_dma_buffers(dev: *MyDevice): i32 {
    // Allocate TX ring
    let tx_size = TX_RING_SIZE * @sizeOf(TxDescriptor)
    dev.tx_ring.dma = dma_alloc_coherent(dev.pci_dev, tx_size) ?? return -ENOMEM

    dev.tx_ring.desc = @ptrCast(dev.tx_ring.dma.cpu_addr)

    // Allocate RX ring
    let rx_size = RX_RING_SIZE * @sizeOf(RxDescriptor)
    dev.rx_ring.dma = dma_alloc_coherent(dev.pci_dev, rx_size) ?? {
        dma_free_coherent(dev.pci_dev, dev.tx_ring.dma)
        return -ENOMEM
    }

    dev.rx_ring.desc = @ptrCast(dev.rx_ring.dma.cpu_addr)

    // Allocate RX buffers
    for i in 0..RX_RING_SIZE {
        let buf = dma_alloc_coherent(dev.pci_dev, RX_BUFFER_SIZE) ?? {
            my_free_dma_buffers(dev)
            return -ENOMEM
        }

        dev.rx_ring.buffers[i] = buf
        dev.rx_ring.desc[i].buffer_addr = buf.dma_addr
        dev.rx_ring.desc[i].status = 0
    }

    // Tell hardware about descriptor rings
    mmio_write64(dev, REG_TX_RING_BASE, dev.tx_ring.dma.dma_addr)
    mmio_write32(dev, REG_TX_RING_SIZE, TX_RING_SIZE)
    mmio_write64(dev, REG_RX_RING_BASE, dev.rx_ring.dma.dma_addr)
    mmio_write32(dev, REG_RX_RING_SIZE, RX_RING_SIZE)

    return 0
}

fn my_free_dma_buffers(dev: *MyDevice) {
    // Free RX buffers
    for i in 0..RX_RING_SIZE {
        if dev.rx_ring.buffers[i].cpu_addr != null {
            dma_free_coherent(dev.pci_dev, dev.rx_ring.buffers[i])
        }
    }

    // Free rings
    if dev.rx_ring.dma.cpu_addr != null {
        dma_free_coherent(dev.pci_dev, dev.rx_ring.dma)
    }
    if dev.tx_ring.dma.cpu_addr != null {
        dma_free_coherent(dev.pci_dev, dev.tx_ring.dma)
    }
}
```

### DMA Mapping

```home
const DmaDirection = enum {
    ToDevice,
    FromDevice,
    Bidirectional
}

fn dma_map_single(dev: *PciDevice, buf: []u8, direction: DmaDirection): u64 {
    let virt = @intFromPtr(buf.ptr)
    let phys = virt_to_phys(virt)

    // Ensure cache coherency
    switch direction {
        DmaDirection.ToDevice => {
            // Write back cache
            cache_flush(virt, buf.len)
        },
        DmaDirection.FromDevice => {
            // Invalidate cache
            cache_invalidate(virt, buf.len)
        },
        DmaDirection.Bidirectional => {
            cache_flush(virt, buf.len)
        }
    }

    return phys
}

fn dma_unmap_single(dev: *PciDevice, dma_addr: u64, size: usize, direction: DmaDirection) {
    if direction == DmaDirection.FromDevice {
        let virt = phys_to_virt(dma_addr)
        cache_invalidate(virt, size)
    }
}
```

## Interrupt Handling

### Interrupt Handler

```home
fn my_interrupt_handler(irq: u32, dev_id: *anyopaque): IrqReturn {
    let dev: *MyDevice = @ptrCast(dev_id)

    // Read interrupt status
    let status = mmio_read32(dev, REG_INTERRUPT)

    if status == 0 {
        return IrqReturn.None  // Not our interrupt
    }

    // Acknowledge interrupts
    mmio_write32(dev, REG_INTERRUPT, status)

    // Handle TX completion
    if (status & INT_TX_DONE) != 0 {
        handle_tx_complete(dev)
    }

    // Handle RX
    if (status & INT_RX_READY) != 0 {
        // Disable RX interrupt, enable NAPI polling
        disable_rx_interrupt(dev)
        napi_schedule(&dev.napi)
    }

    // Handle errors
    if (status & INT_ERROR) != 0 {
        handle_error(dev)
    }

    return IrqReturn.Handled
}

fn handle_tx_complete(dev: *MyDevice) {
    // Process completed TX descriptors
    while dev.tx_ring.clean_index != dev.tx_ring.next_index {
        let idx = dev.tx_ring.clean_index
        let desc = &dev.tx_ring.desc[idx]

        if (desc.status & TX_STATUS_DONE) == 0 {
            break
        }

        // Free buffer
        let buf = dev.tx_ring.buffers[idx]
        if buf != null {
            netbuf_free(buf)
            dev.tx_ring.buffers[idx] = null
        }

        dev.stats.tx_packets += 1
        dev.tx_ring.clean_index = (idx + 1) % TX_RING_SIZE
    }

    // Wake up transmit queue if space available
    if tx_ring_space(dev) >= TX_WAKE_THRESHOLD {
        netif_wake_queue(&dev.net_dev)
    }
}

fn handle_rx_poll(dev: *MyDevice, budget: u32): u32 {
    var processed: u32 = 0

    while processed < budget {
        let idx = dev.rx_ring.next_index
        let desc = &dev.rx_ring.desc[idx]

        if (desc.status & RX_STATUS_DONE) == 0 {
            break
        }

        // Get packet length
        let len = desc.length

        // Get buffer
        let dma_buf = dev.rx_ring.buffers[idx]

        // Allocate network buffer
        let netbuf = netbuf_alloc() ?? break

        // Copy data (or use page flipping for zero-copy)
        @memcpy(&netbuf.data, dma_buf.cpu_addr, len)
        netbuf.len = len
        netbuf.device = &dev.net_dev

        // Pass to network stack
        netif_rx(netbuf)

        // Reset descriptor
        desc.status = 0

        dev.stats.rx_packets += 1
        dev.rx_ring.next_index = (idx + 1) % RX_RING_SIZE
        processed += 1
    }

    // Update RX tail pointer
    mmio_write32(dev, REG_RX_TAIL, dev.rx_ring.next_index)

    return processed
}
```

### NAPI (Polling) Support

```home
const NapiStruct = struct {
    poll: fn (*NapiStruct, u32) u32,
    weight: u32,
    dev: *NetDevice,
    state: u32
}

fn my_napi_poll(napi: *NapiStruct, budget: u32): u32 {
    let dev: *MyDevice = @fieldParentPtr("napi", napi)

    let processed = handle_rx_poll(dev, budget)

    if processed < budget {
        // Done processing, re-enable interrupt
        napi_complete(napi)
        enable_rx_interrupt(dev)
    }

    return processed
}

// In probe:
fn setup_napi(dev: *MyDevice) {
    dev.napi = NapiStruct{
        .poll = my_napi_poll,
        .weight = 64,
        .dev = &dev.net_dev,
        .state = 0
    }
    napi_enable(&dev.napi)
}
```

## Power Management

```home
fn my_suspend(pci_dev: *PciDevice, state: PowerState): i32 {
    let dev: *MyDevice = pci_get_drvdata(pci_dev)

    // Stop hardware operations
    disable_device(dev)

    // Disable interrupts
    mmio_write32(dev, REG_CONTROL, mmio_read32(dev, REG_CONTROL) & ~CTRL_INT_ENABLE)

    // Save device state
    save_device_state(dev)

    // Put device in low power state
    pci_set_power_state(pci_dev, pci_choose_state(pci_dev, state))

    return 0
}

fn my_resume(pci_dev: *PciDevice): i32 {
    let dev: *MyDevice = pci_get_drvdata(pci_dev)

    // Restore power state
    pci_set_power_state(pci_dev, PCI_D0)

    // Re-enable device
    pci_enable_device(pci_dev)
    pci_set_master(pci_dev)

    // Restore device state
    restore_device_state(dev)

    // Re-initialize hardware
    my_hw_init(dev)

    // Re-enable interrupts
    mmio_write32(dev, REG_CONTROL, mmio_read32(dev, REG_CONTROL) | CTRL_INT_ENABLE)

    // Resume operations
    enable_device(dev)

    return 0
}

fn save_device_state(dev: *MyDevice) {
    dev.saved_state.control = mmio_read32(dev, REG_CONTROL)
    dev.saved_state.config = mmio_read32(dev, REG_CONFIG)
    // Save other registers as needed
}

fn restore_device_state(dev: *MyDevice) {
    mmio_write32(dev, REG_CONFIG, dev.saved_state.config)
    mmio_write32(dev, REG_CONTROL, dev.saved_state.control)
}
```

## Debugging

### Debug Logging

```home
const DEBUG_LEVEL = 2  // 0=off, 1=error, 2=warn, 3=info, 4=debug

fn dbg_error(comptime fmt: []const u8, args: anytype) {
    if DEBUG_LEVEL >= 1 {
        kernel_log("my_driver: ERROR: " ++ fmt, args)
    }
}

fn dbg_warn(comptime fmt: []const u8, args: anytype) {
    if DEBUG_LEVEL >= 2 {
        kernel_log("my_driver: WARN: " ++ fmt, args)
    }
}

fn dbg_info(comptime fmt: []const u8, args: anytype) {
    if DEBUG_LEVEL >= 3 {
        kernel_log("my_driver: INFO: " ++ fmt, args)
    }
}

fn dbg_debug(comptime fmt: []const u8, args: anytype) {
    if DEBUG_LEVEL >= 4 {
        kernel_log("my_driver: DEBUG: " ++ fmt, args)
    }
}

// Usage
fn example() {
    dbg_info("Device initialized\n", .{})
    dbg_debug("Register value: {x}\n", .{mmio_read32(dev, REG_STATUS)})
}
```

### Register Dump

```home
fn dump_registers(dev: *MyDevice) {
    kernel_log("=== Register Dump ===\n")
    kernel_log("CONTROL:   {x:08}\n", mmio_read32(dev, REG_CONTROL))
    kernel_log("STATUS:    {x:08}\n", mmio_read32(dev, REG_STATUS))
    kernel_log("INTERRUPT: {x:08}\n", mmio_read32(dev, REG_INTERRUPT))
    kernel_log("TX_HEAD:   {x:08}\n", mmio_read32(dev, REG_TX_HEAD))
    kernel_log("TX_TAIL:   {x:08}\n", mmio_read32(dev, REG_TX_TAIL))
    kernel_log("RX_HEAD:   {x:08}\n", mmio_read32(dev, REG_RX_HEAD))
    kernel_log("RX_TAIL:   {x:08}\n", mmio_read32(dev, REG_RX_TAIL))
    kernel_log("=====================\n")
}
```

## Summary

Writing custom drivers for HomeOS involves:

- **Driver Framework**: Use the kernel's driver model for registration and lifecycle
- **Hardware Access**: MMIO for modern devices, port I/O for legacy devices
- **DMA**: Coherent allocation for descriptor rings, mapping for data buffers
- **Interrupts**: Handler registration with proper acknowledgment and NAPI polling
- **Power Management**: Suspend/resume hooks for proper state transitions
- **Debugging**: Comprehensive logging and register dumps

All driver code is written in the Home programming language, providing type-safe hardware access and memory management.
