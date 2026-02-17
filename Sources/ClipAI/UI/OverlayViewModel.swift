import Foundation

// MARK: - ClipStorageProtocol

/// Protocol for ClipStorage to enable testing with mocks.
protocol ClipStorageProtocol {
    func loadAll() async -> [Clip]
}

/// Extend ClipStorage to conform to protocol.
extension ClipStorage: ClipStorageProtocol {}

// MARK: - OverlayViewModel

/// ViewModel for the overlay panel.
/// Manages clipboard history display and selection.
@MainActor
@Observable
final class OverlayViewModel {
    // MARK: - Constants

    /// Maximum characters to show in preview text.
    static let previewCharacterLimit = 50

    // MARK: - State

    /// The clips to display, sorted by timestamp descending.
    private(set) var clips: [Clip] = []

    /// Whether clips are currently being loaded.
    private(set) var isLoading: Bool = false

    /// The currently selected clip (for Story 6: copy to clipboard).
    var selectedClip: Clip?

    /// Search text for filtering clips.
    var searchText: String = ""

    /// The index of the currently focused clip item, or nil if search field is focused.
    var focusedIndex: Int?

    // MARK: - Computed Properties

    /// Clips filtered by search text using two-phase ranking:
    /// - Phase 1: Content matches (clips where content contains search text)
    /// - Phase 2: Source app matches (clips where source app contains search text, but content doesn't)
    var filteredClips: [Clip] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)

        if query.isEmpty {
            return clips  // No filter
        }

        // Phase 1: Content matches
        let contentMatches = clips.filter { clip in
            clip.content.lowercased().contains(query)
        }

        // Phase 2: Source app matches (but content doesn't match)
        let appMatches = clips.filter { clip in
            !clip.content.lowercased().contains(query) &&
            (clip.sourceApp?.lowercased().contains(query) ?? false)
        }

        return contentMatches + appMatches
    }

    /// Whether there are any clips to display.
    var hasClips: Bool {
        !clips.isEmpty
    }

    // MARK: - Dependencies

    /// The storage service for loading clips.
    private let storage: any ClipStorageProtocol

    /// The paste service for copying clips to clipboard.
    private let pasteService: any PasteServiceProtocol

    /// Callback triggered when a clip is pasted (to dismiss overlay).
    var onClipPasted: (() -> Void)?

    /// Callback triggered when overlay should be dismissed (ESC key).
    var onDismiss: (() -> Void)?

    // MARK: - Initialization

    /// Creates a new OverlayViewModel.
    /// - Parameters:
    ///   - storage: The storage service for loading clips.
    ///   - pasteService: The paste service for copying clips to clipboard.
    init(storage: some ClipStorageProtocol, pasteService: some PasteServiceProtocol) {
        self.storage = storage
        self.pasteService = pasteService
    }

    /// Creates a new OverlayViewModel with default paste service.
    /// - Parameter storage: The storage service for loading clips.
    convenience init(storage: some ClipStorageProtocol) {
        self.init(storage: storage, pasteService: PasteService())
    }

    // MARK: - Actions

    /// Loads clips from storage.
    func loadClips() async {
        isLoading = true
        clips = await storage.loadAll()
        isLoading = false
    }

    /// Dismisses the overlay (triggered by ESC key).
    func dismissOverlay() {
        onDismiss?()
    }

    /// Selects a clip for action.
    /// - Parameter clip: The clip to select.
    func selectClip(_ clip: Clip) {
        selectedClip = clip
    }

    // MARK: - Paste (Story 6)

    /// Pastes the currently selected clip.
    /// - Returns: True if paste was successful, false if no clip was selected.
    @discardableResult
    func pasteSelectedClip() async -> Bool {
        guard let clip = selectedClip else { return false }

        do {
            try await pasteService.copyAndPaste(clip)
            // Notify observers that paste completed
            onClipPasted?()
            return true
        } catch {
            // Log error but don't crash
            return false
        }
    }

    /// Gets the currently focused clip based on focusedIndex.
    /// - Returns: The focused clip, or nil if no clip is focused.
    func getFocusedClip() -> Clip? {
        guard let index = focusedIndex, index < filteredClips.count else { return nil }
        return filteredClips[index]
    }

    /// Selects and pastes the currently focused clip.
    /// - Returns: True if paste was successful, false if no clip is focused.
    @discardableResult
    func selectAndPasteFocusedClip() async -> Bool {
        guard let clip = getFocusedClip() else { return false }
        selectClip(clip)
        return await pasteSelectedClip()
    }

    // MARK: - Search

    /// Sets the search text for filtering clips.
    /// - Parameter text: The search text.
    func setSearchText(_ text: String) {
        searchText = text
        // Reset focus when search text changes
        focusedIndex = nil
    }

    // MARK: - Focus Navigation

    /// Sets the focused index directly.
    /// - Parameter index: The index to focus, or nil for search field.
    func setFocusIndex(_ index: Int?) {
        focusedIndex = index
    }

    /// Resets focus to the search field.
    func resetFocus() {
        focusedIndex = nil
    }

    /// Moves focus down (from search to first item, or to next item).
    func moveFocusDown() {
        let itemCount = filteredClips.count
        guard itemCount > 0 else { return }

        if let current = focusedIndex {
            // Move to next item, but don't go past last item
            focusedIndex = min(current + 1, itemCount - 1)
        } else {
            // From search, move to first item
            focusedIndex = 0
        }
    }

    /// Moves focus up (from item to previous item, or from first item to search).
    func moveFocusUp() {
        if let current = focusedIndex {
            if current > 0 {
                // Move to previous item
                focusedIndex = current - 1
            } else {
                // At first item, return to search
                focusedIndex = nil
            }
        }
        // If already at search (nil), stay there
    }

    // MARK: - Preview Helpers

    /// Returns a truncated preview of the clip content.
    /// - Parameter clip: The clip to preview.
    /// - Returns: Truncated text with ellipsis if needed.
    func previewText(for clip: Clip) -> String {
        let content = clip.content
        if content.count > Self.previewCharacterLimit {
            let index = content.index(content.startIndex, offsetBy: Self.previewCharacterLimit)
            return String(content[..<index]) + "..."
        }
        return content
    }

    /// Returns a relative time string for the clip timestamp.
    /// - Parameter clip: The clip to format.
    /// - Returns: A human-readable relative time string.
    func relativeTime(for clip: Clip) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: clip.timestamp, relativeTo: Date())
    }
}
