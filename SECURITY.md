# Security Policy

## Supported Versions

The following versions of home-os receive security updates:

| Version | Supported          | End of Support |
| ------- | ------------------ | -------------- |
| 1.0.x   | :white_check_mark: | December 2030  |
| < 1.0   | :x:                | Pre-release    |

**LTS (Long Term Support)** releases receive security updates for 5 years.
**Regular** releases receive security updates for 9 months.

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue, please report it responsibly.

### How to Report

**DO NOT** report security vulnerabilities through public GitHub issues.

Instead, please report them via:

1. **Email**: security@home-os.org (preferred)
2. **Encrypted Email**: Use our PGP key (see below)
3. **Security Advisory**: GitHub Security Advisories (private)

### PGP Key

For sensitive reports, encrypt your email using our PGP key:

```
Key ID: 0xABCD1234EFGH5678
Fingerprint: ABCD 1234 EFGH 5678 IJKL MNOP QRST UVWX YZ12 3456
```

Download: https://home-os.org/security/pgp-key.asc

### What to Include

Please include the following information:

- **Type of vulnerability** (e.g., buffer overflow, privilege escalation)
- **Location** of the affected code (file path, function name)
- **Steps to reproduce** the issue
- **Proof of concept** code if available
- **Impact assessment** of the vulnerability
- **Suggested fix** if you have one
- **Your contact information** for follow-up

### What to Expect

1. **Acknowledgment**: Within 24-48 hours
2. **Initial Assessment**: Within 1 week
3. **Status Updates**: Every 7 days until resolved
4. **Resolution Timeline**:
   - Critical: 24-72 hours
   - High: 1-2 weeks
   - Medium: 2-4 weeks
   - Low: Next regular release

### Disclosure Policy

We follow a **coordinated disclosure** policy:

1. Reporter submits vulnerability privately
2. We confirm and assess the issue
3. We develop and test a fix
4. We prepare security advisory
5. We release fix and advisory simultaneously
6. We credit reporter (unless anonymity requested)

**Disclosure Timeline**: 90 days from initial report, or sooner if fix is ready.

## Security Measures

### Kernel Security

home-os implements multiple layers of kernel security:

**Memory Protection**
- W^X (Write XOR Execute) enforcement
- Stack canaries
- ASLR (Address Space Layout Randomization)
- Guard pages
- Memory tagging (ARM MTE when available)

**Access Control**
- Capability-based security model
- Mandatory Access Control (MAC)
- Seccomp syscall filtering
- Namespace isolation

**Integrity**
- Secure boot chain
- Kernel module signing
- Read-only kernel text
- CFI (Control Flow Integrity)

### Application Security

**Sandboxing**
- Process isolation
- Restricted syscall access
- Filesystem access control
- Network filtering per-app

**Cryptography**
- Hardware RNG seeding
- Constant-time crypto operations
- Memory-hard key derivation
- Secure key storage

### Network Security

**Protocols**
- TLS 1.3 for all network services
- SSH-2.0 with modern algorithms
- WireGuard for VPN

**Firewall**
- Stateful packet filtering
- Connection tracking
- Rate limiting
- SYN flood protection

## Security Updates

### Checking for Updates

```bash
# Check for security updates
pkg security-check

# List available security updates
pkg list-updates --security

# Apply security updates only
sudo pkg upgrade --security
```

### Automatic Updates

Enable automatic security updates:

```bash
# Enable in settings
sudo systemctl enable security-updates.timer

# Or configure in /etc/pkg/security.conf
AUTO_SECURITY_UPDATES=yes
```

### Update Notifications

Security updates are announced via:

- **Mailing List**: security-announce@home-os.org
- **RSS Feed**: https://home-os.org/security/feed.xml
- **GitHub**: Security Advisories
- **In-System**: Notification daemon

## Security Advisories

Published advisories are available at:

- https://home-os.org/security/advisories
- https://github.com/home-os/home-os/security/advisories

### Advisory Format

```
ID: HOMEOS-2025-XXXX
Title: Brief description
Severity: Critical/High/Medium/Low
CVE: CVE-2025-XXXXX (if assigned)
Affected: Versions affected
Fixed: Version containing fix
Published: Date
```

## Hardening Guide

### System Hardening

```bash
# Enable all security features
sudo security-harden --all

# Or individually:
sudo security-harden --firewall
sudo security-harden --audit
sudo security-harden --mac
```

### Recommended Settings

**/etc/security/hardening.conf**
```ini
# Enable ASLR
kernel.randomize_va_space = 2

# Restrict kernel pointers
kernel.kptr_restrict = 2

# Restrict dmesg
kernel.dmesg_restrict = 1

# Enable seccomp
kernel.seccomp = 1

# Restrict ptrace
kernel.yama.ptrace_scope = 2
```

### Audit Configuration

Enable security auditing:

```bash
# Enable audit daemon
sudo systemctl enable auditd

# Configure audit rules
sudo audit-setup --recommended
```

## Bug Bounty Program

We offer rewards for responsibly disclosed vulnerabilities:

| Severity | Reward Range |
|----------|--------------|
| Critical | $1,000 - $5,000 |
| High | $500 - $1,000 |
| Medium | $100 - $500 |
| Low | $50 - $100 |

### Eligibility

- First reporter of the vulnerability
- Valid, reproducible security issue
- Follows responsible disclosure
- Not a current employee or contractor

### Scope

**In Scope:**
- Kernel vulnerabilities
- Privilege escalation
- Remote code execution
- Authentication bypass
- Cryptographic weaknesses
- Information disclosure

**Out of Scope:**
- Social engineering
- Physical attacks
- Denial of service (unless severe)
- Third-party software
- Already known issues

## Contact

- **Security Team**: security@home-os.org
- **PGP Key**: https://home-os.org/security/pgp-key.asc
- **Bug Bounty**: bounty@home-os.org

## Acknowledgments

We thank the following researchers for responsibly disclosing vulnerabilities:

*This section will be updated as we receive and resolve reports.*

---

*Last updated: December 2025*
