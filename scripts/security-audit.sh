#!/bin/bash
# Security Audit Script for home-os
# Performs comprehensive security checks on the kernel codebase

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
KERNEL_SRC="$REPO_ROOT/kernel/src"
REPORT_FILE="$REPO_ROOT/security-report.md"

echo "=========================================="
echo "home-os Security Audit"
echo "=========================================="
echo ""

# Initialize report
cat > "$REPORT_FILE" << 'EOF'
# home-os Security Audit Report

Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

## Executive Summary

This report provides a comprehensive security analysis of the home-os kernel.

EOF

# Function to add section to report
add_section() {
  echo "" >> "$REPORT_FILE"
  echo "## $1" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
}

# Function to add finding
add_finding() {
  local severity=$1
  local title=$2
  local description=$3

  case $severity in
    CRITICAL) icon="🔴" ;;
    HIGH)     icon="🟠" ;;
    MEDIUM)   icon="🟡" ;;
    LOW)      icon="🟢" ;;
    INFO)     icon="ℹ️" ;;
  esac

  echo "$icon **[$severity]** $title" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
  echo "$description" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
}

# Check 1: Unsafe code usage
echo "[1/10] Checking for unsafe code patterns..."
add_section "Unsafe Code Analysis"

UNSAFE_COUNT=$(grep -r "unsafe" "$KERNEL_SRC" --include="*.home" | wc -l || echo 0)

if [ "$UNSAFE_COUNT" -gt 100 ]; then
  add_finding "HIGH" "Excessive Unsafe Code" \
    "Found $UNSAFE_COUNT instances of unsafe code. Review and minimize unsafe blocks."
elif [ "$UNSAFE_COUNT" -gt 50 ]; then
  add_finding "MEDIUM" "Moderate Unsafe Code" \
    "Found $UNSAFE_COUNT instances of unsafe code. Consider refactoring where possible."
else
  add_finding "LOW" "Minimal Unsafe Code" \
    "Found $UNSAFE_COUNT instances of unsafe code. This is acceptable for kernel development."
fi

# Check 2: Buffer overflow risks
echo "[2/10] Scanning for buffer overflow risks..."
add_section "Buffer Overflow Analysis"

# Check for unbounded string operations
STRCPY_COUNT=$(grep -rE "(str_copy|strcpy|memcpy)\(" "$KERNEL_SRC" --include="*.home" | \
  grep -v "// SAFETY:" | wc -l || echo 0)

if [ "$STRCPY_COUNT" -gt 0 ]; then
  add_finding "MEDIUM" "Unbounded String Operations" \
    "Found $STRCPY_COUNT potentially unbounded string/memory copy operations. Ensure bounds checking."
fi

# Check for fixed-size arrays
ARRAY_COUNT=$(grep -rE "\[[0-9]+\]u8" "$KERNEL_SRC" --include="*.home" | wc -l || echo 0)
add_finding "INFO" "Fixed-Size Buffers" \
  "Found $ARRAY_COUNT fixed-size buffer declarations. Verify all have proper bounds checking."

# Check 3: Integer overflow risks
echo "[3/10] Checking for integer overflow vulnerabilities..."
add_section "Integer Overflow Analysis"

# Check for unchecked arithmetic
UNCHECKED_ARITH=$(grep -rE "(\+|\*|-) [0-9]+" "$KERNEL_SRC" --include="*.home" | \
  grep -v "overflow_check" | wc -l || echo 0)

if [ "$UNCHECKED_ARITH" -gt 500 ]; then
  add_finding "MEDIUM" "Unchecked Arithmetic Operations" \
    "Found $UNCHECKED_ARITH arithmetic operations. Consider overflow checks for user-controlled values."
else
  add_finding "LOW" "Limited Unchecked Arithmetic" \
    "Found $UNCHECKED_ARITH arithmetic operations. Review critical paths for overflow safety."
fi

# Check 4: Null pointer dereferences
echo "[4/10] Scanning for null pointer dereferences..."
add_section "Null Pointer Analysis"

NULL_CHECKS=$(grep -rE "if .* (==|!=) 0 \{" "$KERNEL_SRC" --include="*.home" | wc -l || echo 0)
POINTER_DEREFS=$(grep -rE "\*[a-zA-Z_]+" "$KERNEL_SRC" --include="*.home" | wc -l || echo 0)

