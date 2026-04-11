import AVFoundation
import CoreMedia
import Foundation
import NaturalLanguage
import Speech

/// Transcription engine using Apple's iOS 26 SpeechAnalyzer/SpeechTranscriber.
///
/// Runs fully on-device with zero memory overhead (model runs out-of-process
/// in a system daemon). Requires speech recognition authorization.
struct SpeechTranscriberEngine: TranscriptionEngine {

    static let requiresModelDownload = false

    var isModelDownloaded: Bool { true }

    var isAvailable: Bool {
        get async {
            let current = SFSpeechRecognizer.authorizationStatus()
            if current == .authorized { return true }
            if current == .denied || current == .restricted { return false }
            let status = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
                SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
            }
            return status == .authorized
        }
    }

    func transcribe(audioFileURL: URL, title: String) async throws -> [TranscriptSegment] {
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw TranscriptionEngineError.audioFileUnreadable
        }

        // Convert compressed audio (MP3, AAC, Opus, etc.) to 16 kHz mono PCM WAV.
        let pcmURL = try await Self.convertToPCM(inputURL: audioFileURL)
        defer { try? FileManager.default.removeItem(at: pcmURL) }

        #if DEBUG
        debugPrint("[SpeechEngine] Converted to PCM at \(pcmURL.path())")
        #endif

        // Detect language from episode title.
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(title)
        let detected = recognizer.dominantLanguage
        let locale: Locale
        if let detected {
            locale = Locale(identifier: detected.rawValue)
        } else {
            locale = .current
        }
        #if DEBUG
        debugPrint("[SpeechEngine] Detected language '\(detected?.rawValue ?? "unknown")' from title, using locale \(locale.identifier)")
        #endif

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: pcmURL)

        // Use a compatible format from the transcriber rather than relying on
        // AVAudioFile.processingFormat, which returns Float32 even for Int16 files.
        let compatibleFormats = await transcriber.availableCompatibleAudioFormats
        #if DEBUG
        debugPrint("[SpeechEngine] Audio file format: \(audioFile.fileFormat), processing: \(audioFile.processingFormat)")
        debugPrint("[SpeechEngine] Compatible formats: \(compatibleFormats)")
        #endif

        let targetFormat = compatibleFormats.first(where: {
            $0.commonFormat == .pcmFormatInt16 && $0.sampleRate == 16000
        }) ?? compatibleFormats.first(where: {
            $0.sampleRate == 16000
        }) ?? compatibleFormats.first

        guard let format = targetFormat else {
            throw TranscriptionEngineError.noCompatibleAudioFormat
        }

        try await analyzer.prepareToAnalyze(in: format)

        let collectionTask = Task { () throws -> [TranscriptSegment] in
            var segments: [TranscriptSegment] = []
            var nextID = 0
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }

                let timeRange = result.range
                segments.append(TranscriptSegment(
                    id: nextID,
                    start: CMTimeGetSeconds(timeRange.start),
                    end: CMTimeGetSeconds(timeRange.start + timeRange.duration),
                    text: text
                ))
                nextID += 1
            }
            return segments
        }

        _ = try await analyzer.analyzeSequence(from: audioFile)
        return try await collectionTask.value
    }

    // MARK: - Format Conversion

    /// Converts a compressed audio file to 16 kHz mono Int16 PCM WAV.
    ///
    /// Both `AVAudioFile` instances are created and consumed within the same
    /// synchronous closure to avoid Sendable issues across task boundaries.
    private static func convertToPCM(inputURL: URL) async throws -> URL {
        let url = inputURL
        return try await Task.detached(priority: .utility) {
            let sourceFile = try AVAudioFile(forReading: url)

            guard let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: 16000,
                channels: 1,
                interleaved: true
            ) else {
                throw TranscriptionEngineError.audioFileUnreadable
            }

            guard let converter = AVAudioConverter(from: sourceFile.processingFormat, to: outputFormat) else {
                throw TranscriptionEngineError.transcriptionFailed(
                    "Cannot convert audio from \(sourceFile.processingFormat) to PCM"
                )
            }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".wav")
            let outputFile = try AVAudioFile(forWriting: tempURL, settings: outputFormat.settings)

            let bufferCapacity: AVAudioFrameCount = 4096
            guard let convertBuffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity: bufferCapacity
            ) else {
                throw TranscriptionEngineError.audioFileUnreadable
            }

            while true {
                var converterError: NSError?
                let status = try converter.convert(to: convertBuffer, error: &converterError) { inNumberOfPackets, outStatus in
                    guard let readBuffer = AVAudioPCMBuffer(
                        pcmFormat: sourceFile.processingFormat,
                        frameCapacity: inNumberOfPackets
                    ) else {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    do {
                        try sourceFile.read(into: readBuffer)
                        if readBuffer.frameLength == 0 {
                            outStatus.pointee = .endOfStream
                            return nil
                        }
                        outStatus.pointee = .haveData
                        return readBuffer
                    } catch {
                        outStatus.pointee = .endOfStream
                        return nil
                    }
                }

                if let converterError {
                    throw TranscriptionEngineError.transcriptionFailed(converterError.localizedDescription)
                }

                if convertBuffer.frameLength == 0 || status == .endOfStream {
                    break
                }

                try outputFile.write(from: convertBuffer)
            }

            return tempURL
        }.value
    }
}
