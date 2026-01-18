# Performance Tuning

This guide covers performance optimization techniques for HomeOS, including kernel tuning, memory optimization, I/O performance, and profiling tools. Written for developers who need to maximize system performance.

## Overview

Performance tuning in HomeOS involves:

- **CPU Optimization**: Scheduler tuning, CPU affinity, and interrupt balancing
- **Memory Performance**: Page allocation, caching, and NUMA awareness
- **I/O Optimization**: Block device tuning, file system options, and network performance
- **Profiling**: Tools for identifying and analyzing bottlenecks

## CPU Performance

### Scheduler Tuning

```home
import kernel/sched

// Scheduler parameters
const SchedParams = struct {
    time_slice_base: u32,        // Base time quantum in ms
    priority_levels: u8,          // Number of priority levels
    interactive_bonus: u8,        // Bonus for interactive tasks
    cpu_bound_penalty: u8,        // Penalty for CPU-bound tasks
    migration_cost: u32,          // Cost threshold for CPU migration
    load_balance_interval: u32    // How often to balance load (ms)
}

let sched_params = SchedParams{
    .time_slice_base = 10,
    .priority_levels = 8,
    .interactive_bonus = 3,
    .cpu_bound_penalty = 1,
    .migration_cost = 500000,     // 500 microseconds
    .load_balance_interval = 100
}

// Tune for different workloads
export fn sched_tune_interactive() {
    // Favor latency over throughput
    sched_params.time_slice_base = 5
    sched_params.interactive_bonus = 5
    sched_params.load_balance_interval = 50
}

export fn sched_tune_throughput() {
    // Favor throughput over latency
    sched_params.time_slice_base = 20
    sched_params.interactive_bonus = 1
    sched_params.load_balance_interval = 200
}

export fn sched_tune_server() {
    // Balanced for server workloads
    sched_params.time_slice_base = 10
    sched_params.interactive_bonus = 2
    sched_params.migration_cost = 1000000
    sched_params.load_balance_interval = 100
}
```

### CPU Affinity

```home
import kernel/cpu

// Set process CPU affinity
export fn sys_sched_setaffinity(pid: i32, mask: *CpuSet): i32 {
    let proc = get_process(pid) ?? return -ESRCH

    if !can_modify_process(proc) {
        return -EPERM
    }

    // Validate mask has at least one online CPU
    let valid_mask = mask.* & online_cpus
    if valid_mask.is_empty() {
        return -EINVAL
    }

    proc.cpu_affinity = valid_mask

    // Migrate if current CPU not in mask
    let current_cpu = proc.current_cpu
    if !valid_mask.contains(current_cpu) {
        migrate_process(proc, valid_mask.first_set())
    }

    return 0
}

// Per-CPU data for cache locality
fn per_cpu_alloc(comptime T: type): []T {
    let num_cpus = get_num_cpus()
    let cache_line_size = 64

    // Allocate with cache line padding to prevent false sharing
    let padded_size = align_up(@sizeOf(T), cache_line_size)
    let total_size = padded_size * num_cpus

    let mem = memory.allocate_aligned(total_size, cache_line_size)
    return @ptrCast([*]T, mem)[0..num_cpus]
}

// Example: Per-CPU statistics
const PerCpuStats = struct {
    syscalls: u64,
    context_switches: u64,
    interrupts: u64,
    _padding: [40]u8  // Pad to cache line
}

let cpu_stats = per_cpu_alloc(PerCpuStats)

fn increment_syscall_count() {
    let cpu_id = get_current_cpu()
    cpu_stats[cpu_id].syscalls += 1
}
```

### Interrupt Balancing

```home
import kernel/interrupt

// IRQ affinity for load balancing
export fn set_irq_affinity(irq: u32, cpu_mask: CpuSet): i32 {
    let desc = get_irq_desc(irq) ?? return -EINVAL

    desc.affinity = cpu_mask

    // Update APIC routing
    if desc.chip.set_affinity != null {
        desc.chip.set_affinity(desc, cpu_mask)
    }

    return 0
}

// Automatic IRQ balancing
fn irq_balance() {
    let cpu_loads = calculate_cpu_irq_loads()

    // Find most and least loaded CPUs
    let max_cpu = cpu_loads.max_index()
    let min_cpu = cpu_loads.min_index()

    let load_diff = cpu_loads[max_cpu] - cpu_loads[min_cpu]

    // Only balance if difference is significant
    if load_diff < IRQ_BALANCE_THRESHOLD {
        return
    }

    // Find IRQ to move
    for irq in irqs_on_cpu(max_cpu) {
        let irq_load = get_irq_load(irq)

        if irq_load > 0 and irq_load < load_diff / 2 {
            // Move this IRQ
            var new_mask = CpuSet{}
            new_mask.set(min_cpu)
            set_irq_affinity(irq, new_mask)
            break
        }
    }
}

// Run balancer periodically
fn irq_balance_timer() {
    irq_balance()
    timer_schedule(irq_balance_timer, IRQ_BALANCE_INTERVAL)
}
```

