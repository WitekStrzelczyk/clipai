import Foundation
import OSLog

/// Log file URL for debugging
private var storageLogFileURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".clipai/clipai.log")
}

/// Writes a log message to file and console
private func storageLog(_ message: String) {
    let formatted = "[ClipAI-Storage] \(message)"
    print(formatted)
    writeToLogFile(formatted)
}

private func writeToLogFile(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "\(timestamp) \(message)\n"
    guard let data = line.data(using: .utf8) else { return }

    // Create directory if needed
    let dir = storageLogFileURL.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: dir.path) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // Append to file
    if FileManager.default.fileExists(atPath: storageLogFileURL.path) {
        let handle = try? FileHandle(forWritingTo: storageLogFileURL)
        handle?.seekToEndOfFile()
        handle?.write(data)
        handle?.closeFile()
    } else {
        try? data.write(to: storageLogFileURL)
    }
}

/// Actor responsible for persisting clips to disk.
/// Uses a single knowledge.json file to store all clips.
actor ClipStorage {
    private let logger = Logger(subsystem: "com.clipai.app", category: "ClipStorage")
    private let fileManager = FileManager.default
    private let storageDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// In-memory cache of all clips
    private var clips: [Clip]

    /// The URL for the knowledge.json file
    private var knowledgeFileURL: URL {
        storageDirectory.appendingPathComponent("knowledge.json")
    }

    /// Creates a new ClipStorage instance and loads existing clips.
    /// - Parameter storageDirectory: The directory where knowledge.json will be stored.
    init(storageDirectory: URL) {
        self.storageDirectory = storageDirectory
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Initialize empty clips array, will be loaded in loadFromDisk
        self.clips = []

        storageLog("ClipStorage initialized with directory: \(storageDirectory.path)")
    }

    /// Loads clips from disk. Must be called after init.
    func loadFromDisk() throws {
        ensureDirectoryExists()

        guard fileManager.fileExists(atPath: knowledgeFileURL.path) else {
            storageLog("No existing knowledge.json file, starting with empty clips")
            clips = []
            return
        }

        do {
            let data = try Data(contentsOf: knowledgeFileURL)
            let knowledgeFile = try decoder.decode(KnowledgeFile.self, from: data)
            self.clips = knowledgeFile.clips
            storageLog("Loaded \(self.clips.count) clips from knowledge.json")
            self.logger.debug("Loaded \(self.clips.count) clips from knowledge.json")
        } catch {
            storageLog("ERROR: Failed to load knowledge.json: \(error.localizedDescription)")
            logger.error("Failed to load knowledge.json: \(error.localizedDescription)")
            throw ClipStorageError.loadFailed(reason: error.localizedDescription)
        }
    }

    /// Saves a clip to memory and persists to disk.
    /// If a clip with the same sourceApp + content already exists, updates its timestamp instead of creating a duplicate.
    /// - Parameter clip: The clip to save.
    /// - Throws: ClipStorageError.saveFailed if the save fails.
    func save(_ clip: Clip) throws {
        storageLog("save() called for clip: \(clip.id)")

        // Check if a clip with same sourceApp + content exists (upsert logic)
        if let existingIndex = clips.firstIndex(where: { existingClip in
            existingClip.sourceApp == clip.sourceApp && existingClip.content == clip.content
        }) {
            // Update existing clip's timestamp
            storageLog("Found existing clip with same key, updating timestamp for clip: \(clips[existingIndex].id)")
            clips[existingIndex] = clips[existingIndex].withUpdatedTimestamp()
        } else {
            // Add new clip
            clips.append(clip)
        }

        // Persist to disk
        do {
            try saveToDisk()
            storageLog("Successfully saved clip \(clip.id)")
            logger.debug("Saved clip \(clip.id)")
        } catch {
            // Remove from memory if save failed
            clips.removeAll { $0.id == clip.id }
            throw error
        }
    }

    /// Finds a clip by its source app and content (the unique key).
    /// - Parameters:
    ///   - sourceApp: The source application name.
    ///   - content: The clip content.
    /// - Returns: The matching clip, or nil if not found.
    func findClip(sourceApp: String?, content: String) -> Clip? {
        clips.first { clip in
            clip.sourceApp == sourceApp && clip.content == content
        }
    }

    /// Loads all clips from memory, sorted by timestamp descending.
    /// - Returns: An array of clips, newest first.
    func loadAll() -> [Clip] {
        // Return sorted copy
        clips.sorted { $0.timestamp > $1.timestamp }
    }

    /// Deletes a clip by its ID.
    /// - Parameter id: The ID of the clip to delete.
    /// - Throws: ClipStorageError.clipNotFound if the clip doesn't exist,
    ///           or ClipStorageError.deleteFailed if deletion fails.
    func delete(_ id: UUID) throws {
        storageLog("delete() called for clip: \(id)")

        guard let index = clips.firstIndex(where: { $0.id == id }) else {
            storageLog("ERROR: Clip not found: \(id)")
            throw ClipStorageError.clipNotFound(id: id)
        }

        clips.remove(at: index)

        do {
            try saveToDisk()
            storageLog("Successfully deleted clip \(id)")
            logger.debug("Deleted clip \(id)")
        } catch {
            throw error
        }
    }

    /// Clears all clips from memory and disk.
    /// - Throws: ClipStorageError.deleteFailed if clearing fails.
    func clearAll() throws {
        storageLog("clearAll() called")

        clips = []

        do {
            try saveToDisk()
            storageLog("Successfully cleared all clips")
            logger.info("Cleared all clips from storage")
        } catch {
            throw error
        }
    }

    // MARK: - Private

    private func saveToDisk() throws {
        ensureDirectoryExists()

        let knowledgeFile = KnowledgeFile(clips: clips)

        do {
            let data = try encoder.encode(knowledgeFile)
            try data.write(to: knowledgeFileURL)
            storageLog("Saved \(clips.count) clips to knowledge.json")
        } catch {
            storageLog("ERROR: Failed to save knowledge.json: \(error.localizedDescription)")
            logger.error("Failed to save knowledge.json: \(error.localizedDescription)")
            throw ClipStorageError.saveFailed(reason: error.localizedDescription)
        }
    }

    private func ensureDirectoryExists() {
        let directoryPath = storageDirectory.path
        storageLog("Checking if directory exists: \(directoryPath)")
        if !fileManager.fileExists(atPath: directoryPath) {
            storageLog("Directory does not exist, creating...")
            do {
                try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
                storageLog("Successfully created storage directory at \(directoryPath)")
                logger.info("Created storage directory at \(directoryPath)")
            } catch {
                storageLog("ERROR: Failed to create storage directory: \(error.localizedDescription)")
                logger.error("Failed to create storage directory: \(error.localizedDescription)")
            }
        } else {
            storageLog("Directory already exists")
        }
    }
}
