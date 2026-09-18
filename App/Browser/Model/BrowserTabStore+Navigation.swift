import SwiftUI

extension BrowserTabStore {

    /// Pushes a location onto the selected tab, so moving between pages gets
    /// the system's push animation and its interactive back gesture rather
    /// than swapping the stack's root out from under itself.
    func navigate(to location: BrowserLocation) {
        updateSelectedTab { tab in
            tab.path.append(location)
            tab.lastVisited = .now
        }
        recordVisit(location)
        markLive(selectedTabID)
        persistTabs()
    }

    func push<Value: Hashable>(_ value: Value) {
        updateSelectedTab { tab in
            tab.path.append(value)
            tab.lastVisited = .now
        }
        persistTabs()
    }

    /// Deep links land in a tab of their own rather than displacing whatever
    /// the selected tab was showing.
    func openTab<Value: Hashable>(pushing value: Value) {
        let tabID = openTab()
        updateTab(tabID) { tab in
            tab.path.append(value)
            tab.lastVisited = .now
        }
        persistTabs()
    }

    func goBack() {
        if let overlay = displayedOverlayPage {
            setOverlayPage(nil, id: overlay.id, for: selectedTabID)
            overlay.dismiss()
            return
        }
        guard selectedTab.canGoBack else { return }
        updateSelectedTab { tab in
            tab.path.removeLast()
            tab.lastVisited = .now
        }
        restoreIdentity(atDepth: selectedTab.path.count, for: selectedTabID)
        persistTabs()
    }

    func popToRoot() {
        updateSelectedTab { $0.path = NavigationPath() }
        restoreIdentity(atDepth: 0, for: selectedTabID)
        persistTabs()
    }

    func pathBinding(for tabID: UUID) -> Binding<NavigationPath> {
        Binding(
            get: { [weak self] in
                self?.tabs.first { $0.id == tabID }?.path ?? NavigationPath()
            },
            set: { [weak self] newPath in
                guard let self else { return }
                let previousDepth = tabs.first { $0.id == tabID }?.path.count ?? 0
                updateTab(tabID) { tab in
                    tab.path = newPath
                    tab.lastVisited = .now
                }
                clearOverlayPages(for: tabID)
                if newPath.count < previousDepth {
                    restoreIdentity(atDepth: newPath.count, for: tabID)
                }
                persistTabs()
            }
        )
    }

    func setPageIdentity(_ identity: BrowserPageIdentity?, for tabID: UUID) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
        guard !isReportFromAnotherPage(identity, in: tab) else { return }
        if tab.pageIdentity != identity {
            updateTab(tabID) { $0.pageIdentity = identity }
        }
        guard let identity else { return }
        recordHistory(identity, depth: tab.path.count, for: tabID)
        persistTabs()
    }

    /// A pop re-runs `onAppear` on the page below the one it reveals, the page
    /// on its way out reports once more as its environment unwinds, and
    /// restoring a stack re-runs it on every page in it, so the last report to
    /// arrive is not always the visible page's. A report is refused when this
    /// tab's own record puts that page at any depth other than the one the tab
    /// now sits at, which covers the page being popped away as well as the
    /// ones under it.
    private func isReportFromAnotherPage(
        _ identity: BrowserPageIdentity?,
        in tab: BrowserTab
    ) -> Bool {
        guard let identity, let history = pageHistories[tab.id] else { return false }
        let depth = tab.path.count
        guard history.count > depth, !history[depth].names(identity) else { return false }
        return history.indices.contains { $0 != depth && history[$0].names(identity) }
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
    func recordHistory(_ identity: BrowserPageIdentity, depth: Int, for tabID: UUID) {
        var history = pageHistories[tabID] ?? []
        if history.count > depth {
            history.removeSubrange(depth...)
        }
        while history.count < depth {
            history.append(identity)
        }
        history.append(identity)
        setPageHistory(history, for: tabID)
    }

    /// Pages behind the current one, nearest first, paired with the depth to
    /// pop back to.
    var backHistory: [(depth: Int, identity: BrowserPageIdentity)] {
        let tab = selectedTab
        let history = pageHistories[tab.id] ?? []
        let current = tab.path.count
        guard current > 0 else { return [] }
        return (0..<min(current, history.count))
            .reversed()
            .map { (depth: $0, identity: history[$0]) }
    }

    func popTo(depth: Int) {
        let current = selectedTab.path.count
        guard depth < current else { return }
        updateSelectedTab { tab in
            tab.path.removeLast(current - depth)
            tab.lastVisited = .now
        }
        restoreIdentity(atDepth: depth, for: selectedTabID)
        persistTabs()
    }
}