## Memory Performance

### Page Allocator Tuning

```home
import kernel/memory

// Page allocation zones
const Zone = struct {
    name: [16]u8,
    start_pfn: usize,
    end_pfn: usize,
    free_pages: usize,
    min_watermark: usize,
    low_watermark: usize,
    high_watermark: usize,
    percpu_cache: []PerCpuPageCache
}

const PerCpuPageCache = struct {
    pages: [64]?*Page,
    count: u32,
    batch: u32,   // Number of pages to refill/drain at once
    high: u32     // Maximum pages in cache
}

// Fast path allocation from per-CPU cache
fn alloc_page_fast(flags: u32): ?*Page {
    let cpu = get_current_cpu()
    let zone = get_preferred_zone(flags)
    let cache = &zone.percpu_cache[cpu]

    if cache.count > 0 {
        cache.count -= 1
        return cache.pages[cache.count]
    }

    // Refill cache from zone
    return alloc_page_slow(zone, cache, flags)
}

fn alloc_page_slow(zone: *Zone, cache: *PerCpuPageCache, flags: u32): ?*Page {
    // Try to refill per-CPU cache
    let batch = @min(cache.batch, zone.free_pages / 2)

    if batch > 0 {
        for i in 0..batch {
            let page = zone_alloc_page(zone) ?? break
            cache.pages[cache.count] = page
            cache.count += 1
        }
    }

    if cache.count > 0 {
        cache.count -= 1
        return cache.pages[cache.count]
    }

    // Fallback to direct allocation
    return zone_alloc_page(zone)
}

// Fast path free to per-CPU cache
fn free_page_fast(page: *Page) {
    let cpu = get_current_cpu()
    let zone = page_zone(page)
    let cache = &zone.percpu_cache[cpu]

    if cache.count < cache.high {
        cache.pages[cache.count] = page
        cache.count += 1
        return
    }

    // Cache full, drain to zone
    free_page_slow(zone, cache, page)
}
```

### Slab Cache Tuning

```home
// Slab cache configuration
const SlabCacheConfig = struct {
    min_partial: u32,     // Minimum partial slabs to keep
    max_partial: u32,     // Maximum partial slabs
    cpu_partial: u32,     // Per-CPU partial slab count
    batch_size: u32,      // Objects to allocate in batch
    align: u32            // Object alignment
}

fn create_optimized_cache(name: []const u8, size: usize, config: SlabCacheConfig): *SlabCache {
    let cache = memory.allocate(SlabCache) ?? kernel_panic("OOM")

    // Round up size for optimal cache line usage
    let aligned_size = if size > 128 {
        align_up(size, 64)  // Cache line align large objects
    } else {
        align_up(size, config.align)
    }

    cache.* = SlabCache{
        .name = name,
        .object_size = aligned_size,
        .objects_per_slab = calculate_objects_per_slab(aligned_size),
        .config = config,
        .percpu_slabs = per_cpu_alloc(PerCpuSlab)
    }

    return cache
}

// Fast path with per-CPU freelists
fn slab_alloc_fast(cache: *SlabCache): ?*anyopaque {
    let cpu = get_current_cpu()
    let percpu = &cache.percpu_slabs[cpu]

    if percpu.freelist != null {
        let obj = percpu.freelist
        percpu.freelist = obj.next
        percpu.free_count -= 1
        return @ptrCast(obj)
    }

    return slab_alloc_slow(cache, percpu)
}
```

### NUMA Optimization

