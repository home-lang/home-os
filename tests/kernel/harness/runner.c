// home-os Kernel Regression Test Harness
//
// Host-side C test runner that mirrors the algorithmic fixes in the
// kernel tree. The real kernel code in kernel/src/*.home type-checks
// but has no runnable codegen target today, so we validate the logic
// here by reimplementing each fix in C and exercising it.
//
// Each test in this file corresponds 1:1 to a fix I landed, and the
// C implementation mirrors the Home source so that bugs in the algo
// show up as failures here. Compile with zig cc (works on macOS 26):
//
//   zig cc tests/kernel/harness/runner.c -o tests/kernel/harness/runner \
//       -target native-macos -O2
//
// Then run: ./tests/kernel/harness/runner
//
// Exit code is the number of failed tests.

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>

// ============================================================================
// TEST FRAMEWORK
// ============================================================================

static int g_pass = 0;
static int g_fail = 0;

#define RUN(name) do { \
    printf("  [ ] %-50s ", #name); \
    fflush(stdout); \
    int before = g_fail; \
    test_##name(); \
    if (g_fail == before) { printf("\x1b[32mPASS\x1b[0m\n"); g_pass++; } \
    else { printf("\x1b[31mFAIL\x1b[0m\n"); } \
} while (0)

#define ASSERT(cond, msg) do { \
    if (!(cond)) { \
        printf("\n    assertion failed: %s (%s:%d)\n", msg, __FILE__, __LINE__); \
        g_fail++; \
        return; \
    } \
} while (0)

#define ASSERT_EQ(a, b, msg) do { \
    if ((uint64_t)(a) != (uint64_t)(b)) { \
        printf("\n    %s: expected %llu, got %llu (%s:%d)\n", msg, \
               (unsigned long long)(b), (unsigned long long)(a), __FILE__, __LINE__); \
        g_fail++; \
        return; \
    } \
} while (0)

// ============================================================================
// memory.home — mem_copy
// ============================================================================
//
// Kernel source: kernel/src/core/memory.home:553
// Fast path: 8-byte aligned bulk copy, overlap-safe backwards for dst>src,
// byte fallback for unaligned / tiny / overlap.

static void mem_copy(uint64_t dst, uint64_t src, uint64_t size) {
    if (size == 0) return;
    if (dst == src) return;

    // Backwards copy for overlap where dst > src.
    if (dst > src && dst < src + size) {
        uint8_t *d = (uint8_t *)dst;
        uint8_t *s = (uint8_t *)src;
        for (uint64_t i = size; i > 0; ) {
            i--;
            d[i] = s[i];
        }
        return;
    }

    // Word-sized fast path.
    if ((dst & 7) == 0 && (src & 7) == 0 && size >= 8) {
        uint64_t *dw = (uint64_t *)dst;
        uint64_t *sw = (uint64_t *)src;
        uint64_t words = size >> 3;
        for (uint64_t i = 0; i < words; i++) dw[i] = sw[i];
        uint64_t copied = words << 3;
        uint8_t *db = (uint8_t *)(dst + copied);
        uint8_t *sb = (uint8_t *)(src + copied);
        uint64_t tail = size - copied;
        for (uint64_t j = 0; j < tail; j++) db[j] = sb[j];
        return;
    }

    // Byte fallback.
    uint8_t *d = (uint8_t *)dst;
    uint8_t *s = (uint8_t *)src;
    for (uint64_t i = 0; i < size; i++) d[i] = s[i];
}

static void test_memcpy_word_aligned(void) {
    uint64_t src[8], dst[8];
    for (int i = 0; i < 8; i++) { src[i] = 0xDEADBEEF00000000ULL + i; dst[i] = 0; }
    mem_copy((uint64_t)dst, (uint64_t)src, 64);
    for (int i = 0; i < 8; i++) ASSERT_EQ(dst[i], src[i], "word copy mismatch");
}

static void test_memcpy_unaligned(void) {
    uint8_t buf[64];
    memset(buf, 0, sizeof buf);
    for (int i = 0; i < 16; i++) buf[1 + i] = (uint8_t)(i + 1);
    mem_copy((uint64_t)(buf + 32), (uint64_t)(buf + 1), 16);
    for (int i = 0; i < 16; i++) ASSERT_EQ(buf[32 + i], (uint8_t)(i + 1), "unaligned copy");
}

