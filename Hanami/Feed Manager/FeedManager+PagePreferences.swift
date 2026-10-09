import Foundation

public extension FeedManager {

    /// The global setting from before per-page preferences existed. It has no
    /// switch anymore, but pages without their own choice still follow it.
    static let legacyHideViewedContentDefaultsKey = "Articles.HideViewedContent"
    static let pagePreferencesDidChangeNotification = Notification.Name("FeedManager.PagePreferencesDidChange")

    func pageKey(for feed: Feed) -> String {
        ContentPageKey.feed(url: feed.url)
    }

    /// Lists from before list sync get their sync ID when sync first starts,
    /// which for most is the one derived from their name.
    func pageKey(for list: FeedList) -> String {
        ContentPageKey.list(syncID: list.syncID ?? DatabaseManager.preSyncListSyncID(forName: list.name))
    }

    /// Doomscrolling Mode turns it off everywhere.
    func hidesReadContent(onPage pageKey: String) -> Bool {
        DoomscrollingMode.effectiveHideViewedContent(storedHidesReadContent(onPage: pageKey))
    }

    func storedHidesReadContent(onPage pageKey: String) -> Bool {
        pageHidesReadContent[pageKey]
            ?? UserDefaults.standard.bool(forKey: Self.legacyHideViewedContentDefaultsKey)
    }

    func setHidesReadContent(_ hidesReadContent: Bool, onPage pageKey: String) {
        pageHidesReadContent[pageKey] = hidesReadContent
        try? database.saveUserPagePreference(pageKey: pageKey, hidesReadContent: hidesReadContent)
        CloudSyncEngine.shared.notePagePreferenceChanged()
        NotificationCenter.default.post(name: Self.pagePreferencesDidChangeNotification, object: self)
    }

    internal nonisolated static func loadPageHidesReadContent(from database: DatabaseManager) -> [String: Bool] {
        let preferences = (try? database.allPagePreferences()) ?? []
        return Dictionary(
            preferences.map { ($0.pageKey, $0.hidesReadContent) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    internal func applyLoadedPageHidesReadContent(_ loaded: [String: Bool]) {
        if loaded != pageHidesReadContent {
            pageHidesReadContent = loaded
            NotificationCenter.default.post(name: Self.pagePreferencesDidChangeNotification, object: self)
        }
    }
}
