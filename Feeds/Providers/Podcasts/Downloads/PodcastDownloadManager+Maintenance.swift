import Foundation

extension PodcastDownloadManager {

    /// Removes download files whose article no longer exists in the database.
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
