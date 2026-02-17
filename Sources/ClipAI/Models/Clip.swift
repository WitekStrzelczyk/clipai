import Foundation

/// A clipboard item captured by ClipAI.
struct Clip: Sendable, Codable, Identifiable, Equatable {
    /// Unique identifier for the clip.
    let id: UUID

    /// The content of the clip (plain text or base64-encoded for images).
    let content: String

    /// The type of content stored in this clip.
    let contentType: ClipContentType

    /// The application from which the content was copied (if available).
    let sourceApp: String?

    /// The URL from which the content was copied (if available, typically for browser content).
    let sourceURL: URL?

    /// The timestamp when the clip was captured.
    let timestamp: Date

    /// Additional metadata about the clip content.
    let metadata: ClipMetadata?

    /// Creates a new clip with the specified content.
    /// - Parameters:
    ///   - content: The clip content.
    ///   - contentType: The type of content.
    ///   - sourceApp: The source application (optional).
    ///   - sourceURL: The source URL (optional).
    ///   - metadata: Additional metadata (optional).
    ///   - timestamp: The capture timestamp (defaults to now).
    ///   - id: Unique identifier (defaults to new UUID).
    init(
        content: String,
        contentType: ClipContentType,
        sourceApp: String? = nil,
        sourceURL: URL? = nil,
        metadata: ClipMetadata? = nil,
        timestamp: Date = Date(),
        id: UUID = UUID()
    ) {
        self.id = id
        self.content = content
        self.contentType = contentType
        self.sourceApp = sourceApp
        self.sourceURL = sourceURL
        self.timestamp = timestamp
        self.metadata = metadata
    }

    /// Generates a filename for this clip in the format: {timestamp}-{uuid}.json
    var fileName: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime]
        let timestampString = formatter.string(from: timestamp)
            .replacingOccurrences(of: ":", with: "-")
        return "\(timestampString)-\(id.uuidString).json"
    }

    /// Returns a new Clip with an updated timestamp, preserving all other fields.
    /// - Parameter newTimestamp: The new timestamp (defaults to now).
    /// - Returns: A new Clip instance with the updated timestamp.
    func withUpdatedTimestamp(_ newTimestamp: Date = Date()) -> Clip {
        Clip(
            content: content,
            contentType: contentType,
            sourceApp: sourceApp,
            sourceURL: sourceURL,
            metadata: metadata,
            timestamp: newTimestamp,
            id: id
        )
    }
}

extension Clip {
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case contentType = "content_type"
        case sourceApp = "source_app"
        case sourceURL = "source_url"
        case timestamp
        case metadata
    }
}
