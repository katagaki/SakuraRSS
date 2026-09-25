import SwiftUI

public extension TabNavigationStore {

    /// Stops the page's media once it is popped or its tab is closed. Being
    /// covered, hidden behind another tab, or evicted leaves it playing, and
    /// a tab with playing media is never the one evicted.
    func registerMediaPage(
        _ token: PathToken,
        in tabID: UUID,
        ownsMedia: @escaping @MainActor () -> Bool,
        stop: @escaping @MainActor () -> Void
    ) {
        let depth = tab(tabID)?.path.count ?? 0
        mediaPages[tabID, default: [:]][token] = MediaPage(
            depth: depth,
            ownsMedia: ownsMedia,
            stop: stop
        )
    }

    func hasPlayingMedia(in tabID: UUID) -> Bool {
        mediaPages[tabID]?.values.contains { $0.ownsMedia() } ?? false
    }
}

extension TabNavigationStore {

    /// Held back while a swipe-back is in flight: the path has already popped
    /// by then, and a cancelled swipe puts the page back.
    func stopMediaLeftBehind(in tabID: UUID) {
        guard !isInteractivelyPopping,
              let pages = mediaPages[tabID], !pages.isEmpty,
              let tab = tab(tabID) else { return }
        for (token, page) in pages where !isPage(token, at: page.depth, reachableIn: tab) {
            mediaPages[tabID]?[token] = nil
            if page.ownsMedia() { page.stop() }
        }
    }

    func stopAllMedia(in tabID: UUID) {
        let pages = mediaPages.removeValue(forKey: tabID) ?? [:]
        for page in pages.values where page.ownsMedia() {
            page.stop()
        }
    }

    /// The tab's history says where the page really sits. The depth recorded
    /// on appear is only the fallback: a rebuilt stack appears every page at
    /// its full depth.
    private func isPage(_ token: PathToken, at registeredDepth: Int, reachableIn tab: Tab) -> Bool {
        let history = pageHistories[tab.id] ?? []
        if let depth = history.firstIndex(where: { $0.pathToken == token }) {
            return depth <= tab.path.count
        }
        return registeredDepth <= tab.path.count
    }
}
