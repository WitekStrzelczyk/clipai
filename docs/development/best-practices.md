# ClipAI Best Practices Reference

---
last_reviewed: 2026-02-17
review_cycle: quarterly
status: current
---

> This document is MANDATORY reading for any coding agent working on ClipAI.
> Follow these practices to ensure code quality, maintainability, and correctness.

## Quick Reference

| Topic | Key Rule |
|-------|----------|
| Concurrency | Use `async/await` with strict concurrency; all shared mutable state in actors |
| SwiftUI | Small views, `@StateObject` for ownership, prefer `LazyVStack` |
| Architecture | MVVM with clear separation; ViewModels are `@MainActor` |
| Testing | TDD workflow; one assert per test; all tests must pass |
| Memory | Use `[weak self]` in closures; avoid retain cycles |
| Quality | Run `./scripts/quality-check.sh --all` before marking done |

---

## 1. Swift Best Practices

### 1.1 Modern Concurrency (Swift 6+)

ClipAI requires strict concurrency compliance. The build uses `-strict-concurrency=complete`.

#### Async/Await Patterns

```swift
// GOOD: Clear async flow
func fetchClips() async throws -> [Clip] {
    let data = try await fileManager.contents(atPath: path)
    return try JSONDecoder().decode([Clip].self, from: data)
}

// BAD: Nested completion handlers
func fetchClips(completion: @escaping (Result<[Clip], Error>) -> Void) {
    // Avoid callback hell
}
```

#### Actor Isolation

Use actors for shared mutable state:

```swift
// GOOD: Actor protects mutable state
actor ClipboardStore {
    private var clips: [Clip] = []

    func add(_ clip: Clip) {
        clips.append(clip)
    }

    func getAll() -> [Clip] {
        clips
    }
}

// BAD: Class without isolation
class ClipboardStore {
    var clips: [Clip] = []  // Data race potential!
}
```

#### Sendable Conformance

All data crossing actor boundaries must be `Sendable`:

```swift
// GOOD: Sendable value type
struct Clip: Sendable, Codable {
    let id: UUID
    let content: String
    let timestamp: Date
}

// GOOD: Sendable with immutable properties
final class ClipService: Sendable {
    let storagePath: URL  // immutable, Sendable

    nonisolated func fetch() async -> [Clip] { ... }
}
```

#### MainActor Usage

UI updates must happen on main actor:

```swift
// GOOD: ViewModel isolated to MainActor
@MainActor
@Observable
final class ClipboardViewModel {
    var clips: [Clip] = []

    func loadClips() async {
        clips = await clipStore.getAll()
    }
}

// BAD: Updating UI from background
class ViewModel {
    func loadClips() {
        Task.detached {
            self.clips = await store.getAll()  // Wrong isolation!
        }
    }
}
```

### 1.2 Error Handling

Use typed throws for expected errors, generic for unexpected:

```swift
// GOOD: Domain-specific error types
enum ClipboardError: LocalizedError {
    case permissionDenied
    case storageCorrupted
    case clipNotFound(id: UUID)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Clipboard access permission denied"
        case .storageCorrupted:
            return "Clipboard storage is corrupted"
        case .clipNotFound(let id):
            return "Clip with ID \(id) not found"
        }
    }
}

// Usage
func loadClip(id: UUID) async throws(ClipboardError) -> Clip {
    guard let clip = store.find(id: id) else {
        throw .clipNotFound(id: id)
    }
    return clip
}
```

### 1.3 Memory Management

#### Avoid Retain Cycles

```swift
// GOOD: Weak self in closures
class ClipboardMonitor {
    var onChange: (() -> Void)?

    func startMonitoring() {
        NotificationCenter.default.addObserver(
            forName: .NSPasteboardChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleChange(notification)
        }
    }
}

// BAD: Strong reference cycle
class ClipboardMonitor {
    func startMonitoring() {
        handler = { self.handleChange() }  // Retains self
    }
}
```

