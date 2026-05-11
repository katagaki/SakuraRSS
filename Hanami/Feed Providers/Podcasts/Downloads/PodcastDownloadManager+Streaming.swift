import AVFoundation
import Foundation

public extension PodcastDownloadManager {

    /// Streams the audio body to disk while concurrently decoding the partial file
    /// and feeding samples to a transcription session. The donut shows download
    /// progress while bytes arrive, then switches to the transcribing spinner once
    /// the download completes but transcription work is still finishing.
    func streamingDownloadAndTranscribe(
        article: Article,
        audioURL: URL,
        destination: URL
    ) async throws {
        let articleID = article.id
        let title = article.title

        let session = try await PodcastTranscriber.makeStreamingSession()
        session.start()

        let request = URLRequest(url: audioURL)
        let (asyncBytes, response) = try await urlSession.bytes(for: request)
        let expectedBytes = max(response.expectedContentLength, 0)
        let bridge = StreamingProgressBridge()

        let progressReporter: @Sendable (Int64) -> Void = { [weak self] bytesWritten in
            let fraction: Double
            if expectedBytes > 0 {
                fraction = min(1.0, Double(bytesWritten) / Double(expectedBytes))
            } else {
                fraction = 0
            }
            self?.reportStreamingProgress(articleID: articleID, fraction: fraction)
        }

        let streamingSession = session
        let pipelineBridge = bridge
        let decoderTask = Task.detached(priority: .userInitiated) { [destination] in
            await StreamingAudioPipeline.run(
                fileURL: destination,
                bridge: pipelineBridge,
                session: streamingSession
            )
        }

        let writerBridge = bridge
        let writerDestination = destination
        let writerTask = Task.detached(priority: .userInitiated) {
            try await StreamingDownloadWriter.run(
                asyncBytes: asyncBytes,
                destination: writerDestination,
                bridge: writerBridge,
                progressReporter: progressReporter
            )
        }

        do {
            try await writerTask.value
        } catch {
            await bridge.notifyFinished()
            await session.cancel()
            decoderTask.cancel()
            throw error
        }

        await bridge.notifyFinished()
        activeDownloads[articleID] = DownloadProgress(state: .transcribing, progress: 1.0)

        await decoderTask.value

        do {
            let segments = try await session.finish()
            if segments.isEmpty {
                log("PodcastDownload", "Streaming produced no segments for \(articleID). Falling back.")
                await attemptTranscription(articleID: articleID, fileURL: destination, title: title)
            } else {
                try DatabaseManager.shared.cacheTranscript(segments, for: articleID)
            }
        } catch {
            log("PodcastDownload", "Streaming transcription finalize failed for \(articleID): \(error)")
            await attemptTranscription(articleID: articleID, fileURL: destination, title: title)
        }
    }

    nonisolated func reportStreamingProgress(articleID: Int64, fraction: Double) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            activeDownloads[articleID] = DownloadProgress(state: .downloading, progress: fraction)
        }
    }
}

enum StreamingDownloadWriter {

    static func run(
        asyncBytes: URLSession.AsyncBytes,
        destination: URL,
        bridge: StreamingProgressBridge,
        progressReporter: @Sendable (Int64) -> Void
    ) async throws {
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let writeHandle = try FileHandle(forWritingTo: destination)
        defer { try? writeHandle.close() }

        var buffer = Data()
        buffer.reserveCapacity(StreamingAudioPipeline.flushChunkBytes)
        var bytesWritten: Int64 = 0

        for try await byte in asyncBytes {
            buffer.append(byte)
            if buffer.count >= StreamingAudioPipeline.flushChunkBytes {
                try writeHandle.write(contentsOf: buffer)
                bytesWritten += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                await bridge.notifyBytesWritten(bytesWritten)
                progressReporter(bytesWritten)
            }
        }
        if !buffer.isEmpty {
            try writeHandle.write(contentsOf: buffer)
            bytesWritten += Int64(buffer.count)
        }
        try writeHandle.synchronize()
        await bridge.notifyBytesWritten(bytesWritten)
    }
}

