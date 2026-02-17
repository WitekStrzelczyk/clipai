import AppKit
import OSLog
import SwiftUI

// MARK: - Overlay Panel

/// Custom NSPanel that handles Escape key and click-outside dismissal.
final class OverlayPanel: NSPanel {
    /// Callback invoked when the overlay should be dismissed.
    var onDismiss: (() -> Void)?

    // Allow panel to become key to receive keyboard events
    override var canBecomeKey: Bool { true }

    // Allow panel to accept first responder for text input
    override var acceptsFirstResponder: Bool { true }

    // Prevent panel from becoming main (doesn't show in window menu)
    override var canBecomeMain: Bool { false }

    // Handle keyboard events
    override func keyDown(with event: NSEvent) {
        // Dismiss on Escape key
        if event.keyCode == 53 { // Escape key
            onDismiss?()
            return
        }
        super.keyDown(with: event)
    }

    // Handle clicks outside the panel
    override func resignKey() {
        super.resignKey()
        // Dismiss when panel loses key status (click outside)
        if isVisible {
            onDismiss?()
        }
    }
}

// MARK: - Overlay Window Controller

/// Controller for managing the overlay panel window.
/// Implements a Raycast-style floating overlay that can be shown/hidden from the menu bar.
final class OverlayWindowController: NSWindowController {
    private let logger = Logger(subsystem: "com.clipai.app", category: "OverlayWindowController")

    /// UserDefaults key for storing window position
    private let positionKey = "com.clipai.overlay.position"

    /// Default window size
    private let defaultSize = CGSize(width: 600, height: 400)

    /// The storage service for loading clips
    private let storage: ClipStorage

    /// The view model for the overlay content
    private var viewModel: OverlayViewModel!

    // MARK: - Initialization

    /// Creates a new OverlayWindowController.
    /// - Parameter storage: The storage service for loading clips.
    init(storage: ClipStorage) {
        self.storage = storage

        // Create the panel with borderless style (no titlebar)
        let panel = OverlayPanel(
            contentRect: NSRect(origin: .zero, size: CGSize(width: 600, height: 400)),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure panel
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false // Allow panel to become key for text input
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear

        super.init(window: panel)

        // Create view model with storage
        self.viewModel = OverlayViewModel(storage: storage)

        // Set up paste completion callback to dismiss overlay
        viewModel.onClipPasted = { [weak self] in
            DispatchQueue.main.async {
                self?.hide()
            }
        }

        // Set up dismiss callback for ESC key
        viewModel.onDismiss = { [weak self] in
            DispatchQueue.main.async {
                self?.hide()
            }
        }

        // Set SwiftUI content
        let overlayView = OverlayView(viewModel: viewModel)
        panel.contentView = NSHostingView(rootView: overlayView)

        // Set up dismissal callback after super.init
        if let overlayPanel = window as? OverlayPanel {
            overlayPanel.onDismiss = { [weak self] in
                self?.hide()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    /// Shows the overlay window, positioning it at the saved location or centered if no saved position.
    func show() {
        guard let window = window else { return }

        // Load saved position or center on screen
        if let savedPosition = loadPosition() {
            var frame = window.frame
            frame.origin = savedPosition
            window.setFrame(frame, display: false)
        } else {
            centerOnScreen()
        }

        window.makeKeyAndOrderFront(nil)
        logger.debug("Overlay shown")
    }

    /// Hides the overlay window.
    func hide() {
        // Save position before hiding
        savePosition()
        window?.orderOut(nil)
        logger.debug("Overlay hidden")
    }

    /// Toggles the overlay visibility.
    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    /// Saves the current window position to UserDefaults.
    func savePosition() {
        guard let window = window else { return }
        let position = window.frame.origin

        do {
            let data = try JSONEncoder().encode(["x": position.x, "y": position.y])
            UserDefaults.standard.set(data, forKey: positionKey)
            logger.debug("Saved overlay position: \(position.x), \(position.y)")
        } catch {
            logger.error("Failed to save overlay position: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    /// Centers the window on the main screen.
    private func centerOnScreen() {
        guard let window = window,
              let screen = NSScreen.main
        else {
            return
        }

        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame

        let x = (screenFrame.width - windowFrame.width) / 2 + screenFrame.origin.x
        let y = (screenFrame.height - windowFrame.height) / 2 + screenFrame.origin.y

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Loads the saved window position from UserDefaults.
    /// - Returns: The saved position, or nil if none exists.
    private func loadPosition() -> NSPoint? {
        guard let data = UserDefaults.standard.data(forKey: positionKey),
              let dict = try? JSONDecoder().decode([String: CGFloat].self, from: data),
              let x = dict["x"],
              let y = dict["y"]
        else {
            return nil
        }

        return NSPoint(x: x, y: y)
    }
}