#### Use value types when possible

```swift
// GOOD: Value type - no reference semantics
struct Clip: Identifiable, Sendable {
    let id: UUID
    var content: String
}

// Prefer value types for data models
// Use classes only when identity matters or for actors
```

### 1.4 Code Organization

#### File Structure

```swift
// 1. MARK: - Imports
import Foundation
import SwiftUI

// 2. MARK: - Type Definition
/// A clipboard item captured by ClipAI.
struct Clip: Identifiable, Sendable, Codable {
    // 3. MARK: - Properties
    let id: UUID
    let content: String
    let timestamp: Date

    // 4. MARK: - Computed Properties
    var preview: String {
        String(content.prefix(50))
    }

    // 5. MARK: - Initialization
    init(content: String) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
    }

    // 6. MARK: - Methods
    func matches(query: String) -> Bool {
        content.localizedCaseInsensitiveContains(query)
    }
}

// 7. MARK: - Extensions
extension Clip: Equatable {
    static func == (lhs: Clip, rhs: Clip) -> Bool {
        lhs.id == rhs.id
    }
}
```

#### Access Control

Default to `private`, escalate only as needed:

```swift
// GOOD: Minimal visibility
struct ClipStore {
    private let fileManager = FileManager.default
    private var clips: [Clip] = []

    func getAll() -> [Clip] { clips }  // Public API

    private func loadFromDisk() throws { ... }
}

// BAD: Everything public
struct ClipStore {
    var clips: [Clip] = []  // Unnecessarily exposed
}
```

---

## 2. SwiftUI Best Practices for macOS

### 2.1 View Composition

Keep views small and focused:

```swift
// GOOD: Small, focused views
struct ClipListView: View {
    let clips: [Clip]
    let onSelect: (Clip) -> Void

    var body: some View {
        List(clips) { clip in
            ClipRowView(clip: clip)
                .onTapGesture { onSelect(clip) }
        }
    }
}

struct ClipRowView: View {
    let clip: Clip

    var body: some View {
        HStack {
            ClipThumbnailView(content: clip.content)
            VStack(alignment: .leading) {
                Text(clip.preview)
                Text(clip.timestamp.formatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// BAD: Monolithic view
struct ClipListView: View {
    var body: some View {
        List {
            ForEach(clips) { clip in
                HStack {
                    // 50+ lines of inline code...
                }
            }
        }
    }
}
```

### 2.2 Property Wrappers

Use the correct wrapper for each scenario:

| Wrapper | Use Case | Ownership |
|---------|----------|-----------|
| `@State` | Local view state | View owns |
| `@Binding` | Pass state to child | Parent owns |
| `@StateObject` | Create Observable in view | View owns |
| `@ObservedObject` | Receive Observable from parent | Parent owns |
| `@EnvironmentObject` | Shared across view hierarchy | App owns |
| `@Environment` | System values, custom keys | System owns |

```swift
// GOOD: Correct ownership
struct OverlayView: View {
    @StateObject private var viewModel = OverlayViewModel()  // View owns
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ClipListView(clips: viewModel.clips)
    }
}

struct ClipListView: View {
    @ObservedObject var viewModel: ClipListViewModel  // Parent owns

    var body: some View { ... }
}
```

### 2.3 Performance Optimization

#### Lazy Loading

```swift
// GOOD: Lazy for large lists
ScrollView {
    LazyVStack(spacing: 8) {
        ForEach(clips) { clip in
            ClipRowView(clip: clip)
        }
    }
}

// BAD: Eager loading of large data
VStack {
    ForEach(1000 clips) { ... }  // All created immediately
}
```

#### Equatable Views

```swift
// GOOD: Prevent unnecessary redraws
struct ClipRowView: View, Equatable {
    let clip: Clip

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.clip.id == rhs.clip.id
    }

    var body: some View { ... }
}

// Use in List
List(clips) { clip in
    ClipRowView(clip: clip)
        .equatable()
}
```

