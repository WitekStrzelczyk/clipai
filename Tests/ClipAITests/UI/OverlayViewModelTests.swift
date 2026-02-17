import XCTest
@testable import ClipAI

final class OverlayViewModelTests: XCTestCase {
    var sut: OverlayViewModel!
    var mockStorage: MockClipStorage!
    var mockPasteService: MockPasteService!

    override func setUp() async throws {
        try await super.setUp()
        mockStorage = MockClipStorage()
        mockPasteService = MockPasteService()
        sut = await OverlayViewModel(storage: mockStorage, pasteService: mockPasteService)
    }

    override func tearDown() async throws {
        sut = nil
        mockStorage = nil
        mockPasteService = nil
        try await super.tearDown()
    }

    // MARK: - Load Clips

    func testLoadClips_WhenStoreHasClips_SetsClipsProperty() async throws {
        // Given
        let expectedClips = [
            Clip(content: "test1", contentType: .text),
            Clip(content: "test2", contentType: .text)
        ]
        await mockStorage.setClips(expectedClips)

        // When
        await sut.loadClips()

        // Then
        let clips = await sut.clips
        XCTAssertEqual(clips.count, 2)
    }

    func testLoadClips_WhenStoreEmpty_SetsEmptyArray() async throws {
        // Given
        await mockStorage.setClips([])

        // When
        await sut.loadClips()

        // Then
        let clips = await sut.clips
        XCTAssertTrue(clips.isEmpty)
    }

    func testLoadClips_SetsLoadingStateCorrectly() async throws {
        // Given
        await mockStorage.setClips([])

        // When
        let isLoadingBefore = await sut.isLoading
        XCTAssertFalse(isLoadingBefore)
        await sut.loadClips()

        // Then
        let isLoadingAfter = await sut.isLoading
        XCTAssertFalse(isLoadingAfter)
    }

    // MARK: - Sorted Clips

    func testClips_AreSortedByTimestampDescending() async throws {
        // Given
        let olderClip = Clip(
            content: "Older",
            contentType: .text,
            timestamp: Date().addingTimeInterval(-60)
        )
        let newerClip = Clip(
            content: "Newer",
            contentType: .text,
            timestamp: Date()
        )
        await mockStorage.setClips([olderClip, newerClip])

        // When
        await sut.loadClips()

        // Then
        let clips = await sut.clips
        XCTAssertEqual(clips.count, 2)
        XCTAssertEqual(clips[0].content, "Newer")
        XCTAssertEqual(clips[1].content, "Older")
    }

    // MARK: - Empty State

    func testHasClips_WhenEmpty_ReturnsFalse() async throws {
        // Given
        await mockStorage.setClips([])
        await sut.loadClips()

        // Then
        let hasClips = await sut.hasClips
        XCTAssertFalse(hasClips)
    }

    func testHasClips_WhenNotEmpty_ReturnsTrue() async throws {
        // Given
        await mockStorage.setClips([Clip(content: "test", contentType: .text)])
        await sut.loadClips()

        // Then
        let hasClips = await sut.hasClips
        XCTAssertTrue(hasClips)
    }

    // MARK: - Selection (prepare for Story 6)

    func testSelectClip_WhenCalled_SetsSelectedClip() async throws {
        // Given
        let clip = Clip(content: "test", contentType: .text)
        await mockStorage.setClips([clip])
        await sut.loadClips()

        // When
        await sut.selectClip(clip)

        // Then
        let selectedClip = await sut.selectedClip
        XCTAssertEqual(selectedClip?.id, clip.id)
    }

    // MARK: - Preview Text

    func testPreviewText_WhenShortContent_ReturnsFullContent() async throws {
        // Given
        let shortContent = "Hello World"
        let clip = Clip(content: shortContent, contentType: .text)

        // When
        let preview = await sut.previewText(for: clip)

        // Then
        XCTAssertEqual(preview, shortContent)
    }

