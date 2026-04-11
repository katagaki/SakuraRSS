import Foundation
import Observation

enum DownloadState: Sendable {
    case idle
    case downloading
    case completed
    case failed
}

struct DownloadProgress: Sendable {
    var state: DownloadState
    var progress: Double
    var error: String?
}

enum PodcastDownloadError: Error {
    case missingAudioURL
    case invalidAudioURL
    case storageUnavailable
    case downloadFailed(String)
}

@Observable
@MainActor
final class PodcastDownloadManager: NSObject, URLSessionDownloadDelegate {

    static let shared = PodcastDownloadManager()

    var activeDownloads: [Int64: DownloadProgress] = [:]

    private var urlSession: URLSession!
    private var downloadTasks: [Int64: URLSessionDownloadTask] = [:]
    /// Maps URLSessionTask identifiers back to article IDs for delegate callbacks.
    private var taskArticleIDs: [Int: Int64] = [:]
    /// Continuations waiting for download completion, keyed by article ID.
    private var downloadContinuations: [Int64: CheckedContinuation<URL, any Error>] = [:]
    private let fileManager = FileManager.default

    /// Tracks pending transcription work so cancellation can reach it.
    private var transcriptionTasks: [Int64: Task<Void, Never>] = [:]

    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600
        self.urlSession = URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: nil
        )
    }

    // MARK: - Storage

    private var downloadsDirectory: URL? {
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        ) else { return nil }
        let dir = container.appendingPathComponent("PodcastDownloads", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func episodeDirectory(for articleID: Int64) -> URL? {
        downloadsDirectory?.appendingPathComponent("\(articleID)", isDirectory: true)
    }

    private func filename(from audioURL: URL) -> String {
        let last = audioURL.lastPathComponent
        if last.isEmpty || last == "/" {
            return "episode.mp3"
        }
        return last
    }

    func localFileURL(for articleID: Int64) -> URL? {
        guard let path = try? DatabaseManager.shared.downloadPath(for: articleID),
              let downloadsDirectory else {
            return nil
        }
        let url = downloadsDirectory.appendingPathComponent(path)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func isDownloaded(articleID: Int64) -> Bool {
        localFileURL(for: articleID) != nil
    }

    // MARK: - Download

    func downloadEpisode(article: Article) {
        guard activeDownloads[article.id] == nil else { return }
        guard let audioURLString = article.audioURL,
              let audioURL = URL(string: audioURLString) else {
            activeDownloads[article.id] = DownloadProgress(
                state: .failed,
                progress: 0,
                error: "Missing audio URL"
            )
            return
        }

        activeDownloads[article.id] = DownloadProgress(state: .downloading, progress: 0)

        let task = Task { @MainActor [weak self] in
            do {
                try await self?.performDownload(article: article, audioURL: audioURL)
            } catch is CancellationError {
                // Cancelled by the user — cancelDownload() already cleaned up state.
            } catch let urlError as URLError where urlError.code == .cancelled {
                // URLSession task was cancelled — same as above.
            } catch {
                self?.markFailed(articleID: article.id, error: error.localizedDescription)
            }
        }
        transcriptionTasks[article.id] = task
    }

    private func performDownload(article: Article, audioURL: URL) async throws {
        guard let episodeDir = episodeDirectory(for: article.id) else {
            throw PodcastDownloadError.storageUnavailable
        }
        let name = filename(from: audioURL)
        let destination = episodeDir.appendingPathComponent(name)
        let articleID = article.id

        // Prepare the directory on a background thread.
        let dir = episodeDir
        let dest = destination
        try await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: dir.path) {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            if fileManager.fileExists(atPath: dest.path) {
                try? fileManager.removeItem(at: dest)
            }
        }.value

        // Start a delegate-based download so we get per-byte progress.
        let tempURL: URL = try await withCheckedThrowingContinuation { continuation in
            let sessionTask = urlSession.downloadTask(with: audioURL)
            downloadTasks[articleID] = sessionTask
            taskArticleIDs[sessionTask.taskIdentifier] = articleID
            downloadContinuations[articleID] = continuation
            sessionTask.resume()
        }

        // Clean up tracking state.
        downloadTasks[articleID] = nil

        // Move the downloaded file to its final location.
        try await Task.detached(priority: .utility) {
            try FileManager.default.moveItem(at: tempURL, to: dest)
        }.value

        // Store relative path so it survives container path changes.
        let relativePath = "\(articleID)/\(name)"
        try DatabaseManager.shared.setDownloadPath(relativePath, for: articleID)

        markCompleted(articleID: articleID)

        // Transcribe in the background without blocking the UI.
        let title = article.title
        let transcriptionTask = Task.detached(priority: .utility) {
            await self.attemptTranscription(articleID: articleID, fileURL: destination, title: title)
        }
        await MainActor.run {
            transcriptionTasks[articleID] = Task { await transcriptionTask.value }
        }
    }

    // MARK: - URLSessionDownloadDelegate

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let taskID = downloadTask.taskIdentifier
        Task { @MainActor [weak self] in
            guard let self,
                  let articleID = taskArticleIDs[taskID] else { return }
            let fraction: Double
            if totalBytesExpectedToWrite > 0 {
                fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            } else {
                fraction = 0
            }
            activeDownloads[articleID] = DownloadProgress(
                state: .downloading,
                progress: fraction
            )
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Copy to a stable temp location before the system deletes it.
        let tempCopy = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.moveItem(at: location, to: tempCopy)

        let taskID = downloadTask.taskIdentifier
        Task { @MainActor [weak self] in
            guard let self,
                  let articleID = taskArticleIDs[taskID],
                  let continuation = downloadContinuations.removeValue(forKey: articleID) else {
                return
            }
            taskArticleIDs[taskID] = nil
            continuation.resume(returning: tempCopy)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard let error else { return }
        let taskID = task.taskIdentifier
        Task { @MainActor [weak self] in
            guard let self,
                  let articleID = taskArticleIDs.removeValue(forKey: taskID),
                  let continuation = downloadContinuations.removeValue(forKey: articleID) else {
                return
            }
            continuation.resume(throwing: error)
        }
    }

    // MARK: - Transcription

    private func attemptTranscription(articleID: Int64, fileURL: URL, title: String) async {
        let transcribeEnabled = UserDefaults.standard.object(forKey: "Podcast.TranscribeDuringDownload") as? Bool ?? false
        guard transcribeEnabled, await PodcastTranscriber.isAvailable else {
            return
        }
        do {
            #if DEBUG
            debugPrint("Transcribing article \(articleID) located at \(fileURL.path())")
            #endif
            let segments = try await PodcastTranscriber.transcribe(audioFileURL: fileURL, title: title)
            try DatabaseManager.shared.cacheTranscript(segments, for: articleID)
        } catch {
            // Transcription failure is non-fatal; download still succeeded.
            print("Transcription failed for article \(articleID): \(error)")
        }
    }

    private func markCompleted(articleID: Int64) {
        activeDownloads[articleID] = DownloadProgress(state: .completed, progress: 1.0)
        downloadTasks[articleID] = nil
        transcriptionTasks[articleID] = nil
        // Fade out completed entry so views reflect the new "downloaded" state.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.activeDownloads[articleID] = nil
        }
    }

    private func markFailed(articleID: Int64, error: String) {
        activeDownloads[articleID] = DownloadProgress(
            state: .failed,
            progress: 0,
            error: error
        )
        downloadTasks[articleID] = nil
        transcriptionTasks[articleID] = nil
    }

    // MARK: - Cancel / Delete

    func cancelDownload(articleID: Int64) {
        downloadTasks[articleID]?.cancel()
        downloadTasks[articleID] = nil
        transcriptionTasks[articleID]?.cancel()
        transcriptionTasks[articleID] = nil
        // If a continuation is still waiting, resume it with a cancellation error
        // so the async chain unwinds cleanly.
        if let continuation = downloadContinuations.removeValue(forKey: articleID) {
            continuation.resume(throwing: CancellationError())
        }
        activeDownloads[articleID] = nil
        // Clean partial file
        if let dir = episodeDirectory(for: articleID),
           fileManager.fileExists(atPath: dir.path) {
            try? fileManager.removeItem(at: dir)
        }
    }

    func deleteDownload(articleID: Int64) throws {
        if let dir = episodeDirectory(for: articleID),
           fileManager.fileExists(atPath: dir.path) {
            try fileManager.removeItem(at: dir)
        }
        try DatabaseManager.shared.setDownloadPath(nil, for: articleID)
        try? DatabaseManager.shared.clearCachedTranscript(for: articleID)
        activeDownloads[articleID] = nil
    }

    func deleteAllDownloads() throws {
        guard let dir = downloadsDirectory else { return }
        if fileManager.fileExists(atPath: dir.path) {
            try fileManager.removeItem(at: dir)
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let ids = (try? DatabaseManager.shared.downloadedArticleIDs()) ?? []
        for identifier in ids {
            try? DatabaseManager.shared.setDownloadPath(nil, for: identifier)
            try? DatabaseManager.shared.clearCachedTranscript(for: identifier)
        }
        activeDownloads.removeAll()
    }

    // MARK: - Cleanup

    /// Removes download files whose article no longer exists in the database.
    /// Static + nonisolated so callers on background queues don't need to hop
    /// to the main actor just to clean up orphaned files.
    nonisolated static func cleanupOrphanedDownloads() {
        let fileManager = FileManager.default
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        ) else { return }
        let root = container.appendingPathComponent("PodcastDownloads", isDirectory: true)
        guard fileManager.fileExists(atPath: root.path) else { return }
        let contents = (try? fileManager.contentsOfDirectory(atPath: root.path)) ?? []
        let validIDs = Set((try? DatabaseManager.shared.downloadedArticleIDs()) ?? [])
        for name in contents {
            guard let identifier = Int64(name) else {
                continue
            }
            if !validIDs.contains(identifier) {
                try? fileManager.removeItem(at: root.appendingPathComponent(name))
            }
        }
    }

    // MARK: - Size

    nonisolated static func totalDownloadedSize() -> Int64 {
        let fileManager = FileManager.default
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        ) else { return 0 }
        let dir = container.appendingPathComponent("PodcastDownloads", isDirectory: true)
        guard let enumerator = fileManager.enumerator(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else {
            return 0
        }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            if let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
               values.isRegularFile == true,
               let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