static void test_memcpy_overlap_down(void) {
    uint8_t buf[32] = {0};
    for (int i = 0; i < 16; i++) buf[i] = (uint8_t)(i + 1);
    // Shift the first 16 bytes up by 4 — overlapping.
    mem_copy((uint64_t)(buf + 4), (uint64_t)buf, 16);
    for (int i = 0; i < 16; i++) ASSERT_EQ(buf[4 + i], (uint8_t)(i + 1), "overlap down");
}

static void test_memcpy_empty_noop(void) {
    uint8_t dst = 0xAB;
    uint8_t src = 0xCD;
    mem_copy((uint64_t)&dst, (uint64_t)&src, 0);
    ASSERT_EQ(dst, 0xAB, "size 0 no-op");
}

static void test_memcpy_tail_bytes(void) {
    uint8_t src[24], dst[24];
    memset(dst, 0, sizeof dst);
    for (int i = 0; i < 24; i++) src[i] = (uint8_t)(0x30 + i);
    // Copy 20 bytes — 2 full words + 4 tail.
    mem_copy((uint64_t)dst, (uint64_t)src, 20);
    for (int i = 0; i < 20; i++) ASSERT_EQ(dst[i], src[i], "tail bytes");
    ASSERT_EQ(dst[20], 0, "past-end untouched");
    ASSERT_EQ(dst[23], 0, "past-end untouched");
}

// ============================================================================
// sync/spinlock.home — atomic contention stats + TTAS backoff
// ============================================================================
//
// Single-thread: contention counter stays 0 on uncontended acquires.
// The spinlock_acquire() algo from spinlock.home, lines 165-197 of the
// patched file.

typedef struct { volatile uint32_t locked; uint64_t contention; uint32_t owner; } Spinlock;

static uint32_t atomic_cmpxchg(volatile uint32_t *p, uint32_t want, uint32_t set) {
    return __sync_val_compare_and_swap(p, want, set);
}
static uint64_t atomic_fetch_add_64(volatile uint64_t *p, uint64_t v) {
    return __sync_fetch_and_add(p, v);
}

static void spin_init(Spinlock *l) { l->locked = 0; l->contention = 0; l->owner = 0xFFFFFFFF; }
static void spin_release(Spinlock *l) { __sync_synchronize(); __sync_lock_release(&l->locked); }
static void spin_acquire(Spinlock *l) {
    uint32_t backoff = 1;
    uint32_t counted = 0;
    for (;;) {
        if (atomic_cmpxchg(&l->locked, 0, 1) == 0) {
            __sync_synchronize();
            return;
        }
        if (counted == 0) {
            atomic_fetch_add_64(&l->contention, 1);
            counted = 1;
        }
        while (__atomic_load_n(&l->locked, __ATOMIC_RELAXED) != 0) {
            for (uint32_t i = 0; i < backoff; i++) __asm__ __volatile__("");
            if (backoff < 1024) backoff <<= 1;
        }
    }
}

static void test_spinlock_no_contention(void) {
    Spinlock lk;
    spin_init(&lk);
    for (int i = 0; i < 100; i++) { spin_acquire(&lk); spin_release(&lk); }
    ASSERT_EQ(lk.contention, 0, "no contention counter");
}

// ============================================================================
// sync/spinlock.home — rwspinlock_try_upgrade
// ============================================================================

#define RW_WRITER (1U << 31)
typedef struct { volatile uint32_t lock; } RWSpinlock;

static void rw_init(RWSpinlock *l) { l->lock = 0; }
static void rw_read_acquire(RWSpinlock *l) {
    for (;;) {
        uint32_t old = __atomic_load_n(&l->lock, __ATOMIC_ACQUIRE);
        if (old & RW_WRITER) continue;
        if (__sync_val_compare_and_swap(&l->lock, old, old + 1) == old) return;
    }
}
static void rw_read_release(RWSpinlock *l) { __sync_fetch_and_sub(&l->lock, 1); }
static void rw_write_release(RWSpinlock *l) { __atomic_store_n(&l->lock, 0, __ATOMIC_RELEASE); }
static uint32_t rw_try_upgrade(RWSpinlock *l) {
    return __sync_val_compare_and_swap(&l->lock, 1, RW_WRITER) == 1;
}

