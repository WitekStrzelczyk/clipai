import AppKit
import Foundation
import OSLog

/// Represents app information retrieved from the system.
struct AppInfo {
    let name: String?
    let icon: NSImage?
    let isInstalled: Bool
}

/// Represents an ignored application with its metadata.
struct IgnoredApp: Identifiable, Hashable {
    let id: String  // bundle identifier
    let bundleIdentifier: String
    let name: String
    let icon: NSImage?

    init(bundleIdentifier: String, name: String? = nil, icon: NSImage? = nil) {
        self.id = bundleIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.name = name ?? bundleIdentifier
        self.icon = icon
    }
}

/// Represents a suggested password manager app.
struct SuggestedApp: Identifiable, Hashable {
    let id: String  // bundle identifier
    let bundleIdentifier: String
    let name: String
    let icon: NSImage?
    let isInstalled: Bool

    init(bundleIdentifier: String, name: String? = nil, icon: NSImage? = nil, isInstalled: Bool) {
        self.id = bundleIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.name = name ?? bundleIdentifier
        self.icon = icon
        self.isInstalled = isInstalled
    }
}

/// Actor responsible for managing the application ignore list.
/// Stores bundle identifiers of apps whose clipboard content should not be captured.
actor IgnoreListManager {
    private let logger = Logger(subsystem: "com.clipai.app", category: "IgnoreListManager")

    /// The UserDefaults key for storing the ignore list.
    private let userDefaultsKey: String

    /// In-memory cache of ignored bundle identifiers.
    private var ignoredBundleIdentifiers: Set<String>

    /// Default password manager bundle identifiers to suggest.
    /// Ordered by most likely to be used, with modern versions first.
    private let defaultPasswordManagers = [
        "com.1password.1password",          // 1Password 8+ (modern)
        "com.agilebits.onepassword7",       // 1Password 7 (legacy)
        "com.agilebits.onepassword4",       // 1Password 4 (legacy)
        "com.bitwarden.desktop",            // Bitwarden
        "com.lastpass.LastPass",            // LastPass
        "com.dashlane.Dashlane",            // Dashlane
        "com.keepersecurity.passwordmanager", // Keeper
    ]

    /// Creates a new IgnoreListManager.
    /// - Parameter userDefaultsKey: The UserDefaults key for storing the ignore list.
    init(userDefaultsKey: String = "com.clipai.ignoreList") {
        self.userDefaultsKey = userDefaultsKey
        self.ignoredBundleIdentifiers = []

        // Load existing data from UserDefaults
        if let saved = UserDefaults.standard.stringArray(forKey: userDefaultsKey) {
            self.ignoredBundleIdentifiers = Set(saved)
            logger.debug("Loaded \(saved.count) ignored apps from UserDefaults")
        }
    }

    // MARK: - Public API

    /// Returns all ignored bundle identifiers.
    /// - Returns: Array of bundle identifiers.
    func getIgnoredBundleIdentifiers() -> [String] {
        Array(ignoredBundleIdentifiers).sorted()
    }

    /// Adds a bundle identifier to the ignore list.
    /// - Parameter bundleIdentifier: The bundle identifier to add.
    func addBundleIdentifier(_ bundleIdentifier: String) {
        guard !ignoredBundleIdentifiers.contains(bundleIdentifier) else {
            logger.debug("Bundle identifier already in ignore list: \(bundleIdentifier)")
            return
        }

        ignoredBundleIdentifiers.insert(bundleIdentifier)
        saveToUserDefaults()
        logger.info("Added to ignore list: \(bundleIdentifier)")
    }

    /// Removes a bundle identifier from the ignore list.
    /// - Parameter bundleIdentifier: The bundle identifier to remove.
    func removeBundleIdentifier(_ bundleIdentifier: String) {
        guard ignoredBundleIdentifiers.remove(bundleIdentifier) != nil else {
            logger.debug("Bundle identifier not in ignore list: \(bundleIdentifier)")
            return
        }

        saveToUserDefaults()
        logger.info("Removed from ignore list: \(bundleIdentifier)")
    }

    /// Checks if a bundle identifier is in the ignore list.
    /// - Parameter bundleIdentifier: The bundle identifier to check.
    /// - Returns: True if the bundle identifier is ignored.
    func isBundleIdentifierIgnored(_ bundleIdentifier: String) -> Bool {
        ignoredBundleIdentifiers.contains(bundleIdentifier)
    }

    /// Returns all ignored apps with metadata (name, icon).
    /// - Returns: Array of IgnoredApp with metadata.
    func getIgnoredApps() -> [IgnoredApp] {
        ignoredBundleIdentifiers.compactMap { bundleId -> IgnoredApp? in
            let appInfo = getAppInfo(for: bundleId)
            return IgnoredApp(
                bundleIdentifier: bundleId,
                name: appInfo.name,
                icon: appInfo.icon
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Returns suggested password managers that are installed.
    /// - Returns: Array of SuggestedApp for installed password managers.
    func getSuggestedPasswordManagers() -> [SuggestedApp] {
        defaultPasswordManagers.compactMap { bundleId -> SuggestedApp? in
            let appInfo = getAppInfo(for: bundleId)
            guard appInfo.isInstalled else { return nil }

            return SuggestedApp(
                bundleIdentifier: bundleId,
                name: appInfo.name,
                icon: appInfo.icon,
                isInstalled: true
            )
        }
    }

    /// Returns all suggested password managers, including not installed ones.
    /// - Returns: Array of SuggestedApp for all password managers.
    func getAllSuggestedPasswordManagers() -> [SuggestedApp] {
        defaultPasswordManagers.map { bundleId in
            let appInfo = getAppInfo(for: bundleId)
            return SuggestedApp(
                bundleIdentifier: bundleId,
                name: appInfo.name,
                icon: appInfo.icon,
                isInstalled: appInfo.isInstalled
            )
        }
    }

    // MARK: - Private

    /// Saves the ignore list to UserDefaults.
    private func saveToUserDefaults() {
        let array = Array(ignoredBundleIdentifiers)
        UserDefaults.standard.set(array, forKey: userDefaultsKey)
        logger.debug("Saved \(array.count) ignored apps to UserDefaults")
    }

    /// Gets app info for a bundle identifier using multiple detection strategies.
    /// - Parameter bundleIdentifier: The bundle identifier to look up.
    /// - Returns: AppInfo with name, icon, and installation status.
    private func getAppInfo(for bundleIdentifier: String) -> AppInfo {
        // Strategy 1: Try NSWorkspace to find app by bundle identifier
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return extractAppInfo(from: appURL, isInstalled: true)
        }

        // Strategy 2: Fallback - scan common app directories
        if let appURL = findAppByScanningDirectories(bundleIdentifier: bundleIdentifier) {
            return extractAppInfo(from: appURL, isInstalled: true)
        }

        // App not installed - generate fallback name from bundle ID
        let fallbackName = generateFallbackName(from: bundleIdentifier)
        return AppInfo(name: fallbackName, icon: nil, isInstalled: false)
    }

    /// Extracts app info from an app bundle URL.
    /// - Parameter appURL: The URL of the app bundle.
    /// - Parameter isInstalled: Whether the app is installed.
    /// - Returns: AppInfo with extracted metadata.
    private func extractAppInfo(from appURL: URL, isInstalled: Bool) -> AppInfo {
        // Try to get the display name from the bundle
        let bundle = Bundle(url: appURL)
        let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? appURL.deletingPathExtension().lastPathComponent

        // Get app icon
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)

        return AppInfo(name: name, icon: icon, isInstalled: isInstalled)
    }

    /// Finds an app by scanning common application directories.
    /// - Parameter bundleIdentifier: The bundle identifier to search for.
    /// - Returns: URL of the app if found, nil otherwise.
    private func findAppByScanningDirectories(bundleIdentifier: String) -> URL? {
        let appDirectories = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Library/CoreServices"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications"),
        ]

        for directory in appDirectories {
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "app" else { continue }

                if let bundle = Bundle(url: fileURL),
                   bundle.bundleIdentifier == bundleIdentifier {
                    return fileURL
                }
            }
        }

        return nil
    }

    /// Generates a fallback display name from a bundle identifier.
    /// - Parameter bundleIdentifier: The bundle identifier.
    /// - Returns: A human-readable name derived from the bundle ID.
    private func generateFallbackName(from bundleIdentifier: String) -> String {
        // Extract the app name from the bundle identifier
        // e.g., "com.agilebits.onepassword7" -> "Onepassword7"
        let components = bundleIdentifier.components(separatedBy: ".")
        if let lastComponent = components.last, !lastComponent.isEmpty {
            // Capitalize first letter
            return lastComponent.prefix(1).uppercased() + lastComponent.dropFirst()
        }
        return bundleIdentifier
    }
}
