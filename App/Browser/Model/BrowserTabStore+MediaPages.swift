import SwiftUI

extension BrowserTabStore {

    func registerMediaPage(
        _ token: BrowserPathToken,
        in tabID: UUID,
        ownsMedia: @escaping @MainActor () -> Bool,
        stop: @escaping @MainActor () -> Void
    ) {
        let depth = tabs.first { $0.id == tabID }?.path.count ?? 0
        mediaPages[tabID, default: [:]][token] = BrowserMediaPage(
            depth: depth,
            ownsMedia: ownsMedia,
            stop: stop
        )
    }

    func hasPlayingMedia(in tabID: UUID) -> Bool {
        mediaPages[tabID]?.values.contains { $0.ownsMedia() } ?? false
    }

    /// Held back while a swipe-back is in flight: the path has already popped
    /// by then, and a cancelled swipe puts the page back.
    func stopMediaLeftBehind(in tabID: UUID) {
        guard !isInteractivelyPopping,
              let pages = mediaPages[tabID], !pages.isEmpty,
              let tab = tabs.first(where: { $0.id == tabID }) else { return }
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
    private func isPage(
        _ token: BrowserPathToken,
        at registeredDepth: Int,
        reachableIn tab: BrowserTab
    ) -> Bool {
        let history = pageHistories[tab.id] ?? []
        if let depth = history.firstIndex(where: { $0.pathToken == token }) {
            return depth <= tab.path.count
        }
        return registeredDepth <= tab.path.count
    }
}
