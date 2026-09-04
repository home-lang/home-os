# homefs — Design Document

> **Status: design complete, pre-implementation.** This document is written
> *before* any homefs implementation lands ([MASTER_PLAN §11.2](../MASTER_PLAN.md)).
> `kernel/src/fs/homefs.home` is a 33-line import stub (stub register S4,
> [#32](https://github.com/home-lang/home-os/issues/32)); nothing here is
> implemented yet.
>
> S4 is registered as "P1 (design doc), P2 (CoW implementation)". This document
> is that P1 deliverable and it is done; the entry stays open for the
> implementation, whose steps are in §9.

- **Version:** 1.0 (draft for review)
- **Date:** 2026-08-24
- **Owner:** Workstream B (kernel) / Workstream E (distribution)
- **Blocks:** Phase 2 `storage-roundtrip`, Phase 6 `snapshot-rollback`, factory reset, pantry snapshot-guarded updates

---

## 1. Goals and Non-Goals

### Goals

1. **Copy-on-write everything, always.** No in-place data overwrite, ever.
   Snapshots are O(1)-ish metadata operations, not copies.
2. **Boot-selectable rollback of whole-OS state.** The bootloader can mount
   an arbitrary snapshot read-only; "roll back" is booting an older root.
3. **Co-design with pantry.** Every update is snapshot-guarded; per-app data
   snapshots are possible because the FS and app data layer share types.
4. **Crash consistency without a journal.** CPO (copy-on-write + ordered
   metadata commits) gives fsck-after-crash semantics; no replay log.
5. **Small, auditable core.** A single-language implementation in Home with
   an unsafe-block census contribution ([MASTER_PLAN §11.3]).

### Non-Goals

- POSIX ACLs (capabilities live at the VFS layer above, per §11.4).
- Deduplication across snapshots at v1 (design leaves room; not built).
- Network/cluster filesystem. Single-host only.
- Being the *only* filesystem: ext2-class remains the Phase 2 round-trip
  target; homefs becomes the root FS when it earns it.

## 2. On-Disk Layout

```
block 0            : GPT (hosted on a partition; homefs starts here)
superblock         : 2 sectors, replicated (primary + last 1MB of device)
object log (olog)  : ring of metadata commit blocks
extent tree blocks : B-tree nodes (see §3)
data blocks        : 4 KiB default (tunable 512B–64KiB at mkfs)
```

Everything is addressed by **64-bit object IDs**, not fixed inode numbers:

| Object type | ID range |
|---|---|
| Regular file | `0x0000_0000_0000_0001` … `0x7fff…` |
| Directory | `0x8000_0000_0000_0001` … `0xbfff…` |
| Snapshot root | `0xc000_0000_0000_0001` … `0xdfff…` |
| Reserved | `0xf000…`+ |

The superblock contains:

```home
struct Superblock {
    magic: u32              // 'HOMS'
    version: u32            // layout version (1)
    block_size: u32
    block_count: u64

    olog_head: u64          // newest valid commit block
    olog_tail: u64          // oldest still-referenced commit block

    root_dir_object: u64    // current root directory tree root
    active_snapshot: u64    // object ID of the booted snapshot root

    flags: u64
    uuid: [16]u8
}
```

Two superblocks alternate ("superblock ping-pong"). A superblock is only
rewritten after its referenced metadata is durable (§5), so any crash
leaves the previous generation fully consistent.

## 3. Trees

Three B-trees (nodes = one block, copy-on-write):

1. **Object table** — object ID → {type, size, gen, extent-tree root,
   refcount}. One entry per file/dir/snapshot.
2. **Extent trees** — per-file logical offset → (physical block, length,
   shared flag). Leaves sorted by logical offset.
3. **Directory trees** — dir object → (name hash → child object ID).

Snapshot roots are entries in the object table whose "extent-tree root"
points to a frozen copy of the object-table node path — i.e., **a snapshot
is a root of the object table itself** (the same trick btrfs uses with
subvolume trees, applied to a flat object table).

Consequences:

- Creating a snapshot = write one new object-table root node + one
  superblock flip. Milliseconds, size-independent.
- Deleting a snapshot = unpin its root; freed extents are reclaimed by a
  generational refcount walk (§6).
- Boot-selectable rollback = the bootloader's tiny read-only homefs driver
  reads `active_snapshot` candidates from the superblock area and mounts
  the chosen snapshot's tree.

## 4. Copy-on-Write Semantics

Write path for file F:

1. Locate leaf extent(s) in F's extent tree.
2. Allocate new physical block(s); copy-modify-write partial blocks
   (RMW happens in the page cache; never in place on disk).
3. New extent records into a new extent-tree node path; new object-table
   path; new directory path if size/mtime changed.
4. Commit (§5).

Overwrite-in-place is impossible by construction: the allocator hands out
only zeroed free blocks, and a block may be freed only when no live or
snapshot-reachable tree references it (§6).

`shared` flag on extents distinguishes data first written after the oldest
snapshot (cheap heuristic for future dedup, not v1).

## 5. Commits and Crash Consistency

- All metadata mutations accumulate in memory against the current
  transaction.
- Commit order (strict):
  1. data blocks of the transaction (barrier)
  2. modified tree nodes (barrier)
  3. object-log commit record {txid, new superblock fields, checksum}
  4. alternate superblock slot
- The object log is a checksummed ring of commit records; recovery scans
  from `olog_tail` to find the newest complete record matching either
  superblock slot.
- After crash: mount reads both superblocks, picks the highest valid
  `(generation, txid)` pair whose commit record checksums clean. No replay.
- `fsck homefs` verifies reachability from all pinned snapshot roots +
  active root; runs online (read-only against a frozen view).

This yields the Tier-2 nightly CI test directly: kill QEMU mid-commit,
remount, assert either old or new state, never a mix
([MASTER_PLAN §12]).

## 6. Extent Refcounting and Free Space

- Refcounts live in a fourth B-tree keyed by physical block, updated only
  at commit boundaries (deferred, like btrfs). In-memory deltas batch per
  transaction.
- Free-space: extent-indexed free tree (contiguous runs), rebuilt by
  inverting the refcount tree if corrupted.
- A block is reclaimable when its refcount drops to 0 *and* its dropping
  transaction is committed and older than the oldest pinned snapshot.
- Delete of a snapshot triggers background reclamation, budgeted per
  commit to bound latency (no unbounded delete stalls).

## 7. Snapshots, Rollback, Factory Reset

| Operation | Mechanism |
|---|---|
| `snapshot create NAME` | pin current object-table root under a new snapshot object; superblock flip |
| boot menu rollback | bootloader lists snapshot roots; sets `active_snapshot`; kernel mounts it read-write by *branching* (new snapshot of the snapshot), never mutating history |
| `pantry update` | auto-snapshot pre-install (`pre-update-<txid>`); failed/rolled-back update = boot previous snapshot |
| factory reset | `@factory` is a preserved pristine snapshot created at install; reset = boot-select it and prune newer snapshots |
| per-app data snapshots | apps store data under typed keys (§11.5 data layer); snapshotting `/data/<app>` subtree is an ordinary snapshot scoped by path prefix |

Rollback covers whole-OS state — kernel, userspace, configs, app data —
because everything lives under one root tree. This is the beat over
Omarchy's snapper-on-btrfs: co-designed updater and filesystem in one
language, not layered tooling.

## 8. Home-Language Mapping

- All structures are Home `struct`s with explicit endianness via
  `@bitCast` on load/store; packed structs where bit-layout matters.
- Block I/O through the VFS block-io layer (`kernel/src/core/vfs_block_io.home`);
  no direct driver coupling — virtio-blk first (R2), AHCI/NVMe later (7a).
- Volatile MMIO needs do not arise here (pure block device consumer), which
  keeps the module inside the safe subset; any escape hatches count toward
  the unsafe-block census.
- The B-tree and commit machinery get executed unit tests in-VM before any
  disk attach (`libc-suite`-style harness), per register rule 1: *a stub
  may not be closed without a runtime test exercising it.*

## 9. Implementation Plan

| Step | Deliverable | Gate |
|---|---|---|
| 1 | On-disk struct definitions + encode/decode unit tests | compiles in MVK subset |
| 2 | Ramdisk-backed block device; B-trees with in-memory mirror | executed tree tests |
| 3 | Commit protocol + crash-consistency tests (QEMU kill mid-write) | Tier-2 nightly job |
| 4 | Mount/read path; ELF + coreutils run from homefs | Phase 2 `storage-roundtrip` variant |
| 5 | Write path + fsck | Phase 2 exit |
| 6 | Snapshots + boot-menu rollback | Phase 6 `snapshot-rollback` |
| 7 | Pantry integration (auto-snapshot updates, `@factory`) | Phase 6 channels |

Steps 1–2 start only after Phase 1 exits; step 4–5 are the S4 closure.

## 10. Open Questions

1. ~~**Checksum algorithm:**~~ **Resolved.** This asked whether commit records
   should use CRC32C as an interim because blake2s was stubbed. STUB(S5) is
   closed: `kernel/src/crypto/blake2s.home` implements RFC 7693 and the boot
   gate checks it against the Appendix B vector on every commit. Use blake2s
   directly — there is no interim to carry, and no superblock `flags` upgrade
   path to design and later support. The same primitive already backs pantry's
   signed indexes, so the filesystem and the updater agree on one digest.
2. **Encryption:** out of scope for v1; fscrypt-style per-file encryption
   would hook the write path at step 4. Needs its own ADR.
3. **Compression:** transparent LZO/zstd per-extent — post-v1; the `shared`
   flag word has room for a compression type nibble.
4. **Maximum snapshot count:** object-ID space says millions; practical
   ceiling is reclamation cost. Cap at 256 pinned snapshots for v1.
