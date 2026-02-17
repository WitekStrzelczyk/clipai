import Foundation

/// The type of content stored in a clip.
enum ClipContentType: String, Sendable, Codable, Equatable {
    /// Text content (plain or formatted).
    case text

    /// Image content (stored as base64).
    case image
}
