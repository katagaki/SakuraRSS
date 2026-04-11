import Foundation
import WhisperKit

/// Transcription engine using WhisperKit (OpenAI Whisper models via CoreML/ANE).
///
/// Models are downloaded on demand and cached locally.
/// Runs in-process on the Neural Engine. Supports MP3/M4A/WAV natively.
struct WhisperTranscriberEngine: TranscriptionEngine {

    static let requiresModelDownload = true

    private var modelVariant: String {
        "openai_whisper-\(UserDefaults.standard.string(forKey: "Podcast.WhisperModel") ?? "base")"
    }

    var isModelDownloaded: Bool {
        guard let folder = try? WhisperKit.modelFolder(for: modelVariant) else { return false }
        return FileManager.default.fileExists(atPath: folder)
    }

    var isAvailable: Bool {
        get async { isModelDownloaded }
    }

    func downloadModel() async throws {
        let variant = modelVariant
        #if DEBUG
        debugPrint("[WhisperEngine] Downloading model '\(variant)'")
        #endif
        _ = try await WhisperKit.download(variant: variant)
        #if DEBUG
        debugPrint("[WhisperEngine] Model download complete")
        #endif
    }

    func deleteModel() throws {
        // WhisperKit stores models in Application Support/huggingface
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let hfHub = appSupport.appendingPathComponent("huggingface", isDirectory: true)
        if FileManager.default.fileExists(atPath: hfHub.path) {
            try FileManager.default.removeItem(at: hfHub)
        }
    }

    func transcribe(audioFileURL: URL, title: String) async throws -> [TranscriptSegment] {
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw TranscriptionEngineError.audioFileUnreadable
        }
        guard isModelDownloaded else {
            throw TranscriptionEngineError.modelNotDownloaded
        }

        #if DEBUG
        debugPrint("[WhisperEngine] Initializing WhisperKit with model '\(modelVariant)'")
        #endif

        let config = WhisperKitConfig(model: modelVariant, download: false)
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