CHECK_RATIO=$(echo "scale=2; $NULL_CHECKS * 100 / $POINTER_DEREFS" | bc)
add_finding "INFO" "Null Pointer Checking" \
  "Found $NULL_CHECKS null checks for $POINTER_DEREFS pointer dereferences (${CHECK_RATIO}% check ratio)."

# Check 5: Race conditions
echo "[5/10] Checking for potential race conditions..."
add_section "Race Condition Analysis"

SHARED_STATE=$(grep -rE "(static|var) [a-zA-Z_]+:" "$KERNEL_SRC" --include="*.home" | wc -l || echo 0)
MUTEX_COUNT=$(grep -rE "(mutex|spinlock|atomic)" "$KERNEL_SRC" --include="*.home" | wc -l || echo 0)

if [ "$SHARED_STATE" -gt "$MUTEX_COUNT" ]; then
  add_finding "MEDIUM" "Potentially Unprotected Shared State" \
    "Found $SHARED_STATE global variables but only $MUTEX_COUNT synchronization primitives. Review for race conditions."
else
  add_finding "LOW" "Adequate Synchronization" \
    "Synchronization primitives ($MUTEX_COUNT) appear sufficient for shared state ($SHARED_STATE)."
fi

# Check 6: Privilege escalation vectors
echo "[6/10] Analyzing privilege escalation vectors..."
add_section "Privilege Escalation Analysis"

# Check for syscall validation
SYSCALL_COUNT=$(grep -r "syscall_" "$KERNEL_SRC" --include="*.home" | wc -l || echo 0)
VALIDATION_COUNT=$(grep -rE "(validate|check|verify).*user" "$KERNEL_SRC" --include="*.home" | wc -l || echo 0)

if [ "$SYSCALL_COUNT" -gt 0 ] && [ "$VALIDATION_COUNT" -eq 0 ]; then
  add_finding "HIGH" "Missing Syscall Validation" \
    "Found $SYSCALL_COUNT syscall implementations but no user input validation. Add validation."
else
  add_finding "INFO" "Syscall Validation Present" \
    "Found $VALIDATION_COUNT validation checks for $SYSCALL_COUNT syscalls."
fi

# Check 7: Information disclosure
echo "[7/10] Checking for information disclosure risks..."
add_section "Information Disclosure Analysis"

# Check for kernel pointers being exposed
PRINT_PTR=$(grep -rE "(print|serial_write).*0x" "$KERNEL_SRC" --include="*.home" | wc -l || echo 0)

if [ "$PRINT_PTR" -gt 20 ]; then
  add_finding "MEDIUM" "Potential Kernel Pointer Leaks" \
    "Found $PRINT_PTR instances of pointer printing. Consider %pK format specifier to avoid KASLR bypass."
else
  add_finding "LOW" "Limited Pointer Printing" \
    "Found $PRINT_PTR instances of pointer printing. Review for production builds."
fi

# Check 8: Stack protection
echo "[8/10] Verifying stack protection..."
add_section "Stack Protection Analysis"

STACK_CANARY=$(grep -r "stack_canary\|stack_guard" "$KERNEL_SRC" --include="*.home" | wc -l || echo 0)

if [ "$STACK_CANARY" -eq 0 ]; then
  add_finding "HIGH" "Missing Stack Canaries" \
    "No stack canary implementation found. Add stack protection to prevent buffer overflow exploits."
else
  add_finding "LOW" "Stack Protection Implemented" \
    "Found $STACK_CANARY stack canary references. Stack protection appears implemented."
fi

# Check 9: KASLR and ASLR
echo "[9/10] Checking address space randomization..."
add_section "Address Space Randomization"

KASLR=$(grep -r "kaslr\|randomize.*base" "$KERNEL_SRC" --include="*.home" | wc -l || echo 0)

if [ "$KASLR" -eq 0 ]; then
  add_finding "MEDIUM" "KASLR Not Implemented" \
    "Kernel Address Space Layout Randomization (KASLR) not found. Consider implementing for security."
else
  add_finding "LOW" "KASLR Implemented" \
    "Found $KASLR KASLR references. Address randomization appears implemented."
fi

# Check 10: Hardening features
echo "[10/10] Verifying kernel hardening features..."
add_section "Kernel Hardening Features"

HARDENING_FEATURES=0

if grep -qr "stack_canary" "$KERNEL_SRC"; then
  echo "- ✅ Stack canaries" >> "$REPORT_FILE"
  ((HARDENING_FEATURES++))
