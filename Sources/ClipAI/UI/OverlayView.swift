import SwiftUI

// MARK: - Focus Field

/// Represents focusable elements in the overlay.
enum FocusField: Hashable {
    case search
    case clip(id: UUID)
}

// MARK: - OverlayView

/// SwiftUI view for the overlay content.
/// Displays a Raycast-style dark overlay with clipboard history list.
struct OverlayView: View {
    @State private var viewModel: OverlayViewModel
    @FocusState private var focusedField: FocusField?
    @State private var hoveredIndex: Int? = nil

    // MARK: - Initialization

    init(viewModel: OverlayViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar

            // Content area
            contentArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.98))
        )
        .task {
            await viewModel.loadClips()
            // Focus search field on appear
            focusedField = .search
        }
        .onChange(of: viewModel.focusedIndex) { _, newValue in
            // Update SwiftUI focus when ViewModel focus changes
            if let index = newValue, index < viewModel.filteredClips.count {
                focusedField = .clip(id: viewModel.filteredClips[index].id)
            } else {
                focusedField = .search
            }
        }
        .onChange(of: focusedField) { _, newValue in
            // Update ViewModel focus when SwiftUI focus changes
            switch newValue {
            case .search:
                viewModel.focusedIndex = nil
            case .clip(let id):
                if let index = viewModel.filteredClips.firstIndex(where: { $0.id == id }) {
                    viewModel.focusedIndex = index
                }
            case .none:
                break
            }
        }
        .onKeyPress(.downArrow) {
            viewModel.moveFocusDown()
            return .handled
        }
        .onKeyPress(.upArrow) {
            viewModel.moveFocusUp()
            return .handled
        }
        .onKeyPress(.return) {
            // Paste the focused clip when Enter is pressed
            Task {
                if await viewModel.selectAndPasteFocusedClip() {
                    // Dismiss handled by onClipPasted callback
                }
            }
            return .handled
        }
    }

    // MARK: - View Components

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search clips...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .search)
                .onSubmit {
                    // When pressing Enter in search, move to first item
                    viewModel.moveFocusDown()
                }
                .onExitCommand {
                    // ESC key dismisses overlay
                    viewModel.dismissOverlay()
                }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isLoading {
            loadingView
        } else if viewModel.filteredClips.isEmpty {
            emptyStateView
        } else {
            clipListView
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No clips yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Copy something to get started.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var clipListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(Array(viewModel.filteredClips.enumerated()), id: \.element.id) { index, clip in
                    ClipRowView(
                        clip: clip,
                        previewText: viewModel.previewText(for: clip),
                        relativeTime: viewModel.relativeTime(for: clip),
                        isFocused: viewModel.focusedIndex == index,
                        isHovered: hoveredIndex == index
                    ) {
                        // Select and paste on click
                        Task {
                            viewModel.selectClip(clip)
                            await viewModel.pasteSelectedClip()
                        }
                    }
                    .focused($focusedField, equals: .clip(id: clip.id))
                    .focusable()
                    .focusEffectDisabled()
                    .onHover { isHovered in
                        hoveredIndex = isHovered ? index : nil
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - ClipRowView

/// A single row in the clip list displaying preview and metadata.
struct ClipRowView: View {
    let clip: Clip
    let previewText: String
    let relativeTime: String
    let isFocused: Bool
    let isHovered: Bool
    let onSelect: () -> Void

    // MARK: - Computed Properties

    /// Background color based on focus and hover states.
    /// Uses neutral gray colors that adapt to both dark and light mode.
    /// - Keyboard focus (isFocused): 15% opacity - darker, persistent, clearly visible
    /// - Mouse hover (isHovered): 8% opacity - lighter, temporary, subtle
    /// - Both on same item: keyboard focus style takes precedence
    ///
    /// Color.primary automatically adapts:
    /// - Dark mode: White with opacity (lighter highlight on dark background)
    /// - Light mode: Black with opacity (darker highlight on light background)
    private var backgroundColor: Color {
        if isFocused {
            return Color.primary.opacity(0.15)
        } else if isHovered {
            return Color.primary.opacity(0.08)
        }
        return Color.clear
    }

    var body: some View {
        HStack(spacing: 12) {
            // Content type icon or thumbnail
            contentTypeIcon

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(previewText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    if let sourceApp = clip.sourceApp {
                        Text(sourceApp)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(relativeTime)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(
            Rectangle()
                .fill(backgroundColor)
        )
        .onTapGesture {
            onSelect()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Clip: \(previewText)")
        .accessibilityHint("Double tap to paste")
    }

    @ViewBuilder
    private var contentTypeIcon: some View {
        switch clip.contentType {
        case .text:
            Image(systemName: "doc.text")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)

        case .image:
            // For images, show a thumbnail placeholder
            // Story 4 will implement actual thumbnails
            Image(systemName: "photo")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
        }
    }
}

// MARK: - Preview

#Preview("With Clips") {
    let storage = MockPreviewStorage()
    let viewModel = OverlayViewModel(storage: storage)
    return OverlayView(viewModel: viewModel)
        .frame(width: 600, height: 400)
}

#Preview("Empty State") {
    let storage = MockEmptyStorage()
    let viewModel = OverlayViewModel(storage: storage)
    return OverlayView(viewModel: viewModel)
        .frame(width: 600, height: 400)
}

// MARK: - Preview Helpers

private actor MockPreviewStorage: ClipStorageProtocol {
    func loadAll() async -> [Clip] {
        [
            Clip(
                content: "Hello World from the article I was reading this morning",
                contentType: .text,
                sourceApp: "Safari",
                timestamp: Date().addingTimeInterval(-120)
            ),
            Clip(
                content: "func calculateTotal() -> Int { return items.reduce(0) { $0 + $1.price } }",
                contentType: .text,
                sourceApp: "Xcode",
                timestamp: Date().addingTimeInterval(-900)
            ),
            Clip(
                content: "Screenshot",
                contentType: .image,
                sourceApp: "Screenshots",
                timestamp: Date().addingTimeInterval(-3600)
            )
        ]
    }
}

private actor MockEmptyStorage: ClipStorageProtocol {
    func loadAll() async -> [Clip] { [] }
}
