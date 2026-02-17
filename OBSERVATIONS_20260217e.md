# Observations: Menu Bar Icon and Basic Overlay (Story 2)

Date: 2026-02-17
Agent: reflective-coding-agent

## Problem Solved

Implemented Story 2: A Raycast-style overlay window that appears when clicking the ClipAI menu bar icon. The overlay is centered, draggable, dismissible via Escape or click-outside, and remembers its position across sessions.

---

## For Future Self

### How to Prevent This Problem

- [ ] When creating NSWindowController subclasses, always set up callbacks **after** `super.init(window:)` to avoid "self used before super.init" errors
- [ ] Use custom NSPanel subclasses for overlay windows to properly handle keyboard events and resignKey notifications
- [ ] Test window behavior with `@MainActor` annotation on test classes to avoid concurrency warnings

### How to Find Solution Faster

- Key insight: Use `OverlayPanel` subclass to override `keyDown(with:)` for Escape key and `resignKey()` for click-outside dismissal
- Search that works: `NSPanel nonactivatingPanel floating` finds the correct configuration
- Start here: `/Users/witek/projects/copies/clipai/Sources/ClipAI/UI/OverlayWindowController.swift`
- Debugging step: Check `canBecomeKey` and `canBecomeMain` overrides in custom NSPanel

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| `Grep "NSPanel floating"` | Found correct window configuration |
| Read best-practices.md | Showed the Panel/Floating window pattern |
| `swift test --filter OverlayWindowControllerTests` | Quickly verified implementation during TDD |
| TDD Red-Green-Refactor | Ensured all requirements were tested before implementation |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Initial test without `@MainActor` | Caused concurrency warnings that needed fixing |
| Setting callback before `super.init` | Caused build error that required refactoring |
| Using `string(forKey:)` instead of `data(forKey:)` | Test failed initially because position was saved as Data |

---

## Agent Self-Reflection

### My Approach

1. Created failing tests first (TDD Red phase) - worked well
2. Implemented minimal code to pass tests (TDD Green phase) - worked well
3. Added Escape/click-outside dismissal functionality - required refactoring
4. Fixed initialization order issue - pivoted to set callback after super.init

### What Was Critical for Success

- **Key insight:** NSPanel subclass with `keyDown` and `resignKey` overrides is the cleanest way to handle dismissal
- **Right tool:** XCTest with `@MainActor` for UI-related tests
- **Right question:** "How do Raycast/Spotlight handle overlay dismissal?"

### What I Would Do Differently

- [ ] Add callback setup in a separate method called after init to avoid order issues
- [ ] Test keyboard events with actual key codes early in the process
- [ ] Read existing macOS overlay implementations before starting

### TDD Compliance

- [x] Wrote test first (Red)
- [x] Minimal implementation (Green)
- [x] Refactored while green
- All steps followed correctly

---

## Code Changed

- `/Users/witek/projects/copies/clipai/Sources/ClipAI/UI/OverlayWindowController.swift` - Created with OverlayPanel and OverlayWindowController classes
- `/Users/witek/projects/copies/clipai/Sources/ClipAI/UI/OverlayView.swift` - Created placeholder SwiftUI view
- `/Users/witek/projects/copies/clipai/Sources/ClipAI/ClipAIApp.swift` - Added overlay controller and status bar click handler

## Tests Added

- `/Users/witek/projects/copies/clipai/Tests/ClipAITests/UI/OverlayWindowControllerTests.swift`
  - 22 tests covering:
    - Window configuration (NSPanel, floating level, size, non-activating)
    - Show/hide/toggle behavior
    - Position persistence
    - Collection behavior (canJoinAllSpaces, transient)
    - Escape key dismissal
    - Click-outside dismissal

## Verification

```bash
# Run tests
swift test

# Run quality checks
./scripts/quality-check.sh --all

# Build the app
swift build
```

## Acceptance Criteria Status

| Criteria | Status |
|----------|--------|
| Menu bar icon visible (already done) | PASS |
| Click opens centered overlay | PASS |
| Overlay is draggable | PASS |
| Escape or click-outside dismisses | PASS |
| Position persists across sessions | PASS |
