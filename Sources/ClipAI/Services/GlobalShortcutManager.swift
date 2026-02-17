import AppKit
import Carbon
import OSLog

// MARK: - GlobalShortcutManager

/// Manages global keyboard shortcuts for ClipAI.
/// Uses NSEvent.addGlobalMonitorForEvents to detect shortcuts when the app is not active.
final class GlobalShortcutManager {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.clipai.app", category: "GlobalShortcutManager")

    /// The key code for the shortcut (e.g., 9 for 'V')
    private let keyCode: UInt16

    /// The modifier flags required for the shortcut
    private let modifiers: NSEvent.ModifierFlags

    /// The callback to invoke when the shortcut is pressed
    private let callback: @Sendable () -> Void

    /// The event monitor for global events
    private var eventMonitor: Any?

    /// Whether the shortcut manager is currently monitoring
    private(set) var isRunning: Bool = false

    // MARK: - Initialization

    /// Creates a new GlobalShortcutManager.
    /// - Parameters:
    ///   - keyCode: The key code for the shortcut (e.g., 9 for 'V')
    ///   - modifiers: The modifier flags required
    ///   - callback: The callback to invoke when shortcut is pressed
    init(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        callback: @escaping @Sendable () -> Void
    ) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.callback = callback
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    /// Starts monitoring for the global shortcut.
    func start() {
        guard !isRunning else { return }

        // Monitor global events (when app is not active)
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            if self.matchesShortcut(keyCode: event.keyCode, modifiers: event.modifierFlags) {
                self.logger.debug("Global shortcut detected")
                self.callback()
            }
        }

        isRunning = true
        logger.info("Global shortcut monitoring started")
    }

    /// Stops monitoring for the global shortcut.
    func stop() {
        guard let monitor = eventMonitor else { return }
        NSEvent.removeMonitor(monitor)
        eventMonitor = nil
        isRunning = false
        logger.info("Global shortcut monitoring stopped")
    }

    /// Checks if the given key code and modifiers match the configured shortcut.
    /// - Parameters:
    ///   - keyCode: The key code to check
    ///   - modifiers: The modifier flags to check
    /// - Returns: True if they match the configured shortcut
    func matchesShortcut(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        // Check key code matches
        guard keyCode == self.keyCode else { return false }

        // Convert to comparable sets - remove device-specific flags
        let expectedFlags = self.modifiers.intersection(.deviceIndependentFlagsMask)
        let actualFlags = modifiers.intersection(.deviceIndependentFlagsMask)

        return expectedFlags == actualFlags
    }

    /// Simulates a shortcut press (for testing).
    func simulateShortcutPress() {
        callback()
    }

    // MARK: - Factory Methods

    /// Creates a GlobalShortcutManager with the default Cmd+Shift+V shortcut.
    /// - Parameter callback: The callback to invoke when shortcut is pressed
    /// - Returns: A configured GlobalShortcutManager
    static func defaultShortcut(callback: @escaping @Sendable () -> Void) -> GlobalShortcutManager {
        // V key has key code 9
        GlobalShortcutManager(
            keyCode: 9,
            modifiers: [.command, .shift],
            callback: callback
        )
    }
}
