# Quality Tools Reference

Detailed documentation for ClipAI's code quality toolchain.

---
last_reviewed: 2026-02-17
review_cycle: quarterly
status: current
---

## Overview

ClipAI uses three quality layers:

| Layer | Tool | Behavior | Blocking |
|-------|------|----------|----------|
| Format | swift-format | Reports style issues | No (advisory) |
| Lint | SwiftLint | Catches code problems | Yes (errors block) |
| Concurrency | Swift compiler | Validates thread safety | Yes (errors block) |

## Scripts Reference

### quality-check.sh

**Purpose:** Main entry point that orchestrates all quality checks.

**Usage:**
```bash
./scripts/quality-check.sh [--changed|--all]
```

**Arguments:**
- `--changed` (default) - Check only changed files
- `--all` - Check all Swift files in the project

**Exit Behavior:**
- Exits 0 if all required checks pass
- Exits 1 if lint or concurrency checks fail
- Format issues are advisory and never cause failure

**What it runs:**
1. `format-check.sh` - Advisory formatting check
2. `lint.sh` - Required lint check
3. `strict-concurrency-check.sh` - Required concurrency check

**Example:**
```bash
# Check only changed files (default)
./scripts/quality-check.sh

# Check all files (useful for full validation)
./scripts/quality-check.sh --all

# In CI, compare against main branch
QUALITY_DIFF_BASE=origin/main ./scripts/quality-check.sh
```

---

### format.sh

**Purpose:** In-place code formatting using swift-format.

**Usage:**
```bash
./scripts/format.sh [--changed|--all]
```

**Behavior:**
- Modifies files directly (in-place)
- Uses `.swift-format` configuration
- Requires `swift-format` installed (`brew install swift-format`)

**Example:**
```bash
# Format changed files
./scripts/format.sh

# Format all files
./scripts/format.sh --all
```

---

### format-check.sh

**Purpose:** Read-only format validation (doesn't modify files).

**Usage:**
```bash
./scripts/format-check.sh [--changed|--all]
```

**Behavior:**
- Uses `swift format lint --strict`
- Always exits 0 (advisory only)
- Reports issues but doesn't block

**When to use:**
- CI pipelines to report style drift
- Pre-commit hooks (non-blocking)
- Code review preparation

---

### lint.sh

**Purpose:** SwiftLint execution for code quality rules.

**Usage:**
```bash
./scripts/lint.sh [--changed|--all]
```

**Behavior:**
- Uses `.swiftlint.yml` configuration
- Creates temp cache at `${TMPDIR}/clipai-swiftlint-cache`
- Exits 1 on errors (blocking)

**Example:**
```bash
# Lint changed files
./scripts/lint.sh

# Lint all files
./scripts/lint.sh --all
```

---

### changed-swift-files.sh

**Purpose:** Utility to determine which Swift files to check.

**Usage:**
```bash
./scripts/changed-swift-files.sh [--changed|--all]
```

**Diff Base Resolution:**
1. `QUALITY_DIFF_BASE` environment variable (highest priority)
2. `origin/$GITHUB_BASE_REF` for GitHub PRs
3. `HEAD~1` (previous commit)
4. Falls back to `--all` behavior if no diff base available

**Output:**
- Newline-separated list of Swift file paths
- Empty output if no files to check

**Example:**
```bash
# Get changed files
./scripts/changed-swift-files.sh

# Get all Swift files
./scripts/changed-swift-files.sh --all

# Custom diff base
QUALITY_DIFF_BASE=origin/main ./scripts/changed-swift-files.sh
```

---

### strict-concurrency-check.sh

**Purpose:** Validates Swift concurrency safety with complete strict mode.

**Usage:**
```bash
./scripts/strict-concurrency-check.sh
```

**Behavior:**
- Builds with `-Xswiftc -strict-concurrency=complete`
- Fails on concurrency-related errors
- Reports concurrency-related warnings
- Always checks all files (not scope-aware)

**Detected Issues:**
- Sendable conformance violations
- Actor isolation problems
- Data race potential
- Missing isolation annotations

**Example:**
```bash
./scripts/strict-concurrency-check.sh
```

## Configuration Files

### .swiftlint.yml

Enables 14 focused rules across three categories:

**Complexity Rules:**
| Rule | Warning | Error |
|------|---------|-------|
| `cyclomatic_complexity` | 10 | 20 |
| `function_body_length` | 50 lines | 100 lines |
| `function_parameter_count` | 5 params | 8 params |
| `type_body_length` | 250 lines | 350 lines |
| `file_length` | 400 lines | 1000 lines |

**Style Rules:**
| Rule | Warning | Error |
|------|---------|-------|
| `line_length` | 120 chars | 200 chars |
| `nesting` (type) | 1 level | - |
| `nesting` (function) | 2 levels | - |
| `large_tuple` | 2 elements | 3 elements |

**Safety Rules:**
- `force_cast` - Prevents `as!`
- `force_try` - Prevents `try!`
- `force_unwrapping` - Prevents `!` on optionals
- `implicitly_unwrapped_optional` - Discourages `!` type annotations
- `duplicate_imports` - Prevents redundant imports

**Included Paths:**
- `Sources/`
- `Tests/`
- `Package.swift`

### .swift-format

Configures swift-format with these key settings:

**Indentation:**
- 4 spaces per tab
- Spaces for indentation

**Line Length:**
- Maximum: 120 characters
- Respects existing line breaks

**Enabled Rules (9):**
| Rule | Effect |
|------|--------|
| `AlwaysUseLowerCamelCase` | `myFunction` not `MyFunction` |
| `DoNotUseSemicolons` | No `;` at line ends |
| `NoAssignmentInExpressions` | Separate assignment from conditions |
| `NoParensAroundConditions` | `if x` not `if (x)` |
| `NoVoidReturnOnFunctionSignature` | Omit `-> Void` |
| `ReturnVoidInsteadOfEmptyTuple` | Use `Void` not `()` |
| `TypeNamesShouldBeCapitalized` | `MyType` not `myType` |
| `UseShorthandTypeNames` | `[String]` not `Array<String>` |

**Privacy:**
- File-scoped declarations default to `private`

## Troubleshooting

### swift-format not found

```bash
brew install swift-format
```

### swiftlint not found

```bash
brew install swiftlint
```

### No files to check

The `changed-swift-files.sh` script returns empty when:
- No Swift files have changed
- Not in a git repository
- No previous commits exist

Solution: Use `--all` flag or commit files first.

### Concurrency warnings in existing code

Strict concurrency checking may reveal existing issues:

1. Review each warning carefully
2. Add proper `@Sendable` conformances
3. Use actors for shared mutable state
4. Apply isolation annotations where needed

### Lint cache issues

Clear the SwiftLint cache:

```bash
rm -rf "${TMPDIR}/clipai-swiftlint-cache"
```

## Integration Examples

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

./scripts/format.sh
./scripts/quality-check.sh || exit 1
```

### GitHub Actions

```yaml
- name: Quality Check
  run: |
    QUALITY_DIFF_BASE=origin/main ./scripts/quality-check.sh
```

### Makefile

```makefile
quality:
	./scripts/quality-check.sh

format:
	./scripts/format.sh

lint:
	./scripts/lint.sh

.PHONY: quality format lint
```

## Related Documentation

- [Development Guide](README.md) - Quick start reference
- [Architecture](../architecture/) - System design decisions