```home
import kernel/numa

const NumaNode = struct {
    id: u32,
    cpus: CpuSet,
    memory_start: usize,
    memory_size: usize,
    distance: [MAX_NUMA_NODES]u8
}

// NUMA-aware allocation
export fn numa_alloc_pages(node: u32, count: usize, flags: u32): ?*Page {
    let numa_node = get_numa_node(node) ?? return alloc_pages(count, flags)

    // Try preferred node first
    if let page = zone_alloc_pages(&numa_node.zone, count, flags) {
        return page
    }

    // Fall back to nearest nodes
    for other_node in sorted_by_distance(node) {
        if let page = zone_alloc_pages(&other_node.zone, count, flags) {
            return page
        }
    }

    return null
}

// Get NUMA node for current CPU
fn get_current_numa_node(): u32 {
    let cpu = get_current_cpu()
    return cpu_to_node[cpu]
}

// Memory policy for processes
const MemPolicy = enum {
    Default,      // Use default allocation
    Bind,         // Bind to specific nodes
    Interleave,   // Interleave across nodes
    Preferred     // Prefer specific node
}

export fn sys_set_mempolicy(mode: MemPolicy, nodes: *NodeMask): i32 {
    let proc = get_current_process()
    proc.mem_policy.mode = mode
    proc.mem_policy.nodes = nodes.*
    return 0
}
```

## I/O Performance

### Block Device Tuning

```home
import kernel/block

const IoScheduler = struct {
    name: [16]u8,
    queue_request: fn (*RequestQueue, *Request) void,
    dispatch: fn (*RequestQueue) ?*Request,
    completed: fn (*RequestQueue, *Request) void
}

// Deadline scheduler for latency-sensitive workloads
const deadline_scheduler = IoScheduler{
    .name = "deadline",
    .queue_request = deadline_queue,
    .dispatch = deadline_dispatch,
    .completed = deadline_completed
}

const DeadlineData = struct {
    read_fifo: RequestList,
    write_fifo: RequestList,
    read_deadline: u64,   // Default read deadline (ms)
    write_deadline: u64,  // Default write deadline (ms)
    writes_starved: u32,
    fifo_batch: u32
}

fn deadline_queue(queue: *RequestQueue, req: *Request) {
    let dd: *DeadlineData = queue.scheduler_data

    // Set deadline
    let deadline = get_time_ns() + if req.is_read {
        dd.read_deadline * 1000000
    } else {
        dd.write_deadline * 1000000
    }
    req.deadline = deadline

    // Add to appropriate FIFO
    if req.is_read {
        dd.read_fifo.add_sorted_by_deadline(req)
    } else {
        dd.write_fifo.add_sorted_by_deadline(req)
    }
}

fn deadline_dispatch(queue: *RequestQueue): ?*Request {
    let dd: *DeadlineData = queue.scheduler_data
    let now = get_time_ns()

    // Check for expired deadlines
    if dd.read_fifo.head) |read_req| {
        if read_req.deadline <= now {
            return dd.read_fifo.remove_head()
        }
    }

    if dd.write_fifo.head) |write_req| {
        if write_req.deadline <= now {
            return dd.write_fifo.remove_head()
        }
    }

    // Prioritize reads unless writes are starving
    if !dd.read_fifo.is_empty() and dd.writes_starved < 2 {
        dd.writes_starved += 1
        return dd.read_fifo.remove_head()
    }

    if !dd.write_fifo.is_empty() {
        dd.writes_starved = 0
        return dd.write_fifo.remove_head()
    }

    return dd.read_fifo.remove_head()
}

// Request merging for better throughput
fn try_merge_requests(queue: *RequestQueue, req: *Request): bool {
    // Try back merge
    for existing in queue.requests {
        if existing.sector + existing.count == req.sector {
            // Back merge
            existing.count += req.count
            return true
        }
        if req.sector + req.count == existing.sector {
            // Front merge
            existing.sector = req.sector
            existing.count += req.count
            return true
        }
    }
    return false
}
```

### File System Caching

```home
import kernel/pagecache

// Page cache tuning
const PageCacheConfig = struct {
    dirty_ratio: u32,           // % of memory for dirty pages
    dirty_background_ratio: u32, // Start writeback at this %
    dirty_writeback_interval: u32, // Writeback check interval (ms)
    read_ahead_pages: u32,      // Default readahead size
    max_read_ahead_pages: u32   // Maximum readahead size
}

let pagecache_config = PageCacheConfig{
    .dirty_ratio = 20,
    .dirty_background_ratio = 10,
    .dirty_writeback_interval = 500,
    .read_ahead_pages = 32,
    .max_read_ahead_pages = 256
}

// Adaptive readahead
const ReadaheadState = struct {
    start: u64,
    size: u32,
    async_size: u32,
    prev_pos: u64,
    hit_count: u32,
    miss_count: u32
}

fn do_readahead(file: *File, ra: *ReadaheadState, pos: u64): void {
    // Check for sequential access
    if pos == ra.prev_pos + PAGE_SIZE {
        ra.hit_count += 1
    } else {
        ra.miss_count += 1
    }
    ra.prev_pos = pos

    // Adjust readahead size based on access pattern
    if ra.hit_count > 3 and ra.miss_count == 0 {
        // Sequential - increase readahead
        ra.size = @min(ra.size * 2, pagecache_config.max_read_ahead_pages)
    } else if ra.miss_count > ra.hit_count {
        // Random - decrease readahead
        ra.size = @max(ra.size / 2, 4)
        ra.hit_count = 0
        ra.miss_count = 0
    }

    // Submit readahead
    let start_page = pos / PAGE_SIZE
    let end_page = start_page + ra.size

    for page_num in start_page..end_page {
        if !page_cache_lookup(file.inode, page_num) {
            submit_read_request(file, page_num)
        }
    }
}
```

