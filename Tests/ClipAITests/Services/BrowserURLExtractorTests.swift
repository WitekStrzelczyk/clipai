import AppKit
import XCTest
@testable import ClipAI

final class BrowserURLExtractorTests: XCTestCase {
    var sut: BrowserURLExtractor!

    override func setUp() async throws {
        try await super.setUp()
        sut = BrowserURLExtractor()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Permission Checking

    func testCheckAccessibilityPermissions_ReturnsBool() {
        // When
        let hasPermissions = sut.checkAccessibilityPermissions()

        // Then - just verify it returns a bool without crashing
        // The actual value depends on system settings
        _ = hasPermissions
    }

    // MARK: - Browser Detection

    func testIsSupportedBrowser_WithSafari_ReturnsTrue() {
        // Safari bundle ID
        XCTAssertTrue(sut.isSupportedBrowser(bundleIdentifier: "com.apple.Safari"))
    }

    func testIsSupportedBrowser_WithChrome_ReturnsTrue() {
        // Chrome bundle ID
        XCTAssertTrue(sut.isSupportedBrowser(bundleIdentifier: "com.google.Chrome"))
    }

    func testIsSupportedBrowser_WithFirefox_ReturnsTrue() {
        // Firefox bundle ID
        XCTAssertTrue(sut.isSupportedBrowser(bundleIdentifier: "org.mozilla.firefox"))
    }

    func testIsSupportedBrowser_WithEdge_ReturnsTrue() {
        // Edge bundle ID
        XCTAssertTrue(sut.isSupportedBrowser(bundleIdentifier: "com.microsoft.edgemac"))
    }

    func testIsSupportedBrowser_WithUnsupportedApp_ReturnsFalse() {
        // Not a browser
        XCTAssertFalse(sut.isSupportedBrowser(bundleIdentifier: "com.apple.finder"))
        XCTAssertFalse(sut.isSupportedBrowser(bundleIdentifier: "com.microsoft.Word"))
        XCTAssertFalse(sut.isSupportedBrowser(bundleIdentifier: nil), "nil bundle ID should return false")
    }

    // MARK: - URL Extraction

    func testExtractURL_WithNilApp_ReturnsNil() {
        // When
        let result: URL? = sut.extractURL(from: nil)

        // Then
        XCTAssertNil(result)
    }

    func testExtractURL_WithNonBrowserApp_ReturnsNil() {
        // Given - find a non-browser app
        let apps = NSWorkspace.shared.runningApplications
        let nonBrowserApp = apps.first { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return !sut.isSupportedBrowser(bundleIdentifier: bundleId)
        }

        // When
        let result = sut.extractURL(from: nonBrowserApp)

        // Then - should return nil for non-browser apps
        XCTAssertNil(result)
    }

    func testExtractURL_WithoutAccessibilityPermissions_ReturnsNilGracefully() throws {
        // This test verifies graceful fallback when permissions are not granted
        // Given - find a browser app (or use Safari if running)
        let apps = NSWorkspace.shared.runningApplications
        let browserApp = apps.first {
            $0.bundleIdentifier == "com.apple.Safari" ||
            $0.bundleIdentifier == "com.google.Chrome"
        }

        // Skip test if no browser is running
        guard browserApp != nil else {
            throw XCTSkip("No supported browser is running")
        }

        // When - if permissions are not granted, should return nil gracefully
        // Note: This test doesn't modify actual permissions, just verifies the method doesn't crash
        let result = sut.extractURL(from: browserApp)

        // Then - should either return a URL or nil, but never crash
        // We can't assert the exact value without controlling accessibility permissions
        _ = result
    }

    // MARK: - Supported Browsers List

    func testSupportedBrowsers_ContainsExpectedBrowsers() {
        // When
        let supportedBrowsers = sut.supportedBrowsers

        // Then
        XCTAssertTrue(supportedBrowsers.contains("com.apple.Safari"))
        XCTAssertTrue(supportedBrowsers.contains("com.google.Chrome"))
        XCTAssertTrue(supportedBrowsers.contains("org.mozilla.firefox"))
        XCTAssertTrue(supportedBrowsers.contains("com.microsoft.edgemac"))
    }
}