static void test_rw_upgrade_single_reader(void) {
    RWSpinlock lk;
    rw_init(&lk);
    rw_read_acquire(&lk);
    uint32_t ok = rw_try_upgrade(&lk);
    ASSERT_EQ(ok, 1, "single reader upgrade");
    rw_write_release(&lk);
}

static void test_rw_upgrade_multi_reader_fails(void) {
    RWSpinlock lk;
    rw_init(&lk);
    rw_read_acquire(&lk);
    rw_read_acquire(&lk);
    uint32_t ok = rw_try_upgrade(&lk);
    ASSERT_EQ(ok, 0, "multi reader upgrade must fail");
    rw_read_release(&lk);
    rw_read_release(&lk);
}

// ============================================================================
// sched/scheduler.home — pid_hash with linear probing
// ============================================================================
//
// Mirrors pid_hash, hash_insert, hash_remove, find_rq_entry from
// kernel/src/sched/scheduler.home:148-232.

#define RQ_HASH 256
#define RQ_MASK 255
#define HASH_EMPTY    0xFFFFFFFFU
#define HASH_TOMBSTONE 0xFFFFFFFEU

typedef struct { uint32_t pid; uint64_t vruntime; uint32_t on_rq; } RqEntry;
typedef struct {
    RqEntry rq[RQ_HASH];
    uint32_t pid_hash[RQ_HASH];
    uint32_t free_head;
} Rq;

static uint32_t pid_hash_fn(uint32_t pid) { return ((pid * 2654435761U) >> 8) & RQ_MASK; }

static void rq_init(Rq *r) {
    r->free_head = 0;
    for (uint32_t j = 0; j < RQ_HASH; j++) {
        r->rq[j].pid = 0;
        r->rq[j].on_rq = 0;
        r->rq[j].vruntime = (j + 1 < RQ_HASH) ? j + 1 : 0xFFFFFFFFFFFFFFFFULL;
        r->pid_hash[j] = HASH_EMPTY;
    }
}

static uint32_t rq_find(Rq *r, uint32_t pid) {
    if (pid == 0) return HASH_EMPTY;
    uint32_t h = pid_hash_fn(pid);
    for (uint32_t p = 0; p < RQ_HASH; p++) {
        uint32_t slot = r->pid_hash[h];
        if (slot == HASH_EMPTY) return HASH_EMPTY;
        if (slot != HASH_TOMBSTONE && r->rq[slot].pid == pid) return slot;
        h = (h + 1) & RQ_MASK;
    }
    return HASH_EMPTY;
}

static void rq_hash_insert(Rq *r, uint32_t pid, uint32_t slot) {
    uint32_t h = pid_hash_fn(pid);
    for (uint32_t p = 0; p < RQ_HASH; p++) {
        uint32_t cur = r->pid_hash[h];
        if (cur == HASH_EMPTY || cur == HASH_TOMBSTONE) { r->pid_hash[h] = slot; return; }
        h = (h + 1) & RQ_MASK;
    }
}

static void rq_hash_remove(Rq *r, uint32_t pid) {
    uint32_t h = pid_hash_fn(pid);
    for (uint32_t p = 0; p < RQ_HASH; p++) {
        uint32_t slot = r->pid_hash[h];
        if (slot == HASH_EMPTY) return;
        if (slot != HASH_TOMBSTONE && r->rq[slot].pid == pid) {
            r->pid_hash[h] = HASH_TOMBSTONE;
            return;
        }
        h = (h + 1) & RQ_MASK;
    }
}

static uint32_t rq_alloc_slot(Rq *r) {
    uint32_t head = r->free_head;
    if (head >= RQ_HASH) return HASH_EMPTY;
    uint64_t next = r->rq[head].vruntime;
    r->free_head = (next == 0xFFFFFFFFFFFFFFFFULL) ? HASH_EMPTY : (uint32_t)next;
    return head;
}

static void rq_free_slot(Rq *r, uint32_t slot) {
    uint32_t head = r->free_head;
    r->rq[slot].vruntime = (head == HASH_EMPTY) ? 0xFFFFFFFFFFFFFFFFULL : head;
    r->free_head = slot;
}