### Network Performance

```home
import kernel/net

// TCP tuning parameters
const TcpTuning = struct {
    initial_cwnd: u32,         // Initial congestion window
    max_cwnd: u32,             // Maximum congestion window
    rto_min: u32,              // Minimum retransmit timeout (ms)
    rto_max: u32,              // Maximum retransmit timeout (ms)
    delayed_ack_timeout: u32,  // Delayed ACK timeout (ms)
    rmem_default: u32,         // Default receive buffer
    rmem_max: u32,             // Maximum receive buffer
    wmem_default: u32,         // Default send buffer
    wmem_max: u32              // Maximum send buffer
}

let tcp_tuning = TcpTuning{
    .initial_cwnd = 10,
    .max_cwnd = 65535,
    .rto_min = 200,
    .rto_max = 120000,
    .delayed_ack_timeout = 40,
    .rmem_default = 212992,
    .rmem_max = 16777216,
    .wmem_default = 212992,
    .wmem_max = 16777216
}

// TCP buffer autotuning
fn tcp_autotune_buffers(conn: *TcpConnection) {
    // Calculate BDP (Bandwidth-Delay Product)
    let rtt_ms = conn.srtt / 1000
    let bandwidth_estimate = conn.bytes_acked / rtt_ms  // bytes/ms

    let bdp = bandwidth_estimate * rtt_ms * 2  // Double for safety

    // Set receive buffer
    let new_rcvbuf = @min(@max(bdp, tcp_tuning.rmem_default), tcp_tuning.rmem_max)
    conn.rcvbuf = new_rcvbuf

    // Advertise window
    conn.recv_window = new_rcvbuf / conn.mss
}

// Interrupt coalescing for network devices
const InterruptCoalescing = struct {
    rx_usecs: u32,         // Delay before RX interrupt
    rx_frames: u32,        // Max frames before RX interrupt
    tx_usecs: u32,         // Delay before TX interrupt
    tx_frames: u32,        // Max frames before TX interrupt
    adaptive: bool         // Enable adaptive coalescing
}

fn set_coalescing(dev: *NetDevice, config: InterruptCoalescing): i32 {
    if dev.ops.set_coalescing != null {
        return dev.ops.set_coalescing(dev, config)
    }
    return -EOPNOTSUPP
}
```

## Profiling Tools

### CPU Profiling

```home
import kernel/perf

const PerfEvent = struct {
    type: PerfEventType,
    config: u64,
    sample_period: u64,
    sample_type: u32,
    callback: fn (*PerfSample) void
}

const PerfEventType = enum {
    Hardware,
    Software,
    Tracepoint,
    HwCache
}

const PerfSample = struct {
    ip: usize,           // Instruction pointer
    pid: u32,
    tid: u32,
    time: u64,
    cpu: u32,
    period: u64,
    callchain: []usize
}

// CPU cycle profiling
fn start_cpu_profiling(pid: i32, callback: fn (*PerfSample) void): i32 {
    let event = PerfEvent{
        .type = PerfEventType.Hardware,
        .config = PERF_COUNT_HW_CPU_CYCLES,
        .sample_period = 1000000,  // Sample every 1M cycles
        .sample_type = PERF_SAMPLE_IP | PERF_SAMPLE_CALLCHAIN,
        .callback = callback
    }

    return perf_event_open(&event, pid)
}

// Example profiler callback
fn profile_callback(sample: *PerfSample) {
    let sym = lookup_symbol(sample.ip)

    // Increment symbol hit count
    if profile_data.get(sym.name)) |count| {
        count.* += sample.period
    } else {
        profile_data.put(sym.name, sample.period)
    }
}

// Print profile results
fn print_profile_results() {
    let sorted = profile_data.entries_sorted_by_value_desc()

    kernel_log("=== CPU Profile ===\n")
    kernel_log("%-40s %12s %6s\n", "Function", "Cycles", "%")

    let total = profile_data.total_value()

    for entry in sorted[0..@min(20, sorted.len)] {
        let pct = entry.value * 100 / total
        kernel_log("%-40s %12d %5d%%\n", entry.key, entry.value, pct)
    }
}
```

