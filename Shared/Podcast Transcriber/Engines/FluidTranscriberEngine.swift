import AVFoundation
import FluidAudio
import Foundation

/// Transcription engine using FluidAudio (NVIDIA Parakeet TDT models via CoreML/ANE).
///
/// Models are downloaded on demand and stored in FluidAudio's managed cache.
/// Runs in-process on the Neural Engine. 25+ European languages supported.
struct FluidTranscriberEngine: TranscriptionEngine {

    static let requiresModelDownload = true

    private static var modelVersion: AsrModelVersion { .v3 }

    private static var cacheDirectory: URL {
        AsrModels.defaultCacheDirectory(for: modelVersion)
    }

    var isModelDownloaded: Bool {
        AsrModels.modelsExist(at: Self.cacheDirectory, version: Self.modelVersion)
    }

    var isAvailable: Bool {
        get async { isModelDownloaded }
    }

    func downloadModel(progress: (@Sendable (Double) -> Void)?) async throws {
        #if DEBUG
        debugPrint("[FluidEngine] Downloading Parakeet TDT v3 model")
        #endif
        let handler: DownloadUtils.ProgressHandler?
        if let progress {
            handler = { @Sendable (dp: DownloadUtils.DownloadProgress) -> Void in
                progress(dp.fractionCompleted)
            }
        } else {
            handler = nil
        }
        _ = try await AsrModels.download(
            version: Self.modelVersion,
            progressHandler: handler
        )
        #if DEBUG
        debugPrint("[FluidEngine] Model download complete")
        #endif
    }

    func deleteModel() throws {
        try? FileManager.default.removeItem(at: Self.cacheDirectory)
    }

    func transcribe(audioFileURL: URL, title: String) async throws -> [TranscriptSegment] {
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw TranscriptionEngineError.audioFileUnreadable
        }
        guard isModelDownloaded else {
            throw TranscriptionEngineError.modelNotDownloaded
        }

        #if DEBUG
        debugPrint("[FluidEngine] Loading Parakeet TDT v3 model")
        #endif

        let models = try await AsrModels.downloadAndLoad(version: Self.modelVersion)
        let manager = AsrManager(models: models)

        #if DEBUG
        debugPrint("[FluidEngine] Transcribing \(audioFileURL.lastPathComponent)")
        #endif

        var decoderState = TdtDecoderState.make()
        let result = try await manager.transcribe(audioFileURL, decoderState: &decoderState)

        // FluidAudio returns full text without segment-level timestamps.
        // Split into sentences and distribute timestamps proportionally.
        let duration = try await Self.audioDuration(of: audioFileURL)
        return Self.distributeTimestamps(text: result.text, totalDuration: duration)
    }

    // MARK: - Helpers

    /// Returns the duration of an audio file in seconds.
    private static func audioDuration(of url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    /// Splits text into sentences and assigns evenly distributed timestamps.
    static func distributeTimestamps(text: String, totalDuration: TimeInterval) -> [TranscriptSegment] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, totalDuration > 0 else { return [] }

        var sentences: [String] = []
        trimmed.enumerateSubstrings(in: trimmed.startIndex..., options: [.bySentences, .localized]) { sub, _, _, _ in
            if let sentence = sub?.trimmingCharacters(in: .whitespacesAndNewlines), !sentence.isEmpty {
                sentences.append(sentence)
            }
        }
        if sentences.isEmpty {
            sentences = [trimmed]
        }

        let segmentDuration = totalDuration / Double(sentences.count)
        return sentences.enumerated().map { (index, sentence) in
            TranscriptSegment(
                id: index,
                start: Double(index) * segmentDuration,
                end: Double(index + 1) * segmentDuration,
                text: sentence
            )
        }
    }
}
