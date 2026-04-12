import Foundation

/// Errors that any transcription engine may throw.
enum TranscriptionEngineError: Error {
    case notAvailable
    case audioFileUnreadable
    case modelNotDownloaded
    case transcriptionFailed(String)
}

/// Protocol that all transcription engines conform to.
protocol TranscriptionEngine: Sendable {
    /// Whether this engine requires a separate model download.
    static var requiresModelDownload: Bool { get }

    /// Whether the model is currently downloaded and ready to use.
    var isModelDownloaded: Bool { get }

    /// Check if this engine is available and ready to use.
    var isAvailable: Bool { get async }

    /// Transcribe a local audio file and return timed segments.
    func transcribe(audioFileURL: URL, title: String) async throws -> [TranscriptSegment]

    /// Downloads the model. The progress callback reports fractional progress (0.0–1.0).
    func downloadModel(progress: (@Sendable (Double) -> Void)?) async throws

    /// Deletes the downloaded model.
    func deleteModel() throws
}
