import UIKit

/// Tab snapshots on disk, so the switcher still has something to show for
/// every tab after a relaunch. Kept in caches: they are worth keeping but
/// cheap to rebuild, and they have no business in a backup.
nonisolated enum BrowserSnapshotArchive {

    private static let directoryName = "BrowserTabSnapshots"
    private static let compressionQuality: CGFloat = 0.8

    static func encode(_ image: UIImage) -> Data? {
        image.jpegData(compressionQuality: compressionQuality)
    }

    static func write(_ data: Data, for tabID: UUID) {
        guard let url = fileURL(for: tabID) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load(_ tabIDs: [UUID]) -> [UUID: Data] {
        tabIDs.reduce(into: [:]) { loaded, tabID in
            guard let url = fileURL(for: tabID),
                  let data = try? Data(contentsOf: url) else { return }
            loaded[tabID] = data
        }
    }

    static func remove(_ tabID: UUID) {
        guard let url = fileURL(for: tabID) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Drops the files of tabs that are gone: a closed tab is forgotten while
    /// the app runs, but one closed on a previous launch never was.
    static func removeAll(except tabIDs: Set<UUID>) {
        guard let directory = directory(),
              let files = try? FileManager.default.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: nil
              ) else { return }
        let kept = Set(tabIDs.map(\.uuidString))
        for file in files where !kept.contains(file.deletingPathExtension().lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func fileURL(for tabID: UUID) -> URL? {
        directory()?.appending(path: "\(tabID.uuidString).jpg")
    }

    private static func directory() -> URL? {
        guard let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let directory = caches.appending(path: directoryName)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
