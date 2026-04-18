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
        let handler: DownloadUtils.ProgressHandler?
        if let progress {
            handler = { @Sendable (downloadProgress: DownloadUtils.DownloadProgress) in
                progress(downloadProgress.fractionCompleted)
            }
        } else {
            handler = nil
        }
        _ = try await AsrModels.download(
            version: Self.modelVersion,
            progressHandler: handler
        )
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

        let models = try await AsrModels.downloadAndLoad(version: Self.modelVersion)
        let manager = AsrManager(models: models)

        var decoderState = TdtDecoderState.make()
        let result = try await manager.transcribe(audioFileURL, decoderState: &decoderState)

        if let timings = result.tokenTimings, !timings.isEmpty {
            return Self.buildSegments(from: timings)
        }

        // Fallback: no token timings returned (shouldn't happen for TDT models).
        let duration = try await Self.audioDuration(of: audioFileURL)
        return Self.distributeTimestamps(text: result.text, totalDuration: duration)
    }

    // MARK: - Segment construction from token timings

    /// Group per-token timings into sentence-level `TranscriptSegment`s using
    /// real start/end times from the TDT decoder.
    ///
    /// FluidAudio normalizes tokens before returning them: the SentencePiece
    /// word-boundary marker `▁` is already replaced with a space, so simply
    /// concatenating `token` strings yields the natural transcript text.
    /// Punctuation tokens (`.`, `!`, `?`) are attached to the preceding word
    /// and mark sentence boundaries.
    static func buildSegments(from timings: [TokenTiming]) -> [TranscriptSegment] {
        var segments: [TranscriptSegment] = []
        var buffer = ""
        var segmentStart: TimeInterval?
        var segmentEnd: TimeInterval = 0
        var nextID = 0

        func flush() {
            let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let start = segmentStart else {
                buffer = ""
                segmentStart = nil
                return
            }
            segments.append(
                TranscriptSegment(
                    id: nextID,
                    start: start,
                    end: max(segmentEnd, start + 0.001),
                    text: trimmed
                )
            )
            nextID += 1
            buffer = ""
            segmentStart = nil
        }

        for timing in timings {
            if segmentStart == nil {
                segmentStart = timing.startTime
            }
            buffer.append(timing.token)
            segmentEnd = timing.endTime

            if endsSentence(timing.token) {
                flush()
            }
        }
        flush()

        // If no sentence punctuation was ever emitted, fall back to one segment
        // covering the entire utterance.
        if segments.isEmpty, let first = timings.first, let last = timings.last {
            let text = timings
                .map(\.token)
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                segments.append(
                    TranscriptSegment(
                        id: 0,
                        start: first.startTime,
                        end: max(last.endTime, first.startTime + 0.001),
                        text: text
                    )
                )
            }
        }

        return segments
    }

    /// Whether a token's trailing character ends a sentence.
    private static func endsSentence(_ token: String) -> Bool {
        guard let last = token.last else { return false }
        return last == "." || last == "!" || last == "?" || last == "。" || last == "？" || last == "！"
    }

    // MARK: - Helpers

    /// Returns the duration of an audio file in seconds.
    private static func audioDuration(of url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    /// Degraded fallback for the rare case where no token timings are returned.
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
