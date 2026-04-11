import AVFoundation
import Foundation
import ParakeetASR

/// Transcription engine using ParakeetASR (NVIDIA Parakeet TDT models via CoreML/ANE).
///
/// Models are downloaded on demand via HuggingFace and cached by the library.
/// Runs in-process on the Neural Engine. 25 European languages supported.
struct FluidTranscriberEngine: TranscriptionEngine {

    static let requiresModelDownload = true

    /// Marker file we write after a successful download so we know the model is ready.
    private static var markerFile: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(".parakeet_model_ready")
    }

    var isModelDownloaded: Bool {
        FileManager.default.fileExists(atPath: Self.markerFile.path)
    }

    var isAvailable: Bool {
        get async { isModelDownloaded }
    }

    func downloadModel() async throws {
        #if DEBUG
        debugPrint("[ParakeetEngine] Downloading Parakeet TDT v3 model")
        #endif
        // Let the library manage its own cache location.
        _ = try await ParakeetASRModel.fromPretrained()
        // Write a marker so we know the download succeeded.
        FileManager.default.createFile(atPath: Self.markerFile.path, contents: Data())
        #if DEBUG
        debugPrint("[ParakeetEngine] Model download complete")
        #endif
    }

    func deleteModel() throws {
        // Remove the marker file.
        try? FileManager.default.removeItem(at: Self.markerFile)
        // The library caches in ~/Library/Caches — clear its known locations.
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        for dirName in ["qwen3-speech", "parakeet-asr", "huggingface"] {
            let dir = caches.appendingPathComponent(dirName, isDirectory: true)
            if FileManager.default.fileExists(atPath: dir.path) {
                try? FileManager.default.removeItem(at: dir)
            }
        }
        // Also check Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let parakeetDir = appSupport.appendingPathComponent("ParakeetASR", isDirectory: true)
        if FileManager.default.fileExists(atPath: parakeetDir.path) {
            try FileManager.default.removeItem(at: parakeetDir)
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

        let model = try await ParakeetASRModel.fromPretrained()

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
