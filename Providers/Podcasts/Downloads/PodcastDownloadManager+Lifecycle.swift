import Foundation

extension PodcastDownloadManager {

    func cancelDownload(articleID: Int64) {
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
}
