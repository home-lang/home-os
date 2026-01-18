# Security Model

HomeOS implements a comprehensive security model that protects the system and user data through multiple layers of defense. Built entirely in the Home programming language, the security subsystem provides access control, capability-based security, and various hardening mechanisms.

## Overview

The security architecture in HomeOS includes:

- **Access Control**: User/group permissions and Access Control Lists (ACLs)
- **Capability System**: Fine-grained resource access control
- **Mandatory Access Control**: SELinux-style policy enforcement
- **Memory Protection**: ASLR, stack canaries, and guard pages
- **Secure Boot**: Chain of trust verification
- **Cryptographic Services**: Kernel crypto API

## User and Group Management

### User Structures

```home
const MAX_USERS = 65536
const MAX_GROUPS = 65536

const User = struct {
    uid: u32,
    name: [32]u8,
    password_hash: [64]u8,
    home_dir: [256]u8,
    shell: [128]u8,
    groups: [32]u32,
    num_groups: u8,
    flags: UserFlags
}

const UserFlags = packed struct(u32) {
    disabled: bool,
    password_expired: bool,
    must_change_password: bool,
    no_password: bool,
    system_user: bool,
    reserved: u27
}

const Group = struct {
    gid: u32,
    name: [32]u8,
    members: [256]u32,
    num_members: u16
}

// User and group tables
let users: [MAX_USERS]?*User = undefined
let groups: [MAX_GROUPS]?*Group = undefined
```

### Credential Management

```home
const Credentials = struct {
    uid: u32,
    gid: u32,
    euid: u32,  // Effective UID
    egid: u32,  // Effective GID
    suid: u32,  // Saved UID
    sgid: u32,  // Saved GID
    fsuid: u32, // Filesystem UID
    fsgid: u32, // Filesystem GID
    supplementary_groups: [32]u32,
    num_groups: u8,
    capabilities: CapabilitySet,
    securebits: u32
}

export fn get_current_credentials(): *Credentials {
    return &get_current_process().credentials
}

export fn sys_setuid(uid: u32): i32 {
    let cred = get_current_credentials()

    // Check permission
    if cred.euid != 0 and uid != cred.uid and uid != cred.suid {
        return -EPERM
    }

    if cred.euid == 0 {
        // Root can set all UIDs
        cred.uid = uid
        cred.euid = uid
        cred.suid = uid
        cred.fsuid = uid
    } else {
        // Non-root can only set effective UID
        cred.euid = uid
        cred.fsuid = uid
    }

    return 0
}

export fn sys_setgid(gid: u32): i32 {
    let cred = get_current_credentials()

    if cred.euid != 0 and gid != cred.gid and gid != cred.sgid {
        return -EPERM
    }

    if cred.euid == 0 {
        cred.gid = gid
        cred.egid = gid
        cred.sgid = gid
        cred.fsgid = gid
    } else {
        cred.egid = gid
        cred.fsgid = gid
    }

    return 0
}

export fn sys_getgroups(size: i32, list: []u32): i32 {
    let cred = get_current_credentials()

    if size == 0 {
        return cred.num_groups
    }

    if size < cred.num_groups {
        return -EINVAL
    }

    for i in 0..cred.num_groups {
        list[i] = cred.supplementary_groups[i]
    }

    return cred.num_groups
}
```

## Permission Checking

### File Permission Model

```home
const FileMode = packed struct(u16) {
    other_execute: bool,
    other_write: bool,
    other_read: bool,
    group_execute: bool,
    group_write: bool,
    group_read: bool,
    owner_execute: bool,
    owner_write: bool,
    owner_read: bool,
    sticky: bool,
    setgid: bool,
    setuid: bool,
    file_type: u4
}

const AccessMode = enum(u32) {
    Read = 4,
    Write = 2,
    Execute = 1,
    Exists = 0
}

export fn check_permission(inode: *Inode, mode: AccessMode): bool {
    let cred = get_current_credentials()

    // Root can do anything (except execute without execute bit)
    if cred.euid == 0 {
        if mode != AccessMode.Execute {
            return true
        }
        // Root can execute if any execute bit is set
        if (inode.mode & 0o111) != 0 {
            return true
        }
    }

    let required = @intFromEnum(mode)
    let file_mode = inode.mode

    // Check owner permission
    if cred.fsuid == inode.uid {
        let owner_perm = (file_mode >> 6) & 7
        return (owner_perm & required) == required
    }

    // Check group permission
    if cred.fsgid == inode.gid or is_in_group(cred, inode.gid) {
        let group_perm = (file_mode >> 3) & 7
        return (group_perm & required) == required
    }

    // Check other permission
    let other_perm = file_mode & 7
    return (other_perm & required) == required
}

fn is_in_group(cred: *Credentials, gid: u32): bool {
    for i in 0..cred.num_groups {
        if cred.supplementary_groups[i] == gid {
            return true
        }
    }
    return false
}
```

