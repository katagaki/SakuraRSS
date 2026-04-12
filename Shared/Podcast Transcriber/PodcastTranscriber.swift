import Foundation

/// Central dispatcher for podcast transcription.
///
/// Reads the user's engine preference from UserDefaults and delegates
/// to the corresponding ``TranscriptionEngine`` implementation.
/// Skips transcription entirely if the selected engine requires a model
/// that hasn't been downloaded yet.
enum PodcastTranscriber {

    private static var selectedEngineType: TranscriptionEngineType {
        guard let raw = UserDefaults.standard.string(forKey: "Podcast.TranscriptionEngine"),
              let type = TranscriptionEngineType(rawValue: raw) else {
            return .off
        }
        return type
    }

    static func engine(for type: TranscriptionEngineType) -> (any TranscriptionEngine)? {
        switch type {
        case .off:     return nil
        case .speech:  return SpeechTranscriberEngine()
        case .whisper: return WhisperTranscriberEngine()
        case .fluid:   return FluidTranscriberEngine()
        }
    }

    // MARK: - Public API

    /// Whether transcription is enabled, the selected engine is available,
    /// and any required models are downloaded.
    static var isAvailable: Bool {
        get async {
            guard let engine = engine(for: selectedEngineType) else { return false }
            if type(of: engine).requiresModelDownload && !engine.isModelDownloaded {
                return false
            }
            return await engine.isAvailable
        }
    }

    /// Transcribes a local audio file using the user's selected engine.
    static func transcribe(audioFileURL: URL, title: String) async throws -> [TranscriptSegment] {
        guard let engine = engine(for: selectedEngineType) else {
            throw TranscriptionEngineError.notAvailable
        }
        if type(of: engine).requiresModelDownload && !engine.isModelDownloaded {
            throw TranscriptionEngineError.modelNotDownloaded
        }
        return try await engine.transcribe(audioFileURL: audioFileURL, title: title)
    }
}
