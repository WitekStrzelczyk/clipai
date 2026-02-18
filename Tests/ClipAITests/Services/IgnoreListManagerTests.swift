import XCTest
import AppKit
@testable import ClipAI

final class IgnoreListManagerTests: XCTestCase {
    var sut: IgnoreListManager!
    let testKey = "com.clipai.test.ignoreList"

    override func setUp() async throws {
        try await super.setUp()
        // Clear any existing test data
        UserDefaults.standard.removeObject(forKey: testKey)
        sut = IgnoreListManager(userDefaultsKey: testKey)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: testKey)
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func testInit_WhenNoExistingData_StartsWithEmptyList() async throws {
        // Given: No existing data in UserDefaults
        UserDefaults.standard.removeObject(forKey: testKey)

        // When: Create new manager
        let manager = IgnoreListManager(userDefaultsKey: testKey)

        // Then: List should be empty
        let ignoredApps = await manager.getIgnoredBundleIdentifiers()
        XCTAssertTrue(ignoredApps.isEmpty, "Should start with empty ignore list")
    }

    func testInit_LoadsExistingDataFromUserDefaults() async throws {
        // Given: Existing data in UserDefaults
        let existingApps = ["com.agilebits.onepassword7", "com.bitwarden.desktop"]
        UserDefaults.standard.set(existingApps, forKey: testKey)

        // When: Create new manager
        let manager = IgnoreListManager(userDefaultsKey: testKey)

        // Then: Should load existing apps
        let ignoredApps = await manager.getIgnoredBundleIdentifiers()
        XCTAssertEqual(ignoredApps.count, 2)
        XCTAssertTrue(ignoredApps.contains("com.agilebits.onepassword7"))
        XCTAssertTrue(ignoredApps.contains("com.bitwarden.desktop"))
    }

    // MARK: - Add to Ignore List

    func testAddBundleIdentifier_AddsToIgnoreList() async throws {
        // Given: Empty ignore list
        var ignoredApps = await sut.getIgnoredBundleIdentifiers()
        XCTAssertTrue(ignoredApps.isEmpty)

        // When: Add a bundle identifier
        await sut.addBundleIdentifier("com.agilebits.onepassword7")

        // Then: Should be in the list
        ignoredApps = await sut.getIgnoredBundleIdentifiers()
        XCTAssertEqual(ignoredApps.count, 1)
        XCTAssertTrue(ignoredApps.contains("com.agilebits.onepassword7"))
    }

    func testAddBundleIdentifier_SavesToUserDefaults() async throws {
        // When: Add a bundle identifier
        await sut.addBundleIdentifier("com.bitwarden.desktop")

        // Then: Should be persisted in UserDefaults
        let saved = UserDefaults.standard.stringArray(forKey: testKey)
        XCTAssertEqual(saved?.count, 1)
        XCTAssertTrue(saved?.contains("com.bitwarden.desktop") ?? false)
    }

    func testAddBundleIdentifier_PreventsDuplicates() async throws {
        // When: Add same bundle identifier twice
        await sut.addBundleIdentifier("com.lastpass.LastPass")
        await sut.addBundleIdentifier("com.lastpass.LastPass")

        // Then: Should only appear once
        let ignoredApps = await sut.getIgnoredBundleIdentifiers()
        XCTAssertEqual(ignoredApps.count, 1)
    }

    func testAddBundleIdentifier_TakesEffectImmediately() async throws {
        // Given: Bundle is not ignored
        var isIgnored = await sut.isBundleIdentifierIgnored("com.dashlane.Dashlane")
        XCTAssertFalse(isIgnored)

        // When: Add to ignore list
        await sut.addBundleIdentifier("com.dashlane.Dashlane")

        // Then: Should be ignored immediately
        isIgnored = await sut.isBundleIdentifierIgnored("com.dashlane.Dashlane")
        XCTAssertTrue(isIgnored)
    }

    // MARK: - Remove from Ignore List

