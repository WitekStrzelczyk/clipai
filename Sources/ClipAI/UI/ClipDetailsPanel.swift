import SwiftUI

// MARK: - ClipDetailsPanel

/// A panel displaying full details of a clip for the right side of the overlay.
/// Shows content (scrollable text or image preview), source app, timestamp, and source URL.
struct ClipDetailsPanel: View {
    let clip: Clip?
    let relativeTime: String

    // MARK: - Constants

    /// Maximum size for image preview.
    static let maxImageSize: CGFloat = 300

    // MARK: - Body

    var body: some View {
        if let clip = clip {
            clipDetailsContent(for: clip)
        } else {
            placeholderView
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private func clipDetailsContent(for clip: Clip) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                headerSection(for: clip)

                // Content section
                contentSection(for: clip)

                // Metadata section
                metadataSection(for: clip)
            }
            .padding(16)
        }
    }

    private func headerSection(for clip: Clip) -> some View {
        HStack {
            contentTypeIcon(for: clip)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            Text("Details")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()
        }
    }

    @ViewBuilder
    private func contentSection(for clip: Clip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Content")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            switch clip.contentType {
            case .text:
                textContentPreview(clip.content)
            case .image:
                imageContentPreview(clip.content)
            }
        }
    }

    private func textContentPreview(_ content: String) -> some View {
        ScrollView {
            Text(content)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(maxHeight: 200)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func imageContentPreview(_ base64Content: String) -> some View {
        Group {
            if let imageData = Data(base64Encoded: base64Content),
               let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: Self.maxImageSize, maxHeight: Self.maxImageSize)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Fallback for invalid image data
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("Image preview unavailable")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func metadataSection(for clip: Clip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Source app
            if let sourceApp = clip.sourceApp {
                metadataRow(label: "Source", value: sourceApp, icon: "app")
            }

            // Source URL
            if let sourceURL = clip.sourceURL {
                metadataRow(
                    label: "URL",
                    value: sourceURL.absoluteString,
                    icon: "link",
                    isURL: true,
                    url: sourceURL
                )
            }

            // Timestamp
            metadataRow(label: "Copied", value: relativeTime, icon: "clock")
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func metadataRow(
        label: String,
        value: String,
        icon: String,
        isURL: Bool = false,
        url: URL? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if isURL, let url = url {
                    Link(destination: url) {
                        Text(value)
                            .font(.caption)
                            .foregroundStyle(.link)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
                    .help("Click to open: \(value)")
                } else {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "sidebar.right")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Hover over a clip to see details")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func contentTypeIcon(for clip: Clip) -> some View {
        switch clip.contentType {
        case .text:
            Image(systemName: "doc.text")
        case .image:
            Image(systemName: "photo")
        }
    }
}

// MARK: - Preview

#Preview("With Text Clip") {
    let clip = Clip(
        content: "This is a longer piece of text that would be shown in the details panel. It can span multiple lines and should be scrollable if it gets too long.",
        contentType: .text,
        sourceApp: "Safari",
        sourceURL: URL(string: "https://example.com/article"),
        timestamp: Date().addingTimeInterval(-120)
    )

    ClipDetailsPanel(clip: clip, relativeTime: "2 min ago")
        .frame(width: 280, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
}

#Preview("Placeholder") {
    ClipDetailsPanel(clip: nil, relativeTime: "")
        .frame(width: 280, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
}