static void rq_enqueue(Rq *r, uint32_t pid) {
    uint32_t slot = rq_find(r, pid);
    if (slot == HASH_EMPTY) {
        slot = rq_alloc_slot(r);
        if (slot == HASH_EMPTY) return;
        rq_hash_insert(r, pid, slot);
    }
    r->rq[slot].pid = pid;
    r->rq[slot].on_rq = 1;
    r->rq[slot].vruntime = 0;
}

static void rq_dequeue(Rq *r, uint32_t pid) {
    uint32_t slot = rq_find(r, pid);
    if (slot == HASH_EMPTY) return;
    r->rq[slot].pid = 0;
    r->rq[slot].on_rq = 0;
    rq_hash_remove(r, pid);
    rq_free_slot(r, slot);
}

static void test_rq_enqueue_find(void) {
    Rq rq;
    rq_init(&rq);
    rq_enqueue(&rq, 42);
    rq_enqueue(&rq, 7);
    rq_enqueue(&rq, 1337);

    ASSERT(rq_find(&rq, 42) != HASH_EMPTY, "find 42");
    ASSERT(rq_find(&rq, 7) != HASH_EMPTY, "find 7");
    ASSERT(rq_find(&rq, 1337) != HASH_EMPTY, "find 1337");
    ASSERT_EQ(rq_find(&rq, 9999), HASH_EMPTY, "missing PID returns empty");
}

static void test_rq_dequeue_free_slot_reuse(void) {
    Rq rq;
    rq_init(&rq);
    rq_enqueue(&rq, 1);
    rq_enqueue(&rq, 2);
    rq_enqueue(&rq, 3);
    rq_dequeue(&rq, 2);
    ASSERT_EQ(rq_find(&rq, 2), HASH_EMPTY, "2 gone after dequeue");
    // Enqueue 4 — should reuse slot 1 (where 2 used to live, now on free list).
    rq_enqueue(&rq, 4);
    uint32_t slot = rq_find(&rq, 4);
    ASSERT(slot != HASH_EMPTY, "4 found after enqueue");
    ASSERT_EQ(slot, 1, "slot 1 reused");
}

static void test_rq_collision_walk(void) {
    Rq rq;
    rq_init(&rq);
    // Insert PIDs that collide — pid 1 and pid 1+RQ_HASH hash to same bucket
    // only if the multiplier happens to wrap there; more portably, just
    // insert many and verify all round-trip.
    const uint32_t n = 200;
    for (uint32_t i = 1; i <= n; i++) rq_enqueue(&rq, i * 17);
    for (uint32_t i = 1; i <= n; i++) {
        uint32_t slot = rq_find(&rq, i * 17);
        ASSERT(slot != HASH_EMPTY, "bulk insert lookup");
    }
}

// ============================================================================
// mm/buddy.home — magic sentinel in free-block header
// ============================================================================
//
// Mirrors the FREE_BLOCK_MAGIC trick. O(1) find_free_block instead of
// walking the free list.

#define FREE_BLOCK_MAGIC 0xB0DDF00DU

typedef struct FreeBlock {
    struct FreeBlock *next;
    struct FreeBlock *prev;
    uint32_t order;
    uint32_t zone;
    uint32_t magic;
} FreeBlock;

static FreeBlock *buddy_find(uint64_t addr, uint32_t order, uint64_t base, uint64_t size) {
    if (addr < base) return NULL;
    if (addr >= base + size) return NULL;
    FreeBlock *b = (FreeBlock *)(uintptr_t)addr;
    if (b->magic != FREE_BLOCK_MAGIC) return NULL;
    if (b->order != order) return NULL;
    return b;
}

static void test_buddy_magic_sentinel(void) {
    uint8_t arena[4096];
    memset(arena, 0, sizeof arena);
    uint64_t base = (uint64_t)(uintptr_t)arena;

    // Place a fake free block at offset 0.
    FreeBlock *b = (FreeBlock *)arena;
    b->next = NULL; b->prev = NULL;
    b->order = 2;
    b->zone = 0;
    b->magic = FREE_BLOCK_MAGIC;

    ASSERT(buddy_find(base, 2, base, sizeof arena) == b, "find live free block");
    ASSERT_EQ(buddy_find(base, 3, base, sizeof arena), (uint64_t)NULL, "wrong order → null");

    // "Allocate" by clearing magic.
    b->magic = 0;
    ASSERT_EQ(buddy_find(base, 2, base, sizeof arena), (uint64_t)NULL, "cleared magic → null");

    // Out of range returns null.
    ASSERT_EQ(buddy_find(base - 1, 2, base, sizeof arena), (uint64_t)NULL, "below base → null");
    ASSERT_EQ(buddy_find(base + sizeof arena, 2, base, sizeof arena), (uint64_t)NULL, "above end → null");
}