### Access Control Lists

```home
const ACL_TYPE_ACCESS = 0x8000
const ACL_TYPE_DEFAULT = 0x4000

const AclEntryType = enum(u16) {
    UserObj = 0x01,
    User = 0x02,
    GroupObj = 0x04,
    Group = 0x08,
    Mask = 0x10,
    Other = 0x20
}

const AclEntry = struct {
    type: AclEntryType,
    id: u32,  // UID or GID
    permissions: u16
}

const Acl = struct {
    entries: [32]AclEntry,
    count: u8
}

export fn acl_check_permission(inode: *Inode, mode: AccessMode): bool {
    let acl = inode.acl
    if acl == null {
        // Fall back to standard permission check
        return check_permission(inode, mode)
    }

    let cred = get_current_credentials()
    let required = @intFromEnum(mode)

    // Find applicable entry
    var entry: ?*AclEntry = null
    var mask_entry: ?*AclEntry = null

    for i in 0..acl.count {
        let e = &acl.entries[i]

        switch e.type {
            AclEntryType.UserObj => {
                if cred.fsuid == inode.uid {
                    return (e.permissions & required) == required
                }
            },
            AclEntryType.User => {
                if cred.fsuid == e.id {
                    entry = e
                }
            },
            AclEntryType.GroupObj => {
                if cred.fsgid == inode.gid and entry == null {
                    entry = e
                }
            },
            AclEntryType.Group => {
                if is_in_group(cred, e.id) and entry == null {
                    entry = e
                }
            },
            AclEntryType.Mask => {
                mask_entry = e
            },
            AclEntryType.Other => {
                if entry == null {
                    entry = e
                }
            }
        }
    }

    if entry == null {
        return false
    }

    // Apply mask
    var perm = entry.permissions
    if mask_entry != null and entry.type != AclEntryType.UserObj and entry.type != AclEntryType.Other {
        perm &= mask_entry.permissions
    }

    return (perm & required) == required
}
```

## Capability System

### Capability Definitions

```home
const CAP_CHOWN = 0
const CAP_DAC_OVERRIDE = 1
const CAP_DAC_READ_SEARCH = 2
const CAP_FOWNER = 3
const CAP_FSETID = 4
const CAP_KILL = 5
const CAP_SETGID = 6
const CAP_SETUID = 7
const CAP_SETPCAP = 8
const CAP_LINUX_IMMUTABLE = 9
const CAP_NET_BIND_SERVICE = 10
const CAP_NET_BROADCAST = 11
const CAP_NET_ADMIN = 12
const CAP_NET_RAW = 13
const CAP_IPC_LOCK = 14
const CAP_IPC_OWNER = 15
const CAP_SYS_MODULE = 16
const CAP_SYS_RAWIO = 17
const CAP_SYS_CHROOT = 18
const CAP_SYS_PTRACE = 19
const CAP_SYS_PACCT = 20
const CAP_SYS_ADMIN = 21
const CAP_SYS_BOOT = 22
const CAP_SYS_NICE = 23
const CAP_SYS_RESOURCE = 24
const CAP_SYS_TIME = 25
const CAP_SYS_TTY_CONFIG = 26
const CAP_MKNOD = 27
const CAP_LEASE = 28
const CAP_AUDIT_WRITE = 29
const CAP_AUDIT_CONTROL = 30

const CapabilitySet = struct {
    effective: u64,
    permitted: u64,
    inheritable: u64,
    bounding: u64,
    ambient: u64
}

export fn capable(cap: u32): bool {
    let cred = get_current_credentials()

    if cap >= 64 {
        return false
    }

    return (cred.capabilities.effective & (1 << cap)) != 0
}

export fn cap_raise(caps: *CapabilitySet, cap: u32) {
    if cap < 64 {
        caps.effective |= (1 << cap)
    }
}

export fn cap_lower(caps: *CapabilitySet, cap: u32) {
    if cap < 64 {
        caps.effective &= ~(1 << cap)
    }
}
```

### Capability Enforcement

