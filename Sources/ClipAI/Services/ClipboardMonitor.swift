import AppKit
import Foundation
import OSLog

/// Log file URL for debugging
private var monitorLogFileURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("clipai/clipai.log")
}

/// Writes a log message to file and console
private func monitorLog(_ message: String) {
    let formatted = "[ClipAI-Monitor] \(message)"
    print(formatted)
    writeToLogFile(formatted)
}

private func writeToLogFile(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "\(timestamp) \(message)\n"
    guard let data = line.data(using: .utf8) else { return }

    // Create directory if needed
    let dir = monitorLogFileURL.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: dir.path) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // Append to file
    if FileManager.default.fileExists(atPath: monitorLogFileURL.path) {
        let handle = try? FileHandle(forWritingTo: monitorLogFileURL)
        handle?.seekToEndOfFile()
        handle?.write(data)
        handle?.closeFile()
    } else {
        try? data.write(to: monitorLogFileURL)
    }
}

/// Actor responsible for monitoring clipboard changes.
actor ClipboardMonitor {
    private let logger = Logger(subsystem: "com.clipai.app", category: "ClipboardMonitor")
    private let pasteboard: NSPasteboard
    private var changeCount: Int
    private var lastCapturedContent: String?
    private var lastCaptureTime: Date?
    private var isMonitoring = false

    /// Nonisolated holder for the timer to avoid actor isolation issues
    /// Uses nonisolated(unsafe) since timer is only accessed from main thread
    private nonisolated(unsafe) var timer: Timer?

    /// The deduplication window in seconds.
    private let deduplicationWindow: TimeInterval = 5.0

    /// Callback invoked when a new clip is captured.
    private let onClipCaptured: @Sendable (Clip) async -> Void

    /// Optional browser URL extractor for extracting URLs from browser address bars.
    private let browserURLExtractor: BrowserURLExtractor?

    /// Whether accessibility permissions are available for browser URL extraction.
    private var hasAccessibilityPermissions: Bool = false

    /// Creates a new ClipboardMonitor instance.
    /// - Parameters:
    ///   - pasteboard: The pasteboard to monitor (defaults to general pasteboard).
    ///   - browserURLExtractor: Optional extractor for browser URLs (defaults to new instance).
    ///   - onClipCaptured: Callback invoked when a clip is captured.
    init(
        pasteboard: NSPasteboard = .general,
        browserURLExtractor: BrowserURLExtractor? = BrowserURLExtractor(),
        onClipCaptured: @escaping @Sendable (Clip) async -> Void
    ) {
        self.pasteboard = pasteboard
        self.browserURLExtractor = browserURLExtractor
        self.onClipCaptured = onClipCaptured
        self.changeCount = pasteboard.changeCount

        // Check accessibility permissions on init
        if let extractor = browserURLExtractor {
            self.hasAccessibilityPermissions = extractor.checkAccessibilityPermissions()
            monitorLog("ClipboardMonitor initialized - accessibility permissions: \(hasAccessibilityPermissions)")
        } else {
            self.hasAccessibilityPermissions = false
            monitorLog("ClipboardMonitor initialized - no browser URL extractor")
        }

        monitorLog("ClipboardMonitor initialized with initial changeCount: \(changeCount)")
    }

    /// Starts monitoring the clipboard for changes.
    /// - Parameter interval: The polling interval in seconds (default 0.5).
    func startMonitoring(interval: TimeInterval = 0.5) {
        guard !isMonitoring else {
            monitorLog("Already monitoring, skipping start")
            return
        }

        isMonitoring = true
        monitorLog("Starting clipboard monitoring with interval: \(interval)s")
        logger.info("Starting clipboard monitoring with interval: \(interval)s")

        // Capture self as unowned to avoid retain cycle
        unowned let unownedSelf = self

        // Create timer on main thread to ensure it works with the run loop
        DispatchQueue.main.async {
            let newTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                Task {
                    await unownedSelf.checkForChanges()
                }
            }
            unownedSelf.timer = newTimer

            // Ensure timer runs in common run loop modes
            RunLoop.main.add(newTimer, forMode: .common)
            monitorLog("Timer scheduled on main run loop")
        }
    }

    /// Stops monitoring the clipboard.
    func stopMonitoring() {
        guard isMonitoring else {
            monitorLog("Not monitoring, skipping stop")
            return
        }

        isMonitoring = false

        // Invalidate timer on main thread
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = nil
            monitorLog("Timer invalidated")
        }

        monitorLog("Stopped clipboard monitoring")
        logger.info("Stopped clipboard monitoring")
    }

    /// Manually checks for clipboard changes (useful for testing).
    func checkForChanges() async {
        let currentChangeCount = pasteboard.changeCount

        // Log every check for debugging (can be noisy, but helpful)
        // monitorLog("Checking... current: \(currentChangeCount), last: \(changeCount)")

        // Check if change count has changed
        guard currentChangeCount != changeCount else { return }

        monitorLog("CHANGE DETECTED! Old count: \(changeCount), New count: \(currentChangeCount)")
        changeCount = currentChangeCount

        // Try to capture clip from clipboard
        if let clip = await captureClipFromPasteboard() {
            monitorLog("Clip captured from pasteboard: \(clip.id), type: \(clip.contentType)")

            // Check for duplicates within deduplication window
            if !isDuplicate(clip) {
                lastCapturedContent = clip.content
                lastCaptureTime = Date()
                monitorLog("New unique clip - invoking callback")
                logger.debug("Captured new clip: \(clip.id)")
                await onClipCaptured(clip)
                monitorLog("Callback completed for clip: \(clip.id)")
            } else {
                monitorLog("Skipped duplicate clip within deduplication window")
                logger.debug("Skipped duplicate clip within deduplication window")
            }
        } else {
            monitorLog("No supported content in clipboard")
        }
    }

    // MARK: - Private

    private func captureClipFromPasteboard() async -> Clip? {
        // Try to get text content first
        if let text = pasteboard.string(forType: .string) {
            return createTextClip(text)
        }

        // Try to get image content
        if let image = NSImage(pasteboard: pasteboard) {
            return createImageClip(image)
        }

        logger.debug("No supported content type found in clipboard")
        return nil
    }

    private func createTextClip(_ text: String) -> Clip {
        let sourceApp = getSourceApplication()
        var sourceURL = getSourceURL()

        // If no URL from pasteboard, try to extract from browser address bar
        if sourceURL == nil, hasAccessibilityPermissions, let extractor = browserURLExtractor {
            let frontmostApp = NSWorkspace.shared.frontmostApplication
            if let app = frontmostApp, extractor.isSupportedBrowser(bundleIdentifier: app.bundleIdentifier) {
                sourceURL = extractor.extractURL(from: app)
                if let url = sourceURL {
                    monitorLog("Extracted browser URL: \(url.absoluteString)")
                }
            }
        }

        let metadata = ClipMetadata(textLength: text.count)

        return Clip(
            content: text,
            contentType: .text,
            sourceApp: sourceApp,
            sourceURL: sourceURL,
            metadata: metadata
        )
    }

    private func createImageClip(_ image: NSImage) -> Clip {
        let sourceApp = getSourceApplication()

        // Get image dimensions
        let imageWidth = Int(image.size.width)
        let imageHeight = Int(image.size.height)

        let metadata = ClipMetadata(imageWidth: imageWidth, imageHeight: imageHeight)

        // Convert image to base64
        let base64Content = imageToBase64(image)

        return Clip(
            content: base64Content,
            contentType: .image,
            sourceApp: sourceApp,
            sourceURL: nil,
            metadata: metadata
        )
    }

    private func getSourceApplication() -> String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }

    private func getSourceURL() -> URL? {
        // Try to get URL from pasteboard
        if let urlString = pasteboard.string(forType: .URL),
           let url = URL(string: urlString)
        {
            return url
        }

        // Also check for URL in string format
        if let urlString = pasteboard.string(forType: .string),
           let url = URL(string: urlString),
           let scheme = url.scheme,
           ["http", "https"].contains(scheme)
        {
            return url
        }

        return nil
    }

    private func isDuplicate(_ clip: Clip) -> Bool {
        guard let lastContent = lastCapturedContent,
              let lastTime = lastCaptureTime
        else {
            return false
        }

        let timeSinceLastCapture = Date().timeIntervalSince(lastTime)

        return clip.content == lastContent && timeSinceLastCapture < deduplicationWindow
    }

    private func imageToBase64(_ image: NSImage) -> String {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            logger.warning("Failed to convert image to PNG data")
            return ""
        }

        return pngData.base64EncodedString()
    }
}
