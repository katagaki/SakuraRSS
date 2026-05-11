import AVFoundation
import FluidAudio
import Foundation

public extension FluidTranscriberEngine {

    func makeStreamingSession() async throws -> StreamingTranscriptionSession {
        guard isModelDownloaded else {
            throw TranscriptionEngineError.modelNotDownloaded
        }
        let config = SlidingWindowAsrConfig(
            chunkSeconds: 15.0,
            hypothesisChunkSeconds: 1.0,
            leftContextSeconds: 2.0,
            rightContextSeconds: 2.0,
            minContextForConfirmation: 10.0,
            confirmationThreshold: 0.85
        )
        let manager = SlidingWindowAsrManager(config: config)
        let models = try await AsrModels.downloadAndLoad(version: Self.modelVersion)
        try await manager.loadModels(models)
        try await manager.startStreaming(source: .system)
        return StreamingTranscriptionSession(manager: manager)
    }
}

public final class StreamingTranscriptionSession: @unchecked Sendable {

    private let manager: SlidingWindowAsrManager
    private let collector = TimingCollector()
    private var updatesTask: Task<Void, Never>?
    private var finished = false

    init(manager: SlidingWindowAsrManager) {
        self.manager = manager
    }

    public func start() {
        let updates = manager.transcriptionUpdates
        let collector = self.collector
        updatesTask = Task {
            for await update in updates {
                if Task.isCancelled { return }
                collector.append(update: update)
            }
        }
    }

    public func streamAudio(_ buffer: AVAudioPCMBuffer) {
        if finished { return }
        manager.streamAudio(buffer)
    }

    public func finish() async throws -> [TranscriptSegment] {
        if finished {
            return FluidTranscriberEngine.buildSegments(from: collector.snapshot())
        }
        finished = true
        _ = try await manager.finish()
        await updatesTask?.value
        updatesTask = nil
        return FluidTranscriberEngine.buildSegments(from: collector.snapshot())
    }

    public func cancel() async {
        finished = true
        updatesTask?.cancel()
        updatesTask = nil
        await manager.cancel()
    }
}

private final class TimingCollector: @unchecked Sendable {

    private let lock = NSLock()
    private var timings: [TokenTiming] = []

    func append(update: SlidingWindowTranscriptionUpdate) {
        guard update.isConfirmed, !update.tokenTimings.isEmpty else { return }
        lock.lock()
        timings.append(contentsOf: update.tokenTimings)
        lock.unlock()
    }

    func snapshot() -> [TokenTiming] {
        lock.lock()
        defer { lock.unlock() }
        return timings
    }
}
