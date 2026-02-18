# ClipAI - User Stories

> A macOS clipboard manager with Raycast-style UI and JSON-based storage.

---

## Use Cases

### Use Case 1: Capture and Retrieve Clipboard History

**Actor:** Knowledge worker who frequently copies content between applications
**Goal:** Quickly access previously copied content without re-finding source material
**Preconditions:**
- ClipAI is running in the background
- User has copied content to clipboard at least once

**Flow:**
1. User invokes ClipAI overlay via keyboard shortcut or menu bar click
2. System displays overlay with list of recent clips (sorted by date, newest first)
3. User browses or searches through clip history
4. User selects desired clip
5. System copies selected clip to system clipboard
6. System simulates Cmd+V to paste into active application
7. Overlay dismisses automatically

**Alternative Flows:**
- 3a. User hovers over clip to see full details in right panel
- 3b. User types search query to filter clips
- 4a. User drags clip to target application instead of selecting

---

### Use Case 2: Manage Persistent Snippets

**Actor:** Support agent or developer who reuses text templates frequently
**Goal:** Store and quickly insert frequently-used text blocks
**Preconditions:**
- ClipAI is running
- User has created at least one snippet folder

**Flow:**
1. User copies text they want to save as snippet
2. User invokes ClipAI overlay
3. User selects "Save as Snippet" action
4. User provides name and selects destination folder
5. System saves snippet to persistent storage
6. Later, user invokes ClipAI and navigates to Snippets section
7. User selects snippet from folder
8. System pastes snippet content

**Alternative Flows:**
- 6a. User searches snippets by name or content
- 7a. User uses keyboard shortcut for direct snippet access

---

### Use Case 3: Protect Sensitive Content

**Actor:** Security-conscious user who works with password managers and sensitive data
**Goal:** Prevent clipboard history from capturing sensitive information
**Preconditions:**
- ClipAI is running
- User has identified apps that handle sensitive data

**Flow:**
1. User opens ClipAI preferences
2. User navigates to Privacy settings
3. User adds apps to ignore list (e.g., 1Password, Bitwarden)
4. System stops monitoring clipboard when ignored apps are active
5. User copies password from ignored app
6. ClipAI does not capture the clipboard content
7. User verifies sensitive content is not in history

---

### Use Case 4: Configure and Customize ClipAI

**Actor:** Power user who wants to optimize ClipAI for their workflow
**Goal:** Customize keyboard shortcuts, appearance, and behavior
**Preconditions:**
- ClipAI is installed and running

**Flow:**
1. User clicks menu bar icon and selects Preferences
2. User configures global keyboard shortcut
3. User sets history limit (number of items to retain)
4. User enables/disables auto-launch at login
5. User adjusts appearance settings (overlay size, theme)
6. System saves all preferences
7. Changes take effect immediately

---

### Use Case 5: Search and Filter Clipboard History

**Actor:** Researcher who needs to find specific previously-copied content
**Goal:** Quickly locate a specific clip among many historical items
**Preconditions:**
- ClipAI is running
- User has accumulated clipboard history

**Flow:**
1. User invokes ClipAI overlay
2. User begins typing in search field
3. System filters clips in real-time based on query
4. System highlights matching text in results
5. User sees matching clips in left panel
6. User hovers to preview full content in right panel
7. User selects desired clip
8. System copies and pastes content

---

## User Stories

### [x] Story 1: Background Clipboard Monitoring

**As a** knowledge worker who switches between applications frequently
**I want** ClipAI to automatically capture everything I copy to the clipboard
**So that** I never lose important content I've copied

#### Use Case Context
Part of: "Capture and Retrieve Clipboard History" use case
- This is the foundation story - must be implemented first
- Enables all other clipboard-related features

#### Verification Strategy
Verify that clipboard content is captured correctly by checking:
1. JSON files are created in `~/clipai/knowledge`
2. All required metadata is captured
3. Both text and images are handled
4. No duplicate captures for same content

