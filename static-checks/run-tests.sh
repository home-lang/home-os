#!/bin/bash
# home-os Test Runner
# Runs unit, integration, and system tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
TEST_SUITE="all"
ARCH="aarch64"
VERBOSE=0
PARALLEL=1
OUTPUT_DIR="$SCRIPT_DIR/results"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --suite)
      TEST_SUITE="$2"
      shift 2
      ;;
    --arch)
      ARCH="$2"
      shift 2
      ;;
    --verbose|-v)
      VERBOSE=1
      shift
      ;;
    --serial)
      PARALLEL=0
      shift
      ;;
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --all)
      TEST_SUITE="all"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--suite unit|integration|system|perf|stress|all] [--arch aarch64] [--verbose] [--serial] [--output DIR]"
      exit 1
      ;;
  esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Color output
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
fi

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
  echo -e "${RED}[FAIL]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test statistics
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

START_TIME=$(date +%s)

# Function to run a test
run_test() {
  local test_name=$1
  local test_script=$2

  ((TOTAL_TESTS++))

  if [ $VERBOSE -eq 1 ]; then
    log_info "Running: $test_name"
  fi

  local output_file="$OUTPUT_DIR/${test_name}.log"

  if timeout 300 bash "$test_script" > "$output_file" 2>&1; then
    ((PASSED_TESTS++))
    log_success "$test_name"
    return 0
  else
    ((FAILED_TESTS++))
    log_error "$test_name"
    if [ $VERBOSE -eq 1 ]; then
      echo "--- Test output ---"
      cat "$output_file"
      echo "-------------------"
    fi
    return 1
  fi
}

# Function to skip a test
skip_test() {
  local test_name=$1
  local reason=$2

  ((TOTAL_TESTS++))
  ((SKIPPED_TESTS++))
  log_warning "$test_name (skipped: $reason)"
}

# Print header
echo "=========================================="
echo "home-os Test Suite"
echo "=========================================="
echo "Suite:        $TEST_SUITE"
echo "Architecture: $ARCH"
echo "Parallel:     $([ $PARALLEL -eq 1 ] && echo 'yes' || echo 'no')"
echo "Output:       $OUTPUT_DIR"
echo "=========================================="
echo ""

# Run unit tests
if [ "$TEST_SUITE" == "all" ] || [ "$TEST_SUITE" == "unit" ]; then
  log_info "Running unit tests..."

  for test in "$SCRIPT_DIR"/unit/*.sh; do
    if [ -f "$test" ]; then
      test_name=$(basename "$test" .sh)
      run_test "unit-$test_name" "$test" &
      if [ $PARALLEL -eq 0 ]; then
        wait
      fi
    fi
  done

  if [ $PARALLEL -eq 1 ]; then
    wait
  fi
fi

# Run integration tests
if [ "$TEST_SUITE" == "all" ] || [ "$TEST_SUITE" == "integration" ]; then
  log_info "Running integration tests..."

  for test in "$SCRIPT_DIR"/integration/*.sh; do
    if [ -f "$test" ]; then
      test_name=$(basename "$test" .sh)
      run_test "integration-$test_name" "$test" &
      if [ $PARALLEL -eq 0 ]; then
        wait
      fi
    fi
  done

  if [ $PARALLEL -eq 1 ]; then
    wait
  fi
fi

# Run system tests
if [ "$TEST_SUITE" == "all" ] || [ "$TEST_SUITE" == "system" ]; then
  log_info "Running system tests..."

  for test in "$SCRIPT_DIR"/system/*.sh; do
    if [ -f "$test" ]; then
      test_name=$(basename "$test" .sh)
      # System tests run serially due to QEMU resource usage
      run_test "system-$test_name" "$test"
    fi
  done
fi

# Run performance tests
if [ "$TEST_SUITE" == "all" ] || [ "$TEST_SUITE" == "perf" ]; then
  log_info "Running performance tests..."

  for test in "$SCRIPT_DIR"/perf/*.sh; do
    if [ -f "$test" ]; then
      test_name=$(basename "$test" .sh)
      run_test "perf-$test_name" "$test" &
      if [ $PARALLEL -eq 0 ]; then
        wait
      fi
    fi
  done

  if [ $PARALLEL -eq 1 ]; then
    wait
  fi
fi

# Run stress tests
if [ "$TEST_SUITE" == "all" ] || [ "$TEST_SUITE" == "stress" ]; then
  log_info "Running stress tests..."

  for test in "$SCRIPT_DIR"/stress/*.sh; do
    if [ -f "$test" ]; then
      test_name=$(basename "$test" .sh)
      # Stress tests run serially to avoid resource contention
      run_test "stress-$test_name" "$test"
    fi
  done
fi

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Generate JUnit XML report
generate_junit_report() {
  local xml_file="$OUTPUT_DIR/junit-report.xml"

  cat > "$xml_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="home-os" tests="$TOTAL_TESTS" failures="$FAILED_TESTS" skipped="$SKIPPED_TESTS" time="$DURATION">
  <testsuite name="$TEST_SUITE" tests="$TOTAL_TESTS" failures="$FAILED_TESTS" skipped="$SKIPPED_TESTS" time="$DURATION">
EOF

  for log_file in "$OUTPUT_DIR"/*.log; do
    if [ -f "$log_file" ]; then
      local test_name=$(basename "$log_file" .log)
      local status="passed"

      if grep -q "FAIL" "$log_file"; then
        status="failed"
        echo "    <testcase name=\"$test_name\" time=\"0\">" >> "$xml_file"
        echo "      <failure message=\"Test failed\">" >> "$xml_file"
        cat "$log_file" | sed 's/&/&amp;/g; s/</&lt;/g; s/>/&gt;/g' >> "$xml_file"
        echo "      </failure>" >> "$xml_file"
        echo "    </testcase>" >> "$xml_file"
      else
        echo "    <testcase name=\"$test_name\" time=\"0\"/>" >> "$xml_file"
      fi
    fi
  done

  cat >> "$xml_file" << EOF
  </testsuite>
</testsuites>
EOF

  log_info "JUnit report: $xml_file"
}

generate_junit_report

# Print summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Total:   $TOTAL_TESTS"
echo -e "Passed:  ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed:  ${RED}$FAILED_TESTS${NC}"
echo -e "Skipped: ${YELLOW}$SKIPPED_TESTS${NC}"
echo "Duration: ${DURATION}s"
echo "=========================================="

# Exit with appropriate code
if [ $FAILED_TESTS -gt 0 ]; then
  exit 1
else
  exit 0
fi
