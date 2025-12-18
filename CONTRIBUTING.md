# Contributing to home-os

Thank you for your interest in contributing to home-os! This document provides guidelines and information for contributors.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [How to Contribute](#how-to-contribute)
4. [Development Setup](#development-setup)
5. [Coding Standards](#coding-standards)
6. [Commit Guidelines](#commit-guidelines)
7. [Pull Request Process](#pull-request-process)
8. [Issue Guidelines](#issue-guidelines)
9. [Testing](#testing)
10. [Documentation](#documentation)
11. [Community](#community)

---

## Code of Conduct

This project adheres to a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to conduct@home-os.org.

---

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- Git installed
- Home compiler (`~/Code/home/` or from https://home-lang.org)
- QEMU for testing (recommended)
- A GitHub account

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/home-os.git
   cd home-os
   ```
3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/home-os/home-os.git
   ```

---

## How to Contribute

### Types of Contributions

We welcome many types of contributions:

- **Bug Fixes**: Fix issues in the codebase
- **Features**: Implement new functionality
- **Documentation**: Improve docs, tutorials, examples
- **Tests**: Add or improve test coverage
- **Translations**: Help translate to other languages
- **Bug Reports**: Report issues you encounter
- **Feature Requests**: Suggest new features
- **Code Review**: Review pull requests

### Finding Issues to Work On

- Look for issues labeled `good first issue` for beginner-friendly tasks
- Issues labeled `help wanted` are ready for community contribution
- Check the [TODO.md](TODO.md) for planned features

### Claiming an Issue

1. Comment on the issue expressing interest
2. Wait for maintainer assignment
3. Begin work once assigned

---

## Development Setup

### Building home-os

```bash
# Clone the repository
git clone https://github.com/home-os/home-os.git
cd home-os

# Build the kernel
cd kernel
home build

# Or use the Makefile
make all
```

### Running in QEMU

```bash
# x86_64
make run-x86

# ARM64 / Raspberry Pi
make run-arm64

# With debugging
make run-debug
```

### Directory Structure

```
home-os/
├── kernel/           # Kernel source code
│   ├── src/
│   │   ├── core/     # Core kernel (scheduler, IPC, memory)
│   │   ├── arch/     # Architecture-specific code
│   │   ├── drivers/  # Device drivers
│   │   ├── fs/       # Filesystems
│   │   ├── net/      # Networking
│   │   ├── security/ # Security subsystems
│   │   └── ui/       # Graphics and UI
│   └── build.home
├── apps/             # Userspace applications
├── libs/             # Shared libraries
├── tools/            # Build and development tools
├── tests/            # Test suites
├── docs/             # Documentation
└── installer/        # Installation system
```

---

## Coding Standards

### Home Language Style

Follow these conventions for Home code:

**Naming**
```home
// Functions: snake_case
fn calculate_checksum(data: *u8, len: u32): u32

// Variables: snake_case
var page_count: u32 = 0
let max_buffer_size: u32 = 4096

// Constants: SCREAMING_SNAKE_CASE
const MAX_PROCESSES: u32 = 1024
const PAGE_SIZE: u32 = 4096

// Structs: PascalCase
struct ProcessDescriptor {
  pid: u32,
  name: [u8; 64],
  state: ProcessState
}

// Enums: PascalCase with PascalCase variants
enum ProcessState {
  Running,
  Waiting,
  Stopped,
  Zombie
}
```

**Formatting**
- Use 2-space indentation
- Maximum line length: 100 characters
- Opening braces on same line
- Spaces around operators

**Comments**
```home
// Single-line comments for brief explanations

// Multi-line comments for longer explanations
// that span multiple lines and provide
// detailed context

// Use section headers for organization
// ============================================================================
// SECTION NAME
// ============================================================================
```

**Function Documentation**
```home
// Calculate the CRC32 checksum of a data buffer
// Parameters:
//   data - Pointer to the data buffer
//   len  - Length of data in bytes
// Returns: CRC32 checksum value
fn crc32_calculate(data: *u8, len: u32): u32 {
  // Implementation
}
```

### File Organization

Each source file should have:
1. Copyright header
2. Import statements
3. Constants
4. Type definitions (structs, enums)
5. Global variables
6. Function implementations
7. Export declarations

### Error Handling

```home
// Use explicit error returns
fn open_file(path: *u8): FileResult {
  if path == null {
    return FileResult { error: ERR_INVALID_PARAM, fd: 0 }
  }
  // ...
}

// Check errors at call sites
var result: FileResult = open_file(path)
if result.error != 0 {
  // Handle error
}
```

---

## Commit Guidelines

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, no code change
- `refactor`: Code change without feature/fix
- `perf`: Performance improvement
- `test`: Adding tests
- `chore`: Build, tooling, etc.

**Examples**
```
feat(scheduler): add priority inheritance for mutexes

Implement priority inheritance protocol to prevent priority
inversion in the real-time scheduler.

Closes #123
```

```
fix(network): resolve TCP connection timeout

The TCP stack was not properly retransmitting SYN packets,
causing connection attempts to fail on lossy networks.

Fixes #456
```

### Commit Best Practices

- Make atomic commits (one logical change per commit)
- Write clear, descriptive messages
- Reference related issues
- Keep commits small and focused

---

## Pull Request Process

### Before Submitting

1. **Sync with upstream**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run tests**
   ```bash
   make test
   ```

3. **Check code style**
   ```bash
   make lint
   ```

4. **Update documentation** if needed

### Submitting a PR

1. Push your branch:
   ```bash
   git push origin feature/your-feature
   ```

2. Open a Pull Request on GitHub

3. Fill out the PR template:
   - Description of changes
   - Related issue numbers
   - Testing performed
   - Screenshots (if UI changes)

### PR Template

```markdown
## Description
Brief description of changes

## Related Issues
Fixes #123
Related to #456

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation
- [ ] Performance improvement

## Testing
Describe testing performed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] All tests passing
```

### Review Process

1. Maintainers will review within 1-2 weeks
2. Address feedback in additional commits
3. Once approved, maintainer will merge
4. Delete your branch after merge

---

## Issue Guidelines

### Bug Reports

Use the bug report template:

```markdown
**Describe the bug**
Clear description of the bug

**To Reproduce**
Steps to reproduce:
1. Go to '...'
2. Click on '...'
3. See error

**Expected behavior**
What should happen

**Environment**
- home-os version:
- Hardware:
- Architecture:

**Additional context**
Logs, screenshots, etc.
```

### Feature Requests

Use the feature request template:

```markdown
**Is this related to a problem?**
Description of the problem

**Proposed solution**
Your suggested solution

**Alternatives considered**
Other approaches you considered

**Additional context**
Any other relevant information
```

---

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run specific test suite
make test-kernel
make test-network
make test-fs

# Run with verbose output
make test VERBOSE=1
```

### Writing Tests

Tests are located in `tests/` and use the test framework in `tests/kernel/test_suite.home`.

```home
// Register a test
test_register(
  @ptrFromInt("My test name"),
  @ptrFromInt("Category"),
  @ptrFromInt(test_my_function)
)

// Test function
fn test_my_function(): u32 {
  var result: u32 = function_under_test()
  return assert_eq(expected, result, @ptrFromInt("Expected X"))
}
```

### Test Coverage

- All new features should include tests
- Bug fixes should include regression tests
- Aim for meaningful coverage, not just lines

---

## Documentation

### Types of Documentation

- **Code comments**: Explain complex logic
- **API docs**: Document public interfaces
- **User docs**: In `docs/` directory
- **Examples**: Working code samples

### Documentation Style

- Use clear, simple language
- Include code examples
- Keep information current
- Link to related documentation

### Building Documentation

```bash
make docs
```

---

## Community

### Communication Channels

- **GitHub Issues**: Bug reports, feature requests
- **GitHub Discussions**: General questions, ideas
- **IRC**: #home-os on Libera.Chat
- **Discord**: https://discord.gg/home-os
- **Forum**: https://forum.home-os.org
- **Mailing List**: dev@home-os.org

### Getting Help

- Check existing documentation first
- Search closed issues for similar problems
- Ask in community channels
- Be patient and respectful

### Recognition

Contributors are recognized in:
- Release notes
- CONTRIBUTORS.md file
- Project website

---

## License

By contributing to home-os, you agree that your contributions will be licensed under the MIT License.

---

## Questions?

If you have questions about contributing, please:
1. Check this document
2. Search existing issues
3. Ask in community channels
4. Email maintainers@home-os.org

Thank you for contributing to home-os!
