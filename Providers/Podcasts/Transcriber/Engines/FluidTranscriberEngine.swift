import AVFoundation
import FluidAudio
import Foundation

/// Transcription engine using FluidAudio's Parakeet TDT models on the Neural Engine.
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

        // Fallback: no token timings (shouldn't happen for TDT models).
        let duration = try await Self.audioDuration(of: audioFileURL)
        return Self.distributeTimestamps(text: result.text, totalDuration: duration)
    }

    // MARK: - Segment construction from token timings

    /// Groups per-token timings into sentence-level segments using the TDT decoder's timestamps.
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

        // Fallback single-segment if no sentence punctuation was emitted.
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

    private static func endsSentence(_ token: String) -> Bool {
        guard let last = token.last else { return false }
        return last == "." || last == "!" || last == "?" || last == "。" || last == "？" || last == "！"
    }

    // MARK: - Helpers

    private static func audioDuration(of url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    /// Degraded fallback: splits text into sentences with evenly distributed timestamps.
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