    func testPreviewText_WhenLongContent_TruncatesWithEllipsis() async throws {
        // Given
        let longContent = String(repeating: "a", count: 100)
        let clip = Clip(content: longContent, contentType: .text)

        // When
        let preview = await sut.previewText(for: clip)

        // Then
        XCTAssertEqual(preview.count, 53) // 50 chars + "..."
        XCTAssertTrue(preview.hasSuffix("..."))
    }

    // MARK: - Relative Time

    func testRelativeTime_WhenRecent_ReturnsShortTimeAgo() async throws {
        // Given
        let clip = Clip(
            content: "test",
            contentType: .text,
            timestamp: Date().addingTimeInterval(-60) // 1 minute ago
        )

        // When
        let timeString = await sut.relativeTime(for: clip)

        // Then
        XCTAssertFalse(timeString.isEmpty)
    }

    // MARK: - Search Text

    func testSearchText_WhenSet_FiltersClips() async throws {
        // Given
        let clips = [
            Clip(content: "Hello World", contentType: .text),
            Clip(content: "Swift Programming", contentType: .text),
            Clip(content: "Hello Swift", contentType: .text)
        ]
        await mockStorage.setClips(clips)
        await sut.loadClips()

        // When
        await sut.setSearchText("Hello")

        // Then
        let filteredClips = await sut.filteredClips
        XCTAssertEqual(filteredClips.count, 2)
        XCTAssertTrue(filteredClips.allSatisfy { $0.content.contains("Hello") })
    }

    func testSearchText_WhenEmpty_ShowsAllClips() async throws {
        // Given
        let clips = [
            Clip(content: "Hello World", contentType: .text),
            Clip(content: "Swift Programming", contentType: .text)
        ]
        await mockStorage.setClips(clips)
        await sut.loadClips()

        // When
        await sut.setSearchText("")

        // Then
        let filteredClips = await sut.filteredClips
        XCTAssertEqual(filteredClips.count, 2)
    }

    // MARK: - Two-Phase Search Ranking

    func testSearchText_ContentMatchesComeFirst_ThenSourceAppMatches() async throws {
        // Given
        let contentMatchClip = Clip(
            content: "chrome://settings",
            contentType: .text,
            sourceApp: "Safari",
            timestamp: Date().addingTimeInterval(-60)
        )
        let appMatchClip = Clip(
            content: "Hello World",
            contentType: .text,
            sourceApp: "Chrome",
            timestamp: Date()
        )
        let noMatchClip = Clip(
            content: "Random text",
            contentType: .text,
            sourceApp: "Notes",
            timestamp: Date().addingTimeInterval(-120)
        )
        await mockStorage.setClips([contentMatchClip, appMatchClip, noMatchClip])
        await sut.loadClips()

        // When
        await sut.setSearchText("chrome")

        // Then
        let filteredClips = await sut.filteredClips
        XCTAssertEqual(filteredClips.count, 2, "Should have 2 matches: content and source app")
        XCTAssertEqual(filteredClips[0].content, "chrome://settings", "Content match should come first")
        XCTAssertEqual(filteredClips[1].sourceApp, "Chrome", "Source app match should come second")
    }

    func testSearchText_WhenBothContentAndAppMatch_OnlyShowsOnce() async throws {
        // Given
        let bothMatchClip = Clip(
            content: "chrome://settings",
            contentType: .text,
            sourceApp: "Chrome",
            timestamp: Date()
        )
        await mockStorage.setClips([bothMatchClip])
        await sut.loadClips()

        // When
        await sut.setSearchText("chrome")

        // Then
        let filteredClips = await sut.filteredClips
        XCTAssertEqual(filteredClips.count, 1, "Should only appear once even if both content and app match")
    }

    func testSearchText_SourceAppMatchIsCaseInsensitive() async throws {
        // Given
        let clip = Clip(
            content: "Hello World",
            contentType: .text,
            sourceApp: "Google Chrome",
            timestamp: Date()
        )
        await mockStorage.setClips([clip])
        await sut.loadClips()

        // When
        await sut.setSearchText("CHROME")

        // Then
        let filteredClips = await sut.filteredClips
        XCTAssertEqual(filteredClips.count, 1, "Should match despite case difference")
    }

