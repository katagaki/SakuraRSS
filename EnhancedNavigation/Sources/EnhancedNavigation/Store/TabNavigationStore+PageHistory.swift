import SwiftUI

public extension TabNavigationStore {

    func setPageIdentity(_ identity: Identity?, for tabID: UUID) {
        guard let tab = tab(tabID) else { return }
        guard !isReportFromAnotherPage(identity, in: tab) else { return }
        if tab.pageIdentity != identity {
            updateTab(tabID) { $0.pageIdentity = identity }
        }
        guard let identity else { return }
        recordHistory(identity, depth: tab.path.count, for: tabID)
        persistTabs()
    }

    /// A page that was revealed once already, by a pop from deeper still, does
    /// not run `onAppear` again when it finally becomes the top one, so a pop
    /// takes the name from the tab's own record rather than waiting for a
    /// report that never arrives.
    func restoreIdentity(atDepth depth: Int, for tabID: UUID) {
        let history = pageHistories[tabID] ?? []
        let identity = history.indices.contains(depth) ? history[depth] : nil
        updateTab(tabID) { tab in
            guard tab.pageIdentity != identity else { return }
            tab.pageIdentity = identity
        }
    }

    /// The entry at each depth is replaced rather than appended, so going back
    /// and down a different branch does not leave the old branch behind.
    func recordHistory(_ identity: Identity, depth: Int, for tabID: UUID) {
        var history = pageHistories[tabID] ?? []
        if history.count > depth {
            history.removeSubrange(depth...)
        }
        while history.count < depth {
            history.append(identity)
        }
        history.append(identity)
        pageHistories[tabID] = history
    }

    /// Pages behind the current one, nearest first.
    func backHistory(for tabID: UUID) -> [BackHistoryEntry<Identity>] {
        guard let tab = tab(tabID) else { return [] }
        let history = pageHistories[tabID] ?? []
        let current = tab.path.count
        guard current > 0 else { return [] }
        return (0..<min(current, history.count))
            .reversed()
            .map { BackHistoryEntry(depth: $0, identity: history[$0]) }
    }
}

extension TabNavigationStore {

    /// A pop re-runs `onAppear` on the page below the one it reveals, the page
    /// on its way out reports once more as its environment unwinds, and
    /// restoring a stack re-runs it on every page in it, so the last report to
    /// arrive is not always the visible page's. A report is refused when this
    /// tab's own record puts that page at any depth other than the one the tab
    /// now sits at, which covers the page being popped away as well as the
    /// ones under it.
    private func isReportFromAnotherPage(_ identity: Identity?, in tab: Tab) -> Bool {
        guard let identity, let history = pageHistories[tab.id] else { return false }
        let depth = tab.path.count
        guard history.count > depth, !history[depth].names(identity) else { return false }
        return history.indices.contains { $0 != depth && history[$0].names(identity) }
    }
}
