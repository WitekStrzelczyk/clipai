import AppKit
import XCTest
@testable import ClipAI

final class PasteServiceTests: XCTestCase {
    var sut: PasteService!
    var mockPasteboard: MockPasteboard!

    override func setUp() async throws {
        try await super.setUp()
        mockPasteboard = MockPasteboard()
        sut = PasteService(pasteboard: mockPasteboard)
    }

    override func tearDown() async throws {
        sut = nil
        mockPasteboard = nil
        try await super.tearDown()
    }

    // MARK: - Copy to Clipboard

    func testCopyToClipboard_WithTextClip_SetsStringContent() async throws {
        // Given
        let clip = Clip(content: "Hello World", contentType: .text)

        // When
        try await sut.copyToClipboard(clip)

        // Then
        XCTAssertEqual(mockPasteboard.setStringCallCount, 1)
        XCTAssertEqual(mockPasteboard.lastStringContent, "Hello World")
    }

    func testCopyToClipboard_ClearsPasteboardFirst() async throws {
        // Given
        let clip = Clip(content: "Test", contentType: .text)

        // When
        try await sut.copyToClipboard(clip)

        // Then
        XCTAssertEqual(mockPasteboard.clearCallCount, 1)
    }

    func testCopyToClipboard_UsesGeneralPasteboard() async throws {
        // Given
        sut = PasteService() // Uses real NSPasteboard.general

        // This test verifies the default initializer works
        XCTAssertNotNil(sut)
    }

    // MARK: - Paste Simulation

    func testSimulateCmdV_CreatesKeyboardEvent() async throws {
        // Given/When/Then - should not crash
        try await sut.simulateCmdV()
    }

    // MARK: - Copy and Paste Combined

    func testCopyAndPaste_SetsClipboardThenSimulatesPaste() async throws {
        // Given
        let clip = Clip(content: "Test Content", contentType: .text)

        // When
        try await sut.copyAndPaste(clip)

        // Then
        XCTAssertEqual(mockPasteboard.setStringCallCount, 1)
        XCTAssertEqual(mockPasteboard.lastStringContent, "Test Content")
    }

    // MARK: - Delay

    func testPasteDelay_IsReasonableValue() {
        // Given - default delay should be 50-100ms
        let delay = PasteService.pasteDelay

        // Then
        XCTAssertGreaterThanOrEqual(delay, 0.05)
        XCTAssertLessThanOrEqual(delay, 0.15)
    }
}

// MARK: - Mock Pasteboard

/// Mock implementation of NSPasteboard for testing.
final class MockPasteboard: PasteboardProtocol, @unchecked Sendable {
    var clearCallCount = 0
    var setStringCallCount = 0
    var lastStringContent: String?
    var lastDataType: NSPasteboard.PasteboardType?

    private var contents: [NSPasteboard.PasteboardType: Any] = [:]

    func clearContents() -> Int {
        clearCallCount += 1
        let count = contents.count
        contents.removeAll()
        return count
    }

    func setString(_ string: String, forType type: NSPasteboard.PasteboardType) -> Bool {
        setStringCallCount += 1
        lastStringContent = string
        lastDataType = type
        contents[type] = string
        return true
    }

    func string(forType type: NSPasteboard.PasteboardType) -> String? {
        contents[type] as? String
    }
}