/// Coordinates the byte-writer (network task) and the audio-reader (decoder task).
/// The decoder waits on `bytesAvailable` for new bytes; `finished` signals the
/// network stream is complete so the decoder can perform a final read.
actor StreamingProgressBridge {

    private var bytesWritten: Int64 = 0
    private var isFinished = false
    private var waiters: [CheckedContinuation<StreamingBridgeSignal, Never>] = []

    func notifyBytesWritten(_ count: Int64) {
        bytesWritten = max(bytesWritten, count)
        resumeWaiters(with: .bytesAvailable(bytesWritten))
    }

    func notifyFinished() {
        isFinished = true
        resumeWaiters(with: .finished(bytesWritten))
    }

    func waitForNextSignal(after lastSeen: Int64) async -> StreamingBridgeSignal {
        if isFinished { return .finished(bytesWritten) }
        if bytesWritten > lastSeen { return .bytesAvailable(bytesWritten) }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func resumeWaiters(with signal: StreamingBridgeSignal) {
        let pending = waiters
        waiters.removeAll()
        for continuation in pending {
            continuation.resume(returning: signal)
        }
    }
}

enum StreamingBridgeSignal: Sendable {
    case bytesAvailable(Int64)
    case finished(Int64)
}

/// Reads PCM samples from the growing audio file and feeds them to the
/// transcription session. Opens a fresh `AVAudioFile` each pass and seeks past
/// the frames it has already consumed so we only decode new audio.
enum StreamingAudioPipeline {

    static let flushChunkBytes = 64 * 1024
    static let minBytesBeforeFirstDecode: Int64 = 256 * 1024
    static let decodeFrameCapacity: AVAudioFrameCount = 16_000 * 5

    static func run(
        fileURL: URL,
        bridge: StreamingProgressBridge,
        session: StreamingTranscriptionSession
    ) async {
        var lastSeenBytes: Int64 = 0
        var lastReadFrame: AVAudioFramePosition = 0
        var finished = false
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )
        guard let targetFormat else { return }

        while !finished {
            if Task.isCancelled { return }
            let signal = await bridge.waitForNextSignal(after: lastSeenBytes)
            switch signal {
            case .bytesAvailable(let total):
                lastSeenBytes = total
                if total < minBytesBeforeFirstDecode { continue }
            case .finished(let total):
                lastSeenBytes = total
                finished = true
            }

            let advancedFrames = decodeAvailable(
                fileURL: fileURL,
                startingAt: lastReadFrame,
                targetFormat: targetFormat,
                session: session
            )
            if advancedFrames > 0 {
                lastReadFrame += AVAudioFramePosition(advancedFrames)
            }
        }
    }

    /// Decodes from `startingAt` to the current EOF of `fileURL`, returning the
    /// number of source-format frames advanced. Returns 0 if no new frames are
    /// readable (e.g., the next MP3 frame hasn't fully landed yet).
    private static func decodeAvailable(
        fileURL: URL,
        startingAt startingFrame: AVAudioFramePosition,
        targetFormat: AVAudioFormat,
        session: StreamingTranscriptionSession
    ) -> AVAudioFramePosition {
        guard let audioFile = try? AVAudioFile(forReading: fileURL) else { return 0 }
        let totalFrames = audioFile.length
        guard totalFrames > startingFrame else { return 0 }
        audioFile.framePosition = startingFrame

        let sourceFormat = audioFile.processingFormat
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            return 0
        }

        let chunkSourceFrames = AVAudioFrameCount(
            max(1, min(Int64(decodeFrameCapacity), totalFrames - startingFrame))
        )
        guard let sourceBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: chunkSourceFrames
        ) else {
            return 0
        }

        do {
            try audioFile.read(into: sourceBuffer)
        } catch {
            return 0
        }
        let framesRead = AVAudioFramePosition(sourceBuffer.frameLength)
        guard sourceBuffer.frameLength > 0 else { return 0 }

        let ratio = targetFormat.sampleRate / sourceFormat.sampleRate
        let targetFrameCapacity = AVAudioFrameCount(
            (Double(sourceBuffer.frameLength) * ratio).rounded(.up) + 1024
        )
        guard let targetBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: targetFrameCapacity
        ) else {
            return framesRead
        }

        var providedBuffer = false
        var conversionError: NSError?
        let status = converter.convert(to: targetBuffer, error: &conversionError) { _, inputStatus in
            if providedBuffer {
                inputStatus.pointee = .endOfStream
                return nil
            }
            providedBuffer = true
            inputStatus.pointee = .haveData
            return sourceBuffer
        }
        if status == .error || conversionError != nil {
            return framesRead
        }
        if targetBuffer.frameLength > 0 {
            session.streamAudio(targetBuffer)
        }
        return framesRead
    }
}
