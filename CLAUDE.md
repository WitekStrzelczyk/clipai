# ClipAI Project Instructions

## Required Reading

**MANDATORY for all coding work:**

1. **[docs/development/best-practices.md](docs/development/best-practices.md)** - Swift, SwiftUI, and testing best practices
2. **[docs/development/quality-tools.md](docs/development/quality-tools.md)** - Quality toolchain reference
3. **[docs/vision.md](docs/vision.md)** - Product vision and architecture

Read these documents before writing any code. They contain essential patterns, conventions, and requirements.

---

## Coding Rules

### Authorized Coding Agent

**ONLY the `reflective-coding-agent` is authorized to write code in this project.**

- No other agent (including the main Claude instance) should directly modify Swift code
- If coding is needed, you MUST invoke the reflective-coding-agent
- This ensures all code goes through proper TDD and quality checks

### Quality Check Requirement

Before marking any story as "done", the quality check workflow MUST be followed:

1. Implement the feature with TDD
2. Run `swift test` - all tests must pass
3. Run `./scripts/quality-check.sh --all` - must pass with no errors
4. Fix any issues found
5. Only then mark the story as complete

**Reference:** See `docs/development/quality-tools.md` for full documentation of quality tools.

### Story Completion Checklist

A story is NOT done until:

- [ ] All tests pass (`swift test`)
- [ ] Quality check passes (`./scripts/quality-check.sh --all`)
- [ ] No SwiftLint errors
- [ ] No strict concurrency warnings
- [ ] Code is formatted (`./scripts/format.sh`)

## Project Structure

```
clipai/
├── Sources/ClipAI/          # Main app code
├── Tests/ClipAITests/       # Test files
├── scripts/                 # Quality and utility scripts
├── docs/                    # Documentation
│   ├── vision.md           # Product vision
│   ├── development/        # Dev guides
│   └── competitors/        # Competitor analysis
├── TODO.md                 # User stories backlog
└── CLAUDE.md               # This file
```

## Quick Commands

```bash
./scripts/run-app.sh                  # Build and run the app (use this!)
swift build                           # Build the project
swift test                            # Run all tests
./scripts/quality-check.sh            # Check changed files
./scripts/quality-check.sh --all      # Check all files
./scripts/format.sh                   # Format code in-place
```

**After implementing changes, always use `./scripts/run-app.sh` to rebuild and test the app.**

## Dependencies

```bash
brew install swiftlint swift-format
```
