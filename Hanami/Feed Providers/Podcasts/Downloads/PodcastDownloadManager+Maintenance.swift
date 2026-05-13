import Foundation

public extension PodcastDownloadManager {

    /// Removes download files whose article no longer exists in the database.
    nonisolated static func cleanupOrphanedDownloads() {
        log("PodcastDownload", "Starting orphaned download cleanup")
        let fileManager = FileManager.default
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        ) else {
            log("PodcastDownload", "Cleanup aborted: app group container unavailable")
            return
        }
        let root = container.appendingPathComponent("PodcastDownloads", isDirectory: true)
        guard fileManager.fileExists(atPath: root.path) else {
            log("PodcastDownload", "Cleanup skipped: PodcastDownloads directory does not exist")
            return
        }
        let contents = (try? fileManager.contentsOfDirectory(atPath: root.path)) ?? []
        let validIDs = Set((try? DatabaseManager.shared.downloadedArticleIDs()) ?? [])
        log("PodcastDownload", "Found \(contents.count) item(s) on disk, \(validIDs.count) valid ID(s) in database")
        for name in contents {
            guard let identifier = Int64(name) else {
                continue
            }
            if !validIDs.contains(identifier) {
                log("PodcastDownload", "Removing orphaned download directory for article \(identifier)")
                try? fileManager.removeItem(at: root.appendingPathComponent(name))
            }
        }
        log("PodcastDownload", "Orphaned download cleanup complete")
    }

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
