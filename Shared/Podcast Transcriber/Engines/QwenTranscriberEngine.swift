import AVFoundation
import Foundation
import Qwen3ASR

/// Transcription engine using Qwen3-ASR (Alibaba's Qwen3 model via CoreML/ANE).
///
/// Model is downloaded on demand and cached in Application Support.
/// Supports 52 languages. Runs in-process on the Neural Engine.
struct QwenTranscriberEngine: TranscriptionEngine {

    static let requiresModelDownload = true

    private static var modelDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Qwen3ASR", isDirectory: true)
    }

    var isModelDownloaded: Bool {
        let dir = Self.modelDirectory
        guard FileManager.default.fileExists(atPath: dir.path) else { return false }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return !contents.isEmpty
    }

    var isAvailable: Bool {
        get async { isModelDownloaded }
    }

    func downloadModel() async throws {
        #if DEBUG
        debugPrint("[QwenEngine] Downloading Qwen3-ASR model")
        #endif
        try FileManager.default.createDirectory(at: Self.modelDirectory, withIntermediateDirectories: true)
        _ = try await Qwen3ASRModel.fromPretrained(cacheDir: Self.modelDirectory)
        #if DEBUG
        debugPrint("[QwenEngine] Model download complete")
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
        debugPrint("[QwenEngine] Loading Qwen3-ASR model")
        #endif

        let model = try await Qwen3ASRModel.fromPretrained(
            cacheDir: Self.modelDirectory,
            offlineMode: true
        )

        #if DEBUG
        debugPrint("[QwenEngine] Transcribing \(audioFileURL.lastPathComponent)")
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

        // Convert to Float array.
        guard let channelData = buffer.floatChannelData else {
            throw TranscriptionEngineError.audioFileUnreadable
        }
        let samples = Array(UnsafeBufferPointer(
            start: channelData[0],
            count: Int(buffer.frameLength)
        ))

        let text = try model.transcribe(audio: samples, sampleRate: Int(sampleRate))

        // Qwen3-ASR returns full text without segment-level timestamps.
        // Split into sentences and distribute timestamps proportionally.
        let duration = Double(buffer.frameLength) / sampleRate
        return FluidTranscriberEngine.distributeTimestamps(
            text: text,
            totalDuration: duration
        )
    }
}
