import Foundation

extension PodcastDownloadManager {

    var downloadsDirectory: URL? {
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        ) else { return nil }
        let dir = container.appendingPathComponent("PodcastDownloads", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func episodeDirectory(for articleID: Int64) -> URL? {
        downloadsDirectory?.appendingPathComponent("\(articleID)", isDirectory: true)
    }

    func filename(from audioURL: URL) -> String {
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
}