### 2.4 macOS-Specific Patterns

#### Menu Bar App

```swift
// Menu bar status item setup
@main
struct ClipAIApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        // No main window for menu bar app
        Settings {
            PreferencesView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(named: "MenuBarIcon")
        statusItem?.menu = createMenu()
    }

    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open ClipAI", action: #selector(openOverlay), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        return menu
    }
}
```

#### Panel/Floating Window

```swift
// Non-activating floating panel
class OverlayPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .transient]
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
    }

    // Allow panel to stay visible when app is in background
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
```

### 2.5 Dark Mode Support

Use semantic colors:

```swift
// GOOD: Semantic colors adapt to mode
struct ClipRowView: View {
    var body: some View {
        HStack {
            Text(clip.preview)
                .foregroundStyle(.primary)  // Adapts to dark/light

            Text(clip.sourceApp)
                .foregroundStyle(.secondary)  // Dimmer in both modes
        }
        .background(Color(nsColor: .controlBackgroundColor))  // System background
    }
}

// BAD: Fixed colors
Text(clip.preview)
    .foregroundStyle(.black)  // Invisible in dark mode!
```

---

## 3. Architecture Patterns

### 3.1 MVVM for ClipAI

```
View (SwiftUI)
    |
    v
ViewModel (@MainActor, @Observable)
    |
    v
Service/Store (Actor)
    |
    v
Storage (FileManager, JSON)
```

#### ViewModel Pattern

```swift
@MainActor
@Observable
final class ClipboardViewModel {
    // State
    private(set) var clips: [Clip] = []
    var searchText: String = ""
    var isLoading: Bool = false

    // Dependencies
    private let store: ClipboardStore

    // Computed
    var filteredClips: [Clip] {
        if searchText.isEmpty {
            clips
        } else {
            clips.filter { $0.matches(query: searchText) }
        }
    }

    init(store: ClipboardStore) {
        self.store = store
    }

    // Actions
    func loadClips() async {
        isLoading = true
        clips = await store.getAll()
        isLoading = false
    }

    func deleteClip(_ clip: Clip) async {
        await store.remove(clip.id)
        clips.removeAll { $0.id == clip.id }
    }
}
```

### 3.2 Dependency Injection

Use protocols for testability:

```swift
// Protocol for abstraction
protocol ClipboardStoring: Actor {
    func getAll() async -> [Clip]
    func add(_ clip: Clip) async
    func remove(_ id: UUID) async
}

// Production implementation
actor ClipboardStore: ClipboardStoring {
    private var clips: [Clip] = []

    func getAll() async -> [Clip] { clips }
    func add(_ clip: Clip) async { clips.append(clip) }
    func remove(_ id: UUID) async { clips.removeAll { $0.id == id } }
}

// Test implementation
actor MockClipboardStore: ClipboardStoring {
    var clips: [Clip] = []
    var addCallCount = 0

    func getAll() async -> [Clip] { clips }
    func add(_ clip: Clip) async {
        addCallCount += 1
        clips.append(clip)
    }
    func remove(_ id: UUID) async { ... }
}
```

### 3.3 App Structure

```
ClipAI/
├── App/
│   ├── ClipAIApp.swift          # App entry point
│   └── AppDelegate.swift        # Menu bar, lifecycle
├── Models/
│   ├── Clip.swift               # Data model
│   └── Snippet.swift            # Data model
├── ViewModels/
│   ├── ClipboardViewModel.swift
│   └── OverlayViewModel.swift
├── Views/
│   ├── Overlay/
│   │   ├── OverlayView.swift
│   │   ├── ClipListView.swift
│   │   └── ClipDetailView.swift
│   └── Preferences/
│       └── PreferencesView.swift
├── Services/
│   ├── ClipboardMonitor.swift   # Actor
│   └── ClipboardStore.swift     # Actor
└── Utilities/
    ├── Constants.swift
    └── Extensions/
```

