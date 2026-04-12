import Foundation

/// Central dispatcher for podcast transcription.
///
/// Reads the user's "transcription enabled" preference from UserDefaults and
/// delegates to the FluidAudio Parakeet engine. Skips transcription if the
/// toggle is off or the model hasn't finished downloading.
enum PodcastTranscriber {

    /// UserDefaults key for the Parakeet-on-off toggle.
    static let enabledKey = "Podcast.TranscriptionEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static var engine: any TranscriptionEngine { FluidTranscriberEngine() }

    // MARK: - Public API

    /// Whether transcription is enabled and the Parakeet model is downloaded.
    static var isAvailable: Bool {
        get async {
            guard isEnabled else { return false }
            guard engine.isModelDownloaded else { return false }
            return await engine.isAvailable
        }
    }

    /// Transcribes a local audio file using the Parakeet engine.
    static func transcribe(audioFileURL: URL, title: String) async throws -> [TranscriptSegment] {
        guard isEnabled else {
            throw TranscriptionEngineError.notAvailable
        }
        guard engine.isModelDownloaded else {
            throw TranscriptionEngineError.modelNotDownloaded
        }
        return try await engine.transcribe(audioFileURL: audioFileURL, title: title)
    }
}