### Memory Profiling

```home
// Track allocation hot spots
const AllocProfile = struct {
    callsite: usize,
    alloc_count: u64,
    free_count: u64,
    total_bytes: u64,
    peak_bytes: u64,
    current_bytes: u64
}

let alloc_profiles: HashMap(usize, AllocProfile) = undefined

fn profile_alloc(size: usize, callsite: usize) {
    if alloc_profiles.get(callsite)) |profile| {
        profile.alloc_count += 1
        profile.total_bytes += size
        profile.current_bytes += size
        profile.peak_bytes = @max(profile.peak_bytes, profile.current_bytes)
    } else {
        alloc_profiles.put(callsite, AllocProfile{
            .callsite = callsite,
            .alloc_count = 1,
            .free_count = 0,
            .total_bytes = size,
            .peak_bytes = size,
            .current_bytes = size
        })
    }
}

fn profile_free(size: usize, callsite: usize) {
    if alloc_profiles.get(callsite)) |profile| {
        profile.free_count += 1
        profile.current_bytes -= size
    }
}

// Detect memory leaks
fn detect_leaks() {
    kernel_log("=== Potential Memory Leaks ===\n")

    for entry in alloc_profiles.entries() {
        let profile = entry.value
        if profile.current_bytes > 0 {
            let sym = lookup_symbol(profile.callsite)
            kernel_log("%s: %d bytes in %d allocations\n",
                sym.name, profile.current_bytes,
                profile.alloc_count - profile.free_count)
        }
    }
}
```

### Latency Tracing

```home
const TraceEvent = struct {
    timestamp: u64,
    cpu: u32,
    pid: u32,
    event_type: u8,
    data: [48]u8
}

const TRACE_BUFFER_SIZE = 1024 * 1024

let trace_buffer: RingBuffer(TraceEvent) = undefined

fn trace_event(event_type: u8, data: []const u8) {
    let event = TraceEvent{
        .timestamp = rdtsc(),
        .cpu = get_current_cpu(),
        .pid = get_current_pid(),
        .event_type = event_type
    }

    @memcpy(&event.data, data.ptr, @min(data.len, 48))

    trace_buffer.write(event)
}

// Trace scheduler latency
fn trace_sched_wakeup(proc: *Process) {
    var data: [48]u8 = undefined
    let info = @ptrCast(*SchedTraceInfo, &data)
    info.pid = proc.pid
    info.prio = proc.priority
    info.target_cpu = proc.cpu_affinity.first_set()

    trace_event(TRACE_SCHED_WAKEUP, &data)
    proc.wakeup_time = rdtsc()
}

fn trace_sched_switch(prev: *Process, next: *Process) {
    var data: [48]u8 = undefined
    let info = @ptrCast(*SchedSwitchInfo, &data)
    info.prev_pid = prev.pid
    info.next_pid = next.pid
    info.prev_state = prev.state

    trace_event(TRACE_SCHED_SWITCH, &data)

    // Calculate latency
    if next.wakeup_time > 0 {
        let latency = rdtsc() - next.wakeup_time
        record_sched_latency(next, latency)
        next.wakeup_time = 0
    }
}

fn dump_latency_histogram() {
    kernel_log("=== Scheduler Latency Histogram ===\n")
    kernel_log("Latency (us)    Count\n")

    for i in 0..latency_histogram.len {
        if latency_histogram[i] > 0 {
            let latency_us = (1 << i) * 1000 / cpu_freq_khz
            kernel_log("%8d    %8d\n", latency_us, latency_histogram[i])
        }
    }
}
```

## Summary

Performance tuning in HomeOS involves:

- **CPU**: Scheduler parameters, affinity, interrupt balancing
- **Memory**: Per-CPU caches, slab tuning, NUMA awareness
- **I/O**: Request scheduling, page cache tuning, network buffers
- **Profiling**: CPU sampling, memory tracking, latency tracing

All performance code is written in the Home programming language, providing type-safe access to hardware performance counters and low-level tuning knobs.