---

## 4. Testing Best Practices

### 4.1 TDD Workflow

Follow this cycle for every feature:

1. **Red**: Write a failing test
2. **Green**: Write minimal code to pass
3. **Refactor**: Clean up while keeping tests green

```swift
// Step 1: RED - Write failing test
final class ClipboardStoreTests: XCTestCase {
    func testAddClip_IncreasesCount() async throws {
        let store = ClipboardStore()
        let clip = Clip(content: "test")

        await store.add(clip)  // Doesn't exist yet

        let clips = await store.getAll()
        XCTAssertEqual(clips.count, 1)
    }
}

// Step 2: GREEN - Minimal implementation
actor ClipboardStore {
    private var clips: [Clip] = []

    func getAll() async -> [Clip] { clips }
    func add(_ clip: Clip) async { clips.append(clip) }
}

// Step 3: REFACTOR - Improve if needed
// (Tests still pass after changes)
```

### 4.2 Test Organization

```swift
final class ClipboardViewModelTests: XCTestCase {
    var sut: ClipboardViewModel!
    var mockStore: MockClipboardStore!

    override func setUp() async throws {
        mockStore = MockClipboardStore()
        sut = ClipboardViewModel(store: mockStore)
    }

    override func tearDown() async throws {
        sut = nil
        mockStore = nil
    }

    // MARK: - Load Clips

    func testLoadClips_WhenStoreHasClips_SetsClipsProperty() async throws {
        // Given
        let expectedClips = [Clip(content: "test1"), Clip(content: "test2")]
        mockStore.clips = expectedClips

        // When
        await sut.loadClips()

        // Then
        XCTAssertEqual(sut.clips.count, 2)
    }

    func testLoadClips_WhenStoreEmpty_SetsEmptyArray() async throws {
        // Given
        mockStore.clips = []

        // When
        await sut.loadClips()

        // Then
        XCTAssertTrue(sut.clips.isEmpty)
    }

    // MARK: - Search

    func testFilteredClips_WhenSearchTextMatches_ReturnsMatching() async throws {
        // Given
        sut.clips = [
            Clip(content: "hello world"),
            Clip(content: "goodbye"),
            Clip(content: "hello there")
        ]

        // When
        sut.searchText = "hello"

        // Then
        XCTAssertEqual(sut.filteredClips.count, 2)
    }
}
```

### 4.3 Test Naming Convention

```
test<Method>_<Condition>_<ExpectedResult>
```

Examples:
- `testAddClip_WhenValid_IncreasesCount`
- `testLoadClips_WhenStoreEmpty_ReturnsEmpty`
- `testDeleteClip_WhenNotFound_ThrowsError`

### 4.4 One Assert Per Test

```swift
// GOOD: Single focus
func testAddClip_IncreasesCount() async {
    let initialCount = await store.count
    await store.add(Clip(content: "test"))
    let newCount = await store.count

    XCTAssertEqual(newCount, initialCount + 1)
}

// BAD: Multiple unrelated assertions
func testClipProperties() {
    XCTAssertEqual(clip.content, "test")
    XCTAssertNotNil(clip.id)
    XCTAssertTrue(clip.timestamp <= Date())
    // Which one failed?
}
```

### 4.5 Test Coverage Goals

| Layer | Target Coverage |
|-------|-----------------|
| Models | 100% |
| ViewModels | 90%+ |
| Services | 80%+ |
| Views | Manual / UI Tests |

### 4.6 Async Testing

```swift
func testAsyncOperation() async throws {
    let expectation = expectation(description: "Load completes")

    var result: [Clip]?
    sut.onLoadComplete = { clips in
        result = clips
        expectation.fulfill()
    }

    sut.loadClips()

    await fulfillment(of: [expectation], timeout: 1.0)

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.count, 3)
}
```

---

## 5. Accessibility

### 5.1 VoiceOver Support

