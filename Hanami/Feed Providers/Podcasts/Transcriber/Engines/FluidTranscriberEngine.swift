import AVFoundation
import FluidAudio
import Foundation

/// Transcription engine using FluidAudio's Parakeet TDT models on the Neural Engine.
public struct FluidTranscriberEngine: TranscriptionEngine {

    public init() {}

    public static let requiresModelDownload = true

    internal static var modelVersion: AsrModelVersion { .v3 }

    internal static var cacheDirectory: URL {
        AsrModels.defaultCacheDirectory(for: modelVersion)
    }

    public var isModelDownloaded: Bool {
        AsrModels.modelsExist(at: Self.cacheDirectory, version: Self.modelVersion)
    }

    public var isAvailable: Bool {
        get async { isModelDownloaded }
    }

    public func downloadModel(progress: (@Sendable (Double) -> Void)?) async throws {
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

    public func deleteModel() throws {
        try? FileManager.default.removeItem(at: Self.cacheDirectory)
    }

    public func transcribe(audioFileURL: URL, title: String) async throws -> [TranscriptSegment] {
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
    public static func buildSegments(from timings: [TokenTiming]) -> [TranscriptSegment] {
        var builder = SegmentBuilder()
        for timing in timings {
            builder.consume(timing)
        }
        builder.flush()

        var segments = builder.segments
        if segments.isEmpty {
            segments = fallbackSingleSegment(from: timings) ?? []
        }
        return segments
    }

    private static func fallbackSingleSegment(
        from timings: [TokenTiming]
    ) -> [TranscriptSegment]? {
        guard let first = timings.first, let last = timings.last else { return nil }
        let text = timings
            .map(\.token)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return [TranscriptSegment(
            id: 0,
            start: first.startTime,
            end: max(last.endTime, first.startTime + 0.001),
            text: text
        )]
    }

    private struct SegmentBuilder {
        var segments: [TranscriptSegment] = []
        private var buffer = ""
        private var segmentStart: TimeInterval?
        private var segmentEnd: TimeInterval = 0
        private var nextID = 0

        mutating func consume(_ timing: TokenTiming) {
            if segmentStart == nil { segmentStart = timing.startTime }
            buffer.append(timing.token)
            segmentEnd = timing.endTime
            if endsSentence(timing.token) {
                flush()
            }
        }

        mutating func flush() {
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
    }

    private static func endsSentence(_ token: String) -> Bool {
        guard let last = token.last else { return false }
        return last == "." || last == "!" || last == "?" || last == "。" || last == "？" || last == "！"
    }
    private static func audioDuration(of url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    /// Degraded fallback: splits text into sentences with evenly distributed timestamps.
    public static func distributeTimestamps(text: String, totalDuration: TimeInterval) -> [TranscriptSegment] {
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
