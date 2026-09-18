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
}