```swift
struct ClipRowView: View {
    let clip: Clip

    var body: some View {
        HStack {
            Image(systemName: "doc.on.clipboard")
            VStack(alignment: .leading) {
                Text(clip.preview)
                Text(clip.timestamp.formatted())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Clip: \(clip.preview)")
        .accessibilityHint("Double tap to paste")
        .accessibilityAddTraits(.isButton)
    }
}
```

### 5.2 Keyboard Navigation

```swift
struct OverlayView: View {
    @FocusState private var focusedField: FocusField?

    enum FocusField {
        case search
        case clipList
    }

    var body: some View {
        VStack {
            TextField("Search...", text: $searchText)
                .focused($focusedField, equals: .search)

            ClipListView(clips: clips)
                .focused($focusedField, equals: .clipList)
        }
        .onAppear {
            focusedField = .search
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }
}
```

---

## 6. Quality Tools Workflow

### 6.1 Mandatory Quality Checklist

Before marking ANY story as complete:

```bash
# 1. Run all tests
swift test

# 2. Run quality check on all files
./scripts/quality-check.sh --all

# 3. Fix any issues found
# 4. Re-run until clean

# 5. Format code
./scripts/format.sh
```

### 6.2 Quality Check Layers

| Check | Tool | Blocking | Fix Command |
|-------|------|----------|-------------|
| Format | swift-format | No (advisory) | `./scripts/format.sh` |
| Lint | SwiftLint | Yes | Fix reported issues |
| Concurrency | Swift compiler | Yes | Add Sendable/Actor isolation |

### 6.3 Common Issues and Fixes

#### Sendable Conformance Missing

```swift
// Error: Non-sendable type 'Clip' crossing actor boundary

// Fix: Add Sendable conformance
struct Clip: Sendable, Codable {
    let id: UUID
    let content: String
}
```

#### Actor Isolation Error

```swift
// Error: Actor-isolated property 'clips' can not be referenced

// Fix: Use async access
let clips = await store.getAll()

// NOT: let clips = store.clips
```

#### SwiftLint Cyclomatic Complexity

```swift
// Error: Cyclomatic complexity exceeds 10

// Fix: Extract to separate methods
func handleClipAction(_ action: ClipAction) {
    switch action {
    case .copy: copyClip()
    case .delete: deleteClip()
    case .edit: editClip()
    }
}

private func copyClip() { ... }
private func deleteClip() { ... }
private func editClip() { ... }
```

#### Force Unwrap Warning

```swift
// Error: Force unwrap is discouraged

// BAD
let clip = clips.first!

// GOOD
guard let clip = clips.first else { return }
// or
if let clip = clips.first { ... }
```

---

## 7. Code Examples

### 7.1 Complete Actor Example

```swift
/// Actor responsible for monitoring clipboard changes.
actor ClipboardMonitor {
    private var changeCount: Int = 0
    private var timer: Timer?
    private let pasteboard = NSPasteboard.general
    private let onClipCaptured: @Sendable (Clip) async -> Void

    init(onClipCaptured: @escaping @Sendable (Clip) async -> Void) {
        self.onClipCaptured = onClipCaptured
    }

    func startMonitoring(interval: TimeInterval = 0.5) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.checkForChanges()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkForChanges() async {
        let currentCount = pasteboard.changeCount
        guard currentCount != changeCount else { return }

        changeCount = currentCount

        if let content = pasteboard.string(forType: .string) {
            let clip = Clip(content: content)
            await onClipCaptured(clip)
        }
    }
}
```

### 7.2 Complete ViewModel Example

