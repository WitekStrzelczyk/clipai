import AppKit
import XCTest
@testable import ClipAI

final class GlobalShortcutManagerTests: XCTestCase {
    var sut: GlobalShortcutManager!
    var callbackCallCount = 0

    override func setUp() async throws {
        try await super.setUp()
        callbackCallCount = 0
    }

    override func tearDown() async throws {
        sut?.stop()
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization

    func testInit_WithValidShortcut_StoresDefaultShortcut() {
        // Given/When
        sut = GlobalShortcutManager(
            keyCode: 9, // V key
            modifiers: [.command, .shift]
        ) { }

        // Then - should not crash
        XCTAssertNotNil(sut)
    }

    func testInit_StoresCallback() {
        // Given
        let expectation = XCTestExpectation(description: "Callback called")
        sut = GlobalShortcutManager(
            keyCode: 9,
            modifiers: [.command, .shift]
        ) {
            expectation.fulfill()
        }

        // When - simulate callback directly
        sut.simulateShortcutPress()

        // Then
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Start/Stop

    func testStart_CanBeCalledMultipleTimes() {
        // Given
        sut = GlobalShortcutManager(
            keyCode: 9,
            modifiers: [.command, .shift]
        ) { }

        // When/Then - should not crash
        sut.start()
        sut.start()
    }

    func testStop_CanBeCalledWithoutStart() {
        // Given
        sut = GlobalShortcutManager(
            keyCode: 9,
            modifiers: [.command, .shift]
        ) { }

        // When/Then - should not crash
        sut.stop()
    }

    func testStop_CanBeCalledMultipleTimes() {
        // Given
        sut = GlobalShortcutManager(
            keyCode: 9,
            modifiers: [.command, .shift]
        ) { }
        sut.start()

        // When/Then - should not crash
        sut.stop()
        sut.stop()
    }

    // MARK: - Shortcut Matching

    func testMatchesShortcut_WithCorrectKeyCodeAndModifiers_ReturnsTrue() {
        // Given
        sut = GlobalShortcutManager(
            keyCode: 9, // V key
            modifiers: [.command, .shift]
        ) { }

        // When
        let matches = sut.matchesShortcut(keyCode: 9, modifiers: [.command, .shift])

        // Then
        XCTAssertTrue(matches)
    }

    func testMatchesShortcut_WithWrongKeyCode_ReturnsFalse() {
        // Given
        sut = GlobalShortcutManager(
            keyCode: 9, // V key
            modifiers: [.command, .shift]
        ) { }

        // When
        let matches = sut.matchesShortcut(keyCode: 0, modifiers: [.command, .shift])

        // Then
        XCTAssertFalse(matches)
    }

    func testMatchesShortcut_WithMissingModifier_ReturnsFalse() {
        // Given
        sut = GlobalShortcutManager(
            keyCode: 9,
            modifiers: [.command, .shift]
        ) { }

        // When
        let matches = sut.matchesShortcut(keyCode: 9, modifiers: [.command])

        // Then
        XCTAssertFalse(matches)
    }

    func testMatchesShortcut_WithExtraModifier_ReturnsFalse() {
        // Given
        sut = GlobalShortcutManager(
            keyCode: 9,
            modifiers: [.command, .shift]
        ) { }

        // When
        let matches = sut.matchesShortcut(keyCode: 9, modifiers: [.command, .shift, .option])

        // Then
        XCTAssertFalse(matches)
    }

    // MARK: - Is Running

    func testIsRunning_WhenNotStarted_ReturnsFalse() {
        // Given
        sut = GlobalShortcutManager(
            keyCode: 9,
            modifiers: [.command, .shift]
        ) { }

        // Then
        XCTAssertFalse(sut.isRunning)
    }

    func testIsRunning_WhenStarted_ReturnsTrue() {
        // Given
        sut = GlobalShortcutManager(
            keyCode: 9,
            modifiers: [.command, .shift]
        ) { }

        // When
        sut.start()

        // Then
        XCTAssertTrue(sut.isRunning)
    }

    func testIsRunning_WhenStopped_ReturnsFalse() {
        // Given
        sut = GlobalShortcutManager(
            keyCode: 9,
            modifiers: [.command, .shift]
        ) { }
        sut.start()

        // When
        sut.stop()

        // Then
        XCTAssertFalse(sut.isRunning)
    }

    // MARK: - Default Shortcut

    func testDefaultShortcut_IsCmdShiftV() {
        // Given
        sut = GlobalShortcutManager.defaultShortcut { }

        // When
        let matchesV = sut.matchesShortcut(keyCode: 9, modifiers: [.command, .shift])

        // Then
        XCTAssertTrue(matchesV)
    }
}
