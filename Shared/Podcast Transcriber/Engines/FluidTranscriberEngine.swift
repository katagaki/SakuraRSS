import AVFoundation
import Foundation
import ParakeetASR

/// Transcription engine using ParakeetASR (NVIDIA Parakeet TDT models via CoreML/ANE).
///
/// Models are downloaded on demand and stored in a known directory.
/// Runs in-process on the Neural Engine. 25 European languages supported.
struct FluidTranscriberEngine: TranscriptionEngine {

    static let requiresModelDownload = true

    /// Fixed directory where we tell the library to cache its models.
    private static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ParakeetModels", isDirectory: true)
    }

    var isModelDownloaded: Bool {
        let dir = Self.cacheDirectory
        guard FileManager.default.fileExists(atPath: dir.path) else { return false }
        // The library downloads multiple files. Check that the directory is non-trivially populated.
        guard let enumerator = FileManager.default.enumerator(atPath: dir.path) else { return false }
        var count = 0
        while enumerator.nextObject() != nil {
            count += 1
            if count >= 3 { return true }
        }
        return false
    }

    var isAvailable: Bool {
        get async { isModelDownloaded }
    }

    func downloadModel() async throws {
        #if DEBUG
        debugPrint("[ParakeetEngine] Downloading Parakeet TDT v3 model to \(Self.cacheDirectory.path)")
        #endif
        try FileManager.default.createDirectory(at: Self.cacheDirectory, withIntermediateDirectories: true)
        _ = try await ParakeetASRModel.fromPretrained(cacheDir: Self.cacheDirectory)
        #if DEBUG
        debugPrint("[ParakeetEngine] Model download complete")
        #endif
    }

    func deleteModel() throws {
        let dir = Self.cacheDirectory
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
        debugPrint("[ParakeetEngine] Loading Parakeet TDT v3 model from \(Self.cacheDirectory.path)")
        #endif

        let model = try await ParakeetASRModel.fromPretrained(
            cacheDir: Self.cacheDirectory,
            offlineMode: true
        )

        #if DEBUG
        debugPrint("[ParakeetEngine] Transcribing \(audioFileURL.lastPathComponent)")
        #endif

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

        let duration = Double(buffer.frameLength) / sampleRate
        return Self.distributeTimestamps(text: text, totalDuration: duration)
    }

    // MARK: - Helpers

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
