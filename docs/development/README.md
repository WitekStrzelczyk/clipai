# Development Guide

Quick reference for developing ClipAI.

## Prerequisites

```bash
# Install required tools
brew install swiftlint swift-format
```

## Essential Commands

| Command | Description |
|---------|-------------|
| `./scripts/run-app.sh` | Build and run the app (stops existing, rebuilds, starts) |
| `swift build` | Build the project |
| `swift test` | Run all tests |
| `./scripts/quality-check.sh` | Check changed files (format, lint, concurrency) |
| `./scripts/format.sh` | Auto-format changed files |

## Running the App

To build and run the app during development:

```bash
./scripts/run-app.sh
```

This script:
1. Stops any existing ClipAI instance
2. Builds the project
3. Starts the app
4. Shows feature reminders and log location

**Logs:** `tail -f ~/.clipai/clipai.log`

## Quality Checks

Before committing, run:

```bash
./scripts/quality-check.sh
```

This runs three checks:
1. **Format** (advisory) - Reports style issues
2. **Lint** (required) - Catches code problems
3. **Concurrency** (required) - Validates thread safety

## Check Scope

By default, checks run on changed files only:

```bash
./scripts/quality-check.sh          # Changed files only
./scripts/quality-check.sh --all    # All files
./scripts/format.sh --all           # Format all files
```

## Common Workflows

### Starting Work

```bash
# Build and verify environment
swift build

# Run tests
swift test
```

### Before Committing

```bash
# Check quality
./scripts/quality-check.sh

# Fix formatting issues
./scripts/format.sh

# Run tests
swift test
```

### CI Environment

Set `QUALITY_DIFF_BASE` to compare against a specific branch:

```bash
QUALITY_DIFF_BASE=origin/main ./scripts/quality-check.sh
```

## Configuration

| File | Purpose |
|------|---------|
| `.swiftlint.yml` | Linting rules (14 rules) |
| `.swift-format` | Formatting style (4-space indent, 120 char lines) |

## Need More?

- **[Best Practices](best-practices.md)** - Swift, SwiftUI, and testing best practices (MANDATORY reading)
- [Quality Tools Reference](quality-tools.md) - Detailed tool documentation
- [Architecture](../architecture/) - System design docs
- [Guides](../guides/) - How-to guides

---

*Last reviewed: 2026-02-17*
*Review cycle: quarterly*
