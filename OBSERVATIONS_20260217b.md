# Observations: Story 1 - Background Clipboard Monitoring

Date: 2026-02-17
Agent: reflective-coding-agent

## Problem Solved
Implemented background clipboard monitoring for ClipAI, enabling automatic capture of text and images copied to the clipboard with source app detection, URL extraction, and persistent JSON storage.

---

## For Future Self

### How to Prevent This Problem
- [x] Always pass mock dependencies (like NSPasteboard) to actors/services for testability
- [x] Create actors for shared mutable state before writing tests
- [x] Use Logger instead of print for production code
- [x] Avoid force unwrapping in production code - use guard let or optional binding

Example: "Before implementing a service that interacts with system APIs, create a protocol or accept the dependency as a parameter to enable testing"

### How to Find Solution Faster
- Key insight: NSPasteboard.withUniqueName() creates isolated pasteboards for testing
- Search that works: `NSPasteboard changeCount` for clipboard change detection
- Start here: ClipboardMonitor.swift for clipboard polling logic
- Debugging step: Use actor isolation check - if tests fail to capture, ensure the monitor is using the injected pasteboard

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| TDD Red-Green cycle | Writing tests first caught design issues early |
| `NSPasteboard.withUniqueName()` | Created isolated pasteboards for each test |
| Swift actors | Protected shared mutable state automatically |
| `OSLog Logger` | Structured logging for debugging production issues |
| swift test --filter | Running specific test suites during development |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Initial tests using general pasteboard | Tests interfered with each other and system clipboard |
| XCTAssertNotNil for source app | Frontmost app is unpredictable in test environment |
| Multiple assertions in one test | Made it unclear which specific behavior failed |

---

## Agent Self-Reflection

### My Approach
1. Read documentation files first - **worked well** to understand project conventions
2. Created Clip model with TDD - **worked well**, caught JSON encoding issues early
3. Created ClipStorage actor with TDD - **worked well**, identified directory creation timing
4. Created ClipboardMonitor with TDD - **initially failed** because I used general pasteboard
5. Pivoted to inject pasteboard dependency - **this succeeded**

### What Was Critical for Success
- **Key insight:** Dependency injection of NSPasteboard enables isolated testing
- **Right tool:** Swift actors for thread-safe mutable state (changeCount, timer)
- **Right question:** "How do I test clipboard monitoring without affecting the system clipboard?"

### What I Would Do Differently
- [x] Ask about dependency injection pattern upfront for system APIs
- [x] Read best-practices.md more carefully for actor patterns before starting
- [x] Consider testing strategy before writing implementation

### TDD Compliance
- [x] Wrote test first (Red)
- [x] Minimal implementation (Green)
- [x] Refactored while green
- All components followed strict TDD: Clip model, ClipMetadata, ClipStorage, ClipboardMonitor

---

## Code Changed
- `Sources/ClipAI/Models/Clip.swift` - Core data model for clipboard items
- `Sources/ClipAI/Models/ClipContentType.swift` - Enum for text/image types
- `Sources/ClipAI/Models/ClipMetadata.swift` - Metadata for clips
- `Sources/ClipAI/Services/ClipStorage.swift` - Actor for JSON file persistence
- `Sources/ClipAI/Services/ClipStorageError.swift` - Error types for storage
- `Sources/ClipAI/Services/ClipboardMonitor.swift` - Actor for clipboard polling
- `Sources/ClipAI/ClipAIApp.swift` - Updated to start monitoring on launch

## Tests Added
- `ClipTests.swift` - 10 tests covering Clip model creation, encoding, fileName generation
- `ClipMetadataTests.swift` - 5 tests covering metadata for text and images
- `ClipStorageTests.swift` - 10 tests covering save, load, delete, clear operations
- `ClipStorageErrorTests.swift` - 4 tests covering error descriptions
- `ClipboardMonitorTests.swift` - 9 tests covering change detection, deduplication, source detection

## Verification
```bash
swift test                    # All 39 tests pass
swift build                   # Compiles without errors
./scripts/quality-check.sh --all  # All checks pass
```

## Acceptance Criteria Status

1. **Text capture to JSON** - Implemented and tested
   - ClipStorage saves to ~/clipai/knowledge
   - Clip model serializes to JSON with all fields

2. **Image capture to JSON** - Implemented and tested
   - Images converted to base64 PNG
   - Metadata includes dimensions

3. **Source app and URL detection** - Implemented and tested
   - NSWorkspace.shared.frontmostApplication for app name
   - NSPasteboard URL type extraction

4. **Deduplication within 5 seconds** - Implemented and tested
   - ClipboardMonitor tracks lastCapturedContent and lastCaptureTime
   - Skips capture if same content within deduplicationWindow

5. **Required JSON fields** - Implemented and tested
   - id, content, content_type, source_app, source_url, timestamp, metadata

---

## Technical Notes

### Architecture
```
ClipAIApp (AppDelegate)
    |
    v
ClipboardMonitor (actor) --captures--> Clip (Sendable)
    |                                    |
    v                                    v
ClipStorage (actor) --saves--> ~/clipai/knowledge/{timestamp}-{uuid}.json
```

### Key Patterns Used
1. **Actor isolation** - ClipboardMonitor and ClipStorage protect mutable state
2. **Dependency injection** - NSPasteboard passed to ClipboardMonitor for testing
3. **Value types** - Clip and ClipMetadata are Sendable structs
4. **Callback pattern** - onClipCaptured closure bridges monitor to storage

### Polling Interval
Default 500ms (configurable via startMonitoring parameter)

### File Naming
`{ISO8601Timestamp}-{UUID}.json` e.g., `20260217T103000-12345678-1234-1234-1234-123456789012.json`
