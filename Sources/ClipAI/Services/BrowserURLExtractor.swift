import AppKit
import ApplicationServices
import Foundation
import OSLog

/// Service for extracting URLs from browser address bars using the Accessibility API.
/// Gracefully falls back when permissions are not available.
final class BrowserURLExtractor: Sendable {
    private let logger = Logger(subsystem: "com.clipai.app", category: "BrowserURLExtractor")

    /// Known browser bundle identifiers that this extractor supports.
    let supportedBrowsers: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.microsoft.edgemac"
    ]

    /// Creates a new BrowserURLExtractor instance.
    init() {}

    // MARK: - Permission Checking

    /// Checks if the app has accessibility permissions.
    /// - Returns: `true` if permissions are granted, `false` otherwise.
    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let hasPermissions = AXIsProcessTrustedWithOptions(options)
        logger.debug("Accessibility permissions check: \(hasPermissions)")
        return hasPermissions
    }

    /// Requests accessibility permissions by opening System Preferences.
    /// Note: This will prompt the user to grant permissions.
    func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        logger.info("Requested accessibility permissions")
    }

    // MARK: - Browser Detection

    /// Checks if the given bundle identifier corresponds to a supported browser.
    /// - Parameter bundleIdentifier: The bundle identifier to check.
    /// - Returns: `true` if this is a supported browser, `false` otherwise.
    func isSupportedBrowser(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier = bundleIdentifier else { return false }
        return supportedBrowsers.contains(bundleIdentifier)
    }

    // MARK: - URL Extraction

    /// Extracts the current URL from a browser's address bar.
    /// - Parameter app: The running application to extract the URL from.
    /// - Returns: The URL from the address bar, or `nil` if extraction failed.
    func extractURL(from app: NSRunningApplication?) -> URL? {
        guard let app = app else {
            logger.debug("Cannot extract URL: app is nil")
            return nil
        }

        // Check permissions first
        guard checkAccessibilityPermissions() else {
            logger.debug("Cannot extract URL: no accessibility permissions")
            return nil
        }

        // Check if this is a supported browser
        guard isSupportedBrowser(bundleIdentifier: app.bundleIdentifier) else {
            logger.debug("Cannot extract URL: \(app.bundleIdentifier ?? "unknown") is not a supported browser")
            return nil
        }

        // Extract based on browser type
        switch app.bundleIdentifier {
        case "com.apple.Safari":
            return extractURLFromSafari(app: app)
        case "com.google.Chrome":
            return extractURLFromChrome(app: app)
        case "org.mozilla.firefox":
            return extractURLFromFirefox(app: app)
        case "com.microsoft.edgemac":
            return extractURLFromEdge(app: app)
        default:
            return nil
        }
    }

    // MARK: - Private - Browser-Specific Extraction

    private func extractURLFromSafari(app: NSRunningApplication) -> URL? {
        let pid = app.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

        // Get the main window
        var windowRef: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(appRef, kAXMainWindowAttribute as CFString, &windowRef)

        guard windowResult == .success,
              let window = windowRef
        else {
            logger.debug("Failed to get Safari main window: \(windowResult.rawValue)")
            return nil
        }

        // Safari's address bar is typically in the toolbar
        // We look for the AXTextField with AXURL attribute or search in the toolbar
        return extractURLFromWindow(window, browserName: "Safari")
    }

    private func extractURLFromChrome(app: NSRunningApplication) -> URL? {
        let pid = app.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

        // Get the main window
        var windowRef: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(appRef, kAXMainWindowAttribute as CFString, &windowRef)

        guard windowResult == .success,
              let window = windowRef
        else {
            logger.debug("Failed to get Chrome main window: \(windowResult.rawValue)")
            return nil
        }

        return extractURLFromWindow(window, browserName: "Chrome")
    }

    private func extractURLFromFirefox(app: NSRunningApplication) -> URL? {
        let pid = app.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

        // Get the main window
        var windowRef: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(appRef, kAXMainWindowAttribute as CFString, &windowRef)

        guard windowResult == .success,
              let window = windowRef
        else {
            logger.debug("Failed to get Firefox main window: \(windowResult.rawValue)")
            return nil
        }

        return extractURLFromWindow(window, browserName: "Firefox")
    }

    private func extractURLFromEdge(app: NSRunningApplication) -> URL? {
        let pid = app.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)

        // Get the main window
        var windowRef: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(appRef, kAXMainWindowAttribute as CFString, &windowRef)

        guard windowResult == .success,
              let window = windowRef
        else {
            logger.debug("Failed to get Edge main window: \(windowResult.rawValue)")
            return nil
        }

        return extractURLFromWindow(window, browserName: "Edge")
    }

    /// Generic URL extraction from a browser window by searching for text fields containing URLs.
    private func extractURLFromWindow(_ window: CFTypeRef, browserName: String) -> URL? {
        // Convert to AXUIElement for attribute access
        let windowElement = unsafeBitCast(window, to: AXUIElement.self)

        // Try to find the address bar by searching for text fields
        var childrenRef: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(
            windowElement,
            kAXChildrenAttribute as CFString,
            &childrenRef
        )

        guard childrenResult == .success, let children = childrenRef as? [AXUIElement] else {
            logger.debug("Failed to get children for \(browserName) window")
            return nil
        }

        // Recursively search for a text field containing a URL
        return findURLInElements(children, browserName: browserName)
    }

    /// Recursively searches elements for a URL text field.
    private func findURLInElements(_ elements: [AXUIElement], browserName: String) -> URL? {
        for element in elements {
            // Check if this element has a value that looks like a URL
            var valueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
               let value = valueRef as? String,
               let url = parseURL(from: value)
            {
                logger.debug("Found URL in \(browserName): \(url.absoluteString)")
                return url
            }

            // Check the role
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
               let role = roleRef as? String
            {
                // Look for text fields and combo boxes (address bars)
                if role == kAXTextFieldRole || role == kAXComboBoxRole {
                    // Try to get the value
                    if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
                       let value = valueRef as? String,
                       let url = parseURL(from: value)
                    {
                        return url
                    }
                }
            }

            // Recursively search children
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement]
            {
                if let url = findURLInElements(children, browserName: browserName) {
                    return url
                }
            }
        }

        return nil
    }

    /// Attempts to parse a URL from a string value.
    private func parseURL(from value: String) -> URL? {
        // Trim whitespace
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if it looks like a URL
        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme)
        else {
            return nil
        }

        // Make sure it has a host
        guard url.host != nil else { return nil }

        return url
    }
}
