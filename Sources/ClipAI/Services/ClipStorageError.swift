import Foundation

/// Errors that can occur during clip storage operations.
enum ClipStorageError: LocalizedError {
    /// The clip with the specified ID was not found.
    case clipNotFound(id: UUID)

    /// Failed to save the clip to storage.
    case saveFailed(reason: String)

    /// Failed to load clips from storage.
    case loadFailed(reason: String)

    /// Failed to delete the clip from storage.
    case deleteFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .clipNotFound(let id):
            return "Clip with ID \(id) not found"
        case .saveFailed(let reason):
            return "Failed to save clip: \(reason)"
        case .loadFailed(let reason):
            return "Failed to load clips: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete clip: \(reason)"
        }
    }
}
