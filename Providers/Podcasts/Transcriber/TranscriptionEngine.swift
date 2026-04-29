import Foundation

enum TranscriptionEngineError: Error {
    case notAvailable
    case audioFileUnreadable
    case modelNotDownloaded
    case transcriptionFailed(String)
}

protocol TranscriptionEngine: Sendable {
    static var requiresModelDownload: Bool { get }

    var isModelDownloaded: Bool { get }

    var isAvailable: Bool { get async }

    func transcribe(audioFileURL: URL, title: String) async throws -> [TranscriptSegment]

    /// Progress callback reports fractional progress (0.0–1.0).
    func downloadModel(progress: (@Sendable (Double) -> Void)?) async throws

    func deleteModel() throws
}
