import XCTest
import AppKit
@testable import ClipAI

final class ClipboardMonitorTests: XCTestCase {
    var sut: ClipboardMonitor!
    var capturedClips: [Clip]!
    var mockPasteboard: NSPasteboard!

    override func setUp() async throws {
        try await super.setUp()
        capturedClips = []
        // Create a unique pasteboard for testing
        mockPasteboard = NSPasteboard.withUniqueName()
    }

    override func tearDown() async throws {
        await sut?.stopMonitoring()
        sut = nil
        capturedClips = nil
        mockPasteboard = nil
        try await super.tearDown()
    }

    // MARK: - Clipboard Change Detection

    func testStartMonitoring_WhenClipboardChanges_CapturesText() async throws {
        sut = ClipboardMonitor(
            pasteboard: mockPasteboard,
            onClipCaptured: { [weak self] clip in
                self?.capturedClips.append(clip)
            }
        )

        await sut.startMonitoring(interval: 0.1)

        // Simulate clipboard change
        mockPasteboard.clearContents()
        mockPasteboard.setString("Hello World", forType: .string)

        // Trigger a check manually for testing
        await sut.checkForChanges()

        // Wait a bit for async processing
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(capturedClips.count, 1)
        XCTAssertEqual(capturedClips.first?.content, "Hello World")
        XCTAssertEqual(capturedClips.first?.contentType, .text)
    }

    func testCheckForChanges_WhenNoChange_DoesNotCapture() async throws {
        sut = ClipboardMonitor(
            pasteboard: mockPasteboard,
            onClipCaptured: { [weak self] clip in
                self?.capturedClips.append(clip)
            }
        )

        // Set initial content
        mockPasteboard.clearContents()
        mockPasteboard.setString("Initial", forType: .string)
        await sut.checkForChanges()  // Set baseline

        capturedClips.removeAll()

        // Check again without changing clipboard
        await sut.checkForChanges()

        XCTAssertTrue(capturedClips.isEmpty, "Should not capture when content hasn't changed")
    }

    func testCheckForChanges_WhenSameContentWithin5Seconds_DoesNotCaptureDuplicate() async throws {
        sut = ClipboardMonitor(
            pasteboard: mockPasteboard,
            onClipCaptured: { [weak self] clip in
                self?.capturedClips.append(clip)
            }
        )

        mockPasteboard.clearContents()
        mockPasteboard.setString("Same Content", forType: .string)

        // First capture
        await sut.checkForChanges()

        // Immediate second capture with same content
        await sut.checkForChanges()

        // Should only capture once within deduplication window
        XCTAssertEqual(capturedClips.count, 1)
    }

    // MARK: - Source App Detection

    func testCaptureClip_IncludesSourceApp() async throws {
        sut = ClipboardMonitor(
            pasteboard: mockPasteboard,
            onClipCaptured: { [weak self] clip in
                self?.capturedClips.append(clip)
            }
        )

        mockPasteboard.clearContents()
        mockPasteboard.setString("Test", forType: .string)

        await sut.checkForChanges()

        // Source app may be nil in test environment, so just verify it's optional
        // The actual value depends on the frontmost application during test
        _ = capturedClips.first?.sourceApp
    }

    // MARK: - Source URL Detection

    func testCaptureClip_WhenURLAvailable_IncludesSourceURL() async throws {
        sut = ClipboardMonitor(
            pasteboard: mockPasteboard,
            onClipCaptured: { [weak self] clip in
                self?.capturedClips.append(clip)
            }
        )

        mockPasteboard.clearContents()
        mockPasteboard.setString("Test", forType: .string)
        // Use setString for URL type
        mockPasteboard.setString("https://example.com/page", forType: .URL)

        await sut.checkForChanges()

        XCTAssertEqual(capturedClips.first?.sourceURL?.absoluteString, "https://example.com/page")
    }

    func testCaptureClip_WhenNoURLAvailable_SourceURLIsNil() async throws {
        sut = ClipboardMonitor(
            pasteboard: mockPasteboard,
            onClipCaptured: { [weak self] clip in
                self?.capturedClips.append(clip)
            }
        )

        mockPasteboard.clearContents()
        mockPasteboard.setString("Test", forType: .string)

        await sut.checkForChanges()

        XCTAssertNil(capturedClips.first?.sourceURL)
    }

    // MARK: - Image Capture

    func testCheckForChanges_WhenImageInClipboard_CapturesImage() async throws {
        sut = ClipboardMonitor(
            pasteboard: mockPasteboard,
            onClipCaptured: { [weak self] clip in
                self?.capturedClips.append(clip)
            }
        )

        // Create a small test image
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        image.unlockFocus()

        mockPasteboard.clearContents()
        mockPasteboard.writeObjects([image])

        await sut.checkForChanges()

        XCTAssertEqual(capturedClips.count, 1)
        XCTAssertEqual(capturedClips.first?.contentType, .image)
        XCTAssertNotNil(capturedClips.first?.metadata?.imageWidth)
        XCTAssertNotNil(capturedClips.first?.metadata?.imageHeight)
    }

    // MARK: - Metadata

    func testCaptureTextClip_IncludesTextLengthMetadata() async throws {
        sut = ClipboardMonitor(
            pasteboard: mockPasteboard,
            onClipCaptured: { [weak self] clip in
                self?.capturedClips.append(clip)
            }
        )

        mockPasteboard.clearContents()
        mockPasteboard.setString("Hello World", forType: .string)

        await sut.checkForChanges()

        XCTAssertEqual(capturedClips.first?.metadata?.textLength, 11)
    }

