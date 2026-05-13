import Foundation

public enum TranscriptionEngineError: Error {
    case notAvailable
    case audioFileUnreadable
    case modelNotDownloaded
    case transcriptionFailed(String)
}

public protocol TranscriptionEngine: Sendable {
    static var requiresModelDownload: Bool { get }

    var isModelDownloaded: Bool { get }

    var isAvailable: Bool { get async }

    func transcribe(
        audioFileURL: URL,
        title: String,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> [TranscriptSegment]

    /// Progress callback reports fractional progress (0.0 to 1.0).
    func downloadModel(progress: (@Sendable (Double) -> Void)?) async throws

    func deleteModel() throws
}

extension TranscriptionEngine {
    public func transcribe(audioFileURL: URL, title: String) async throws -> [TranscriptSegment] {
        try await transcribe(audioFileURL: audioFileURL, title: title, progress: nil)
    }
}
