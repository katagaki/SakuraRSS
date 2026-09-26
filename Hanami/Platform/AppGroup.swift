import Foundation

public enum AppGroup {

    /// macOS requires the team identifier prefix on app group containers;
    /// iOS and its siblings reject it.
    public nonisolated static let identifier: String = {
        #if os(macOS)
        "YYM4Z6MU8F.group.com.tsubuzaki.SakuraRSS"
        #else
        "group.com.tsubuzaki.SakuraRSS"
        #endif
    }()

    public nonisolated static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    public nonisolated static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    /// Where shared storage lives. Unprovisioned local macOS builds are handed
    /// a group container path that does not exist and cannot be created, so the
    /// directory is confirmed usable before it is trusted.
    public nonisolated static var storageURL: URL {
        if let containerURL, FileManager.default.fileExists(atPath: containerURL.path) {
            return containerURL
        }
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SakuraRSS", isDirectory: true)
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }
}
