import Foundation
import WhisperKit

/// Transcription engine using WhisperKit (OpenAI Whisper models via CoreML/ANE).
///
/// Models are downloaded on demand and cached locally.
/// Runs in-process on the Neural Engine. Supports MP3/M4A/WAV natively.
struct WhisperTranscriberEngine: TranscriptionEngine {

    static let requiresModelDownload = true

    private static var modelVariant: String {
        "openai_whisper-\(UserDefaults.standard.string(forKey: "Podcast.WhisperModel") ?? "base")"
    }

    /// Directory where WhisperKit.download stores the model.
    /// We persist the path after download so we can find it again.
    private static var storedModelFolder: String? {
        get { UserDefaults.standard.string(forKey: "Podcast.WhisperModelFolder") }
        set { UserDefaults.standard.set(newValue, forKey: "Podcast.WhisperModelFolder") }
    }

    var isModelDownloaded: Bool {
        guard let folder = Self.storedModelFolder else { return false }
        return FileManager.default.fileExists(atPath: folder)
    }

    var isAvailable: Bool {
        get async { isModelDownloaded }
    }

    func downloadModel() async throws {
        let variant = Self.modelVariant
        #if DEBUG
        debugPrint("[WhisperEngine] Downloading model '\(variant)'")
        #endif
        let folder = try await WhisperKit.download(variant: variant)
        Self.storedModelFolder = folder.path
        #if DEBUG
        debugPrint("[WhisperEngine] Model downloaded to \(folder.path)")
        #endif
    }

    func deleteModel() throws {
        if let folder = Self.storedModelFolder {
            // Delete the specific model folder
            if FileManager.default.fileExists(atPath: folder) {
                try FileManager.default.removeItem(atPath: folder)
            }
            // Also try to clean up the parent (repo) directory if empty
            let parent = (folder as NSString).deletingLastPathComponent
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: parent)) ?? []
            if contents.isEmpty {
                try? FileManager.default.removeItem(atPath: parent)
            }
        }
        Self.storedModelFolder = nil
    }

    func transcribe(audioFileURL: URL, title: String) async throws -> [TranscriptSegment] {
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw TranscriptionEngineError.audioFileUnreadable
        }
        guard let folder = Self.storedModelFolder, FileManager.default.fileExists(atPath: folder) else {
            throw TranscriptionEngineError.modelNotDownloaded
        }

        #if DEBUG
        debugPrint("[WhisperEngine] Loading WhisperKit from \(folder)")
        #endif

        let config = WhisperKitConfig(
            modelFolder: folder,
            download: false
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
