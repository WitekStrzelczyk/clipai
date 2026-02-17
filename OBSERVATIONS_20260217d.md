# Observations: Browser URL Extraction via Accessibility API

Date: 2026-02-17
Agent: reflective-coding-agent

## Problem Solved
Added optional browser URL extraction using macOS Accessibility API with graceful fallback. When accessibility permissions are granted, ClipAI can now extract the current URL from Safari, Chrome, Firefox, and Edge address bars when content is copied from a browser.

---

## For Future Self

### How to Prevent This Problem
- [ ] When using Accessibility API, always check `AXIsProcessTrusted()` before attempting extraction
- [ ] Use `unsafeBitCast` for CFTypeRef to AXUIElement conversion (not force cast `as!`)
- [ ] Design features with optional dependencies - app should work without accessibility permissions

### How to Find Solution Faster
- Key insight: The Accessibility API returns `CFTypeRef` which must be converted to `AXUIElement` using `unsafeBitCast` rather than force casting
- Search that works: `AXUIElementCopyAttributeValue` for finding the main window and children
- Start here: `/Users/witek/projects/copies/clipai/Sources/ClipAI/Services/BrowserURLExtractor.swift`
- Debugging step: Check `AXIsProcessTrustedWithOptions` first to verify permissions

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| `swift test --filter X` | Isolated tests for faster iteration |
| `./scripts/quality-check.sh --all` | Caught force cast violations before commit |
| Read existing ClipboardMonitor.swift | Showed the pattern for integrating new features |
| SwiftLint error messages | Identified exact lines with force cast violations |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Initial force cast approach | Caused SwiftLint errors requiring refactoring |
| Long log lines | Had to break up for line length violations |

---

## Agent Self-Reflection

### My Approach
1. Created tests first (Red phase) - tests failed as expected
2. Implemented BrowserURLExtractor with minimal code (Green phase)
3. Integrated into ClipboardMonitor with optional dependency pattern
4. Updated ClipAIApp to log permission status
5. Fixed SwiftLint violations (force casts, line lengths)

### What Was Critical for Success
- **Key insight:** Using optional `BrowserURLExtractor?` parameter in ClipboardMonitor allows app to work with or without accessibility permissions
- **Right tool:** SwiftLint caught force cast violations that would cause crashes
- **Right question:** "How do I gracefully fall back when permissions are not available?"

### What I Would Do Differently
- [ ] Use `unsafeBitCast` from the start instead of force cast `as!`
- [ ] Break long log messages into multiple lines earlier

### TDD Compliance
- [x] Wrote test first (Red)
- [x] Minimal implementation (Green)
- [x] Refactored while green
- N/A - Did not skip steps

---

## Code Changed
- `/Users/witek/projects/copies/clipai/Sources/ClipAI/Services/BrowserURLExtractor.swift` - NEW: Service for extracting URLs from browser address bars via Accessibility API
- `/Users/witek/projects/copies/clipai/Sources/ClipAI/Services/ClipboardMonitor.swift` - Added optional BrowserURLExtractor dependency, tries browser URL extraction when source is browser
- `/Users/witek/projects/copies/clipai/Sources/ClipAI/ClipAIApp.swift` - Added browser URL extractor initialization and permission logging

## Tests Added
- `/Users/witek/projects/copies/clipai/Tests/ClipAITests/Services/BrowserURLExtractorTests.swift` - 10 tests covering:
  - Permission checking
  - Browser detection (Safari, Chrome, Firefox, Edge)
  - URL extraction with nil app
  - URL extraction with non-browser app
  - Graceful fallback without permissions
- `/Users/witek/projects/copies/clipai/Tests/ClipAITests/Services/ClipboardMonitorTests.swift` - 3 new tests for browser URL extraction integration

## Verification
```bash
# Run all tests
swift test

# Run quality checks
./scripts/quality-check.sh --all

# Verify build
swift build
```

## Summary
- 55 tests pass (10 new BrowserURLExtractor tests + 3 new ClipboardMonitor integration tests)
- Quality checks pass (0 serious violations)
- App works WITH and WITHOUT accessibility permissions
- Supports Safari, Chrome, Firefox, and Edge
