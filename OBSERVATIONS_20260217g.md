# Observations: Fix Focus and Keyboard Navigation in Overlay

Date: 2026-02-17
Agent: reflective-coding-agent

## Problem Solved
Fixed focus and keyboard navigation issues in the ClipAI overlay by implementing proper SwiftUI focus management, keyboard navigation with arrow keys, and configuring the NSPanel to accept keyboard input.

---

## For Future Self

### How to Prevent This Problem
- [ ] When creating floating NSPanels with text input, always set `becomesKeyOnlyIfNeeded = false` from the start
- [ ] Include keyboard navigation tests in the ViewModel from the beginning - they're easy to write and test
- [ ] Remember: `canBecomeKey = true` alone is not sufficient for text input - the panel must also accept first responder

Example: "Before implementing an overlay with text input, check that: 1) canBecomeKey = true, 2) acceptsFirstResponder = true, 3) becomesKeyOnlyIfNeeded = false"

### How to Find Solution Faster
- Key insight: The issue was `becomesKeyOnlyIfNeeded = true` which prevented the panel from becoming key automatically
- Search that works: `grep -r "becomesKeyOnlyIfNeeded"` to find the configuration
- Start here: `OverlayWindowController.swift` - the panel configuration section
- Debugging step: Check if the panel is actually becoming key using `NSPanel.becomesKeyOnlyIfNeeded`

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| `Read OverlayView.swift` | Identified that it was using a placeholder view instead of real TextField |
| `Read OverlayWindowController.swift` | Found the `becomesKeyOnlyIfNeeded` setting that was blocking keyboard input |
| TDD approach | Writing failing tests first helped define the exact behavior needed |
| `swift test --filter` | Allowed focused testing of specific test suites |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| None significant | The TDD approach kept the implementation focused |

---

## Agent Self-Reflection

### My Approach
1. Read the existing code files to understand current state - worked well
2. Write failing tests for ViewModel keyboard navigation - worked well
3. Implement ViewModel changes - worked well
4. Implement OverlayView with TextField and focus management - worked well
5. Fix OverlayPanel configuration - this was the key fix

### What Was Critical for Success
- **Key insight:** `becomesKeyOnlyIfNeeded = true` was preventing the panel from becoming key for text input
- **Right tool:** SwiftUI's `@FocusState` property wrapper for managing focus between search field and list items
- **Right question:** "Why can't the text field get focus?" - led to investigating panel configuration

### What I Would Do Differently
- [ ] When implementing overlays with text input, check `becomesKeyOnlyIfNeeded` immediately
- [ ] Consider adding an integration test that verifies text input works

### TDD Compliance
- [x] Wrote test first (Red)
- [x] Minimal implementation (Green)
- [x] Refactored while green
- Tests were added to ViewModel for keyboard navigation logic, then implementation followed

---

## Code Changed
- `/Users/witek/projects/copies/clipai/Sources/ClipAI/UI/OverlayViewModel.swift` - Added searchText, filteredClips, focusedIndex, and keyboard navigation methods
- `/Users/witek/projects/copies/clipai/Sources/ClipAI/UI/OverlayView.swift` - Replaced placeholder with real TextField, added @FocusState, keyboard handling
- `/Users/witek/projects/copies/clipai/Sources/ClipAI/UI/OverlayWindowController.swift` - Added acceptsFirstResponder, changed becomesKeyOnlyIfNeeded to false
- `/Users/witek/projects/copies/clipai/Tests/ClipAITests/UI/OverlayViewModelTests.swift` - Added 10 new tests for search and keyboard navigation
- `/Users/witek/projects/copies/clipai/Tests/ClipAITests/UI/OverlayWindowControllerTests.swift` - Updated test for new panel configuration

## Tests Added
- OverlayViewModelTests.swift - 10 new tests:
  - testSearchText_WhenSet_FiltersClips
  - testSearchText_WhenEmpty_ShowsAllClips
  - testFocusedIndex_WhenInitialized_IsNil
  - testMoveFocusDown_WhenSearchFocused_MovesToFirstItem
  - testMoveFocusDown_WhenAtLastItem_StaysAtLastItem
  - testMoveFocusDown_WhenInMiddle_MovesToNextItem
  - testMoveFocusUp_WhenAtFirstItem_ReturnsToSearch
  - testMoveFocusUp_WhenInMiddle_MovesToPreviousItem
  - testMoveFocusUp_WhenSearchFocused_StaysAtSearch
  - testResetFocus_WhenCalled_ReturnsToNil

## Verification
```bash
swift test && swift build && ./scripts/quality-check.sh --all
```

## Summary of Changes

### 1. OverlayPanel Configuration (OverlayWindowController.swift)
- Added `acceptsFirstResponder: Bool { true }` to allow text input
- Changed `becomesKeyOnlyIfNeeded` from `true` to `false` to allow panel to become key for text input

### 2. OverlayViewModel Enhancements
- Added `searchText: String` property for search functionality
- Added `focusedIndex: Int?` property for keyboard navigation (nil = search focused)
- Added `filteredClips` computed property for search filtering
- Added `moveFocusDown()`, `moveFocusUp()`, `resetFocus()`, `setFocusIndex()` methods

### 3. OverlayView SwiftUI Updates
- Replaced placeholder with real `TextField` bound to `viewModel.searchText`
- Added `@FocusState` with `FocusField` enum for managing focus between search and items
- Added `.onKeyPress(.downArrow)` and `.onKeyPress(.upArrow)` handlers
- Added visual focus indicator on ClipRowView (accent color background)
- Search field is automatically focused when overlay opens

### 4. User Experience
- Search field is focused when overlay opens (user can start typing immediately)
- Arrow Down from search field moves to first item
- Arrow Up from first item returns to search field
- Arrow keys navigate between list items
- Focused items have a visual highlight
