import AppKit
import OSLog
import SwiftUI

// MARK: - Logging Helper

/// Log file URL for debugging
private var logFileURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".clipai/clipai.log")
}

/// Writes a log message to file, os_log, and console
func logDebug(_ message: String) {
    let formatted = "[ClipAI] \(message)"
    print(formatted)
    writeToFile(formatted)
}

func logInfo(_ message: String) {
    let formatted = "[ClipAI] INFO: \(message)"
    print(formatted)
    writeToFile(formatted)
}

func logError(_ message: String) {
    let formatted = "[ClipAI] ERROR: \(message)"
    print(formatted)
    writeToFile(formatted)
}

private func writeToFile(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "\(timestamp) \(message)\n"
    guard let data = line.data(using: .utf8) else { return }

    // Create directory if needed
    let dir = logFileURL.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: dir.path) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // Append to file
    if FileManager.default.fileExists(atPath: logFileURL.path) {
        let handle = try? FileHandle(forWritingTo: logFileURL)
        handle?.seekToEndOfFile()
        handle?.write(data)
        handle?.closeFile()
    } else {
        try? data.write(to: logFileURL)
    }
}

// MARK: - App

@main
struct ClipAIApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    init() {
        // Set up as accessory app (menu bar only, no dock icon)
        NSApplication.shared.setActivationPolicy(.accessory)
        logInfo("ClipAIApp initialized - set activation policy to accessory")
    }

    var body: some Scene {
        // Empty scene - we run as background app
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.clipai.app", category: "AppDelegate")
    private var clipboardMonitor: ClipboardMonitor!
    private var clipStorage: ClipStorage!
    private var statusItem: NSStatusItem?
    private var browserURLExtractor: BrowserURLExtractor?
    private var overlayWindowController: OverlayWindowController?
    private var globalShortcutManager: GlobalShortcutManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logInfo("=== ClipAI Starting Up ===")
        logger.info("ClipAI starting up")

        // Create status bar item (keeps app alive)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipAI")
            button.toolTip = "ClipAI - Clipboard Manager"
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        logInfo("Status bar item created")

        // Set up storage directory (hidden directory)
        let storageDirectory = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".clipai")

        // Initialize storage first
        clipStorage = ClipStorage(storageDirectory: storageDirectory)

        // Initialize overlay window controller with storage
        overlayWindowController = OverlayWindowController(storage: clipStorage)
        logInfo("Overlay window controller initialized")

        // Initialize global shortcut manager (Cmd+Shift+V)
        globalShortcutManager = GlobalShortcutManager.defaultShortcut { [weak self] in
            logDebug("Global shortcut Cmd+Shift+V pressed")
            DispatchQueue.main.async {
                self?.overlayWindowController?.toggle()
            }
        }
        globalShortcutManager?.start()
        logInfo("Global shortcut manager started - Cmd+Shift+V to toggle overlay")

        // Initialize browser URL extractor and check permissions
        browserURLExtractor = BrowserURLExtractor()
        if let extractor = browserURLExtractor {
            let hasPermissions = extractor.checkAccessibilityPermissions()
            let statusText = hasPermissions ? "granted" : "not granted"
            logInfo("Accessibility permissions for browser URL extraction: \(statusText)")
            logger.info("Accessibility permissions: \(statusText)")

            if !hasPermissions {
                logInfo(
                    "Browser URL extraction disabled. Grant accessibility permissions " +
                    "in System Preferences > Privacy & Security > Accessibility."
                )
            }
        }

        // Initialize and start clipboard monitoring
        clipboardMonitor = ClipboardMonitor(
            browserURLExtractor: browserURLExtractor
        ) { [weak self] clip in
            logInfo("Callback received - new clip captured: \(clip.id)")
            guard let self = self else {
                logError("Self is nil in callback")
                return
            }
            Task { [weak self] in
                guard let self = self else {
                    logError("Self is nil in Task")
                    return
                }
                do {
                    try await self.clipStorage.save(clip)
                    logInfo("Successfully saved clip: \(clip.id)")
                    self.logger.info("Saved clip: \(clip.id)")
                } catch {
                    logError("Failed to save clip: \(error.localizedDescription)")
                    self.logger.error("Failed to save clip: \(error.localizedDescription)")
                }
            }
        }
        logDebug("ClipboardMonitor created")

        // Start monitoring with default 500ms interval
        Task { [weak self] in
            logDebug("Starting monitoring task...")
            guard let self = self else {
                logError("Self is nil when starting monitor")
                return
            }

            // Load existing clips from disk
            do {
                try await self.clipStorage.loadFromDisk()
                logDebug("ClipStorage loaded from disk")
            } catch {
                logError("Failed to load clips from disk: \(error.localizedDescription)")
                self.logger.error("Failed to load clips from disk: \(error.localizedDescription)")
            }

            await self.clipboardMonitor.startMonitoring(interval: 0.5)
            logInfo("Clipboard monitoring started successfully")
        }

        logInfo("=== ClipAI is now monitoring clipboard ===")
        logger.info("ClipAI is now monitoring clipboard")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logInfo("=== ClipAI Shutting Down ===")
        logger.info("ClipAI shutting down")

        // Stop global shortcut manager
        globalShortcutManager?.stop()
        logInfo("Global shortcut manager stopped")

        Task { [weak self] in
            await self?.clipboardMonitor?.stopMonitoring()
            logInfo("Monitoring stopped")
        }
    }

    // MARK: - Actions

    @objc private func statusBarButtonClicked() {
        logDebug("Status bar button clicked")
        overlayWindowController?.toggle()
    }
}