    func testSearchText_SourceAppWithNilApp_DoesNotCrash() async throws {
        // Given
        let clipWithNilApp = Clip(
            content: "Hello World",
            contentType: .text,
            sourceApp: nil,
            timestamp: Date()
        )
        await mockStorage.setClips([clipWithNilApp])
        await sut.loadClips()

        // When
        await sut.setSearchText("chrome")

        // Then
        let filteredClips = await sut.filteredClips
        XCTAssertEqual(filteredClips.count, 0, "Should not crash when sourceApp is nil")
    }

    // MARK: - Keyboard Navigation - Focused Item Index

    func testFocusedIndex_WhenInitialized_IsNil() async throws {
        // Then
        let focusedIndex = await sut.focusedIndex
        XCTAssertNil(focusedIndex)
    }

    func testMoveFocusDown_WhenSearchFocused_MovesToFirstItem() async throws {
        // Given
        let clips = [
            Clip(content: "First", contentType: .text),
            Clip(content: "Second", contentType: .text)
        ]
        await mockStorage.setClips(clips)
        await sut.loadClips()
        // Initially no focus (search field has focus conceptually)

        // When
        await sut.moveFocusDown()

        // Then
        let focusedIndex = await sut.focusedIndex
        XCTAssertEqual(focusedIndex, 0)
    }

    func testMoveFocusDown_WhenAtLastItem_StaysAtLastItem() async throws {
        // Given
        let clips = [
            Clip(content: "First", contentType: .text),
            Clip(content: "Second", contentType: .text)
        ]
        await mockStorage.setClips(clips)
        await sut.loadClips()
        await sut.setFocusIndex(1) // Focus on last item

        // When
        await sut.moveFocusDown()

        // Then
        let focusedIndex = await sut.focusedIndex
        XCTAssertEqual(focusedIndex, 1) // Still at last item
    }

    func testMoveFocusDown_WhenInMiddle_MovesToNextItem() async throws {
        // Given
        let clips = [
            Clip(content: "First", contentType: .text),
            Clip(content: "Second", contentType: .text),
            Clip(content: "Third", contentType: .text)
        ]
        await mockStorage.setClips(clips)
        await sut.loadClips()
        await sut.setFocusIndex(0) // Focus on first item

        // When
        await sut.moveFocusDown()

        // Then
        let focusedIndex = await sut.focusedIndex
        XCTAssertEqual(focusedIndex, 1)
    }

    func testMoveFocusUp_WhenAtFirstItem_ReturnsToSearch() async throws {
        // Given
        let clips = [
            Clip(content: "First", contentType: .text),
            Clip(content: "Second", contentType: .text)
        ]
        await mockStorage.setClips(clips)
        await sut.loadClips()
        await sut.setFocusIndex(0) // Focus on first item

        // When
        await sut.moveFocusUp()

        // Then
        let focusedIndex = await sut.focusedIndex
        XCTAssertNil(focusedIndex) // Back to search (nil means search focused)
    }

    func testMoveFocusUp_WhenInMiddle_MovesToPreviousItem() async throws {
        // Given
        let clips = [
            Clip(content: "First", contentType: .text),
            Clip(content: "Second", contentType: .text),
            Clip(content: "Third", contentType: .text)
        ]
        await mockStorage.setClips(clips)
        await sut.loadClips()
        await sut.setFocusIndex(1) // Focus on middle item

        // When
        await sut.moveFocusUp()

        // Then
        let focusedIndex = await sut.focusedIndex
        XCTAssertEqual(focusedIndex, 0)
    }

    func testMoveFocusUp_WhenSearchFocused_StaysAtSearch() async throws {
        // Given
        let clips = [
            Clip(content: "First", contentType: .text)
        ]
        await mockStorage.setClips(clips)
        await sut.loadClips()
        // focusedIndex is nil (search focused)

        // When
        await sut.moveFocusUp()

        // Then
        let focusedIndex = await sut.focusedIndex
        XCTAssertNil(focusedIndex) // Still at search
    }

