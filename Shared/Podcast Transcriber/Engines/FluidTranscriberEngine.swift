import AVFoundation
import Foundation
import ParakeetASR

/// Transcription engine using ParakeetASR (NVIDIA Parakeet TDT models via CoreML/ANE).
///
/// Models are downloaded on demand and cached in Application Support.
/// Runs in-process on the Neural Engine. 25 European languages supported.
struct FluidTranscriberEngine: TranscriptionEngine {

    static let requiresModelDownload = true

    private static var modelDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ParakeetASR", isDirectory: true)
    }

    var isModelDownloaded: Bool {
        let dir = Self.modelDirectory
        // Check if the cache directory exists and contains model files.
        guard FileManager.default.fileExists(atPath: dir.path) else { return false }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return !contents.isEmpty
    }

    var isAvailable: Bool {
        get async { isModelDownloaded }
    }

    func downloadModel() async throws {
        #if DEBUG
        debugPrint("[ParakeetEngine] Downloading Parakeet TDT v3 model")
        #endif
        try FileManager.default.createDirectory(at: Self.modelDirectory, withIntermediateDirectories: true)
        _ = try await ParakeetASRModel.fromPretrained(cacheDir: Self.modelDirectory)
        #if DEBUG
        debugPrint("[ParakeetEngine] Model download complete")
        #endif
    }

    func deleteModel() throws {
        let dir = Self.modelDirectory
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
        debugPrint("[ParakeetEngine] Loading Parakeet TDT v3 model")
        #endif

        let model = try await ParakeetASRModel.fromPretrained(
            cacheDir: Self.modelDirectory,
            offlineMode: true
        )

        #if DEBUG
        debugPrint("[ParakeetEngine] Transcribing \(audioFileURL.lastPathComponent)")
        #endif

        // Load audio samples from the file.
        let audioFile = try AVAudioFile(forReading: audioFileURL)
        let sampleRate = audioFile.processingFormat.sampleRate
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: frameCount
        ) else {
            throw TranscriptionEngineError.audioFileUnreadable
        }
        try audioFile.read(into: buffer)

        guard let channelData = buffer.floatChannelData else {
            throw TranscriptionEngineError.audioFileUnreadable
        }
        let samples = Array(UnsafeBufferPointer(
            start: channelData[0],
            count: Int(buffer.frameLength)
        ))

        let text = try model.transcribeAudio(samples, sampleRate: Int(sampleRate))

        // ParakeetASR returns full text without segment-level timestamps.
        // Split into sentences and distribute timestamps proportionally.
        let duration = Double(buffer.frameLength) / sampleRate
        return Self.distributeTimestamps(text: text, totalDuration: duration)
    }

    // MARK: - Helpers

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
