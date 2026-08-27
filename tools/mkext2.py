#!/usr/bin/env python3
"""Build a small ext2 filesystem image, and check one.

No mke2fs or e2fsck exists on every machine this repo is developed on, and
the storage gate needs both: something to hand the kernel, and something
independent to verify what the kernel wrote back. Writing both here means the
check is not the kernel grading its own work.

The image is deliberately minimal — revision 1, 1024-byte blocks, a single
block group, no journal — because every feature left out is one the kernel
does not have to implement to be correct.

  python3 tools/mkext2.py build IMAGE [--size-mb N] [FILE=CONTENT ...]
  python3 tools/mkext2.py check IMAGE [--expect PATH=CONTENT ...]
"""
import argparse
import struct
import sys

BLOCK_SIZE = 1024
INODE_SIZE = 128
ROOT_INO = 2
FIRST_INO = 11
EXT2_MAGIC = 0xEF53

S_IFREG = 0x8000
S_IFDIR = 0x4000

FT_REG = 1
FT_DIR = 2

# A fixed timestamp keeps the image byte-identical between runs, so a gate
# comparing images is comparing content rather than clocks.
FIXED_TIME = 1700000000


class Image:
    def __init__(self, blocks):
        self.blocks = blocks
        self.data = bytearray(blocks * BLOCK_SIZE)

    def put(self, block, payload, offset=0):
        base = block * BLOCK_SIZE + offset
        self.data[base:base + len(payload)] = payload

    def get(self, block, length=BLOCK_SIZE, offset=0):
        base = block * BLOCK_SIZE + offset
        return bytes(self.data[base:base + length])


def superblock(inodes, blocks, free_blocks, free_inodes, inodes_per_group):
    sb = bytearray(1024)
    struct.pack_into('<IIIIII', sb, 0,
                     inodes, blocks, 0, free_blocks, free_inodes, 1)
    struct.pack_into('<II', sb, 24, 0, 0)          # log block/frag size: 1024
    struct.pack_into('<III', sb, 32, blocks, blocks, inodes_per_group)
    struct.pack_into('<II', sb, 44, FIXED_TIME, FIXED_TIME)
    struct.pack_into('<HH', sb, 52, 1, 20)         # mount count, max mounts
    struct.pack_into('<HHH', sb, 56, EXT2_MAGIC, 1, 1)  # magic, clean, errors
    struct.pack_into('<H', sb, 62, 0)              # minor rev
    struct.pack_into('<II', sb, 64, FIXED_TIME, 0)
    struct.pack_into('<II', sb, 72, 0, 1)          # creator Linux, rev 1
    struct.pack_into('<HH', sb, 80, 0, 0)
    struct.pack_into('<I', sb, 84, FIRST_INO)
    struct.pack_into('<H', sb, 88, INODE_SIZE)
    struct.pack_into('<H', sb, 90, 0)
    struct.pack_into('<III', sb, 92, 0, 0, 0)      # no optional features
    sb[120:120 + 8] = b'home-os\x00'
    return bytes(sb)


def group_desc(block_bitmap, inode_bitmap, inode_table,
               free_blocks, free_inodes, used_dirs):
    gd = bytearray(32)
    struct.pack_into('<III', gd, 0, block_bitmap, inode_bitmap, inode_table)
    struct.pack_into('<HHH', gd, 12, free_blocks, free_inodes, used_dirs)
    return bytes(gd)


def inode(mode, size, blocks_512, block_ptrs, links=1):
    ino = bytearray(INODE_SIZE)
    struct.pack_into('<HHI', ino, 0, mode, 0, size)
    struct.pack_into('<IIII', ino, 8, FIXED_TIME, FIXED_TIME, FIXED_TIME, 0)
    struct.pack_into('<HH', ino, 24, 0, links)
    struct.pack_into('<II', ino, 28, blocks_512, 0)
    for i, b in enumerate(block_ptrs[:15]):
        struct.pack_into('<I', ino, 40 + i * 4, b)
    return bytes(ino)


def dir_block(entries):
    """Pack directory entries into one block, the last one filling it out."""
    out = bytearray()
    for i, (ino, name, ftype) in enumerate(entries):
        nb = name.encode()
        need = 8 + len(nb)
        rec = (need + 3) & ~3
        if i == len(entries) - 1:
            rec = BLOCK_SIZE - len(out)
        out += struct.pack('<IHBB', ino, rec, len(nb), ftype)
        out += nb
        out += b'\x00' * (rec - 8 - len(nb))
    assert len(out) == BLOCK_SIZE, f'directory block is {len(out)} bytes'
    return bytes(out)