// ============================================================================
// net/socket.home — FD hash table (O(1) find_socket)
// ============================================================================

#define FD_BASE 100
#define FD_TABLE 512
#define FD_MASK  511

static uint32_t fd_table[FD_TABLE];
static uint32_t fd_used[FD_TABLE]; // slot → fd
static uint32_t fd_count;

static uint32_t fd_hash(uint32_t fd) {
    return ((fd - FD_BASE) * 2654435761U) & FD_MASK;
}

static void fd_reset(void) {
    for (int i = 0; i < FD_TABLE; i++) { fd_table[i] = HASH_EMPTY; fd_used[i] = 0; }
    fd_count = 0;
}

static void fd_insert(uint32_t fd, uint32_t slot) {
    fd_used[slot] = fd;
    uint32_t h = fd_hash(fd);
    for (uint32_t p = 0; p < FD_TABLE; p++) {
        uint32_t cur = fd_table[h];
        if (cur == HASH_EMPTY || cur == HASH_TOMBSTONE) { fd_table[h] = slot; return; }
        h = (h + 1) & FD_MASK;
    }
}

static uint32_t fd_find(uint32_t fd) {
    if (fd < FD_BASE) return HASH_EMPTY;
    uint32_t h = fd_hash(fd);
    for (uint32_t p = 0; p < FD_TABLE; p++) {
        uint32_t slot = fd_table[h];
        if (slot == HASH_EMPTY) return HASH_EMPTY;
        if (slot != HASH_TOMBSTONE && fd_used[slot] == fd) return slot;
        h = (h + 1) & FD_MASK;
    }
    return HASH_EMPTY;
}

static void fd_remove(uint32_t fd) {
    uint32_t h = fd_hash(fd);
    for (uint32_t p = 0; p < FD_TABLE; p++) {
        uint32_t slot = fd_table[h];
        if (slot == HASH_EMPTY) return;
        if (slot != HASH_TOMBSTONE && fd_used[slot] == fd) {
            fd_table[h] = HASH_TOMBSTONE;
            return;
        }
        h = (h + 1) & FD_MASK;
    }
}

static void test_fd_hash_roundtrip(void) {
    fd_reset();
    fd_insert(100, 0);
    fd_insert(101, 1);
    fd_insert(102, 2);
    ASSERT_EQ(fd_find(100), 0, "find 100");
    ASSERT_EQ(fd_find(101), 1, "find 101");
    ASSERT_EQ(fd_find(102), 2, "find 102");
    fd_remove(101);
    ASSERT_EQ(fd_find(101), HASH_EMPTY, "101 gone");
    ASSERT_EQ(fd_find(100), 0, "100 still there");
    ASSERT_EQ(fd_find(102), 2, "102 still there");
}

static void test_fd_hash_below_base(void) {
    fd_reset();
    ASSERT_EQ(fd_find(42), HASH_EMPTY, "fd < FD_BASE rejected");
    ASSERT_EQ(fd_find(0), HASH_EMPTY, "fd 0 rejected");
}

// ============================================================================
// net/tcp.home — 5-tuple hash
// ============================================================================

#define TCP_HASH 512
#define TCP_MASK 511

static uint32_t tcp_hash(uint16_t local_port, uint32_t remote_ip, uint16_t remote_port) {
    uint32_t k = remote_ip;
    k ^= ((uint32_t)local_port << 16);
    k ^= (uint32_t)remote_port;
    k *= 2654435761U;
    return (k >> 16) & TCP_MASK;
}

static void test_tcp_hash_stable(void) {
    uint32_t h1 = tcp_hash(12345, 0x0A000001, 80);
    uint32_t h2 = tcp_hash(12345, 0x0A000001, 80);
    ASSERT_EQ(h1, h2, "hash is stable");
}

