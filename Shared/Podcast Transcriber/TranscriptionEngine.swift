import Foundation

/// The user-facing identifier for each transcription engine.
enum TranscriptionEngineType: String, CaseIterable, Identifiable, Codable {
    case off = "off"
    case speech = "speech"
    case whisper = "whisper"
    case fluid = "fluid"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off:     return String(localized: "Podcast.Transcripts.Engine.Off")
        case .speech:  return String(localized: "Podcast.Transcripts.Engine.iOS")
        case .whisper: return String(localized: "Podcast.Transcripts.Engine.Whisper")
        case .fluid:   return String(localized: "Podcast.Transcripts.Engine.Parakeet")
        }
    }

    var engineDescription: String {
        switch self {
        case .off:
            return String(localized: "Podcast.Transcripts.Engine.Off.Description")
        case .speech:
            return String(localized: "Podcast.Transcripts.Engine.iOS.Description")
        case .whisper:
            return String(localized: "Podcast.Transcripts.Engine.Whisper.Description")
        case .fluid:
            return String(localized: "Podcast.Transcripts.Engine.Parakeet.Description")
        }
    }

    /// Whether this engine requires a downloaded model to function.
    var requiresModelDownload: Bool {
        switch self {
        case .off, .speech: return false
        case .whisper, .fluid: return true
        }
    }
}

/// Errors that any transcription engine may throw.
enum TranscriptionEngineError: Error {
    case notAvailable
    case audioFileUnreadable
    case authorizationDenied
    case noCompatibleAudioFormat
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

    /// Downloads the model. Only called for engines where ``requiresModelDownload`` is true.
    /// The progress callback reports fractional progress (0.0–1.0) if the underlying
    /// library supports it. Pass `nil` if progress reporting is not needed.
    func downloadModel(progress: (@Sendable (Double) -> Void)?) async throws

    /// Deletes the downloaded model. Only called for engines where ``requiresModelDownload`` is true.
    func deleteModel() throws
}

/// Default implementations for engines that don't need model management.
extension TranscriptionEngine {
    func downloadModel(progress: (@Sendable (Double) -> Void)?) async throws {}
    func deleteModel() throws {}
}
