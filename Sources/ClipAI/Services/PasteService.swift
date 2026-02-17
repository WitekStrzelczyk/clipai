import AppKit
import Carbon
import OSLog

// MARK: - PasteboardProtocol

/// Protocol for NSPasteboard to enable testing with mocks.
protocol PasteboardProtocol: AnyObject {
    func clearContents() -> Int
    func setString(_ string: String, forType type: NSPasteboard.PasteboardType) -> Bool
    func string(forType type: NSPasteboard.PasteboardType) -> String?
}

// MARK: - NSPasteboard Extension

extension NSPasteboard: PasteboardProtocol {}

// MARK: - PasteServiceProtocol

/// Protocol for PasteService to enable testing with mocks.
protocol PasteServiceProtocol: AnyObject {
    func copyToClipboard(_ clip: Clip) async throws
    func simulateCmdV() async throws
    func copyAndPaste(_ clip: Clip) async throws
}

// MARK: - PasteService

/// Service for copying clip content to clipboard and simulating paste operations.
final class PasteService: @unchecked Sendable {
    // MARK: - Constants

    /// Delay in seconds between setting clipboard and simulating paste.
    /// This ensures the clipboard is ready before we simulate Cmd+V.
    static let pasteDelay: TimeInterval = 0.05 // 50ms

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.clipai.app", category: "PasteService")
    private let pasteboard: PasteboardProtocol

    // MARK: - Initialization

    /// Creates a new PasteService with the general pasteboard.
    init() {
        self.pasteboard = NSPasteboard.general
    }

    /// Creates a new PasteService with a custom pasteboard (for testing).
    /// - Parameter pasteboard: The pasteboard to use.
    init(pasteboard: PasteboardProtocol) {
        self.pasteboard = pasteboard
    }

    // MARK: - Public Methods

    /// Copies the clip content to the clipboard.
    /// - Parameter clip: The clip to copy.
    /// - Throws: PasteError if the copy fails.
    func copyToClipboard(_ clip: Clip) async throws {
        logger.debug("Copying clip to clipboard: \(clip.id)")

        // Clear the pasteboard first
        _ = pasteboard.clearContents()

        // Set the content based on clip type
        switch clip.contentType {
        case .text:
            let success = pasteboard.setString(clip.content, forType: .string)
            guard success else {
                logger.error("Failed to set clipboard content")
                throw PasteError.clipboardSetFailed
            }
        case .image:
            // For images, the content is base64-encoded
            // We'll store it as a string for now (full image support in future stories)
            let success = pasteboard.setString(clip.content, forType: .string)
            guard success else {
                logger.error("Failed to set clipboard content")
                throw PasteError.clipboardSetFailed
            }
        }

        logger.info("Successfully copied clip to clipboard")
    }

    /// Simulates a Cmd+V keystroke to paste from the clipboard.
    /// - Throws: PasteError if the simulation fails.
    func simulateCmdV() async throws {
        logger.debug("Simulating Cmd+V keystroke")

        // Create key down event
        let source = CGEventSource(stateID: .combinedSessionState)
        let cmdVDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(9), // V key
            keyDown: true
        )

        // Set modifier flags (Command)
        cmdVDown?.flags = .maskCommand

        // Post the key down event
        cmdVDown?.post(tap: .cghidEventTap)

        // Create key up event
        let cmdVUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(9),
            keyDown: false
        )
        cmdVUp?.flags = .maskCommand

        // Post the key up event
        cmdVUp?.post(tap: .cghidEventTap)

        logger.info("Successfully simulated Cmd+V")
    }

    /// Copies the clip to clipboard and then simulates a paste.
    /// Includes a small delay between operations to ensure clipboard is ready.
    /// - Parameter clip: The clip to copy and paste.
    /// - Throws: PasteError if either operation fails.
    func copyAndPaste(_ clip: Clip) async throws {
        // Copy to clipboard
        try await copyToClipboard(clip)

        // Small delay to ensure clipboard is ready
        try await Task.sleep(for: .seconds(Self.pasteDelay))

        // Simulate Cmd+V
        try await simulateCmdV()
    }
}

// MARK: - PasteServiceProtocol Conformance

extension PasteService: PasteServiceProtocol {}

// MARK: - PasteError

/// Errors that can occur during paste operations.
enum PasteError: LocalizedError {
    case clipboardSetFailed
    case pasteSimulationFailed

    var errorDescription: String? {
        switch self {
        case .clipboardSetFailed:
            return "Failed to set clipboard content"
        case .pasteSimulationFailed:
            return "Failed to simulate paste keystroke"
        }
    }
}