static void test_tcp_hash_distinct(void) {
    // Connections that differ in exactly one tuple component must
    // (usually) land in different buckets.
    uint32_t a = tcp_hash(12345, 0x0A000001, 80);
    uint32_t b = tcp_hash(12346, 0x0A000001, 80);
    uint32_t c = tcp_hash(12345, 0x0A000002, 80);
    uint32_t d = tcp_hash(12345, 0x0A000001, 443);
    // At least 2 of the 4 should be distinct from a.
    int distinct = (a != b) + (a != c) + (a != d);
    ASSERT(distinct >= 2, "hash spreads inputs");
}

// ============================================================================
// net/tcp.home — Nagle logic
// ============================================================================
//
// Predicate: should we send now? For sub-MSS chunks with in-flight data,
// answer is NO when Nagle is enabled.

static int tcp_should_send(uint32_t chunk, uint32_t mss, uint32_t in_flight, uint32_t nagle_enabled) {
    if (nagle_enabled && chunk < mss && in_flight > 0) return 0;
    return 1;
}

static void test_nagle_holds_sub_mss_with_inflight(void) {
    ASSERT_EQ(tcp_should_send(100, 1460, 500, 1), 0, "held");
}

static void test_nagle_allows_full_mss(void) {
    ASSERT_EQ(tcp_should_send(1460, 1460, 500, 1), 1, "full MSS sent");
}

static void test_nagle_allows_when_empty(void) {
    ASSERT_EQ(tcp_should_send(100, 1460, 0, 1), 1, "no in-flight → send");
}

static void test_nagle_disabled_ignored(void) {
    ASSERT_EQ(tcp_should_send(100, 1460, 500, 0), 1, "Nagle off → send");
}

// ============================================================================
// net/socket.home — recv/send bounds
// ============================================================================

static int64_t socket_recv_clamp(uint64_t buf, uint64_t len, uint64_t recv_buf_size) {
    if (buf == 0) return -1;
    if (len > recv_buf_size) len = recv_buf_size;
    return (int64_t)len;
}

static void test_socket_recv_null_buf(void) {
    ASSERT_EQ(socket_recv_clamp(0, 128, 65536), (uint64_t)-1, "null buf rejected");
}

static void test_socket_recv_len_clamped(void) {
    ASSERT_EQ(socket_recv_clamp(0xDEAD, 1 << 30, 65536), 65536, "len clamped");
}

static void test_socket_recv_len_passthrough(void) {
    ASSERT_EQ(socket_recv_clamp(0xDEAD, 4096, 65536), 4096, "len passthrough");
}

// ============================================================================
// fs/ext2.home — LRU cache + hash lookup
// ============================================================================

#define EXT2_CACHE 256
#define EXT2_MASK  255

static uint32_t ext2_tags[EXT2_CACHE];
static uint32_t ext2_valid[EXT2_CACHE];
static uint64_t ext2_lru[EXT2_CACHE];
static uint32_t ext2_index[EXT2_CACHE];
static uint64_t ext2_clock;

static uint32_t ext2_hash(uint32_t blk) { return (blk * 2654435761U) & EXT2_MASK; }

static void ext2_reset(void) {
    ext2_clock = 0;
    for (int i = 0; i < EXT2_CACHE; i++) {
        ext2_valid[i] = 0; ext2_tags[i] = 0; ext2_lru[i] = 0;
        ext2_index[i] = HASH_EMPTY;
    }
}

static uint32_t ext2_lookup(uint32_t blk) {
    uint32_t h = ext2_hash(blk);
    for (uint32_t p = 0; p < EXT2_CACHE; p++) {
        uint32_t slot = ext2_index[h];
        if (slot == HASH_EMPTY) return HASH_EMPTY;
        if (ext2_valid[slot] && ext2_tags[slot] == blk) return slot;
        h = (h + 1) & EXT2_MASK;
    }
    return HASH_EMPTY;
}

static uint32_t ext2_pick_victim(void) {
    uint32_t victim = 0;
    uint64_t oldest = 0xFFFFFFFFFFFFFFFFULL;
    for (uint32_t i = 0; i < EXT2_CACHE; i++) {
        if (!ext2_valid[i]) return i;
        if (ext2_lru[i] < oldest) { oldest = ext2_lru[i]; victim = i; }
    }
    return victim;
}

