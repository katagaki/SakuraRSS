import AudioKit
import AVFoundation
import Foundation
import Speech

enum PodcastTranscriberError: Error {
    case notAvailable
    case audioFileUnreadable
    case authorizationDenied
    case transcriptionFailed(String)
}

enum PodcastTranscriber {

    // MARK: - Availability

    /// Checks whether on-device transcription is usable, including authorization.
    static var isAvailable: Bool {
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

    // MARK: - Transcribe

    /// Transcribes a local audio file using Apple's iOS 26 SpeechAnalyzer/SpeechTranscriber.
    ///
    /// Exact API surface of iOS 26's Speech framework may require light adjustment:
    /// results are consumed via the transcriber's `results` AsyncSequence and carry
    /// `.audioTimeRange` attributes on the text's character ranges.
    static func transcribe(audioFileURL: URL) async throws -> [TranscriptSegment] {
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw PodcastTranscriberError.audioFileUnreadable
        }

        // SpeechAnalyzer requires linear PCM audio. If the source file is
        // compressed (MP3, AAC, Opus, etc.) we convert it to a WAV first.
        let fileToTranscribe: URL = audioFileURL.deletingPathExtension().appendingPathExtension("wav")
        var options = FormatConverter.Options()
        options.format = .wav
        options.sampleRate = 48000
        options.bitDepth = 24
        options.channels = 1
        let converter = FormatConverter(
            inputURL: audioFileURL,
            outputURL: fileToTranscribe,
            options: options
        )

        try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            converter.start { error in
                if let error = error {
                    print(error.localizedDescription)
                    continuation.resume(throwing: error)
                } else {
                    #if DEBUG
                    debugPrint("[PodcastTranscriber] Completed file conversion for \(fileToTranscribe)")
                    #endif
                    continuation.resume(returning: ())
                }
            }
        }

        defer {
            try? FileManager.default.removeItem(at: fileToTranscribe)
        }

        #if DEBUG
        debugPrint("[PodcastTranscriber] Using file at \(fileToTranscribe.path()) for speech recognition")
        #endif

        let transcriber = SpeechTranscriber(
            locale: .current,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: fileToTranscribe)

        #if DEBUG
        debugPrint("[PodcastTranscriber] Audio file format: \(audioFile.fileFormat), processing with \(audioFile.processingFormat)")
        #endif

        let collectionTask = Task { () throws -> [TranscriptSegment] in
            var segments: [TranscriptSegment] = []
            var nextID = 0
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }

                segments.append(TranscriptSegment(
                    id: nextID,
                    start: 0,
                    end: 0,
                    text: text
                ))
                nextID += 1
            }
            return segments
        }

        // Stream the file into the analyzer.
        try await analyzer.analyzeSequence(from: audioFile)
        // Wait for any remaining results to drain.
        return try await collectionTask.value
    }

    // MARK: - Format Conversion

    /// Converts a compressed audio file to 16 kHz mono PCM WAV for Speech framework compatibility.
    private static func convertToPCM(sourceFile: AVAudioFile) async throws -> URL {
        try await Task.detached(priority: .utility) {
            guard let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: 16000,
                channels: 1,
                interleaved: true
            ) else {
                throw PodcastTranscriberError.audioFileUnreadable
            }

            guard let converter = AVAudioConverter(from: sourceFile.processingFormat, to: outputFormat) else {
                throw PodcastTranscriberError.transcriptionFailed(
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
                throw PodcastTranscriberError.audioFileUnreadable
            }

            while true {
                let status = try converter.convert(to: convertBuffer, error: nil) { inNumberOfPackets, outStatus in
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

                if convertBuffer.frameLength == 0 || status == .endOfStream {
                    break
                }

                try outputFile.write(from: convertBuffer)
            }

            return tempURL
        }.value
    }
}
