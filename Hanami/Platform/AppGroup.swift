import Foundation

public enum AppGroup {

    /// The iOS-style identifier on macOS too, so the native app opens the same
    /// group container the Catalyst build has been writing to.
    public nonisolated static let identifier = "group.com.tsubuzaki.SakuraRSS"

    public nonisolated static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    public nonisolated static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    /// Where shared storage lives. Unprovisioned local macOS builds are handed
    /// a group container path that either does not exist or, once another app
    /// owns it, is blocked by container protection, so the directory is
    /// confirmed readable before it is trusted.
    public nonisolated static var storageURL: URL {
        if let containerURL,
           (try? FileManager.default.contentsOfDirectory(atPath: containerURL.path)) != nil {
            return containerURL
        }
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SakuraRSS", isDirectory: true)
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }
}
