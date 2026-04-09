import AVFoundation
import Foundation
import Speech

struct TranscriptSegment: Codable, Identifiable, Sendable, Hashable {
    let id: Int
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}

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
            let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
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

        let transcriber = SpeechTranscriber(
            locale: Locale.current,
            preset: .offlineTranscription
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: audioFileURL)

        // Kick off a task that consumes transcription results as they arrive.
        let collectionTask = Task { () throws -> [TranscriptSegment] in
            var segments: [TranscriptSegment] = []
            var nextID = 0
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }

                var start: TimeInterval = 0
                var end: TimeInterval = 0
                if let range = result.range {
                    start = range.start.seconds
                    end = range.end.seconds
                }

                segments.append(TranscriptSegment(
                    id: nextID,
                    start: start.isFinite ? start : 0,
                    end: end.isFinite ? end : 0,
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
}