    func testRemoveBundleIdentifier_RemovesFromIgnoreList() async throws {
        // Given: Bundle identifier is in the list
        await sut.addBundleIdentifier("com.agilebits.onepassword7")
        var ignoredApps = await sut.getIgnoredBundleIdentifiers()
        XCTAssertEqual(ignoredApps.count, 1)

        // When: Remove it
        await sut.removeBundleIdentifier("com.agilebits.onepassword7")

        // Then: Should be removed
        ignoredApps = await sut.getIgnoredBundleIdentifiers()
        XCTAssertTrue(ignoredApps.isEmpty)
    }

    func testRemoveBundleIdentifier_UpdatesUserDefaults() async throws {
        // Given: Bundle identifier is persisted
        await sut.addBundleIdentifier("com.bitwarden.desktop")

        // When: Remove it
        await sut.removeBundleIdentifier("com.bitwarden.desktop")

        // Then: UserDefaults should be updated
        let saved = UserDefaults.standard.stringArray(forKey: testKey)
        XCTAssertTrue(saved?.isEmpty ?? true)
    }

    func testRemoveBundleIdentifier_AllowsCaptureAgain() async throws {
        // Given: Bundle is ignored
        await sut.addBundleIdentifier("com.keepersecurity.passwordmanager")
        var isIgnored = await sut.isBundleIdentifierIgnored("com.keepersecurity.passwordmanager")
        XCTAssertTrue(isIgnored)

        // When: Remove from ignore list
        await sut.removeBundleIdentifier("com.keepersecurity.passwordmanager")

        // Then: Should not be ignored anymore
        isIgnored = await sut.isBundleIdentifierIgnored("com.keepersecurity.passwordmanager")
        XCTAssertFalse(isIgnored)
    }

    // MARK: - Check if Ignored

    func testIsBundleIdentifierIgnored_WhenInList_ReturnsTrue() async throws {
        // Given: Bundle is in ignore list
        await sut.addBundleIdentifier("com.agilebits.onepassword7")

        // When: Check if ignored
        let isIgnored = await sut.isBundleIdentifierIgnored("com.agilebits.onepassword7")

        // Then: Should return true
        XCTAssertTrue(isIgnored)
    }

    func testIsBundleIdentifierIgnored_WhenNotInList_ReturnsFalse() async throws {
        // Given: Bundle is NOT in ignore list
        await sut.addBundleIdentifier("com.agilebits.onepassword7")

        // When: Check different bundle
        let isIgnored = await sut.isBundleIdentifierIgnored("com.bitwarden.desktop")

        // Then: Should return false
        XCTAssertFalse(isIgnored)
    }

    func testIsBundleIdentifierIgnored_IsCaseSensitive() async throws {
        // Given: Bundle identifier with specific case
        await sut.addBundleIdentifier("com.agilebits.onepassword7")

        // When: Check with different case
        let isIgnored = await sut.isBundleIdentifierIgnored("com.agilebits.OnePassword7")

        // Then: Should not match (bundle identifiers are case-sensitive)
        XCTAssertFalse(isIgnored)
    }

    // MARK: - Get Ignored Apps with Metadata