    func testResetFocus_WhenCalled_ReturnsToNil() async throws {
        // Given
        let clips = [
            Clip(content: "First", contentType: .text)
        ]
        await mockStorage.setClips(clips)
        await sut.loadClips()
        await sut.setFocusIndex(0) // Focus on first item

        // When
        await sut.resetFocus()

        // Then
        let focusedIndex = await sut.focusedIndex
        XCTAssertNil(focusedIndex)
    }

    // MARK: - Paste Selected Clip (Story 6)

    func testPasteSelectedClip_WhenClipSelected_CallsPasteService() async throws {
        // Given
        let clip = Clip(content: "Test Content", contentType: .text)
        await mockStorage.setClips([clip])
        await sut.loadClips()
        await sut.selectClip(clip)

        // When
        await sut.pasteSelectedClip()

        // Then
        let callCount = await mockPasteService.copyAndPasteCallCount
        XCTAssertEqual(callCount, 1)
    }

    func testPasteSelectedClip_WhenClipSelected_PastesCorrectContent() async throws {
        // Given
        let clip = Clip(content: "Expected Content", contentType: .text)
        await mockStorage.setClips([clip])
        await sut.loadClips()
        await sut.selectClip(clip)

        // When
        await sut.pasteSelectedClip()

        // Then
        let pastedClip = await mockPasteService.lastPastedClip
        XCTAssertEqual(pastedClip?.content, "Expected Content")
    }

    func testPasteSelectedClip_WhenNoClipSelected_ReturnsFalse() async throws {
        // Given - no clip selected
        await mockStorage.setClips([Clip(content: "Test", contentType: .text)])
        await sut.loadClips()
        // selectedClip is nil

        // When
        let result = await sut.pasteSelectedClip()

        // Then
        XCTAssertFalse(result)
        let callCount = await mockPasteService.copyAndPasteCallCount
        XCTAssertEqual(callCount, 0)
    }

    func testPasteSelectedClip_WhenSuccessful_ReturnsTrue() async throws {
        // Given
        let clip = Clip(content: "Test", contentType: .text)
        await mockStorage.setClips([clip])
        await sut.loadClips()
        await sut.selectClip(clip)

        // When
        let result = await sut.pasteSelectedClip()

        // Then
        XCTAssertTrue(result)
    }

    func testGetFocusedClip_WhenFocusOnClip_ReturnsClip() async throws {
        // Given
        let clips = [
            Clip(content: "First", contentType: .text),
            Clip(content: "Second", contentType: .text)
        ]
        await mockStorage.setClips(clips)
        await sut.loadClips()
        // Index 0 should be "Second" (newer), index 1 should be "First" (older)
        // since clips are sorted by timestamp descending
        await sut.setFocusIndex(0)

        // When
        let focusedClip = await sut.getFocusedClip()

        // Then
        XCTAssertEqual(focusedClip?.content, "Second")
    }

    func testGetFocusedClip_WhenNoFocus_ReturnsNil() async throws {
        // Given
        await mockStorage.setClips([Clip(content: "Test", contentType: .text)])
        await sut.loadClips()
        // focusedIndex is nil

        // When
        let focusedClip = await sut.getFocusedClip()

        // Then
        XCTAssertNil(focusedClip)
    }
}

// MARK: - Mock ClipStorage

/// Mock implementation of ClipStorage for testing.
actor MockClipStorage: ClipStorageProtocol {
    private var clips: [Clip] = []

    func setClips(_ newClips: [Clip]) {
        clips = newClips
    }

    func loadAll() -> [Clip] {
        clips.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Mock PasteService

/// Mock implementation of PasteService for testing.
actor MockPasteService: PasteServiceProtocol {
    var copyAndPasteCallCount = 0
    var lastPastedClip: Clip?

    func copyAndPaste(_ clip: Clip) async throws {
        copyAndPasteCallCount += 1
        lastPastedClip = clip
    }

    func copyToClipboard(_ clip: Clip) async throws {
        // Not used in these tests
    }

    func simulateCmdV() async throws {
        // Not used in these tests
    }
}