```home
export fn sys_setuid_check(): bool {
    return capable(CAP_SETUID)
}

export fn sys_chown_check(inode: *Inode): bool {
    let cred = get_current_credentials()

    // Owner can always change group to one they belong to
    if cred.fsuid == inode.uid {
        return true
    }

    return capable(CAP_CHOWN)
}

export fn sys_bind_port_check(port: u16): bool {
    if port >= 1024 {
        return true  // Unprivileged port
    }

    return capable(CAP_NET_BIND_SERVICE)
}

export fn sys_mknod_check(mode: u16): bool {
    // Block and character devices require CAP_MKNOD
    let type_bits = (mode >> 12) & 0xF

    if type_bits == 2 or type_bits == 6 {  // Character or block device
        return capable(CAP_MKNOD)
    }

    return true
}

export fn sys_module_check(): bool {
    return capable(CAP_SYS_MODULE)
}
```

## Memory Security

### Address Space Layout Randomization

```home
const ASLR_STACK_ENTROPY = 22  // bits
const ASLR_MMAP_ENTROPY = 28
const ASLR_HEAP_ENTROPY = 13

export fn randomize_stack_base(): usize {
    let base = STACK_TOP
    let entropy = get_random_bits(ASLR_STACK_ENTROPY)
    return base - (entropy * PAGE_SIZE)
}

export fn randomize_mmap_base(): usize {
    let base = MMAP_BASE
    let entropy = get_random_bits(ASLR_MMAP_ENTROPY)
    return base + (entropy * PAGE_SIZE)
}

export fn randomize_heap_base(brk: usize): usize {
    let entropy = get_random_bits(ASLR_HEAP_ENTROPY)
    return brk + (entropy * PAGE_SIZE)
}

fn get_random_bits(bits: u32): usize {
    let random = get_random_u64()
    let mask = (1 << bits) - 1
    return random & mask
}

export fn setup_process_aslr(proc: *Process) {
    if !aslr_enabled() {
        return
    }

    proc.stack_base = randomize_stack_base()
    proc.mmap_base = randomize_mmap_base()
    proc.heap_base = randomize_heap_base(proc.brk)
}
```

### Stack Canaries

```home
// Per-thread stack canary
export fn set_stack_canary(thread: *Thread) {
    thread.stack_canary = get_random_u64()
}

export fn verify_stack_canary(thread: *Thread): bool {
    let stack_ptr = thread.stack_pointer

    // Canary is stored just below the return address
    let canary_addr = stack_ptr - 8
    let canary: *u64 = @ptrFromInt(canary_addr)

    return canary.* == thread.stack_canary
}

// Called on function return (compiler-generated)
export fn __stack_chk_fail() {
    kernel_panic("Stack smashing detected")
}

// Function prologue inserts canary
fn example_with_canary() {
    // Compiler generates:
    // mov rax, [gs:0x28]  ; Load canary from thread-local
    // mov [rbp-8], rax    ; Store on stack

    // ... function body ...

    // Compiler generates:
    // mov rax, [rbp-8]    ; Load canary from stack
    // xor rax, [gs:0x28]  ; Compare with thread-local
    // jne __stack_chk_fail
}
```

### Guard Pages

```home
export fn allocate_guarded_stack(size: usize): ?[]u8 {
    // Total size includes guard pages
    let total_size = size + 2 * PAGE_SIZE

    let base = mmap(null, total_size, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)
    if base == MAP_FAILED {
        return null
    }

    // Protect middle region as read/write
    let stack_start = @intFromPtr(base) + PAGE_SIZE
    mprotect(@ptrFromInt(stack_start), size, PROT_READ | PROT_WRITE)

    // Bottom and top guard pages remain PROT_NONE
    return @ptrFromInt(stack_start)[0..size]
}

export fn setup_kernel_guard_pages() {
    // Guard pages around kernel stack
    let guard_bottom = KERNEL_STACK_BOTTOM - PAGE_SIZE
    let guard_top = KERNEL_STACK_TOP

    // Unmap guard pages
    map_page(kernel_pml4, guard_bottom, 0, 0)
    map_page(kernel_pml4, guard_top, 0, 0)
}
```

## Secure Boot

### Boot Verification

