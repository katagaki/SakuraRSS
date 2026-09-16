import Hanami
import SwiftUI

extension BrowserTabStore {

    /// How deep a tab's stack should be written out: its own path once it has
    /// been rebuilt, and what was read back from disk until then.
    func restorableDepth(for tab: BrowserTab) -> Int {
        guard tabsAwaitingPathRestore.contains(tab.id) else { return tab.path.count }
        return max((pageHistories[tab.id]?.count ?? 1) - 1, 0)
    }

    /// Pushes last session's stack back onto a tab. Stops at the first page
    /// whose row has gone, since anything deeper was reached through it.
    func restorePathIfNeeded(for tabID: UUID, in feedManager: FeedManager) {
        guard tabsAwaitingPathRestore.remove(tabID) != nil,
              let tab = tabs.first(where: { $0.id == tabID }),
              tab.path.isEmpty
        else { return }
        let history = pageHistories[tabID] ?? []
        var path = NavigationPath()
        var depth = 0
        for identity in history.dropFirst() {
            guard let token = identity.pathToken,
                  token.append(to: &path, in: feedManager) else { break }
            depth += 1
        }
        setPageHistory(Array(history.prefix(depth + 1)), for: tabID)
        if depth > 0 {
            applyRestoredPath(path, identity: history[depth], for: tabID)
        }
        persistTabs()
    }
}
