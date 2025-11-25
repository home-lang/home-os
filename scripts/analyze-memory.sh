#!/bin/bash
# Memory Analysis Script for home-os
# Analyzes kernel binary size and memory usage

set -e

KERNEL=$1

if [ -z "$KERNEL" ]; then
  echo "Usage: $0 <kernel-elf-file>"
  exit 1
fi

if [ ! -f "$KERNEL" ]; then
  echo "Error: Kernel file not found: $KERNEL"
  exit 1
fi

echo "=========================================="
echo "home-os Memory Analysis"
echo "=========================================="
echo ""

# Overall size
echo "Binary Size Summary:"
size "$KERNEL"
echo ""

# Section breakdown
echo "Section Details:"
readelf -S "$KERNEL" | awk '
  /\.text/  { printf "  .text   (code):     %10d bytes\n", strtonum("0x"$6) }
  /\.rodata/ { printf "  .rodata (read-only): %10d bytes\n", strtonum("0x"$6) }
  /\.data/  { printf "  .data   (init data): %10d bytes\n", strtonum("0x"$6) }
  /\.bss/   { printf "  .bss    (uninit):    %10d bytes\n", strtonum("0x"$6) }
'
echo ""

# Calculate total runtime memory
TEXT_SIZE=$(readelf -S "$KERNEL" | awk '/\.text/ { print strtonum("0x"$6) }')
RODATA_SIZE=$(readelf -S "$KERNEL" | awk '/\.rodata/ { print strtonum("0x"$6) }')
DATA_SIZE=$(readelf -S "$KERNEL" | awk '/\.data/ { print strtonum("0x"$6) }')
BSS_SIZE=$(readelf -S "$KERNEL" | awk '/\.bss/ { print strtonum("0x"$6) }')

TOTAL_RUNTIME=$((TEXT_SIZE + RODATA_SIZE + DATA_SIZE + BSS_SIZE))
TOTAL_DISK=$((TEXT_SIZE + RODATA_SIZE + DATA_SIZE))

echo "Memory Footprint:"
printf "  Runtime memory:  %10d bytes (%.2f MB)\n" $TOTAL_RUNTIME $(echo "scale=2; $TOTAL_RUNTIME / 1048576" | bc)
printf "  Disk footprint:  %10d bytes (%.2f MB)\n" $TOTAL_DISK $(echo "scale=2; $TOTAL_DISK / 1048576" | bc)
echo ""

# Budget check
MAX_BUDGET=$((50 * 1024 * 1024))  # 50 MB
PERCENT_USED=$(echo "scale=2; $TOTAL_RUNTIME * 100 / $MAX_BUDGET" | bc)

echo "Budget Analysis:"
printf "  Budget target:   %10d bytes (50.00 MB)\n" $MAX_BUDGET
printf "  Current usage:   %10d bytes (%.2f MB)\n" $TOTAL_RUNTIME $(echo "scale=2; $TOTAL_RUNTIME / 1048576" | bc)
printf "  Budget used:     %10.2f%%\n" $PERCENT_USED

if [ $TOTAL_RUNTIME -gt $MAX_BUDGET ]; then
  printf "  Status:          ❌ OVER BUDGET by %d bytes\n" $((TOTAL_RUNTIME - MAX_BUDGET))
  echo ""
  exit 1
else
  REMAINING=$((MAX_BUDGET - TOTAL_RUNTIME))
  printf "  Status:          ✅ WITHIN BUDGET (%d bytes remaining)\n" $REMAINING
fi
echo ""

# Largest symbols
echo "Largest Symbols (Top 20):"
readelf -s "$KERNEL" | \
  awk '$4 != "0" && $4 != "" { printf "%10d  %s\n", strtonum($3), $8 }' | \
  sort -rn | \
  head -20
echo ""

# Section-wise symbol breakdown
echo "Symbol Count by Section:"
readelf -s "$KERNEL" | \
  awk 'NR>3 && $7 != "" && $7 != "UND" && $7 != "ABS" {
    section[$7]++
  }
  END {
    for (s in section)
      printf "  %-15s: %5d symbols\n", s, section[s]
  }' | \
  sort -t: -k2 -rn
echo ""

# Code density analysis
if [ $TEXT_SIZE -gt 0 ]; then
  SYMBOL_COUNT=$(readelf -s "$KERNEL" | awk '$4 == "FUNC"' | wc -l)
  if [ $SYMBOL_COUNT -gt 0 ]; then
    AVG_FUNC_SIZE=$((TEXT_SIZE / SYMBOL_COUNT))
    echo "Code Metrics:"
    printf "  Total functions: %10d\n" $SYMBOL_COUNT
    printf "  Avg func size:   %10d bytes\n" $AVG_FUNC_SIZE
    echo ""
  fi
fi

# Alignment waste analysis
echo "Alignment Analysis:"
ALIGN_WASTE=$(readelf -S "$KERNEL" | awk '
  BEGIN { total_waste = 0 }
  /PROGBITS|NOBITS/ {
    addr = strtonum("0x"$5)
    size = strtonum("0x"$6)
    align = strtonum("0x"$NF)
    if (align > 1) {
      waste = (align - (addr % align)) % align
      total_waste += waste
    }
  }
  END { printf "  Alignment waste: %10d bytes\n", total_waste }
')
echo "$ALIGN_WASTE"
echo ""

echo "=========================================="
echo "Analysis Complete"
echo "=========================================="