```home
const SIGNATURE_SIZE = 256
const HASH_SIZE = 32

const BootModule = struct {
    name: [64]u8,
    data: []const u8,
    signature: [SIGNATURE_SIZE]u8,
    hash: [HASH_SIZE]u8
}

const PublicKey = struct {
    modulus: [256]u8,
    exponent: u32
}

// Embedded platform key
const platform_key = PublicKey{
    .modulus = embed_key("platform_key.pub"),
    .exponent = 65537
}

export fn verify_boot_module(module: *BootModule): bool {
    // Calculate hash of module
    var calculated_hash: [HASH_SIZE]u8 = undefined
    sha256(module.data, &calculated_hash)

    // Verify hash matches
    if !mem_equal(&calculated_hash, &module.hash, HASH_SIZE) {
        return false
    }

    // Verify signature
    var decrypted: [SIGNATURE_SIZE]u8 = undefined
    rsa_decrypt(&platform_key, &module.signature, &decrypted)

    // Check PKCS#1 padding and hash
    return verify_pkcs1_signature(&decrypted, &calculated_hash)
}

export fn secure_boot_init() {
    // Verify kernel modules
    for module in boot_modules {
        if !verify_boot_module(module) {
            kernel_panic("Boot module verification failed")
        }
    }

    // Lock down secure boot state
    secure_boot_locked = true
}
```

### Kernel Lockdown

```home
const LockdownLevel = enum {
    None,
    Integrity,  // Prevent unsigned code execution
    Confidentiality  // Also prevent reading kernel memory
}

let lockdown_level: LockdownLevel = LockdownLevel.None

export fn set_lockdown(level: LockdownLevel): i32 {
    // Can only increase lockdown level
    if @intFromEnum(level) < @intFromEnum(lockdown_level) {
        return -EPERM
    }

    lockdown_level = level
    return 0
}

export fn lockdown_check(operation: LockdownOperation): bool {
    switch lockdown_level {
        LockdownLevel.None => return true,
        LockdownLevel.Integrity => {
            switch operation {
                LockdownOperation.ModuleLoad,
                LockdownOperation.KexecLoad,
                LockdownOperation.Hibernation,
                LockdownOperation.PCMCIA_CIS,
                LockdownOperation.ACPI_Tables,
                LockdownOperation.IRQHandler => return false,
                else => return true
            }
        },
        LockdownLevel.Confidentiality => {
            switch operation {
                LockdownOperation.DevMem,
                LockdownOperation.DevKmem,
                LockdownOperation.DevPort,
                LockdownOperation.MSR,
                LockdownOperation.KernelDebug,
                LockdownOperation.ProcKcore => return false,
                else => return lockdown_check_integrity(operation)
            }
        }
    }
}
```

## Cryptographic Services

### Kernel Crypto API

```home
const CryptoAlgorithm = struct {
    name: [64]u8,
    type: CryptoType,
    init: fn (*CryptoContext) i32,
    update: fn (*CryptoContext, []const u8) i32,
    final: fn (*CryptoContext, []u8) i32,
    setkey: fn (*CryptoContext, []const u8) i32,
    block_size: u32,
    digest_size: u32
}

const CryptoType = enum {
    Hash,
    Cipher,
    AEAD,
    RNG
}

const CryptoContext = struct {
    algorithm: *CryptoAlgorithm,
    key: [256]u8,
    key_len: usize,
    state: [512]u8
}

// Registered algorithms
let crypto_algorithms: HashMap([]const u8, *CryptoAlgorithm) = undefined

export fn crypto_register_alg(alg: *CryptoAlgorithm): i32 {
    crypto_algorithms.put(alg.name, alg)
    return 0
}

export fn crypto_alloc_hash(name: []const u8): ?*CryptoContext {
    let alg = crypto_algorithms.get(name) ?? return null

    if alg.type != CryptoType.Hash {
        return null
    }

    let ctx = memory.allocate(CryptoContext) ?? return null
    ctx.algorithm = alg

    if alg.init(ctx) < 0 {
        memory.free(ctx)
        return null
    }

    return ctx
}

export fn crypto_hash(ctx: *CryptoContext, data: []const u8, out: []u8): i32 {
    let result = ctx.algorithm.update(ctx, data)
    if result < 0 {
        return result
    }

    return ctx.algorithm.final(ctx, out)
}
```

### SHA-256 Implementation

