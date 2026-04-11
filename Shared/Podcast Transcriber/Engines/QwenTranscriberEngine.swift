import AVFoundation
import Foundation
import Qwen3ASR

/// Transcription engine using Qwen3-ASR (Alibaba's Qwen3 model via CoreML/ANE).
///
/// Model is downloaded on first use and cached locally.
/// Supports 52 languages. Runs in-process on the Neural Engine.
struct QwenTranscriberEngine: TranscriptionEngine {

    var isAvailable: Bool {
        get async { true }
    }

    func transcribe(audioFileURL: URL, title: String) async throws -> [TranscriptSegment] {
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw TranscriptionEngineError.audioFileUnreadable
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