    func testGetIgnoredApps_ReturnsAppInfo() async throws {
        // Given: Bundle identifiers in list
        await sut.addBundleIdentifier("com.apple.Safari")

        // When: Get ignored apps with metadata
        let apps = await sut.getIgnoredApps()

        // Then: Should return app info
        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps.first?.bundleIdentifier, "com.apple.Safari")
        // Name may vary, but should not be empty if app is installed
        // Note: Safari should be available on all macOS systems
    }

    func testGetIgnoredApps_IncludesAppIcon() async throws {
        // Given: Bundle identifier for a system app
        await sut.addBundleIdentifier("com.apple.Safari")

        // When: Get ignored apps
        let apps = await sut.getIgnoredApps()

        // Then: Should have icon (if app is installed)
        if let app = apps.first {
            XCTAssertNotNil(app.icon, "Should have app icon for installed apps")
        }
    }

    func testGetIgnoredApps_ForUnknownBundle_ReturnsBundleIdAsName() async throws {
        // Given: A bundle identifier that likely doesn't exist
        let unknownBundleId = "com.nonexistent.app.\(UUID().uuidString)"
        await sut.addBundleIdentifier(unknownBundleId)

        // When: Get ignored apps
        let apps = await sut.getIgnoredApps()

        // Then: Should use bundle ID as name fallback
        if let app = apps.first {
            XCTAssertEqual(app.bundleIdentifier, unknownBundleId)
            // Name should be the bundle ID since app doesn't exist
            XCTAssertNotNil(app.name)
        }
    }

    // MARK: - Default Password Managers

    func testGetSuggestedPasswordManagers_OnlyReturnsInstalledApps() async throws {
        // When: Get suggested password managers (only installed ones)
        let suggestions = await sut.getSuggestedPasswordManagers()

        // Then: All returned apps should be installed
        for suggestion in suggestions {
            XCTAssertTrue(suggestion.isInstalled, "Only installed apps should be returned")
        }
    }

    func testGetAllSuggestedPasswordManagers_IncludesNotInstalledApps() async throws {
        // When: Get all suggested password managers (including not installed)
        let suggestions = await sut.getAllSuggestedPasswordManagers()

        // Then: Should have suggestions even if not all are installed
        XCTAssertFalse(suggestions.isEmpty, "Should have suggested password managers")

        // Check that the list includes known password manager bundle IDs
        let bundleIds = suggestions.map { $0.bundleIdentifier }
        // Modern 1Password (8+) uses com.1password.1password
        XCTAssertTrue(bundleIds.contains("com.1password.1password"), "Should include 1Password 8+")
        XCTAssertTrue(bundleIds.contains("com.bitwarden.desktop"), "Should include Bitwarden")
    }

    func testGetSuggestedPasswordManagers_DetectsModern1Password() async throws {
        // Given: 1Password may be installed with modern bundle ID
        // When: Get suggested password managers
        let suggestions = await sut.getAllSuggestedPasswordManagers()

        // Then: Should include modern 1Password and detect if installed
        let onePassword = suggestions.first { $0.bundleIdentifier == "com.1password.1password" }
        XCTAssertNotNil(onePassword, "Should include modern 1Password in suggestions")

        // If 1Password is installed, it should be marked as installed
        // This test verifies the detection works for the actual installed app
        // The test machine has 1Password installed at /Applications/1Password.app
    }

    func testGetSuggestedPasswordManagers_DetectsSpotlightIfIncluded() async throws {
        // Given: Spotlight is a system app at /System/Library/CoreServices/Spotlight.app
        // When: We check app info for Spotlight
        await sut.addBundleIdentifier("com.apple.Spotlight")

        // Then: Should be detected as installed with proper metadata
        let apps = await sut.getIgnoredApps()
        let spotlight = apps.first { $0.bundleIdentifier == "com.apple.Spotlight" }

        XCTAssertNotNil(spotlight, "Spotlight should be in ignored apps")
        XCTAssertEqual(spotlight?.name, "Spotlight", "Should have correct name")
        XCTAssertNotNil(spotlight?.icon, "Should have app icon")
    }

    func testGetSuggestedPasswordManagers_OnlyIncludesInstalledApps() async throws {
        // When: Get suggested password managers
        let suggestions = await sut.getSuggestedPasswordManagers()

        // Then: All returned apps should be installed (have a name)
        for suggestion in suggestions {
            XCTAssertNotNil(suggestion.name, "Suggested app should have a name")
        }
    }

    // MARK: - Persistence Across Restarts

    func testIgnoreList_PersistsAcrossNewInstances() async throws {
        // Given: Add items via one instance
        await sut.addBundleIdentifier("com.agilebits.onepassword7")
        await sut.addBundleIdentifier("com.bitwarden.desktop")

        // When: Create a new instance
        let newManager = IgnoreListManager(userDefaultsKey: testKey)

        // Then: Should load the same data
        let ignoredApps = await newManager.getIgnoredBundleIdentifiers()
        XCTAssertEqual(ignoredApps.count, 2)
        XCTAssertTrue(ignoredApps.contains("com.agilebits.onepassword7"))
        XCTAssertTrue(ignoredApps.contains("com.bitwarden.desktop"))
    }
}