```home
const SHA256_BLOCK_SIZE = 64
const SHA256_DIGEST_SIZE = 32

const Sha256State = struct {
    h: [8]u32,
    block: [64]u8,
    block_len: usize,
    total_len: u64
}

const sha256_k = [_]u32{
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    // ... (64 constants total)
}

fn sha256_init(ctx: *CryptoContext): i32 {
    let state: *Sha256State = @ptrCast(&ctx.state)

    state.h[0] = 0x6a09e667
    state.h[1] = 0xbb67ae85
    state.h[2] = 0x3c6ef372
    state.h[3] = 0xa54ff53a
    state.h[4] = 0x510e527f
    state.h[5] = 0x9b05688c
    state.h[6] = 0x1f83d9ab
    state.h[7] = 0x5be0cd19
    state.block_len = 0
    state.total_len = 0

    return 0
}

fn sha256_update(ctx: *CryptoContext, data: []const u8): i32 {
    let state: *Sha256State = @ptrCast(&ctx.state)

    var i: usize = 0
    while i < data.len {
        let remaining = SHA256_BLOCK_SIZE - state.block_len
        let to_copy = @min(remaining, data.len - i)

        @memcpy(&state.block[state.block_len], &data[i], to_copy)
        state.block_len += to_copy
        i += to_copy

        if state.block_len == SHA256_BLOCK_SIZE {
            sha256_transform(state)
            state.block_len = 0
        }
    }

    state.total_len += data.len

    return 0
}

fn sha256_final(ctx: *CryptoContext, out: []u8): i32 {
    let state: *Sha256State = @ptrCast(&ctx.state)

    // Padding
    let total_bits = state.total_len * 8
    state.block[state.block_len] = 0x80
    state.block_len += 1

    if state.block_len > 56 {
        @memset(&state.block[state.block_len], 0, 64 - state.block_len)
        sha256_transform(state)
        state.block_len = 0
    }

    @memset(&state.block[state.block_len], 0, 56 - state.block_len)

    // Append length
    state.block[56] = @truncate(total_bits >> 56)
    state.block[57] = @truncate(total_bits >> 48)
    state.block[58] = @truncate(total_bits >> 40)
    state.block[59] = @truncate(total_bits >> 32)
    state.block[60] = @truncate(total_bits >> 24)
    state.block[61] = @truncate(total_bits >> 16)
    state.block[62] = @truncate(total_bits >> 8)
    state.block[63] = @truncate(total_bits)

    sha256_transform(state)

    // Output hash
    for i in 0..8 {
        out[i * 4] = @truncate(state.h[i] >> 24)
        out[i * 4 + 1] = @truncate(state.h[i] >> 16)
        out[i * 4 + 2] = @truncate(state.h[i] >> 8)
        out[i * 4 + 3] = @truncate(state.h[i])
    }

    return 0
}

fn sha256_transform(state: *Sha256State) {
    var w: [64]u32 = undefined
    var a = state.h[0]
    var b = state.h[1]
    var c = state.h[2]
    var d = state.h[3]
    var e = state.h[4]
    var f = state.h[5]
    var g = state.h[6]
    var h = state.h[7]

    // Prepare message schedule
    for i in 0..16 {
        w[i] = (@as(u32, state.block[i * 4]) << 24) |
               (@as(u32, state.block[i * 4 + 1]) << 16) |
               (@as(u32, state.block[i * 4 + 2]) << 8) |
               state.block[i * 4 + 3]
    }

    for i in 16..64 {
        let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
        let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
        w[i] = w[i - 16] +% s0 +% w[i - 7] +% s1
    }

    // Main loop
    for i in 0..64 {
        let S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
        let ch = (e & f) ^ (~e & g)
        let temp1 = h +% S1 +% ch +% sha256_k[i] +% w[i]
        let S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
        let maj = (a & b) ^ (a & c) ^ (b & c)
        let temp2 = S0 +% maj

        h = g
        g = f
        f = e
        e = d +% temp1
        d = c
        c = b
        b = a
        a = temp1 +% temp2
    }

    state.h[0] +%= a
    state.h[1] +%= b
    state.h[2] +%= c
    state.h[3] +%= d
    state.h[4] +%= e
    state.h[5] +%= f
    state.h[6] +%= g
    state.h[7] +%= h
}
```

## Summary

HomeOS security provides:

- **User/Group Model**: Traditional Unix-style user and group management
- **Permission System**: File permissions with ACL support
- **Capabilities**: Fine-grained privilege separation
- **Memory Security**: ASLR, stack canaries, guard pages
- **Secure Boot**: Cryptographic verification chain
- **Kernel Lockdown**: Protection against runtime tampering
- **Crypto API**: Pluggable cryptographic algorithms

All security code is implemented in the Home programming language, providing type-safe access control and cryptographic operations.
