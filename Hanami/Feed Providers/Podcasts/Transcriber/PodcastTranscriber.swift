import Foundation

/// Dispatcher that gates transcription on user opt-in and model availability.
public enum PodcastTranscriber {

    public static let enabledKey = "Podcast.TranscriptionEnabled"

    public static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    public static var engine: any TranscriptionEngine { FluidTranscriberEngine() }

    // MARK: - Public API

    public static var isAvailable: Bool {
        get async {
            guard isEnabled else { return false }
            guard engine.isModelDownloaded else { return false }
            return await engine.isAvailable
        }
    }

    public static func transcribe(audioFileURL: URL, title: String) async throws -> [TranscriptSegment] {
        guard isEnabled else {
            throw TranscriptionEngineError.notAvailable
        }
        guard engine.isModelDownloaded else {
            throw TranscriptionEngineError.modelNotDownloaded
        }
        return try await engine.transcribe(audioFileURL: audioFileURL, title: title)
    }

    public static func makeStreamingSession() async throws -> StreamingTranscriptionSession {
        guard isEnabled else {
            throw TranscriptionEngineError.notAvailable
        }
        return try await FluidTranscriberEngine().makeStreamingSession()
    }
}
