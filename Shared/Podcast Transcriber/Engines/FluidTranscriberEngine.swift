import AVFoundation
import FluidAudio
import Foundation

/// Transcription engine using FluidAudio (NVIDIA Parakeet TDT models via CoreML/ANE).
///
/// Models are downloaded from HuggingFace on first use and cached locally.
/// Runs in-process on the Neural Engine. 25+ European languages supported.
struct FluidTranscriberEngine: TranscriptionEngine {

    var isAvailable: Bool {
        get async { true }
    }

    func transcribe(audioFileURL: URL, title: String) async throws -> [TranscriptSegment] {
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw TranscriptionEngineError.audioFileUnreadable
        }

        #if DEBUG
        debugPrint("[FluidEngine] Downloading/loading Parakeet TDT v3 models")
        #endif

        let models = try await AsrModels.downloadAndLoad(version: .v3)
        let manager = AsrManager(models: models)

        #if DEBUG
        debugPrint("[FluidEngine] Transcribing \(audioFileURL.lastPathComponent)")
        #endif

        var decoderState = TdtDecoderState.make()
        let result = try await manager.transcribe(audioFileURL, decoderState: &decoderState)

        // FluidAudio returns full text without segment-level timestamps.
        // Split into sentences and distribute timestamps proportionally
        // across the audio duration for a usable transcript.
        let duration = try await Self.audioDuration(of: audioFileURL)
        return Self.distributeTimestamps(
            text: result.text,
            totalDuration: duration
        )
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

        // Split on sentence boundaries.
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
