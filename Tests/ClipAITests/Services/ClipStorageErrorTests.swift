import XCTest
@testable import ClipAI

final class ClipStorageErrorTests: XCTestCase {
    func testClipNotFound_ErrorDescription() {
        let id = UUID()
        let error = ClipStorageError.clipNotFound(id: id)

        XCTAssertEqual(error.errorDescription, "Clip with ID \(id) not found")
    }

    func testSaveFailed_ErrorDescription() {
        let error = ClipStorageError.saveFailed(reason: "Disk full")

        XCTAssertEqual(error.errorDescription, "Failed to save clip: Disk full")
    }

    func testLoadFailed_ErrorDescription() {
        let error = ClipStorageError.loadFailed(reason: "Corrupted file")

        XCTAssertEqual(error.errorDescription, "Failed to load clips: Corrupted file")
    }

    func testDeleteFailed_ErrorDescription() {
        let error = ClipStorageError.deleteFailed(reason: "File locked")

        XCTAssertEqual(error.errorDescription, "Failed to delete clip: File locked")
    }
}