#### Test Cases (Acceptance Criteria)
- **Given** ClipAI is running in the background, **When** I copy text "Hello World" in any application, **Then** a JSON entry is created in `~/clipai/knowledge.json` containing the text "Hello World"
- **Given** ClipAI is running, **When** I copy an image (e.g., screenshot), **Then** a JSON entry is created with the image data encoded (base64) and content_type set to "image"
- **Given** I copy text from Safari, **When** the clip is captured, **Then** the JSON includes `source_app: "Safari"` and `source_url` if available
- **Given** I copy the same text from the same app after more than 5 seconds, **When** the second copy occurs, **Then** no new entry is created; instead, the existing clip's timestamp is updated to now (unique key upsert)
- **Given** I copy text, **When** the clip is captured, **Then** the JSON includes `timestamp`, `content_type`, `content`, `source_app`, and `source_url` (null if not available)
- **Given** I copy text from a browser with accessibility permissions granted, **When** no URL is in the pasteboard, **Then** ClipAI extracts the URL from the browser's address bar

#### Implementation Notes
- Use NSPasteboard.changeCount to detect clipboard changes
- Poll interval should be configurable (default 500ms)
- Store images as base64 encoded in the JSON file
- Source app can be obtained via NSWorkspace.frontmostApplication
- URL extraction works for browsers via NSPasteboard.urlTypes
- **Unique Key Upsert**: Use `source_app` + `content` as a natural key. If a clip with the same key exists, update only the timestamp instead of creating a duplicate.
- **Browser URL Extraction**: Use Accessibility API to extract URLs from browser address bars (requires accessibility permissions). See `BrowserURLExtractor` class.

---

### [x] Story 2: Menu Bar Icon and Basic Overlay

**As a** user who wants quick access to clipboard history
**I want** a menu bar icon that opens a Raycast-style overlay when clicked
**So that** I can access my clipboard history without navigating menus

#### Use Case Context
Part of: "Capture and Retrieve Clipboard History" use case
- Depends on: Story 1 (Background Clipboard Monitoring)
- Enables: All UI-based interactions

#### Verification Strategy
Verify the UI components appear correctly:
1. Menu bar icon is visible and clickable
2. Overlay appears centered on screen
3. Overlay is draggable
4. Basic layout matches specifications

#### Test Cases (Acceptance Criteria)
- **Given** ClipAI is running, **When** I look at the menu bar, **Then** I see the ClipAI icon (status item)
- **Given** the ClipAI menu bar icon is visible, **When** I click it, **Then** an overlay appears centered on the screen
- **Given** the overlay is visible, **When** I drag the overlay header, **Then** the overlay moves to the new position
- **Given** the overlay is visible, **When** I press Escape or click outside, **Then** the overlay dismisses
- **Given** the overlay is visible, **When** I reopen it, **Then** it appears at the last dragged position (position persistence)

#### Implementation Notes
- Use NSStatusItem for menu bar icon
- Use NSPanel or NSWindow with .floating level for overlay
- Window should be non-activating (allows app to stay in background)
- Implement drag via NSWindow.movableByWindowBackground
- Store window position in UserDefaults

---

### [x] Story 3: Display Clipboard History List

**As a** user who has accumulated clipboard history
**I want** to see a list of my recent clips sorted by date
**So that** I can browse and select content to paste

#### Use Case Context
Part of: "Capture and Retrieve Clipboard History" use case
- Depends on: Story 1 (Background Monitoring), Story 2 (Overlay UI)
- Enables: Story 4 (Clip Selection), Story 5 (Search)

#### Verification Strategy
Verify clips are displayed correctly from stored JSON files:
1. List loads from `~/clipai/knowledge` directory
2. Items are sorted correctly by timestamp
3. Text and images display appropriately
4. Performance is acceptable with many items

#### Test Cases (Acceptance Criteria)
- **Given** I have 10 clips in `~/clipai/knowledge`, **When** I open the ClipAI overlay, **Then** I see all 10 clips listed in the left panel
- **Given** clips exist with different timestamps, **When** the list loads, **Then** clips are sorted by timestamp descending (newest first)
- **Given** a text clip exists, **When** displayed in the list, **Then** I see a truncated preview (first 50 chars) and the source app name
- **Given** an image clip exists, **When** displayed in the list, **Then** I see a thumbnail preview (not full image)
- **Given** 100 clips exist, **When** I open the overlay, **Then** the list loads within 500ms
- **Given** no clips exist, **When** I open the overlay, **Then** I see an empty state message "No clips yet. Copy something to get started."

