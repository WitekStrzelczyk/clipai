import Foundation

/// Metadata associated with a clip, containing content-specific information.
struct ClipMetadata: Sendable, Codable, Equatable {
    /// Length of text content (for text clips).
    let textLength: Int?

    /// Width of image in pixels (for image clips).
    let imageWidth: Int?

    /// Height of image in pixels (for image clips).
    let imageHeight: Int?

    /// Creates metadata for text content.
    /// - Parameter textLength: The length of the text content.
    init(textLength: Int) {
        self.textLength = textLength
        self.imageWidth = nil
        self.imageHeight = nil
    }

    /// Creates metadata for image content.
    /// - Parameters:
    ///   - imageWidth: The width of the image in pixels.
    ///   - imageHeight: The height of the image in pixels.
    init(imageWidth: Int, imageHeight: Int) {
        self.textLength = nil
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }

    /// Creates metadata from a decoder.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        textLength = try container.decodeIfPresent(Int.self, forKey: .textLength)
        imageWidth = try container.decodeIfPresent(Int.self, forKey: .imageWidth)
        imageHeight = try container.decodeIfPresent(Int.self, forKey: .imageHeight)
    }
}

extension ClipMetadata {
    enum CodingKeys: String, CodingKey {
        case textLength = "text_length"
        case imageWidth = "image_width"
        case imageHeight = "image_height"
    }
}
