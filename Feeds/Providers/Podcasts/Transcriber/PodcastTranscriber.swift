import Foundation

/// Dispatcher that gates transcription on user opt-in and model availability.
enum PodcastTranscriber {

    static let enabledKey = "Podcast.TranscriptionEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static var engine: any TranscriptionEngine { FluidTranscriberEngine() }

    // MARK: - Public API

    static var isAvailable: Bool {
        get async {
            guard isEnabled else { return false }
            guard engine.isModelDownloaded else { return false }
            return await engine.isAvailable
        }
    }

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