#### Implementation Notes
- Use SwiftUI List or NSTableView for the list
- Implement lazy loading for performance
- Cache loaded clips in memory
- Thumbnail size: 32x32 points
- Consider pagination for large histories

---

### [x] Story 4: View Clip Details in Right Panel

**As a** user browsing clipboard history
**I want** to see full details of a clip when I hover over it
**So that** I can verify it's the correct content before pasting

#### Use Case Context
Part of: "Capture and Retrieve Clipboard History" use case
- Depends on: Story 3 (Display History List)
- Works with: Story 6 (Select and Paste)

#### Verification Strategy
Verify details panel shows complete information:
1. Hover triggers details display
2. All metadata is shown
3. Full content is visible
4. Images display at appropriate size

#### Test Cases (Acceptance Criteria)
- **Given** the overlay is open with clips listed, **When** I hover over a clip, **Then** the right panel shows full details for that clip
- **Given** I hover over a text clip, **When** details appear, **Then** I see full text content (scrollable if long), source app, timestamp, and source URL if available
- **Given** I hover over an image clip, **When** details appear, **Then** I see the full image preview (max 300x300 points)
- **Given** I move hover to another clip, **When** hover changes, **Then** details update to show the new clip's information
- **Given** I move hover away from all clips, **When** no clip is hovered for 2 seconds, **Then** the right panel shows a placeholder or last selected clip

#### Implementation Notes
- Use hover state tracking with slight delay (100-200ms)
- Right panel should be scrollable for long content
- Image preview should maintain aspect ratio
- Show metadata badges for source app, URL, content type

---

### [x] Story 5: Global Keyboard Shortcut

**As a** power user who values speed
**I want** to invoke ClipAI with a global keyboard shortcut
**So that** I can access clipboard history without taking my hands off the keyboard

#### Use Case Context
Part of: "Access & Interface" features
- Independent of other stories (can be developed in parallel)
- Default shortcut: Cmd+Shift+V

#### Verification Strategy
Verify keyboard shortcut works globally:
1. Shortcut works from any application
2. Shortcut toggles overlay (open/close)
3. Shortcut is customizable
4. No conflicts with system shortcuts

