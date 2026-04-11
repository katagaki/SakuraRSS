import Foundation

/// The user-facing identifier for each transcription engine.
enum TranscriptionEngineType: String, CaseIterable, Identifiable, Codable {
    case off = "off"
    case speech = "speech"
    case whisper = "whisper"
    case fluid = "fluid"
    case qwen = "qwen"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off:     return String(localized: "Podcast.Transcripts.Engine.Off")
        case .speech:  return String(localized: "Podcast.Transcripts.Engine.iOS")
        case .whisper: return String(localized: "Podcast.Transcripts.Engine.Whisper")
        case .fluid:   return String(localized: "Podcast.Transcripts.Engine.Parakeet")
        case .qwen:    return String(localized: "Podcast.Transcripts.Engine.Qwen")
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
        case .qwen:
            return String(localized: "Podcast.Transcripts.Engine.Qwen.Description")
        }
    }
}

/// Errors that any transcription engine may throw.
enum TranscriptionEngineError: Error {
    case notAvailable
    case audioFileUnreadable
    case authorizationDenied
    case noCompatibleAudioFormat
    case transcriptionFailed(String)
}

/// Protocol that all transcription engines conform to.
protocol TranscriptionEngine: Sendable {
    /// Check if this engine is available and ready to use.
    var isAvailable: Bool { get async }

    /// Transcribe a local audio file and return timed segments.
    func transcribe(audioFileURL: URL, title: String) async throws -> [TranscriptSegment]
}
