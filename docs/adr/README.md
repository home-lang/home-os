# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records for home-os.

## What is an ADR?

An Architecture Decision Record (ADR) captures an important architectural decision made along with its context and consequences.

## Format

Each ADR follows this structure:
- **Title**: Short, descriptive name
- **Status**: Proposed | Accepted | Deprecated | Superseded
- **Context**: The problem and why we need to make a decision
- **Decision**: What we decided to do
- **Consequences**: What happens as a result (positive and negative)

## Index of ADRs

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [0001](0001-use-home-language-for-os.md) | Use Home Programming Language | Accepted | 2025-11-24 |
| [0002](0002-kernel-architecture.md) | Hybrid/Modular Monolithic Kernel | Accepted | 2025-11-24 |
| [0003](0003-memory-management.md) | Memory Management Strategy | Accepted | 2025-11-24 |
| [0004](0004-driver-model.md) | Driver Development Model | Accepted | 2025-11-24 |
| [0005](0005-build-system.md) | Build System Design | Accepted | 2025-11-24 |
| [0006](0006-security-architecture.md) | Security Architecture | Accepted | 2025-11-24 |
| [0007](0007-performance-targets.md) | Performance Targets | Accepted | 2025-11-24 |
| [0008](0008-raspberry-pi-focus.md) | Raspberry Pi First Strategy | Accepted | 2025-11-24 |

## Creating a New ADR

1. Copy the template:
```bash
cp docs/adr/template.md docs/adr/NNNN-short-title.md
```

2. Fill in the sections:
   - Context: Why are we making this decision?
   - Decision: What did we decide?
   - Consequences: What are the trade-offs?

3. Get review from team

4. Update this README index

## Superseding an ADR

When an ADR is superseded:
1. Mark old ADR status as "Superseded by ADR-XXXX"
2. Create new ADR explaining the change
3. Link them together
4. Update this index

## Related Documentation

- `/CLAUDE.md` - Development guidelines
- `/TODO.md` - Development roadmap
- `/TODO-UPDATES.md` - Priority implementation tasks
- `/docs/architecture/` - Detailed architecture docs

## Questions?

For questions about ADRs or to propose new ones, see the team wiki or file an issue.
