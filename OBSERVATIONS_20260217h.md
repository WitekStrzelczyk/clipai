# Observations: Stories 5 & 6 - Global Shortcut and Paste

Date: 2026-02-17
Agent: reflective-coding-agent

## Problem Solved
Implemented global keyboard shortcut (Cmd+Shift+V) to toggle the overlay from any application, and added the ability to paste selected clips via Enter key or mouse click with automatic overlay dismissal.

---

## For Future Self

### How to Prevent This Problem
- [x] Always write tests first (RED) before implementation (GREEN)
- [x] Check existing tests for styleMask expectations when modifying NSPanel/window configuration
- [x] Use protocols for services to enable testability (PasteServiceProtocol, PasteboardProtocol)
- [x] Ensure callback closures use `[weak self]` to prevent retain cycles

### How to Find Solution Faster
- Key insight: Global hotkeys require Accessibility permissions which ClipAI already requests for BrowserURLExtractor
- Search that works: `NSEvent.addGlobalMonitorForEvents` for global hotkey implementation
- Start here: `Sources/ClipAI/UI/OverlayViewModel.swift` for understanding the selection/paste flow
- Debugging step: Use `simulateShortcutPress()` method for testing without actual keyboard events

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| `Grep "NSEvent"` | Found event monitoring patterns in documentation |
| Read `OverlayViewModel.swift` | Showed existing selection logic that needed paste integration |
| `swift test --filter X` | Allowed targeted testing during TDD cycles |
| Protocol-based design | Enabled mock injection for PasteService testing |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Initial test expectation about clip order | Test used wrong index assumption - clips sorted by timestamp descending |
| Reading unrelated test files | Distracted from the core task at hand |

---

## Agent Self-Reflection

### My Approach
1. Read existing codebase to understand architecture - worked well
2. Created task list to track progress - kept work organized
3. Wrote tests first (RED phase) - caught design issues early
4. Implemented services (GREEN phase) - clean, minimal code
5. Wired everything together - straightforward integration

### What Was Critical for Success
- **Key insight:** Using `NSEvent.addGlobalMonitorForEvents` for global hotkey capture
- **Right tool:** Protocol-based dependency injection for PasteService testability
- **Right question:** "How does the overlay dismiss after paste?" - led to onClipPasted callback

### What I Would Do Differently
- [x] Check test assertions more carefully (clip ordering test)
- [ ] Consider adding integration tests for keyboard shortcut + paste flow
- [ ] Document the Accessibility permission requirement in GlobalShortcutManager

### TDD Compliance
- [x] Wrote test first (Red) for GlobalShortcutManager
- [x] Wrote test first (Red) for PasteService
- [x] Wrote test first (Red) for OverlayViewModel paste methods
- [x] Minimal implementation (Green) for all services
- [x] Refactored while green (added protocol conformance)

---

## Code Changed
- `Sources/ClipAI/Services/GlobalShortcutManager.swift` - NEW: Global hotkey manager
- `Sources/ClipAI/Services/PasteService.swift` - NEW: Clipboard and paste simulation service
- `Sources/ClipAI/UI/OverlayViewModel.swift` - Added pasteService dependency and paste methods
- `Sources/ClipAI/UI/OverlayView.swift` - Added Enter key handler and click-to-paste
- `Sources/ClipAI/UI/OverlayWindowController.swift` - Added onClipPasted callback, fixed styleMask
- `Sources/ClipAI/ClipAIApp.swift` - Wired GlobalShortcutManager

## Tests Added
- `Tests/ClipAITests/Services/GlobalShortcutManagerTests.swift` - 13 tests for shortcut management
- `Tests/ClipAITests/Services/PasteServiceTests.swift` - 6 tests for paste operations
- `Tests/ClipAITests/UI/OverlayViewModelTests.swift` - 5 new tests for paste functionality

## Verification
```bash
swift test                    # 134 tests pass
./scripts/quality-check.sh --all  # All checks pass
swift build                   # Compiles without errors
```