def set_bit(bitmap, index):
    bitmap[index // 8] |= 1 << (index % 8)


def build(path, size_mb, files):
    blocks = (size_mb * 1024 * 1024) // BLOCK_SIZE
    inodes_per_group = 64

    # Fixed layout: 0 boot, 1 superblock, 2 group descriptors, 3 block bitmap,
    # 4 inode bitmap, 5.. inode table, then data.
    bb_block, ib_block, it_block = 3, 4, 5
    it_blocks = (inodes_per_group * INODE_SIZE + BLOCK_SIZE - 1) // BLOCK_SIZE
    first_data = it_block + it_blocks

    img = Image(blocks)
    inode_table = {}
    next_ino = FIRST_INO
    next_block = first_data
    used_blocks = list(range(0, first_data))

    root_entries = [(ROOT_INO, '.', FT_DIR), (ROOT_INO, '..', FT_DIR)]

    for name, content in files:
        payload = content.encode() if isinstance(content, str) else content
        needed = (len(payload) + BLOCK_SIZE - 1) // BLOCK_SIZE
        assert needed <= 12, f'{name} needs indirect blocks; keep test files small'
        ptrs = []
        for i in range(needed):
            b = next_block
            next_block += 1
            used_blocks.append(b)
            img.put(b, payload[i * BLOCK_SIZE:(i + 1) * BLOCK_SIZE])
            ptrs.append(b)
        inode_table[next_ino] = inode(
            S_IFREG | 0o644, len(payload), needed * (BLOCK_SIZE // 512), ptrs)
        root_entries.append((next_ino, name, FT_REG))
        next_ino += 1

    # The root directory's own data block, allocated last so its entries are
    # complete.
    root_block = next_block
    next_block += 1
    used_blocks.append(root_block)
    img.put(root_block, dir_block(root_entries))
    inode_table[ROOT_INO] = inode(
        S_IFDIR | 0o755, BLOCK_SIZE, BLOCK_SIZE // 512, [root_block], links=2)

    # Bitmaps.
    block_bitmap = bytearray(BLOCK_SIZE)
    for b in used_blocks:
        set_bit(block_bitmap, b)
    # Blocks past the end of the filesystem are marked used, which is what
    # fsck expects of the padding in a bitmap block.
    for b in range(blocks, BLOCK_SIZE * 8):
        set_bit(block_bitmap, b)
    img.put(bb_block, bytes(block_bitmap))

    inode_bitmap = bytearray(BLOCK_SIZE)
    for i in range(1, next_ino):
        set_bit(inode_bitmap, i - 1)
    for i in range(inodes_per_group, BLOCK_SIZE * 8):
        set_bit(inode_bitmap, i)
    img.put(ib_block, bytes(inode_bitmap))

    for ino, raw in inode_table.items():
        off = (ino - 1) * INODE_SIZE
        img.put(it_block + off // BLOCK_SIZE, raw, off % BLOCK_SIZE)

    free_blocks = blocks - len(used_blocks)
    free_inodes = inodes_per_group - (next_ino - 1)

    img.put(1, superblock(inodes_per_group, blocks, free_blocks,
                          free_inodes, inodes_per_group))
    img.put(2, group_desc(bb_block, ib_block, it_block,
                          free_blocks, free_inodes, 1))

    with open(path, 'wb') as f:
        f.write(img.data)
    print(f'built {path}: {blocks} blocks, {next_ino - 1} inodes, '
          f'{len(files)} file(s), {free_blocks} free blocks')


def read_inode(data, it_block, ino):
    off = it_block * BLOCK_SIZE + (ino - 1) * INODE_SIZE
    return data[off:off + INODE_SIZE]


def check(path, expect):
    data = open(path, 'rb').read()
    problems = []

    magic = struct.unpack_from('<H', data, 1024 + 56)[0]
    if magic != EXT2_MAGIC:
        print(f'FAIL: bad magic 0x{magic:04X}')
        return 1

    inodes, blocks, _, free_blocks, free_inodes, first_data = \
        struct.unpack_from('<IIIIII', data, 1024)
    log_bs = struct.unpack_from('<I', data, 1024 + 24)[0]
    state = struct.unpack_from('<H', data, 1024 + 58)[0]
    inode_size = struct.unpack_from('<H', data, 1024 + 88)[0]

    if log_bs != 0:
        problems.append(f'block size is {1024 << log_bs}, this checker is 1024-only')
    if inode_size != INODE_SIZE:
        problems.append(f'inode size {inode_size}, expected {INODE_SIZE}')
    if state != 1:
        problems.append(f'filesystem not marked clean (state={state})')
    if blocks * BLOCK_SIZE > len(data):
        problems.append(f'superblock claims {blocks} blocks, image holds '
                        f'{len(data) // BLOCK_SIZE}')

    bb, ib, it = struct.unpack_from('<III', data, 2 * BLOCK_SIZE)
    gd_free_blocks, gd_free_inodes, used_dirs = \
        struct.unpack_from('<HHH', data, 2 * BLOCK_SIZE + 12)

    if gd_free_blocks != free_blocks:
        problems.append(f'free block count: superblock {free_blocks}, '
                        f'group descriptor {gd_free_blocks}')
    if gd_free_inodes != free_inodes:
        problems.append(f'free inode count: superblock {free_inodes}, '
                        f'group descriptor {gd_free_inodes}')

    # Every block a file references must be marked used in the bitmap. This is
    # the invariant that catches a write path that allocated without
    # recording, which is the corruption that survives a remount and then
    # eats the next file.
    bitmap = data[bb * BLOCK_SIZE:(bb + 1) * BLOCK_SIZE]

    def bit(i):
        return (bitmap[i // 8] >> (i % 8)) & 1

    root = read_inode(data, it, ROOT_INO)
    root_block = struct.unpack_from('<I', root, 40)[0]
    if root_block == 0:
        print('FAIL: root inode has no data block')
        return 1

    entries = {}
    off = root_block * BLOCK_SIZE
    pos = 0
    while pos < BLOCK_SIZE - 8:
        ino, rec, nlen, _ft = struct.unpack_from('<IHBB', data, off + pos)
        if rec == 0:
            problems.append(f'directory entry at +{pos} has rec_len 0')
            break
        if ino != 0:
            name = data[off + pos + 8:off + pos + 8 + nlen].decode('latin1')
            entries[name] = ino
        pos += rec

    for name, ino in entries.items():
        if name in ('.', '..'):
            continue
        if ino < 1 or ino > inodes:
            problems.append(f'{name}: inode {ino} out of range')
            continue
        raw = read_inode(data, it, ino)
        size = struct.unpack_from('<I', raw, 4)[0]
        for i in range(12):
            b = struct.unpack_from('<I', raw, 40 + i * 4)[0]
            if b == 0:
                continue
            if b >= blocks:
                problems.append(f'{name}: block {b} past end of filesystem')
            elif not bit(b):
                problems.append(f'{name}: block {b} is in use but marked free')

    for spec in expect:
        name, _, want = spec.partition('=')
        if name not in entries:
            problems.append(f'{name}: not present in the root directory')
            continue
        raw = read_inode(data, it, entries[name])
        size = struct.unpack_from('<I', raw, 4)[0]
        got = b''
        for i in range(12):
            b = struct.unpack_from('<I', raw, 40 + i * 4)[0]
            if b == 0:
                break
            got += data[b * BLOCK_SIZE:(b + 1) * BLOCK_SIZE]
        got = got[:size].decode('latin1')
        if got != want:
            problems.append(f'{name}: content is {got!r}, expected {want!r}')

    if problems:
        print(f'FAIL: {len(problems)} problem(s)')
        for p in problems:
            print(f'  - {p}')
        return 1

    listing = ', '.join(sorted(n for n in entries if n not in ('.', '..')))
    print(f'OK: {blocks} blocks, {len(entries) - 2} file(s) [{listing}], '
          f'{free_blocks} free blocks, clean')
    return 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest='cmd', required=True)

    b = sub.add_parser('build')
    b.add_argument('image')
    b.add_argument('--size-mb', type=int, default=8)
    b.add_argument('--file', action='append', default=[], dest='files', help='NAME=CONTENT')

    c = sub.add_parser('check')
    c.add_argument('image')
    c.add_argument('--expect', action='append', default=[],
                   help='NAME=CONTENT the image must contain')

    a = ap.parse_args()
    if a.cmd == 'build':
        files = []
        for spec in a.files:
            name, _, content = spec.partition('=')
            files.append((name, content.replace('\\n', '\n')))
        build(a.image, a.size_mb, files)
        return 0
    return check(a.image, [e.replace('\\n', '\n') for e in a.expect])


if __name__ == '__main__':
    sys.exit(main())
