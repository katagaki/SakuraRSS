import Foundation

/// On-disk cache of downsampled widget thumbnail bytes, scoped per widget configuration.
struct WidgetThumbnailCache {

    let scope: String

    var directory: URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        ) else { return nil }
        let dir = container
            .appendingPathComponent("WidgetThumbnails", isDirectory: true)
            .appendingPathComponent(scope, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func file(for articleID: Int64) -> URL? {
        directory?.appendingPathComponent("\(articleID).jpg")
    }

    func thumbnail(for articleID: Int64) -> Data? {
        guard let url = file(for: articleID) else { return nil }
        return try? Data(contentsOf: url)
    }

    func storeThumbnail(_ data: Data, for articleID: Int64) {
        guard let url = file(for: articleID) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Deletes thumbnails whose article IDs aren't in `ids`.
    func prune(keeping ids: [Int64]) {
        guard let directory else { return }
        let keepSet = Set(ids.map { "\($0).jpg" })
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for entry in entries where !keepSet.contains(entry.lastPathComponent) {
            try? FileManager.default.removeItem(at: entry)
        }
    }
}
