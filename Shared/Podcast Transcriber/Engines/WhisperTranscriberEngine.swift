import Foundation
import WhisperKit

/// Transcription engine using WhisperKit (OpenAI Whisper models via CoreML/ANE).
///
/// Models are downloaded on demand and cached locally.
/// Runs in-process on the Neural Engine. Supports MP3/M4A/WAV natively.
struct WhisperTranscriberEngine: TranscriptionEngine {

    static let requiresModelDownload = true

    /// Base directory for all WhisperKit models.
    private static var baseDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WhisperKit", isDirectory: true)
    }

    private var modelName: String {
        "openai_whisper-\(UserDefaults.standard.string(forKey: "Podcast.WhisperModel") ?? "base")"
    }

    /// The folder containing the actual .mlmodelc files for the selected model.
    private var modelFolder: URL {
        Self.baseDirectory.appendingPathComponent(modelName, isDirectory: true)
    }

    var isModelDownloaded: Bool {
        let dir = modelFolder
        guard FileManager.default.fileExists(atPath: dir.path) else { return false }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return contents.contains { $0.hasSuffix(".mlmodelc") }
    }

    var isAvailable: Bool {
        get async { isModelDownloaded }
    }

    func downloadModel() async throws {
        #if DEBUG
        debugPrint("[WhisperEngine] Downloading model '\(modelName)'")
        #endif
        try FileManager.default.createDirectory(at: Self.baseDirectory, withIntermediateDirectories: true)
        let config = WhisperKitConfig(
            model: modelName,
            downloadBase: Self.baseDirectory
        )
        _ = try await WhisperKit(config)
        #if DEBUG
        debugPrint("[WhisperEngine] Model download complete")
        #endif
    }

    func deleteModel() throws {
        let dir = Self.baseDirectory
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
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
        debugPrint("[WhisperEngine] Initializing WhisperKit with model '\(modelName)' from \(modelFolder.path())")
        #endif

        let config = WhisperKitConfig(
            modelFolder: modelFolder.path()
        )
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