#### Test Cases (Acceptance Criteria)
- **Given** ClipAI is running, **When** I press Cmd+Shift+V from any application, **Then** the ClipAI overlay appears
- **Given** the overlay is visible, **When** I press Cmd+Shift+V again, **Then** the overlay dismisses
- **Given** I am in Safari and press Cmd+Shift+V, **When** the overlay appears, **Then** Safari remains the active application (ClipAI doesn't steal focus)
- **Given** another app is using Cmd+Shift+V, **When** ClipAI starts, **Then** I am notified of the conflict
- **Given** the shortcut is changed in preferences, **When** I press the new shortcut, **Then** the overlay toggles correctly

#### Implementation Notes
- Use NSEvent.addGlobalMonitorForEvents for global hotkey
- Need Accessibility permissions for global monitoring
- Store shortcut in UserDefaults as String (keyboard shortcut representation)
- Consider using MASShortcut or KeyboardShortcuts library
- Validate shortcut against system reserved shortcuts

---

### [x] Story 6: Select and Paste Clip

**As a** user who found the content I need
**I want** to click a clip and have it automatically pasted
**So that** I can insert content into my current work with a single action

#### Use Case Context
Part of: "Capture and Retrieve Clipboard History" use case
- Depends on: Story 3 (Display History List)
- Critical path for user workflow

#### Verification Strategy
Verify paste functionality works correctly:
1. Click copies to system clipboard
2. Paste is simulated in target app
3. Overlay dismisses after paste
4. Works across different applications

#### Test Cases (Acceptance Criteria)
- **Given** the overlay is open and I'm in TextEdit, **When** I click a text clip, **Then** the text appears in TextEdit at cursor position
- **Given** the overlay is open and I'm in a web form, **When** I click a text clip, **Then** the text is pasted into the form field
- **Given** I click a clip, **When** the paste completes, **Then** the overlay dismisses automatically
- **Given** I click a clip, **When** checking system clipboard, **Then** the clip content is now in the clipboard
- **Given** I click an image clip in a text editor, **When** paste is simulated, **Then** the image appears in the document (if supported by target app)
- **Given** the target app cannot receive paste, **When** I click a clip, **Then** content is copied to clipboard but no error is shown

#### Implementation Notes
- Use NSPasteboard to set clipboard content
- Use CGEvent to simulate Cmd+V keystroke
- Small delay (50-100ms) between clipboard set and paste simulation
- Handle paste failure gracefully
- Consider keyboard navigation (Enter to select)

---

### [x] Story 7: Search Clipboard History

**As a** user with extensive clipboard history
**I want** to search through my clips by content
**So that** I can quickly find specific content without scrolling

#### Use Case Context
Part of: "Search and Filter Clipboard History" use case
- Depends on: Story 3 (Display History List)
- Enhances core functionality

#### Verification Strategy
Verify search works correctly and performantly:
1. Real-time filtering as user types
2. Matches text content
3. Results sort by relevance
4. Search is case-insensitive

#### Test Cases (Acceptance Criteria)
- **Given** the overlay is open with clips, **When** I type "hello" in the search field, **Then** only clips containing "hello" are shown
- **Given** a search query is active, **When** matching text is displayed, **Then** the matching text is highlighted
- **Given** I type "HELLO" (uppercase), **When** searching, **Then** clips with "hello" (lowercase) are also found (case-insensitive)
- **Given** I have 100 clips, **When** I type a search query, **Then** results appear within 200ms
- **Given** search has no matches, **When** results display, **Then** I see "No clips match your search"
- **Given** the search field is empty, **When** search is cleared, **Then** all clips are displayed again (sorted by date)

#### Implementation Notes
- Implement debouncing (150-300ms delay) for performance
- Use simple string contains for MVP
- Consider fuzzy matching for future enhancement
- Highlight matches with background color
- Store search index in memory for performance

---

### [ ] Story 8: Application Ignore List (Privacy)

**As a** security-conscious user
**I want** to prevent ClipAI from capturing clips from specific applications
**So that** sensitive data like passwords is never stored

#### Use Case Context
Part of: "Protect Sensitive Content" use case
- Depends on: Story 1 (Background Monitoring)
- Privacy-critical feature

#### Verification Strategy
Verify ignored apps don't contribute to clipboard history:
1. Apps in ignore list are not monitored
2. Existing clips from ignored apps are handled appropriately
3. Ignore list persists across restarts

#### Test Cases (Acceptance Criteria)
- **Given** "1Password" is in the ignore list, **When** I copy text from 1Password, **Then** no clip is added to history
- **Given** the ignore list is empty, **When** I add "Bitwarden" to the list, **Then** clips from Bitwarden stop being captured immediately
- **Given** an app is in the ignore list, **When** I view the ignore list, **Then** I see the app name and icon
- **Given** I remove an app from the ignore list, **When** I copy from that app, **Then** clips are captured again
- **Given** ClipAI restarts, **When** it loads, **Then** the ignore list is preserved from previous session

#### Implementation Notes
- Store ignore list as array of bundle identifiers in UserDefaults
- Check frontmost application bundle ID before capturing
- Provide UI to add/remove apps from list
- Suggest common password managers as defaults
- Consider adding option to clear existing clips from ignored apps

---

### [ ] Story 9: Clear Clipboard History

**As a** user concerned about privacy or clutter
**I want** to clear my clipboard history
**So that** old or sensitive clips are removed from storage

#### Use Case Context
Part of: "Protect Sensitive Content" use case
- Independent feature
- Privacy and storage management

#### Verification Strategy
Verify history is completely cleared:
1. All JSON files are deleted
2. UI reflects empty state
3. Action is reversible (with confirmation)

#### Test Cases (Acceptance Criteria)
- **Given** I have clips in history, **When** I select "Clear History" from menu, **Then** a confirmation dialog appears
- **Given** the confirmation dialog is shown, **When** I confirm, **Then** all JSON files in `~/clipai/knowledge` are deleted
- **Given** history is cleared, **When** I open the overlay, **Then** the empty state message is shown
- **Given** the confirmation dialog is shown, **When** I cancel, **Then** history is preserved (no changes)
- **Given** I clear history, **When** I check the directory, **Then** `~/clipai/knowledge` folder still exists but is empty

#### Implementation Notes
- Add "Clear History" option in menu bar dropdown
- Show confirmation: "Clear all clipboard history? This cannot be undone."
- Use FileManager to delete contents of knowledge directory
- Keep the directory itself (don't delete `~/clipai/knowledge`)
- Log the clear action for debugging

---

### [ ] Story 10: Save and Manage Snippets

**As a** support agent who reuses common responses
**I want** to save frequently-used text as permanent snippets
**So that** I can quickly insert them without searching history

#### Use Case Context
Part of: "Manage Persistent Snippets" use case
- Independent feature
- User retention feature

#### Verification Strategy
Verify snippets are saved and accessible:
1. Snippets persist across app restarts
2. Snippets are separate from history
3. Snippets can be organized in folders

#### Test Cases (Acceptance Criteria)
- **Given** I have text in clipboard, **When** I select "Save as Snippet", **Then** a dialog appears to name the snippet
- **Given** the save dialog is open, **When** I enter name "Greeting" and click Save, **Then** snippet is saved with that name
- **Given** a snippet exists, **When** I open the overlay and navigate to Snippets, **Then** I see the snippet in the list
- **Given** a snippet named "Greeting" exists, **When** I search snippets for "greet", **Then** the snippet appears in results
- **Given** snippets exist, **When** I create a folder "Email Templates", **Then** I can move snippets into that folder
- **Given** a snippet exists, **When** I delete it, **Then** it is removed from the snippet list

#### Implementation Notes
- Store snippets in separate JSON file: `~/clipai/snippets.json`
- Structure: `{ folders: [{ name, snippets: [{ name, content, created }] }] }`
- Add dedicated Snippets tab/section in overlay
- Support default folder "Uncategorized"
- Consider drag-and-drop for folder organization

---

### [ ] Story 11: Configure History Limit

**As a** user with limited disk space
**I want** to set a maximum number of clips to retain
**So that** my clipboard history doesn't grow indefinitely

#### Use Case Context
Part of: "Configure and Customize ClipAI" use case
- Depends on: Story 1 (Background Monitoring)
- Storage management feature

#### Verification Strategy
Verify history limit is enforced:
1. Limit is configurable
2. Oldest clips are removed when limit reached
3. Setting persists across restarts

#### Test Cases (Acceptance Criteria)
- **Given** history limit is set to 50, **When** I copy the 51st item, **Then** the oldest clip is deleted
- **Given** preferences are open, **When** I change history limit to 100, **Then** future clips respect the new limit
- **Given** I have 200 clips and change limit to 50, **When** the setting saves, **Then** oldest 150 clips are removed
- **Given** ClipAI restarts, **When** it loads, **Then** the history limit setting is preserved
- **Given** history limit is set, **When** I view preferences, **Then** I see the current limit value

#### Implementation Notes
- Store limit in UserDefaults (key: "historyLimit")
- Default limit: 100 items
- Clean up on app launch and on setting change
- Consider adding option for "Unlimited" with storage warning
- Implement FIFO (first in, first out) deletion

---

### [ ] Story 12: Auto-Launch at Login

**As a** user who wants ClipAI always available
**I want** ClipAI to start automatically when I log in
**So that** I don't have to manually launch it every day

#### Use Case Context
Part of: "Configure and Customize ClipAI" use case
- Independent feature
- Quality of life improvement

#### Verification Strategy
Verify auto-launch behavior:
1. Setting enables/disables login item
2. Changes take effect immediately
3. Works across macOS versions

#### Test Cases (Acceptance Criteria)
- **Given** ClipAI preferences are open, **When** I enable "Launch at Login", **Then** ClipAI appears in System Preferences > Login Items
- **Given** "Launch at Login" is enabled, **When** I restart my Mac, **Then** ClipAI starts automatically after login
- **Given** "Launch at Login" is enabled, **When** I disable the setting, **Then** ClipAI is removed from Login Items
- **Given** "Launch at Login" is disabled, **When** I restart my Mac, **Then** ClipAI does not start automatically
- **Given** I enable the setting, **When** I check preferences later, **Then** the setting shows as enabled

#### Implementation Notes
- Use SMAppService (macOS 13+) or LSSharedFileList (older macOS)
- Provide toggle in Preferences > General
- Handle permission issues gracefully
- Show current status in preferences
- Consider showing notification on first launch about this feature

---

### [x] Story 13: Keyboard Navigation in Overlay

**As a** keyboard-focused power user
**I want** to navigate and select clips using only the keyboard
**So that** I can work faster without reaching for the mouse

#### Use Case Context
Part of: "Access & Interface" features
- Depends on: Story 3 (Display History List), Story 5 (Global Shortcut)
- Accessibility and efficiency feature

#### Verification Strategy
Verify keyboard-only workflow:
1. Arrow keys navigate list
2. Enter selects and pastes
3. Tab moves between sections
4. Escape dismisses overlay

#### Test Cases (Acceptance Criteria)
- **Given** the overlay is open with clips, **When** I press Down Arrow, **Then** the selection moves to the next clip
- **Given** a clip is selected, **When** I press Up Arrow, **Then** the selection moves to the previous clip
- **Given** a clip is selected, **When** I press Enter, **Then** the clip is copied and pasted to the active app
- **Given** the overlay is open, **When** I press Escape, **Then** the overlay dismisses without pasting
- **Given** the search field is focused, **When** I press Tab, **Then** focus moves to the clip list
- **Given** focus is in the clip list, **When** I press Tab to search field, **Then** focus moves to search field
- **Given** the overlay opens, **When** no search query exists, **Then** focus is in the search field by default

#### Implementation Notes
- Use SwiftUI focus management or NSResponder chain
- Implement arrow key handling in list view
- Track selected index state
- Show visual indication of keyboard selection (different from hover)
- Consider vim-style navigation (j/k) as future enhancement

---

### [ ] Story 14: Drag and Drop Clips

**As a** user working with multiple applications
**I want** to drag clips from ClipAI directly into other apps
**So that** I have more control over where content is placed

#### Use Case Context
Part of: "Capture and Retrieve Clipboard History" use case
- Depends on: Story 3 (Display History List)
- Alternative to click-to-paste

#### Verification Strategy
Verify drag and drop works across applications:
1. Drags initiate from clip items
2. Drop works in common applications
3. Both text and images can be dragged

#### Test Cases (Acceptance Criteria)
- **Given** the overlay is open with a text clip, **When** I drag the clip to TextEdit and drop, **Then** the text appears at the drop location
- **Given** the overlay is open with an image clip, **When** I drag to a document, **Then** the image appears at drop location
- **Given** I start dragging a clip, **When** I drag over a valid drop target, **Then** the target app shows drop feedback
- **Given** I start dragging, **When** I press Escape during drag, **Then** the drag is cancelled
- **Given** I drag a clip, **When** I drop outside any application, **Then** nothing happens (no error)

#### Implementation Notes
- Use NSDraggingSource protocol
- Provide multiple pasteboard types (string, file URL for images)
- Set appropriate drag image (thumbnail for images, text preview for text)
- Handle drag session events
- Consider showing overlay during drag (or dismissing it)

---

### [ ] Story 15: Preferences Window

**As a** user who wants to customize ClipAI
**I want** a dedicated preferences window with all settings
**So that** I can configure ClipAI to match my workflow

#### Use Case Context
Part of: "Configure and Customize ClipAI" use case
- Independent feature
- Aggregates settings from other stories

#### Verification Strategy
Verify all preferences are accessible and functional:
1. All settings are in one place
2. Changes save automatically
3. Settings apply immediately

#### Test Cases (Acceptance Criteria)
- **Given** ClipAI is running, **When** I click the menu bar icon and select "Preferences", **Then** a preferences window opens
- **Given** the preferences window is open, **When** I view it, **Then** I see tabs/sections for General, Shortcuts, Privacy, and Appearance
- **Given** General tab is selected, **When** I view it, **Then** I see options for: Launch at Login, History Limit
- **Given** Shortcuts tab is selected, **When** I view it, **Then** I see the global shortcut configuration
- **Given** Privacy tab is selected, **When** I view it, **Then** I see the ignore list and clear history option
- **Given** I change any setting, **When** I close preferences, **Then** the setting is saved (no explicit save button needed)

#### Implementation Notes
- Use SwiftUI Settings scene (macOS 13+) or NSWindow with tabs
- Follow macOS preferences window conventions
- Implement tabs: General, Shortcuts, Privacy, Appearance
- Use standard macOS controls (toggles, sliders, text fields)
- Settings should save on change (no save button)

---

## Story Prioritization

### Phase 1: MVP (Minimum Viable Product)
Core functionality needed for basic clipboard management:

| Story | Priority | Dependencies |
|-------|----------|--------------|
| Story 1: Background Clipboard Monitoring | HIGH | None |
| Story 2: Menu Bar Icon and Basic Overlay | HIGH | None |
| Story 3: Display Clipboard History List | HIGH | Story 1, Story 2 |
| Story 5: Global Keyboard Shortcut | HIGH | None |
| Story 6: Select and Paste Clip | HIGH | Story 3 |

### Phase 2: Essential Features
Features that significantly improve the experience:

| Story | Priority | Dependencies |
|-------|----------|--------------|
| Story 7: Search Clipboard History | MEDIUM | Story 3 |
| Story 8: Application Ignore List | MEDIUM | Story 1 |
| Story 13: Keyboard Navigation | MEDIUM | Story 3, Story 5 |

### Phase 3: Polish and Power Features
Features for power users and customization:

| Story | Priority | Dependencies |
|-------|----------|--------------|
| Story 4: View Clip Details | LOW | Story 3 |
| Story 9: Clear Clipboard History | LOW | None |
| Story 10: Save and Manage Snippets | LOW | None |
| Story 11: Configure History Limit | LOW | Story 1 |
| Story 12: Auto-Launch at Login | LOW | None |
| Story 14: Drag and Drop Clips | LOW | Story 3 |
| Story 15: Preferences Window | LOW | Multiple |

---

## Technical Notes

### Data Storage Schema

All clips are stored in a single `knowledge.json` file:

```json
{
  "clips": [
    {
      "id": "uuid-v4",
      "content": "base64-encoded-content-or-plain-text",
      "content_type": "text|image",
      "source_app": "Safari",
      "source_url": "https://example.com/page",
      "timestamp": "2026-02-17T10:30:00Z",
      "metadata": {
        "text_length": 150,
        "image_width": 800,
        "image_height": 600
      }
    }
  ]
}
```

### Unique Key (Upsert) Behavior

Clips are deduplicated using a **unique key** composed of `source_app` + `content`:
- If a clip with the same key exists, only the `timestamp` is updated (no new entry)
- This prevents duplicate entries for frequently-copied content
- The timestamp update keeps frequently-used clips fresh in the history

### File Locations
- Clips: `~/clipai/knowledge.json` (single file containing all clips)
- Snippets: `~/clipai/snippets.json`
- Preferences: `~/Library/Preferences/com.clipai.app.plist`
- Debug Log: `~/.clipai/clipai.log`

### Performance Targets
- Overlay open time: < 200ms
- Search response time: < 100ms
- Memory usage: < 50MB for 1000 clips
- Clipboard capture delay: < 500ms after copy

---

## Checklist Legend

- `[ ]` - Available for development (ready to be picked up)
- `[o]` - Taken (being actively worked on)
- `[x]` - Done (completed and verified)
