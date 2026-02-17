import XCTest
@testable import ClipAI

final class ClipTests: XCTestCase {
    // MARK: - Text Clip Creation

    func testInit_WithTextContent_SetsContentTypeToText() {
        let clip = Clip(content: "Hello World", contentType: .text)

        XCTAssertEqual(clip.contentType, .text)
        XCTAssertEqual(clip.content, "Hello World")
    }

    func testInit_WithTextContent_GeneratesUUID() {
        let clip = Clip(content: "Test", contentType: .text)

        XCTAssertNotNil(clip.id)
    }

    func testInit_WithTextContent_SetsTimestampToNow() {
        let before = Date()
        let clip = Clip(content: "Test", contentType: .text)
        let after = Date()

        XCTAssertGreaterThanOrEqual(clip.timestamp, before)
        XCTAssertLessThanOrEqual(clip.timestamp, after)
    }

    func testInit_WithSourceApp_SetsSourceApp() {
        let clip = Clip(
            content: "Test",
            contentType: .text,
            sourceApp: "Safari"
        )

        XCTAssertEqual(clip.sourceApp, "Safari")
    }

    func testInit_WithSourceURL_SetsSourceURL() {
        let clip = Clip(
            content: "Test",
            contentType: .text,
            sourceURL: URL(string: "https://example.com")
        )

        XCTAssertEqual(clip.sourceURL?.absoluteString, "https://example.com")
    }

    func testInit_WithMetadata_SetsMetadata() {
        let metadata = ClipMetadata(textLength: 100)
        let clip = Clip(
            content: "Test",
            contentType: .text,
            metadata: metadata
        )

        XCTAssertEqual(clip.metadata?.textLength, 100)
    }

    // MARK: - Image Clip Creation

    func testInit_WithImageContent_SetsContentTypeToImage() {
        let clip = Clip(content: "base64imagedata", contentType: .image)

        XCTAssertEqual(clip.contentType, .image)
    }

    // MARK: - Codable

    func testEncode_ThenDecode_PreservesAllFields() throws {
        let original = Clip(
            content: "Hello World",
            contentType: .text,
            sourceApp: "Safari",
            sourceURL: URL(string: "https://example.com/page"),
            metadata: ClipMetadata(textLength: 11)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Clip.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.contentType, original.contentType)
        XCTAssertEqual(decoded.sourceApp, original.sourceApp)
        XCTAssertEqual(decoded.sourceURL, original.sourceURL)
        XCTAssertEqual(decoded.metadata?.textLength, original.metadata?.textLength)
    }

    // MARK: - FileName Generation

    func testfileName_GeneratesExpectedFormat() {
        let clip = Clip(
            content: "Test",
            contentType: .text,
            timestamp: ISO8601DateFormatter().date(from: "2026-02-17T10:30:00Z")!,
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!
        )

        let fileName = clip.fileName

        // File name format: 20260217T103000-uuid.json
        XCTAssertEqual(fileName, "20260217T103000-12345678-1234-1234-1234-123456789012.json")
    }

    // MARK: - Sendable Conformance

    func testClip_ConformsToSendable() {
        // This test verifies at compile time that Clip is Sendable
        func acceptSendable<T: Sendable>(_ value: T) {}
        let clip = Clip(content: "Test", contentType: .text)
        acceptSendable(clip)
        XCTAssertTrue(true, "Clip conforms to Sendable")
    }
}
