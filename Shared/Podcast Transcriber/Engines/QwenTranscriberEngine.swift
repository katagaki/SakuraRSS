import AVFoundation
import Foundation
import Qwen3ASR

/// Transcription engine using Qwen3-ASR (Alibaba's Qwen3 model via CoreML/ANE).
///
/// Model is downloaded on demand via HuggingFace and cached by the library.
/// Supports 52 languages. Runs in-process on the Neural Engine.
struct QwenTranscriberEngine: TranscriptionEngine {

    static let requiresModelDownload = true

    /// Marker file we write after a successful download so we know the model is ready.
    private static var markerFile: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(".qwen3asr_model_ready")
    }

    var isModelDownloaded: Bool {
        FileManager.default.fileExists(atPath: Self.markerFile.path)
    }

    var isAvailable: Bool {
        get async { isModelDownloaded }
    }

    func downloadModel() async throws {
        #if DEBUG
        debugPrint("[QwenEngine] Downloading Qwen3-ASR model")
        #endif
        // Let the library manage its own cache location.
        _ = try await Qwen3ASRModel.fromPretrained()
        // Write a marker so we know the download succeeded.
        FileManager.default.createFile(atPath: Self.markerFile.path, contents: Data())
        #if DEBUG
        debugPrint("[QwenEngine] Model download complete")
        #endif
    }

    func deleteModel() throws {
        // Remove the marker file.
        try? FileManager.default.removeItem(at: Self.markerFile)
        // The library caches in ~/Library/Caches — clear its known locations.
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        for dirName in ["qwen3-speech", "qwen3-asr", "huggingface"] {
            let dir = caches.appendingPathComponent(dirName, isDirectory: true)
            if FileManager.default.fileExists(atPath: dir.path) {
                try? FileManager.default.removeItem(at: dir)
            }
        }
        // Also check Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let qwenDir = appSupport.appendingPathComponent("Qwen3ASR", isDirectory: true)
        if FileManager.default.fileExists(atPath: qwenDir.path) {
            try FileManager.default.removeItem(at: qwenDir)
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

        let model = try await Qwen3ASRModel.fromPretrained()

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
