# Observations: Story 8 - Application Ignore List (Privacy)

Date: 2026-02-18
Agent: reflective-coding-agent

## Problem Solved

Implemented privacy feature to prevent ClipAI from capturing clipboard content from specific applications (like password managers). Added `IgnoreListManager` service, integrated it into `ClipboardMonitor`, and created a SwiftUI settings UI accessible from the menu bar.

---

## For Future Self

### How to Prevent This Problem

- [ ] When adding new services that need to be shared across actors, always use the actor pattern with async methods
- [ ] When storing data in UserDefaults, use a dedicated key and document it in code comments
- [ ] For UI with multiple sections, plan the structure early to avoid file length lint violations
- [ ] When returning multiple values from a function, use a struct instead of a tuple to avoid large_tuple lint warnings

### How to Find Solution Faster

- Key insight: Use `NSWorkspace.shared.frontmostApplication?.bundleIdentifier` to get the current app's bundle ID for comparison
- Search that works: `NSWorkspace.shared.frontmostApplication`
- Start here: `Sources/ClipAI/Services/ClipboardMonitor.swift` - this is where clipboard capture happens
- Debugging step: Check `NSPasteboard.changeCount` to detect clipboard changes, then check ignore list before capturing

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| `Grep "NSWorkspace"` | Found how to get frontmost application |
| Read `ClipboardMonitor.swift` | Showed where clipboard capture happens and where to add ignore check |
| `swift test --filter IgnoreListManagerTests` | Rapid feedback on implementation |
| TDD approach | Writing tests first ensured all acceptance criteria were met |
| SwiftLint | Caught large_tuple violation early, forced better struct design |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Initial tuple return type | Had to refactor to AppInfo struct after lint warning |
| File length in IgnoreListView | Had to remove preview code and condense spacing |
| Not reading existing tests first | Could have matched test patterns better |

---

## Agent Self-Reflection

### My Approach
1. Read existing codebase to understand architecture - worked well
2. Write tests first (TDD Red phase) - worked well
3. Implement IgnoreListManager - worked immediately
4. Write tests for ClipboardMonitor integration - worked well
5. Update ClipAIApp with menu and UI - worked
6. Fix lint issues - took extra iterations

### What Was Critical for Success
- **Key insight:** The `ClipboardMonitor.checkForChanges()` method is the perfect place to add the ignore check - right after detecting a change but before capturing
- **Right tool:** SwiftLint caught the large_tuple violation that would have been a code smell
- **Right question:** "Where does clipboard capture happen?" led directly to the integration point

### What I Would Do Differently
- [ ] Check SwiftLint file length limits before writing large UI files
- [ ] Use struct instead of tuple from the start for multi-value returns
- [ ] Plan UI component file structure to stay under 400 lines

### TDD Compliance
- [x] Wrote test first (Red)
- [x] Minimal implementation (Green)
- [x] Refactored while green
- All TDD steps followed correctly.

---

## Code Changed

- `/Users/witek/projects/copies/clipai/Sources/ClipAI/Services/IgnoreListManager.swift` - NEW: Service to manage ignore list
- `/Users/witek/projects/copies/clipai/Sources/ClipAI/Services/ClipboardMonitor.swift` - Added ignore list check before capture
- `/Users/witek/projects/copies/clipai/Sources/ClipAI/UI/IgnoreListView.swift` - NEW: SwiftUI settings view
- `/Users/witek/projects/copies/clipai/Sources/ClipAI/ClipAIApp.swift` - Added menu and ignore list window
- `/Users/witek/projects/copies/clipai/Tests/ClipAITests/Services/IgnoreListManagerTests.swift` - NEW: 19 tests for IgnoreListManager
- `/Users/witek/projects/copies/clipai/Tests/ClipAITests/Services/ClipboardMonitorTests.swift` - Added 3 tests for ignore list integration

## Tests Added

- `IgnoreListManagerTests.swift` - 19 tests covering:
  - Initial state (empty list)
  - Loading existing data from UserDefaults
  - Adding/removing bundle identifiers
  - Checking if app is ignored
  - Getting ignored apps with metadata
  - Suggested password managers
  - Persistence across instances

- `ClipboardMonitorTests.swift` - 3 tests covering:
  - Init with ignore list manager
  - Check changes when app is ignored
  - Setting ignore list manager after init

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

1. **AC1 - 1Password in ignore list, no clip captured**: Implemented - `ClipboardMonitor.checkForChanges()` checks frontmost app bundle ID
2. **AC2 - Add Bitwarden, immediate effect**: Implemented - UserDefaults updates are immediate, next clipboard check uses new list
3. **AC3 - View ignore list with app name and icon**: Implemented - `IgnoreListView` shows apps with icons via `NSWorkspace.shared.icon(forFile:)`
4. **AC4 - Remove from list, capture resumes**: Implemented - Removing from list allows capture on next clipboard change
5. **AC5 - Ignore list persists across restarts**: Implemented - Stored in UserDefaults with key `com.clipai.ignoreList`
