import Foundation

/// Represents the structure of the knowledge.json file.
struct KnowledgeFile: Sendable, Codable {
    /// The array of clips stored in the knowledge base.
    var clips: [Clip]

    /// Creates an empty knowledge file.
    init(clips: [Clip] = []) {
        self.clips = clips
    }
}