static void ext2_rehash(void) {
    for (int i = 0; i < EXT2_CACHE; i++) ext2_index[i] = HASH_EMPTY;
    for (uint32_t i = 0; i < EXT2_CACHE; i++) {
        if (!ext2_valid[i]) continue;
        uint32_t h = ext2_hash(ext2_tags[i]);
        for (uint32_t p = 0; p < EXT2_CACHE; p++) {
            if (ext2_index[h] == HASH_EMPTY) { ext2_index[h] = i; break; }
            h = (h + 1) & EXT2_MASK;
        }
    }
}

static uint32_t ext2_insert(uint32_t blk) {
    ext2_clock++;
    uint32_t slot = ext2_lookup(blk);
    if (slot != HASH_EMPTY) { ext2_lru[slot] = ext2_clock; return slot; }

    uint32_t victim = ext2_pick_victim();
    uint32_t was_valid = ext2_valid[victim];
    uint32_t old_tag = ext2_tags[victim];
    ext2_valid[victim] = 1;
    ext2_tags[victim] = blk;
    ext2_lru[victim] = ext2_clock;

    if (was_valid && old_tag != blk) {
        ext2_rehash();
    } else {
        uint32_t h = ext2_hash(blk);
        for (uint32_t p = 0; p < EXT2_CACHE; p++) {
            uint32_t cur = ext2_index[h];
            if (cur == HASH_EMPTY || cur == victim) { ext2_index[h] = victim; return victim; }
            h = (h + 1) & EXT2_MASK;
        }
        ext2_rehash();
    }
    return victim;
}

static void test_ext2_cache_hit(void) {
    ext2_reset();
    ext2_insert(42);
    ASSERT(ext2_lookup(42) != HASH_EMPTY, "block 42 hit");
}

static void test_ext2_cache_lru_evicts_oldest(void) {
    ext2_reset();
    // Fill the cache.
    for (uint32_t i = 0; i < EXT2_CACHE; i++) ext2_insert(1000 + i);
    // Touch block 1000 so it's the most-recent.
    ext2_lookup(1000);
    ext2_lru[ext2_lookup(1000)] = ++ext2_clock;
    // Insert one more — victim should NOT be 1000.
    uint32_t slot = ext2_insert(9999);
    (void)slot;
    ASSERT(ext2_lookup(1000) != HASH_EMPTY, "1000 survives as MRU");
    ASSERT(ext2_lookup(9999) != HASH_EMPTY, "9999 inserted");
}

// ============================================================================
// MAIN
// ============================================================================

int main(void) {
    printf("\n\x1b[1mhome-os Regression Harness\x1b[0m\n");
    printf("============================\n\n");

    printf("Fixes/memcpy:\n");
    RUN(memcpy_word_aligned);
    RUN(memcpy_unaligned);
    RUN(memcpy_overlap_down);
    RUN(memcpy_empty_noop);
    RUN(memcpy_tail_bytes);

    printf("\nFixes/sync:\n");
    RUN(spinlock_no_contention);
    RUN(rw_upgrade_single_reader);
    RUN(rw_upgrade_multi_reader_fails);

    printf("\nFixes/sched:\n");
    RUN(rq_enqueue_find);
    RUN(rq_dequeue_free_slot_reuse);
    RUN(rq_collision_walk);

    printf("\nFixes/mm:\n");
    RUN(buddy_magic_sentinel);

    printf("\nFixes/net:\n");
    RUN(fd_hash_roundtrip);
    RUN(fd_hash_below_base);
    RUN(tcp_hash_stable);
    RUN(tcp_hash_distinct);
    RUN(nagle_holds_sub_mss_with_inflight);
    RUN(nagle_allows_full_mss);
    RUN(nagle_allows_when_empty);
    RUN(nagle_disabled_ignored);
    RUN(socket_recv_null_buf);
    RUN(socket_recv_len_clamped);
    RUN(socket_recv_len_passthrough);

    printf("\nFixes/fs:\n");
    RUN(ext2_cache_hit);
    RUN(ext2_cache_lru_evicts_oldest);

    printf("\n============================\n");
    printf("Result: \x1b[32m%d passed\x1b[0m, \x1b[31m%d failed\x1b[0m\n\n", g_pass, g_fail);
    return g_fail;
}