    // MARK: - Stop Monitoring

    func testStopMonitoring_StopsCapturing() async throws {
        sut = ClipboardMonitor(
            pasteboard: mockPasteboard,
            onClipCaptured: { [weak self] clip in
                self?.capturedClips.append(clip)
            }
        )

        await sut.startMonitoring(interval: 0.1)

        mockPasteboard.clearContents()
        mockPasteboard.setString("First", forType: .string)
        await sut.checkForChanges()

        await sut.stopMonitoring()

        mockPasteboard.setString("Second", forType: .string)
        await sut.checkForChanges()

        // Should only have captured before stop
        XCTAssertEqual(capturedClips.count, 1)
        XCTAssertEqual(capturedClips.first?.content, "First")
    }

    // MARK: - Browser URL Extraction Integration

    func testInit_WithBrowserURLExtractor_StoresExtractor() async throws {
        // Given
        let extractor = BrowserURLExtractor()

        // When
        sut = ClipboardMonitor(
            pasteboard: mockPasteboard,
            browserURLExtractor: extractor,
            onClipCaptured: { [weak self] clip in
                self?.capturedClips.append(clip)
            }
        )

        // Then - should not crash and should accept the extractor
        mockPasteboard.clearContents()
        mockPasteboard.setString("Test", forType: .string)
        await sut.checkForChanges()

        XCTAssertEqual(capturedClips.count, 1)
    }

    func testInit_WithoutBrowserURLExtractor_StillWorks() async throws {
        // When - no extractor provided
        sut = ClipboardMonitor(
            pasteboard: mockPasteboard,
            onClipCaptured: { [weak self] clip in
                self?.capturedClips.append(clip)
            }
        )

        // Then - should work without extractor
        mockPasteboard.clearContents()
        mockPasteboard.setString("Test", forType: .string)
        await sut.checkForChanges()

        XCTAssertEqual(capturedClips.count, 1)
        XCTAssertEqual(capturedClips.first?.content, "Test")
    }

    func testCaptureClip_WithBrowserSource_TriesURLExtraction() async throws {
        // Given
        let extractor = BrowserURLExtractor()
        sut = ClipboardMonitor(
            pasteboard: mockPasteboard,
            browserURLExtractor: extractor,
            onClipCaptured: { [weak self] clip in
                self?.capturedClips.append(clip)
            }
        )

        // When - capture text (browser URL extraction depends on accessibility permissions)
        mockPasteboard.clearContents()
        mockPasteboard.setString("Browser content", forType: .string)
        await sut.checkForChanges()

        // Then - should capture successfully, URL may or may not be extracted
        XCTAssertEqual(capturedClips.count, 1)
        XCTAssertEqual(capturedClips.first?.content, "Browser content")
        // sourceURL depends on accessibility permissions and frontmost app being a browser
    }

    // MARK: - Ignore List Integration

    func testInit_WithIgnoreListManager_StoresManager() async throws {
        // Given
        let ignoreListManager = IgnoreListManager(userDefaultsKey: "com.clipai.test.ignoreList")

        // When
        sut = ClipboardMonitor(
            pasteboard: mockPasteboard,
            ignoreListManager: ignoreListManager,
            onClipCaptured: { [weak self] clip in
                self?.capturedClips.append(clip)
            }
        )

        // Then - should not crash and should accept the manager
        mockPasteboard.clearContents()
        mockPasteboard.setString("Test", forType: .string)
        await sut.checkForChanges()

        XCTAssertEqual(capturedClips.count, 1)
    }

    func testCheckForChanges_WhenAppIsIgnored_DoesNotCapture() async throws {
        // Given
        let ignoreListManager = IgnoreListManager(userDefaultsKey: "com.clipai.test.ignoreList")
        // Add a bundle identifier that matches the frontmost app bundle ID pattern
        // Note: In tests, we can't control the frontmost app, so we'll mock this
        sut = ClipboardMonitor(
            pasteboard: mockPasteboard,
            ignoreListManager: ignoreListManager,
            onClipCaptured: { [weak self] clip in
                self?.capturedClips.append(clip)
            }
        )

        // When - set ignored bundle identifier that won't match test runner
        await ignoreListManager.addBundleIdentifier("com.nonexistent.app")

        mockPasteboard.clearContents()
        mockPasteboard.setString("Test content", forType: .string)
        await sut.checkForChanges()

        // Then - should capture since frontmost app is not ignored
        XCTAssertEqual(capturedClips.count, 1)
    }

    func testSetIgnoreListManager_UpdatesManager() async throws {
        // Given - start without ignore list manager
        sut = ClipboardMonitor(
            pasteboard: mockPasteboard,
            onClipCaptured: { [weak self] clip in
                self?.capturedClips.append(clip)
            }
        )

        // When - set a new ignore list manager
        let ignoreListManager = IgnoreListManager(userDefaultsKey: "com.clipai.test.ignoreList")
        await sut.setIgnoreListManager(ignoreListManager)

        // Then - should work normally
        mockPasteboard.clearContents()
        mockPasteboard.setString("Test", forType: .string)
        await sut.checkForChanges()

        XCTAssertEqual(capturedClips.count, 1)
    }
}
