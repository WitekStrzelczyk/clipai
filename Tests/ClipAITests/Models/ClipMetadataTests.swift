import XCTest
@testable import ClipAI

final class ClipMetadataTests: XCTestCase {
    // MARK: - Text Metadata

    func testInit_WithTextLength_SetsTextLength() {
        let metadata = ClipMetadata(textLength: 150)

        XCTAssertEqual(metadata.textLength, 150)
        XCTAssertNil(metadata.imageWidth)
        XCTAssertNil(metadata.imageHeight)
    }

    // MARK: - Image Metadata

    func testInit_WithImageDimensions_SetsImageDimensions() {
        let metadata = ClipMetadata(imageWidth: 800, imageHeight: 600)

        XCTAssertEqual(metadata.imageWidth, 800)
        XCTAssertEqual(metadata.imageHeight, 600)
        XCTAssertNil(metadata.textLength)
    }

    // MARK: - Codable

    func testEncode_ThenDecode_PreservesTextMetadata() throws {
        let original = ClipMetadata(textLength: 100)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClipMetadata.self, from: data)

        XCTAssertEqual(decoded.textLength, original.textLength)
    }

    func testEncode_ThenDecode_PreservesImageMetadata() throws {
        let original = ClipMetadata(imageWidth: 1920, imageHeight: 1080)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClipMetadata.self, from: data)

        XCTAssertEqual(decoded.imageWidth, original.imageWidth)
        XCTAssertEqual(decoded.imageHeight, original.imageHeight)
    }

    // MARK: - Sendable Conformance

    func testClipMetadata_ConformsToSendable() {
        func acceptSendable<T: Sendable>(_ value: T) {}
        let metadata = ClipMetadata(textLength: 100)
        acceptSendable(metadata)
        XCTAssertTrue(true, "ClipMetadata conforms to Sendable")
    }
}
