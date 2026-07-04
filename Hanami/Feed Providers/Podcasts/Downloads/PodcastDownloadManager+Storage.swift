import Foundation

public extension PodcastDownloadManager {

    var downloadsDirectory: URL? {
        Self.sharedDownloadsDirectory
    }

    nonisolated static var sharedDownloadsDirectory: URL? {
        let fileManager = FileManager.default
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        ) else { return nil }
        let dir = container.appendingPathComponent("PodcastDownloads", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    @concurrent nonisolated static func verifiedDownloadedIDs() async -> Set<Int64> {
        guard let directory = sharedDownloadsDirectory else { return [] }
        let fileManager = FileManager.default
        let pairs = (try? DatabaseManager.shared.downloadedArticlePaths()) ?? []
        let verified = pairs.filter { _, path in
            fileManager.fileExists(atPath: directory.appendingPathComponent(path).path)
        }
        return Set(verified.map(\.id))
    }

    func episodeDirectory(for articleID: Int64) -> URL? {
        downloadsDirectory?.appendingPathComponent("\(articleID)", isDirectory: true)
    }

    func filename(from audioURL: URL) -> String {
        let last = audioURL.lastPathComponent
        if last.isEmpty || last == "/" {
            return "episode.mp3"
        }
        if last.utf8.count > 200 {
            let ext = audioURL.pathExtension
            return ext.isEmpty ? "episode.mp3" : "episode.\(ext)"
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
        downloadedIDs.contains(articleID)
    }
}
