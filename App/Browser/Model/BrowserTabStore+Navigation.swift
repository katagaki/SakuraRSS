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

    func goBack() {
        guard selectedTab.canGoBack else { return }
        updateSelectedTab { tab in
            tab.path.removeLast()
            tab.lastVisited = .now
        }
        persistTabs()
    }

    func popToRoot() {
        updateSelectedTab { $0.path = NavigationPath() }
        persistTabs()
    }

    func pathBinding(for tabID: UUID) -> Binding<NavigationPath> {
        Binding(
            get: { [weak self] in
                self?.tabs.first { $0.id == tabID }?.path ?? NavigationPath()
            },
            set: { [weak self] newPath in
                guard let self else { return }
                updateTab(tabID) { tab in
                    tab.path = newPath
                    tab.lastVisited = .now
                }
                persistTabs()
            }
        )
    }

    func setPageIdentity(_ identity: BrowserPageIdentity?, for tabID: UUID) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
        if tab.pageIdentity != identity {
            updateTab(tabID) { $0.pageIdentity = identity }
        }
        guard let identity else { return }
        recordHistory(identity, depth: tab.path.count, for: tabID)
        persistTabs()
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
        let history = pageHistories[selectedTabID] ?? []
        updateSelectedTab { tab in
            tab.path.removeLast(current - depth)
            tab.pageIdentity = history.indices.contains(depth) ? history[depth] : nil
            tab.lastVisited = .now
        }
        persistTabs()
    }
}
