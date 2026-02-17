# Observations: Story 1 - Background Clipboard Monitoring Not Working

Date: 2026-02-17
Agent: reflective-coding-agent

## Problem Solved
Fixed clipboard monitoring not working by fixing actor isolation issues with Timer management and added comprehensive console logging for debugging visibility.

---

## For Future Self

### How to Prevent This Problem
- [ ] When using Timer inside an actor, use `nonisolated(unsafe)` for the timer variable to allow main thread access
- [ ] Always wrap Timer creation in `DispatchQueue.main.async` to ensure run loop attachment
- [ ] Add `print()` statements in addition to `os_log` during development - os_log doesn't always show in console
- [ ] When callbacks need to call async code, wrap in a `Task` block

Example: "Timer must be scheduled on the main run loop from the main thread, not from an actor context"

### How to Find Solution Faster
- Key insight: Timer in an actor doesn't automatically attach to the main run loop
- Search that works: `Timer.scheduledTimer actor` or `RunLoop.main actor isolation`
- Start here: Check where timer is created and ensure it's on `DispatchQueue.main`
- Debugging step: Add `print()` statements immediately - they always show in console

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| `swift build` | Showed actor isolation warnings that pointed to the timer issue |
| `swift test` | Confirmed functionality works after changes |
| `./scripts/quality-check.sh --all` | Verified code quality and strict concurrency |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Reading logs in Console.app | os_log doesn't always show info/debug messages by default |
| Assuming actor timer works | Timer needs main run loop, actor context is isolated |

---

## Agent Self-Reflection

### My Approach
1. Read the source files to understand the implementation - found logging existed but used os_log
2. Identified the timer was being created inside an actor without main thread dispatch
3. Fixed by using `nonisolated(unsafe)` and `DispatchQueue.main.async` for timer management
4. Added comprehensive `print()` logging alongside os_log for visibility

### What Was Critical for Success
- **Key insight:** Timer needs to be scheduled on the main run loop from the main thread
- **Right tool:** `nonisolated(unsafe)` to allow timer variable access from main thread
- **Right question:** "How does Timer work inside a Swift actor?"

### What I Would Do Differently
- [ ] Ask user earlier about console visibility preferences
- [ ] Check actor isolation patterns before assuming timer code works

### TDD Compliance
- [x] Ran existing tests to verify changes don't break functionality
- [x] All 39 tests pass
- [ ] Did not add new tests (existing tests cover the functionality)

---

## Code Changed
- `/Users/witek/projects/copies/clipai/Sources/ClipAI/ClipAIApp.swift` - Added logging helper functions and comprehensive logging throughout app lifecycle
- `/Users/witek/projects/copies/clipai/Sources/ClipAI/Services/ClipboardMonitor.swift` - Fixed timer management with `nonisolated(unsafe)`, added `DispatchQueue.main.async` for timer creation, added comprehensive logging
- `/Users/witek/projects/copies/clipai/Sources/ClipAI/Services/ClipStorage.swift` - Added comprehensive logging for storage operations

## Tests Added
- No new tests added - existing tests cover the functionality

## Verification
```bash
# Build and run the app
swift build

# Run tests
swift test

# Verify logging works
# When the app runs, you should see:
# [ClipAI] INFO: === ClipAI Starting Up ===
# [ClipAI] INFO: Storage directory: /Users/xxx/clipai/knowledge
# [ClipAI-Monitor] ClipboardMonitor initialized with initial changeCount: N
# [ClipAI-Monitor] Starting clipboard monitoring with interval: 0.5s
# [ClipAI-Monitor] Timer scheduled on main run loop
# [ClipAI] INFO: === ClipAI is now monitoring clipboard ===

# When you copy something:
# [ClipAI-Monitor] CHANGE DETECTED! Old count: N, New count: N+1
# [ClipAI-Monitor] Clip captured from pasteboard: UUID, type: text
# [ClipAI-Monitor] New unique clip - invoking callback
# [ClipAI] INFO: Callback received - new clip captured: UUID
# [ClipAI-Storage] save() called for clip: UUID
# [ClipAI-Storage] Checking if directory exists: /Users/xxx/clipai/knowledge
# [ClipAI-Storage] Successfully saved clip UUID to /Users/xxx/clipai/knowledge/...

# Check created files
ls ~/clipai/knowledge/
```

## Root Cause Analysis

### Issue 1: Timer Actor Isolation
The original code created a Timer inside an actor and tried to mutate the actor's `timer` property from within a `DispatchQueue.main.async` closure. This caused:
1. Actor isolation warning (mutating actor property from main actor)
2. Timer not properly stored in the actor

**Fix:** Use `nonisolated(unsafe) var timer: Timer?` to allow access from both the actor and main thread.

### Issue 2: Logging Visibility
The original code used `os_log` (Logger) which:
1. Only shows in Console.app with proper configuration
2. Doesn't appear in terminal output when running from Xcode or command line

**Fix:** Added `print()` statements with `[ClipAI]` prefix for immediate console visibility.
