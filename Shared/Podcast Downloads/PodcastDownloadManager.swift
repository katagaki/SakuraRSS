import Foundation
import Observation

enum DownloadState: Sendable {
    case idle
    case downloading
    case transcribing
    case completed
    case failed
}

struct DownloadProgress: Sendable {
    var state: DownloadState
    /// 0.0 – 0.8 reflects download progress; 0.8 – 1.0 reflects transcription progress.
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
final class PodcastDownloadManager {

    static let shared = PodcastDownloadManager()

    var activeDownloads: [Int64: DownloadProgress] = [:]

    private let urlSession: URLSession
    private var downloadTasks: [Int64: Task<Void, Never>] = [:]
    private let fileManager = FileManager.default

    private init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600
        self.urlSession = URLSession(configuration: config)
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
        // `try?` on a throwing method returning `String?` already flattens to `String?`.
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

        let task = Task { [weak self] in
            do {
                try await self?.performDownload(article: article, audioURL: audioURL)
            } catch {
                await self?.markFailed(articleID: article.id, error: error.localizedDescription)
            }
        }
        downloadTasks[article.id] = task
    }

    private func performDownload(article: Article, audioURL: URL) async throws {
        guard let episodeDir = episodeDirectory(for: article.id) else {
            throw PodcastDownloadError.storageUnavailable
        }
        let name = filename(from: audioURL)
        let destination = episodeDir.appendingPathComponent(name)
        let articleID = article.id
        let session = urlSession

        // Do the actual network download + file move off the main actor.
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            if !fm.fileExists(atPath: episodeDir.path) {
                try fm.createDirectory(at: episodeDir, withIntermediateDirectories: true)
            }
            if fm.fileExists(atPath: destination.path) {
                try? fm.removeItem(at: destination)
            }
            let (tempURL, _) = try await session.download(from: audioURL)
            try fm.moveItem(at: tempURL, to: destination)
        }.value

        // Store relative path so it survives container path changes.
        let relativePath = "\(articleID)/\(name)"
        try DatabaseManager.shared.setDownloadPath(relativePath, for: articleID)

        updateProgress(articleID: articleID, state: .transcribing, progress: 0.8)

        // Trigger transcription if available; completion handled there.
        await attemptTranscription(articleID: articleID, fileURL: destination)
    }

    private func attemptTranscription(articleID: Int64, fileURL: URL) async {
        guard await PodcastTranscriber.isAvailable else {
            markCompleted(articleID: articleID)
            return
        }
        do {
            let segments = try await PodcastTranscriber.transcribe(audioFileURL: fileURL)
            try DatabaseManager.shared.cacheTranscript(segments, for: articleID)
        } catch {
            // Transcription failure is non-fatal; download still succeeded.
            print("Transcription failed for article \(articleID): \(error)")
        }
        markCompleted(articleID: articleID)
    }

    private func updateProgress(articleID: Int64, state: DownloadState, progress: Double) {
        activeDownloads[articleID] = DownloadProgress(state: state, progress: progress)
    }

    private func markCompleted(articleID: Int64) {
        activeDownloads[articleID] = DownloadProgress(state: .completed, progress: 1.0)
        downloadTasks[articleID] = nil
        // Fade out completed entry so views reflect the new "downloaded" state.
        Task { [weak self] in
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
    }

    // MARK: - Cancel / Delete

    func cancelDownload(articleID: Int64) {
        downloadTasks[articleID]?.cancel()
        downloadTasks[articleID] = nil
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
        for id in ids {
            try? DatabaseManager.shared.setDownloadPath(nil, for: id)
            try? DatabaseManager.shared.clearCachedTranscript(for: id)
        }
        activeDownloads.removeAll()
    }

    // MARK: - Cleanup

    /// Removes download files whose article no longer exists in the database.
    /// Static + nonisolated so callers on background queues don't need to hop
    /// to the main actor just to clean up orphaned files.
    nonisolated static func cleanupOrphanedDownloads() {
        let fm = FileManager.default
        guard let container = fm.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        ) else { return }
        let root = container.appendingPathComponent("PodcastDownloads", isDirectory: true)
        guard fm.fileExists(atPath: root.path) else { return }
        let contents = (try? fm.contentsOfDirectory(atPath: root.path)) ?? []
        let validIDs = Set((try? DatabaseManager.shared.downloadedArticleIDs()) ?? [])
        for name in contents {
            guard let id = Int64(name) else {
                // Not a directory we created — leave it alone.
                continue
            }
            if !validIDs.contains(id) {
                try? fm.removeItem(at: root.appendingPathComponent(name))
            }
        }
    }

    // MARK: - Size

    nonisolated static func totalDownloadedSize() -> Int64 {
        let fm = FileManager.default
        guard let container = fm.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        ) else { return 0 }
        let dir = container.appendingPathComponent("PodcastDownloads", isDirectory: true)
        guard let enumerator = fm.enumerator(
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