```swift
@MainActor
@Observable
final class OverlayViewModel {
    // MARK: - State

    private(set) var clips: [Clip] = []
    var searchText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let store: ClipboardStore
    private let monitor: ClipboardMonitor

    // MARK: - Computed

    var filteredClips: [Clip] {
        if searchText.isEmpty {
            clips
        } else {
            clips.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var hasClips: Bool {
        !clips.isEmpty
    }

    // MARK: - Init

    init(store: ClipboardStore, monitor: ClipboardMonitor) {
        self.store = store
        self.monitor = monitor
    }

    // MARK: - Actions

    func onAppear() async {
        await loadClips()
        await monitor.startMonitoring { [weak self] clip in
            await self?.handleNewClip(clip)
        }
    }

    func loadClips() async {
        isLoading = true
        errorMessage = nil

        do {
            clips = try await store.getAll()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func selectClip(_ clip: Clip) async {
        await store.copyToPasteboard(clip)
        // Post notification to dismiss overlay
        NotificationCenter.default.post(name: .clipSelected, object: nil)
    }

    func deleteClip(_ clip: Clip) async {
        await store.remove(clip.id)
        clips.removeAll { $0.id == clip.id }
    }

    // MARK: - Private

    private func handleNewClip(_ clip: Clip) async {
        clips.insert(clip, at: 0)
    }
}
```

### 7.3 Complete View Example

```swift
struct OverlayView: View {
    @StateObject private var viewModel: OverlayViewModel
    @Environment(\.dismiss) private var dismiss

    init(store: ClipboardStore, monitor: ClipboardMonitor) {
        _viewModel = StateObject(wrappedValue: OverlayViewModel(store: store, monitor: monitor))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBar(text: $viewModel.searchText)
                .padding()

            Divider()

            // Content
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.hasClips {
                EmptyStateView()
            } else {
                ClipListView(
                    clips: viewModel.filteredClips,
                    onSelect: { clip in
                        Task { await viewModel.selectClip(clip) }
                    }
                )
            }

            // Error banner
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
            }
        }
        .frame(width: 600, height: 400)
        .task {
            await viewModel.onAppear()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipSelected)) { _ in
            dismiss()
        }
    }
}
```

---

## 8. References

### Official Documentation

- [Apple Human Interface Guidelines - macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos)
- [Swift Concurrency](https://swift.org/documentation/concurrency/)
- [Adopting Swift 6](https://developer.apple.com/documentation/swift/adoptingswift6)
- [SwiftUI Tutorials - macOS](https://developer.apple.com/tutorials/swiftui/creating-a-macos-app)

### Research Sources (2026)

- [Swift Concurrency Guide: Async/Await, Actors & iOS Scaling](https://medium.com/@expertappdevs/swift-concurrency-guide-async-await-actors-ios-scaling-1e2032ae3718)
- [Swift Sendable: A Practical Guide](https://blog.stackademic.com/swift-sendable-a-practical-guide-to-safer-concurrency-88826e44fd6c)
- [Embracing Swift Concurrency - WWDC25](https://developer.apple.com/videos/play/wwdc2025/268/)
- [SwiftUI in 2026](https://blog.stackademic.com/swiftui-in-2026-everything-you-need-to-know-to-get-started-d3aa22bc31a2)
- [Mastering Actor Isolation and Swift 6 Concurrency](https://blog.stackademic.com/mastering-actor-isolation-and-swift-6-concurrency-2026-34e27c208b51)
- [How to Build macOS Applications with SwiftUI](https://oneuptime.com/blog/post/2026-02-02-swiftui-macos-applications/view)
- [What I Learned Building a Native macOS Menu Bar App](https://dev.to/heocoi/what-i-learned-building-a-native-macos-menu-bar-app-4im6)
- [XCTest Best Practices for iOS Testing](https://maestro.dev/insights/xctest-best-practices-ios-testing)
- [How to Implement Dependency Injection in Swift](https://oneuptime.com/blog/post/2026-02-02-swift-dependency-injection/view)

### Related Project Documentation

- [Quality Tools Reference](quality-tools.md)
- [Product Vision](../vision.md)
- [User Stories](../../TODO.md)

---

## Changelog

| Date | Change |
|------|--------|
| 2026-02-17 | Initial creation with 2026 best practices research |
