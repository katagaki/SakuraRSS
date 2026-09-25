import SwiftUI

public extension TabNavigationStore {

    /// Appends the value a path token stands for. Returns false when what it
    /// named is gone, which ends the rebuild: anything deeper was reached
    /// through that page and would be stranded without it.
    typealias PathRebuilder = (PathToken, inout NavigationPath) -> Bool

    /// Pushes last session's stack back onto a tab. Stops at the first page
    /// that cannot be rebuilt.
    func restorePathIfNeeded(for tabID: UUID, rebuilding rebuild: PathRebuilder) {
        guard tabsAwaitingPathRestore.remove(tabID) != nil,
              let tab = tab(tabID),
              tab.path.isEmpty
        else { return }
        let history = pageHistories[tabID] ?? []
        var path = NavigationPath()
        var depth = 0
        for identity in history.dropFirst() {
            guard let token = identity.pathToken, rebuild(token, &path) else { break }
            depth += 1
        }
        pageHistories[tabID] = Array(history.prefix(depth + 1))
        if depth > 0 {
            applyRestoredPath(path, identity: history[depth], for: tabID)
        }
        persistTabs()
    }

    /// Rebuilds every waiting tab's stack up front, one tab per run loop pass.
    /// Left to the tab's own `onAppear`, the rebuild lands in the frames a
    /// switcher is growing the page over, and the transition stutters on the
    /// lookups it takes; done ahead of the tap it costs nothing visible.
    func prewarmRestorablePaths(rebuilding rebuild: PathRebuilder) async {
        for tabID in tabs.map(\.id) {
            guard tabsAwaitingPathRestore.contains(tabID) else { continue }
            restorePathIfNeeded(for: tabID, rebuilding: rebuild)
            await Task.yield()
        }
    }
}

extension TabNavigationStore {

    /// How deep a tab's stack should be written out: its own path once it has
    /// been rebuilt, and what was read back from disk until then.
    func restorableDepth(for tab: Tab) -> Int {
        guard tabsAwaitingPathRestore.contains(tab.id) else { return tab.path.count }
        return max((pageHistories[tab.id]?.count ?? 1) - 1, 0)
    }

    /// Without the transaction the rebuilt stack pushes itself in, page by
    /// page, in front of the user.
    private func applyRestoredPath(_ path: NavigationPath, identity: Identity?, for tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            tabs[index].path = path
            tabs[index].pageIdentity = identity
        }
    }
}
