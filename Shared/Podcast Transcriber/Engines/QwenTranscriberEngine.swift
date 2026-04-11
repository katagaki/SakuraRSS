import AVFoundation
import Foundation
import Qwen3ASR

/// Transcription engine using Qwen3-ASR (Alibaba's Qwen3 model via CoreML/ANE).
///
/// Model is downloaded on demand and stored in a known directory.
/// Supports 52 languages. Runs in-process on the Neural Engine.
struct QwenTranscriberEngine: TranscriptionEngine {

    static let requiresModelDownload = true

    /// Fixed directory where we tell the library to cache its models.
    private static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Qwen3Models", isDirectory: true)
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
        debugPrint("[QwenEngine] Downloading Qwen3-ASR model to \(Self.cacheDirectory.path)")
        #endif
        try FileManager.default.createDirectory(at: Self.cacheDirectory, withIntermediateDirectories: true)
        _ = try await Qwen3ASRModel.fromPretrained(cacheDir: Self.cacheDirectory)
        #if DEBUG
        debugPrint("[QwenEngine] Model download complete")
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
        debugPrint("[QwenEngine] Loading Qwen3-ASR model from \(Self.cacheDirectory.path)")
        #endif

        let model = try await Qwen3ASRModel.fromPretrained(
            cacheDir: Self.cacheDirectory,
            offlineMode: true
        )

        #if DEBUG
        debugPrint("[QwenEngine] Transcribing \(audioFileURL.lastPathComponent)")
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

        let text = try model.transcribe(audio: samples, sampleRate: Int(sampleRate))

        let duration = Double(buffer.frameLength) / sampleRate
        return FluidTranscriberEngine.distributeTimestamps(
            text: text,
            totalDuration: duration
        )
    }
}
