import Foundation
import WhisperKit

/// Transcription engine using WhisperKit (OpenAI Whisper models via CoreML/ANE).
///
/// Models are downloaded from HuggingFace on first use and cached locally.
/// Runs in-process on the Neural Engine. Supports MP3/M4A/WAV natively.
struct WhisperTranscriberEngine: TranscriptionEngine {

    var isAvailable: Bool {
        get async { true }
    }

    func transcribe(audioFileURL: URL, title: String) async throws -> [TranscriptSegment] {
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw TranscriptionEngineError.audioFileUnreadable
        }

        let modelName = UserDefaults.standard.string(forKey: "Podcast.WhisperModel") ?? "base"

        #if DEBUG
        debugPrint("[WhisperEngine] Initializing WhisperKit with model '\(modelName)'")
        #endif

        let config = WhisperKitConfig(model: "openai_whisper-\(modelName)")
        let pipe = try await WhisperKit(config)

        #if DEBUG
        debugPrint("[WhisperEngine] Transcribing \(audioFileURL.lastPathComponent)")
        #endif

        let results = try await pipe.transcribe(audioPath: audioFileURL.path())

        var segments: [TranscriptSegment] = []
        var nextID = 0
        for result in results {
            for segment in result.segments {
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                segments.append(TranscriptSegment(
                    id: nextID,
                    start: TimeInterval(segment.start),
                    end: TimeInterval(segment.end),
                    text: text
                ))
                nextID += 1
            }
        }
        return segments
    }
}
