import XCTest
@testable import ClipAI

final class ClipStorageTests: XCTestCase {
    var sut: ClipStorage!
    var testDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        // Create a unique test directory
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipAITests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        sut = ClipStorage(storageDirectory: testDirectory)
        try await sut.loadFromDisk()
    }

    override func tearDown() async throws {
        // Clean up test directory
        if let testDirectory = testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Knowledge.json File Structure

    func testSave_CreatesKnowledgeJsonFile() async throws {
        let clip = Clip(content: "Hello World", contentType: .text)

        try await sut.save(clip)

        let knowledgeFileURL = testDirectory.appendingPathComponent("knowledge.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: knowledgeFileURL.path))
    }

    func testSave_KnowledgeJsonContainsClipsArray() async throws {
        let clip = Clip(content: "Hello World", contentType: .text)

        try await sut.save(clip)

        let knowledgeFileURL = testDirectory.appendingPathComponent("knowledge.json")
        let data = try Data(contentsOf: knowledgeFileURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json?["clips"] as? [[String: Any]])
    }

    func testSave_KnowledgeJsonContainsCorrectClipContent() async throws {
        let clip = Clip(
            content: "Hello World",
            contentType: .text,
            sourceApp: "Safari"
        )

        try await sut.save(clip)

        let knowledgeFileURL = testDirectory.appendingPathComponent("knowledge.json")
        let data = try Data(contentsOf: knowledgeFileURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let clips = json?["clips"] as? [[String: Any]]

        XCTAssertEqual(clips?.count, 1)
        XCTAssertEqual(clips?[0]["content"] as? String, "Hello World")
        XCTAssertEqual(clips?[0]["content_type"] as? String, "text")
        XCTAssertEqual(clips?[0]["source_app"] as? String, "Safari")
    }

    func testSave_WhenCalledMultipleTimes_AppendsToArray() async throws {
        let clip1 = Clip(content: "First", contentType: .text)
        let clip2 = Clip(content: "Second", contentType: .text)

        try await sut.save(clip1)
        try await sut.save(clip2)

        let knowledgeFileURL = testDirectory.appendingPathComponent("knowledge.json")
        let data = try Data(contentsOf: knowledgeFileURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let clips = json?["clips"] as? [[String: Any]]

        XCTAssertEqual(clips?.count, 2)
    }

    // MARK: - Load Clips

    func testLoadAll_WhenNoClips_ReturnsEmptyArray() async throws {
        let clips = await sut.loadAll()

        XCTAssertTrue(clips.isEmpty)
    }

    func testLoadAll_WhenClipsExist_ReturnsClips() async throws {
        let clip = Clip(content: "Test", contentType: .text)
        try await sut.save(clip)

        let clips = await sut.loadAll()

        XCTAssertEqual(clips.count, 1)
        XCTAssertEqual(clips[0].content, "Test")
    }

    func testLoadAll_ReturnsSortedByTimestampDescending() async throws {
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

        try await sut.save(olderClip)
        try await sut.save(newerClip)

        let clips = await sut.loadAll()

        XCTAssertEqual(clips.count, 2)
        XCTAssertEqual(clips[0].content, "Newer")
        XCTAssertEqual(clips[1].content, "Older")
    }

    func testLoadFromDisk_LoadsExistingClipsFromFile() async throws {
        // First, save some clips
        try await sut.save(Clip(content: "First", contentType: .text))
        try await sut.save(Clip(content: "Second", contentType: .text))

        // Create a new storage instance
        let newStorage = ClipStorage(storageDirectory: testDirectory)
        try await newStorage.loadFromDisk()

        let clips = await newStorage.loadAll()
        XCTAssertEqual(clips.count, 2)
    }

    // MARK: - Delete Clip

    func testDelete_WhenClipExists_RemovesFromMemoryAndDisk() async throws {
        let clip = Clip(content: "Test", contentType: .text)
        try await sut.save(clip)

        try await sut.delete(clip.id)

        let clips = await sut.loadAll()
        XCTAssertTrue(clips.isEmpty)

        // Verify file was updated
        let knowledgeFileURL = testDirectory.appendingPathComponent("knowledge.json")
        let data = try Data(contentsOf: knowledgeFileURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let fileClips = json?["clips"] as? [[String: Any]]
        XCTAssertTrue(fileClips?.isEmpty ?? false)
    }

    func testDelete_WhenClipDoesNotExist_ThrowsError() async throws {
        let randomId = UUID()

        do {
            try await sut.delete(randomId)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is ClipStorageError)
        }
    }

    // MARK: - Clear All

    func testClearAll_WhenClipsExist_RemovesAllFromMemoryAndDisk() async throws {
        try await sut.save(Clip(content: "1", contentType: .text))
        try await sut.save(Clip(content: "2", contentType: .text))
        try await sut.save(Clip(content: "3", contentType: .text))

        try await sut.clearAll()

        let clips = await sut.loadAll()
        XCTAssertTrue(clips.isEmpty)

        // Verify file was updated
        let knowledgeFileURL = testDirectory.appendingPathComponent("knowledge.json")
        let data = try Data(contentsOf: knowledgeFileURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let fileClips = json?["clips"] as? [[String: Any]]
        XCTAssertTrue(fileClips?.isEmpty ?? false)
    }

    // MARK: - Initialize Storage Directory

    func testInit_WhenDirectoryDoesNotExist_CreatesDirectoryOnFirstAccess() async throws {
        let newDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NewDir-\(UUID().uuidString)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: newDirectory.path))

        let storage = ClipStorage(storageDirectory: newDirectory)
        try await storage.loadFromDisk()

        // Directory should be created
        XCTAssertTrue(FileManager.default.fileExists(atPath: newDirectory.path))

        try FileManager.default.removeItem(at: newDirectory)
    }

    func testInit_WhenKnowledgeJsonDoesNotExist_StartsWithEmptyClips() async throws {
        let newDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NewDir-\(UUID().uuidString)")
        let storage = ClipStorage(storageDirectory: newDirectory)
        try await storage.loadFromDisk()

        let clips = await storage.loadAll()
        XCTAssertTrue(clips.isEmpty)

        try FileManager.default.removeItem(at: newDirectory)
    }

    // MARK: - Upsert Behavior (Unique Key: sourceApp + content)

    func testSave_WhenSameSourceAppAndContent_UpdatesTimestampInsteadOfDuplicating() async throws {
        // Arrange: Save initial clip
        let originalTimestamp = Date().addingTimeInterval(-60)
        let clip1 = Clip(
            content: "Duplicate content",
            contentType: .text,
            sourceApp: "Safari",
            timestamp: originalTimestamp
        )
        try await sut.save(clip1)

        // Act: Save another clip with same sourceApp + content
        let clip2 = Clip(
            content: "Duplicate content",
            contentType: .text,
            sourceApp: "Safari",
            timestamp: Date()
        )
        try await sut.save(clip2)

        // Assert: Only one clip should exist, with updated timestamp
        let clips = await sut.loadAll()
        XCTAssertEqual(clips.count, 1, "Should not create duplicate for same sourceApp + content")
        XCTAssertNotEqual(clips[0].timestamp, originalTimestamp, "Timestamp should be updated")
        XCTAssertEqual(clips[0].content, "Duplicate content")
        XCTAssertEqual(clips[0].sourceApp, "Safari")
    }

    func testSave_WhenSameContentDifferentSourceApp_CreatesNewClip() async throws {
        // Arrange: Save clip from Safari
        let clip1 = Clip(
            content: "Same content",
            contentType: .text,
            sourceApp: "Safari"
        )
        try await sut.save(clip1)

        // Act: Save same content but from Chrome
        let clip2 = Clip(
            content: "Same content",
            contentType: .text,
            sourceApp: "Chrome"
        )
        try await sut.save(clip2)

        // Assert: Both clips should exist (different sourceApp = different key)
        let clips = await sut.loadAll()
        XCTAssertEqual(clips.count, 2, "Different sourceApp should create separate clips")
    }

    func testSave_WhenSameSourceAppDifferentContent_CreatesNewClip() async throws {
        // Arrange: Save first clip
        let clip1 = Clip(
            content: "First content",
            contentType: .text,
            sourceApp: "Safari"
        )
        try await sut.save(clip1)

        // Act: Save different content from same app
        let clip2 = Clip(
            content: "Second content",
            contentType: .text,
            sourceApp: "Safari"
        )
        try await sut.save(clip2)

        // Assert: Both clips should exist (different content = different key)
        let clips = await sut.loadAll()
        XCTAssertEqual(clips.count, 2, "Different content should create separate clips")
    }

    func testSave_WhenSameContentNilSourceApp_UpdatesExistingNilSourceAppClip() async throws {
        // Arrange: Save clip with nil sourceApp
        let originalTimestamp = Date().addingTimeInterval(-60)
        let clip1 = Clip(
            content: "Content without source",
            contentType: .text,
            sourceApp: nil,
            timestamp: originalTimestamp
        )
        try await sut.save(clip1)

        // Act: Save same content with nil sourceApp again
        let clip2 = Clip(
            content: "Content without source",
            contentType: .text,
            sourceApp: nil,
            timestamp: Date()
        )
        try await sut.save(clip2)

        // Assert: Only one clip should exist, timestamp updated
        let clips = await sut.loadAll()
        XCTAssertEqual(clips.count, 1, "Same content with nil sourceApp should update existing clip")
        XCTAssertNotEqual(clips[0].timestamp, originalTimestamp, "Timestamp should be updated")
    }

    func testSave_WhenNilSourceAppVersusSomeSourceApp_CreatesSeparateClips() async throws {
        // Arrange: Save clip with nil sourceApp
        let clip1 = Clip(
            content: "Same content",
            contentType: .text,
            sourceApp: nil
        )
        try await sut.save(clip1)

        // Act: Save same content with specific sourceApp
        let clip2 = Clip(
            content: "Same content",
            contentType: .text,
            sourceApp: "Safari"
        )
        try await sut.save(clip2)

        // Assert: Both clips should exist (nil != "Safari")
        let clips = await sut.loadAll()
        XCTAssertEqual(clips.count, 2, "nil sourceApp should be distinct from non-nil sourceApp")
    }

    func testFindClip_WhenExists_ReturnsClip() async throws {
        // Arrange
        let clip = Clip(
            content: "Find me",
            contentType: .text,
            sourceApp: "Notes"
        )
        try await sut.save(clip)

        // Act
        let found = await sut.findClip(sourceApp: "Notes", content: "Find me")

        // Assert
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.content, "Find me")
        XCTAssertEqual(found?.sourceApp, "Notes")
    }

    func testFindClip_WhenNotExists_ReturnsNil() async throws {
        // Act
        let found = await sut.findClip(sourceApp: "Notes", content: "Non-existent")

        // Assert
        XCTAssertNil(found)
    }
}
