import AppKit
import XCTest

@testable import ClipAI

@MainActor
final class OverlayWindowControllerTests: XCTestCase {
    var sut: OverlayWindowController!
    var testStorage: ClipStorage!
    var testDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        // Create a unique test directory
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipAITests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        testStorage = ClipStorage(storageDirectory: testDirectory)
        try await testStorage.loadFromDisk()
        sut = OverlayWindowController(storage: testStorage)
    }

    override func tearDown() async throws {
        sut.close()
        sut = nil
        // Clean up test directory
        if let testDirectory = testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }
        testStorage = nil
        try await super.tearDown()
    }

    // MARK: - Window Configuration Tests

    func testWindow_whenCreated_isNSPanel() {
        // Then
        XCTAssertTrue(sut.window is NSPanel, "Window should be an NSPanel")
    }

    func testWindow_whenCreated_hasFloatingLevel() {
        // Then
        XCTAssertEqual(sut.window?.level, .floating, "Window should have floating level")
    }

    func testWindow_whenCreated_hasCorrectSize() {
        // Then
        let expectedSize = CGSize(width: 600, height: 400)
        let windowFrame = sut.window?.frame ?? .zero
        XCTAssertEqual(windowFrame.width, expectedSize.width, accuracy: 1.0, "Window width should be ~600")
        XCTAssertEqual(windowFrame.height, expectedSize.height, accuracy: 1.0, "Window height should be ~400")
    }

    func testWindow_whenCreated_canBecomeKeyForTextInput() {
        // Then - NSPanel should become key to allow text input
        guard let panel = sut.window as? NSPanel else {
            XCTFail("Window should be NSPanel")
            return
        }
        // becomesKeyOnlyIfNeeded = false allows the panel to become key
        // which is required for text field focus and keyboard navigation
        XCTAssertFalse(panel.becomesKeyOnlyIfNeeded, "Panel should be able to become key for text input")
    }

    func testWindow_whenCreated_canBecomeKey() {
        // Then
        XCTAssertTrue(sut.window?.canBecomeKey ?? false, "Window should be able to become key")
    }

    func testWindow_whenCreated_cannotBecomeMain() {
        // Then
        XCTAssertFalse(sut.window?.canBecomeMain ?? true, "Window should not be able to become main")
    }

    func testWindow_whenCreated_isMovableByWindowBackground() {
        // Then
        XCTAssertTrue(sut.window?.isMovableByWindowBackground ?? false, "Window should be movable by background")
    }

    func testWindow_whenCreated_hasRoundedCorners() {
        // Then
        XCTAssertTrue(
            sut.window?.styleMask.contains(.fullSizeContentView) ?? false,
            "Window should have full size content view for styling"
        )
    }

    func testWindow_whenCreated_isOverlayPanel() {
        // Then
        XCTAssertTrue(sut.window is OverlayPanel, "Window should be an OverlayPanel")
    }

    // MARK: - Show/Hide Tests

    func testShow_makesWindowVisible() {
        // When
        sut.show()

        // Then
        XCTAssertTrue(sut.window?.isVisible ?? false, "Window should be visible after show()")
    }

    func testHide_hidesWindow() {
        // Given
        sut.show()

        // When
        sut.hide()

        // Then
        XCTAssertFalse(sut.window?.isVisible ?? true, "Window should not be visible after hide()")
    }

    func testToggle_whenHidden_showsWindow() {
        // Given
        XCTAssertFalse(sut.window?.isVisible ?? true)

        // When
        sut.toggle()

        // Then
        XCTAssertTrue(sut.window?.isVisible ?? false, "Window should be visible after toggle when hidden")
    }

    func testToggle_whenVisible_hidesWindow() {
        // Given
        sut.show()
        XCTAssertTrue(sut.window?.isVisible ?? false)

        // When
        sut.toggle()

        // Then
        XCTAssertFalse(sut.window?.isVisible ?? true, "Window should be hidden after toggle when visible")
    }

    // MARK: - Position Tests

    func testShow_whenFirstShown_centersOnScreen() {
        // Given
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero

        // When
        sut.show()

        // Then
        let windowFrame = sut.window?.frame ?? .zero
        let expectedX = (screenFrame.width - windowFrame.width) / 2 + screenFrame.origin.x
        let expectedY = (screenFrame.height - windowFrame.height) / 2 + screenFrame.origin.y

        XCTAssertEqual(windowFrame.origin.x, expectedX, accuracy: 10.0, "Window should be centered horizontally")
        XCTAssertEqual(windowFrame.origin.y, expectedY, accuracy: 10.0, "Window should be centered vertically")
    }

    func testWindowPosition_whenMoved_isSavedToUserDefaults() {
        // Given
        let defaults = UserDefaults.standard
        let testKey = "com.clipai.overlay.position"
        defaults.removeObject(forKey: testKey)

        // When
        sut.show()
        let newPosition = NSPoint(x: 100, y: 200)
        sut.window?.setFrameOrigin(newPosition)
        sut.savePosition()
        sut.hide()

        // Then
        let savedData = defaults.data(forKey: testKey)
        XCTAssertNotNil(savedData, "Position should be saved to UserDefaults")

        // Verify the saved data can be decoded
        if let data = savedData,
           let dict = try? JSONDecoder().decode([String: CGFloat].self, from: data),
           let x = dict["x"],
           let y = dict["y"]
        {
            XCTAssertEqual(x, 100, accuracy: 1.0, "Saved X position should match")
            XCTAssertEqual(y, 200, accuracy: 1.0, "Saved Y position should match")
        } else {
            XCTFail("Failed to decode saved position")
        }

        // Cleanup
        defaults.removeObject(forKey: testKey)
    }

    func testShow_whenReopened_usesSavedPosition() {
        // Given
        let defaults = UserDefaults.standard
        let testKey = "com.clipai.overlay.position"
        let savedPosition = NSPoint(x: 150, y: 250)
        let positionData = try? JSONEncoder().encode(["x": savedPosition.x, "y": savedPosition.y])
        defaults.set(positionData, forKey: testKey)

        // When
        sut.show()

        // Then
        let windowFrame = sut.window?.frame ?? .zero
        XCTAssertEqual(windowFrame.origin.x, savedPosition.x, accuracy: 1.0, "Window should use saved X position")
        XCTAssertEqual(windowFrame.origin.y, savedPosition.y, accuracy: 1.0, "Window should use saved Y position")

        // Cleanup
        defaults.removeObject(forKey: testKey)
    }

    // MARK: - Collection Behavior Tests

    func testWindow_whenCreated_canJoinAllSpaces() {
        // Then
        let collectionBehavior = sut.window?.collectionBehavior ?? []
        XCTAssertTrue(collectionBehavior.contains(.canJoinAllSpaces), "Window should be able to join all spaces")
    }

    func testWindow_whenCreated_isTransient() {
        // Then
        let collectionBehavior = sut.window?.collectionBehavior ?? []
        XCTAssertTrue(collectionBehavior.contains(.transient), "Window should be transient")
    }

    // MARK: - Dismissal Tests

    func testHide_whenCalled_savesPosition() {
        // Given
        let defaults = UserDefaults.standard
        let testKey = "com.clipai.overlay.position"
        defaults.removeObject(forKey: testKey)
        sut.show()
        sut.window?.setFrameOrigin(NSPoint(x: 300, y: 400))

        // When
        sut.hide()

        // Then
        let savedData = defaults.data(forKey: testKey)
        XCTAssertNotNil(savedData, "Position should be saved when hiding")

        // Cleanup
        defaults.removeObject(forKey: testKey)
    }

    func testOverlayPanel_onDismiss_isCalledWhenEscapePressed() {
        // Given
        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        var dismissCalled = false
        panel.onDismiss = {
            dismissCalled = true
        }

        // When - Simulate Escape key press
        let escapeEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 53 // Escape key code
        )
        panel.keyDown(with: escapeEvent!)

        // Then
        XCTAssertTrue(dismissCalled, "onDismiss should be called when Escape is pressed")
    }

    func testOverlayPanel_onDismiss_isCalledWhenResignsKey() {
        // Given
        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        var dismissCalled = false
        panel.onDismiss = {
            dismissCalled = true
        }

        // Make panel visible and key
        panel.makeKeyAndOrderFront(nil)

        // When - Panel loses key status (simulates click outside)
        panel.resignKey()

        // Then
        XCTAssertTrue(dismissCalled, "onDismiss should be called when panel resigns key")
    }

    func testOverlayPanel_otherKeys_doNotTriggerDismiss() {
        // Given
        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        var dismissCalled = false
        panel.onDismiss = {
            dismissCalled = true
        }

        // When - Simulate 'A' key press
        let aEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0 // 'A' key code
        )
        panel.keyDown(with: aEvent!)

        // Then
        XCTAssertFalse(dismissCalled, "onDismiss should NOT be called for other keys")
    }
}
