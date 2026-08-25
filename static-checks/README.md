# home-os Test Suite

Comprehensive test suite for the home-os kernel.

## Test Structure

```
tests/
├── run-tests.sh        # Main test runner
├── unit/               # Unit tests (fast, isolated)
│   ├── test_memory.sh  # Memory subsystem tests
│   └── test_drivers.sh # Driver subsystem tests
├── integration/        # Integration tests (component interactions)
│   └── test_boot.sh    # Boot sequence integration
├── system/             # System tests (full system in QEMU)
│   └── test_qemu_raspi4.sh
└── results/            # Test results and logs

## Running Tests

### Run all tests
```bash
./run-tests.sh --all
```

### Run specific test suite
```bash
./run-tests.sh --suite unit
./run-tests.sh --suite integration
./run-tests.sh --suite system
```

### Run with verbose output
```bash
./run-tests.sh --all --verbose
```

### Run tests serially (for debugging)
```bash
./run-tests.sh --all --serial
```

## Test Types

### Unit Tests
- Fast, isolated tests of individual components
- No external dependencies
- Run in parallel by default
- Located in `tests/unit/`

**Coverage:**
- Memory management (ZRAM, slab, pools)
- Driver subsystem (RP1, GIC, EMMC, WiFi, USB)
- Power management (DVFS, thermal)
- Debugging tools (GDB, profiler, leak detector)

### Integration Tests
- Test component interactions
- May require kernel binary
- Run in parallel by default
- Located in `tests/integration/`

**Coverage:**
- Boot sequence
- Driver initialization
- Memory layout
- Build system

### System Tests
- End-to-end testing in QEMU
- Require kernel binary and QEMU
- Run serially (resource intensive)
- Located in `tests/system/`

**Coverage:**
- Boot on Raspberry Pi 4
- Boot on Raspberry Pi 5 (when QEMU supports it)
- Shell interaction
- Device driver functionality

## Test Output

Test results are saved to `tests/results/`:
- Individual test logs: `results/<test-name>.log`
- JUnit XML report: `results/junit-report.xml`

## CI/CD Integration

Tests are automatically run in CI/CD pipeline (`.github/workflows/ci.yml`):
- On every push to main/develop
- On pull requests
- Nightly builds

## Writing New Tests

### Unit Test Template
```bash
#!/bin/bash
set -e

TEST_NAME="My Test"
echo "Running $TEST_NAME..."

# Test 1
echo "[1/N] Testing feature X..."
if [ condition ]; then
  echo "FAIL: reason"
  exit 1
fi
echo "PASS: Feature X works"

echo "All tests passed!"
```

### Integration Test Template
```bash
#!/bin/bash
set -e

TEST_NAME="My Integration Test"
KERNEL="$(git rev-parse --show-toplevel)/kernel/build/home-kernel.elf"

echo "Running $TEST_NAME..."

# Test interactions between components
# May use kernel binary for verification

echo "All integration tests passed!"
```

### System Test Template
```bash
#!/bin/bash
set -e

TEST_NAME="My System Test"
KERNEL="$(git rev-parse --show-toplevel)/kernel/build/home-kernel.elf"
SERIAL_LOG="/tmp/my-test.log"

# Boot in QEMU
timeout 30s qemu-system-aarch64 \
  -M raspi4b \
  -m 1G \
  -kernel "$KERNEL" \
  -nographic \
  -serial file:"$SERIAL_LOG" &

QEMU_PID=$!
sleep 5
kill $QEMU_PID

# Verify log
if ! grep -q "expected message" "$SERIAL_LOG"; then
  echo "FAIL"
  exit 1
fi

echo "All system tests passed!"
```

## Test Requirements

### Dependencies
- Bash 4.0+
- QEMU (for system tests)
- readelf, file (for integration tests)
- timeout command

### Build Requirements
System and integration tests require a built kernel:
```bash
cd kernel
home build --profile developer
```

## Troubleshooting

### Tests timeout
Increase timeout in `run-tests.sh` or individual test scripts.

### QEMU not found
Install QEMU:
```bash
# Ubuntu
sudo apt-get install qemu-system-aarch64

# macOS
brew install qemu
```

### Permission denied
Make test scripts executable:
```bash
chmod +x tests/**/*.sh
```

## Coverage Goals

Target code coverage: **70%+**

Current coverage by subsystem:
- Memory management: TBD
- Drivers: TBD
- Boot/init: TBD
- Power management: TBD
- Debugging: TBD

Run coverage analysis:
```bash
home build --profile developer --coverage
./run-tests.sh --all --coverage
home coverage report
```

## Performance Benchmarks

Performance tests are separate from functional tests.

Run benchmarks:
```bash
./scripts/run-benchmarks.sh
```

Compare with baseline:
```bash
./scripts/compare-benchmarks.sh benchmarks.json baseline-benchmarks.json
```

## Continuous Testing

Watch for file changes and re-run tests:
```bash
# Requires: inotifywait (Linux) or fswatch (macOS)
./scripts/watch-tests.sh
```

## Test Metrics

Tests emit metrics to `results/metrics.json`:
- Execution time per test
- Pass/fail/skip counts
- Coverage percentages
- Resource usage (QEMU tests)

View metrics:
```bash
cat results/metrics.json | jq
```

## Contributing

When adding new code:
1. Write unit tests for new functions
2. Add integration tests for component interactions
3. Update system tests if boot/runtime behavior changes
4. Ensure tests pass locally before submitting PR
5. Maintain >70% code coverage

## License

Same as home-os (see top-level LICENSE file).
