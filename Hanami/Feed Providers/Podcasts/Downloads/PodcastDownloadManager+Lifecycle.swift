import Foundation

public extension PodcastDownloadManager {

    func cancelDownload(articleID: Int64) {
        log("PodcastDownload", "Cancelling download for article \(articleID)")
        downloadTasks[articleID]?.cancel()
        downloadTasks[articleID] = nil
        transcriptionTasks[articleID]?.cancel()
        transcriptionTasks[articleID] = nil
        if let continuation = downloadContinuations.removeValue(forKey: articleID) {
            continuation.resume(throwing: CancellationError())
        }
        activeDownloads[articleID] = nil
        if let dir = episodeDirectory(for: articleID),
           fileManager.fileExists(atPath: dir.path) {
            log("PodcastDownload", "Removing partial download directory for article \(articleID)")
            try? fileManager.removeItem(at: dir)
        }
    }

    func deleteDownload(articleID: Int64) throws {
        log("PodcastDownload", "Deleting download for article \(articleID)")
        if let dir = episodeDirectory(for: articleID),
           fileManager.fileExists(atPath: dir.path) {
            try fileManager.removeItem(at: dir)
        }
        try DatabaseManager.shared.setDownloadPath(nil, for: articleID)
        try? DatabaseManager.shared.clearCachedTranscript(for: articleID)
        downloadedIDs.remove(articleID)
        activeDownloads[articleID] = nil
        log("PodcastDownload", "Download deleted for article \(articleID)")
    }

    func deleteAllDownloads() throws {
        log("PodcastDownload", "Deleting all downloads")
        guard let dir = downloadsDirectory else {
            log("PodcastDownload", "Downloads directory unavailable, skipping deleteAllDownloads")
            return
        }
        if fileManager.fileExists(atPath: dir.path) {
            try fileManager.removeItem(at: dir)
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let ids = (try? DatabaseManager.shared.downloadedArticleIDs()) ?? []
        log("PodcastDownload", "Clearing download paths for \(ids.count) article(s)")
        for identifier in ids {
            try? DatabaseManager.shared.setDownloadPath(nil, for: identifier)
            try? DatabaseManager.shared.clearCachedTranscript(for: identifier)
        }
        downloadedIDs.removeAll()
        activeDownloads.removeAll()
        log("PodcastDownload", "All downloads deleted")
    }
}