else
  echo "- ❌ Stack canaries" >> "$REPORT_FILE"
fi

if grep -qr "kaslr" "$KERNEL_SRC"; then
  echo "- ✅ KASLR" >> "$REPORT_FILE"
  ((HARDENING_FEATURES++))
else
  echo "- ❌ KASLR" >> "$REPORT_FILE"
fi

if grep -qr "smep\|smap\|pxn\|pan" "$KERNEL_SRC"; then
  echo "- ✅ Privileged execute protection" >> "$REPORT_FILE"
  ((HARDENING_FEATURES++))
else
  echo "- ❌ Privileged execute protection" >> "$REPORT_FILE"
fi

if grep -qr "seccomp" "$KERNEL_SRC"; then
  echo "- ✅ Seccomp filtering" >> "$REPORT_FILE"
  ((HARDENING_FEATURES++))
else
  echo "- ❌ Seccomp filtering" >> "$REPORT_FILE"
fi

if grep -qr "kasan\|asan" "$KERNEL_SRC"; then
  echo "- ✅ Address sanitizer" >> "$REPORT_FILE"
  ((HARDENING_FEATURES++))
else
  echo "- ❌ Address sanitizer" >> "$REPORT_FILE"
fi

if grep -qr "write_protect\|ro_after_init" "$KERNEL_SRC"; then
  echo "- ✅ Write protection" >> "$REPORT_FILE"
  ((HARDENING_FEATURES++))
else
  echo "- ❌ Write protection" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo "**Hardening Score:** $HARDENING_FEATURES / 6" >> "$REPORT_FILE"

if [ "$HARDENING_FEATURES" -lt 3 ]; then
  add_finding "HIGH" "Insufficient Kernel Hardening" \
    "Only $HARDENING_FEATURES/6 hardening features implemented. Improve security posture."
elif [ "$HARDENING_FEATURES" -lt 5 ]; then
  add_finding "MEDIUM" "Moderate Kernel Hardening" \
    "$HARDENING_FEATURES/6 hardening features implemented. Consider adding more protections."
else
  add_finding "LOW" "Strong Kernel Hardening" \
    "$HARDENING_FEATURES/6 hardening features implemented. Good security posture."
fi

# Summary statistics
add_section "Summary Statistics"

cat >> "$REPORT_FILE" << EOF
| Metric | Count |
|--------|-------|
| Unsafe code blocks | $UNSAFE_COUNT |
| String/memory copies | $STRCPY_COUNT |
| Fixed buffers | $ARRAY_COUNT |
| Null pointer checks | $NULL_CHECKS |
| Synchronization primitives | $MUTEX_COUNT |
| Syscall validations | $VALIDATION_COUNT |
| Hardening features | $HARDENING_FEATURES / 6 |

EOF

# Recommendations
add_section "Recommendations"

cat >> "$REPORT_FILE" << 'EOF'
1. **Minimize Unsafe Code**: Review and refactor unsafe blocks where possible
2. **Add Bounds Checking**: Ensure all buffer operations are bounds-checked
3. **Implement Stack Canaries**: Add stack overflow protection
4. **Enable KASLR**: Implement kernel address randomization
5. **Add Seccomp Filtering**: Restrict syscall surface for userspace
6. **Enable KASAN**: Use address sanitizer during development
7. **Validate User Input**: Add comprehensive syscall parameter validation
8. **Protect Critical Data**: Mark read-only data as immutable
9. **Audit Synchronization**: Review shared state for race conditions
10. **Regular Security Reviews**: Conduct quarterly security audits

EOF

echo ""
echo "=========================================="
echo "Security Audit Complete"
echo "=========================================="
echo ""
echo "Report saved to: $REPORT_FILE"
echo ""

# Display critical/high findings
CRITICAL_COUNT=$(grep -c "🔴 \*\*\[CRITICAL\]" "$REPORT_FILE" || echo 0)
HIGH_COUNT=$(grep -c "🟠 \*\*\[HIGH\]" "$REPORT_FILE" || echo 0)

if [ "$CRITICAL_COUNT" -gt 0 ] || [ "$HIGH_COUNT" -gt 0 ]; then
  echo "⚠️  Security Issues Found:"
  echo "   Critical: $CRITICAL_COUNT"
  echo "   High:     $HIGH_COUNT"
  echo ""
  echo "Review $REPORT_FILE for details."
  exit 1
else
  echo "✅ No critical or high-severity issues found"
  exit 0
fi
