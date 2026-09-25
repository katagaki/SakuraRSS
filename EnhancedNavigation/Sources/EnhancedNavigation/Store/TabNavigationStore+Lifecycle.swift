import SwiftUI

public extension TabNavigationStore {

    func select(_ tabID: UUID) {
        guard tabs.contains(where: { $0.id == tabID }) else { return }
        selectedTabID = tabID
        markLive(tabID)
    }

    @discardableResult
    func openTab(at root: Root = .newTabRoot, inBackground: Bool = false) -> UUID {
        let tab = Tab(root: root)
        tabs.append(tab)
        recordVisit(root)
        if !inBackground {
            selectedTabID = tab.id
            markLive(tab.id)
        }
        persistTabs()
        return tab.id
    }

    /// Deep links land in a tab of their own rather than displacing whatever
    /// the selected tab was showing.
    func openTab<Value: Hashable>(pushing value: Value) {
        let tabID = openTab()
        updateTab(tabID) { $0.path.append(value) }
    }

    func close(_ tabID: UUID) {
        // The last tab stays: an empty stack has nothing to show, and emptying
        // `tabs` even momentarily takes every reader of `selectedTab` with it.
        guard tabs.count > 1, let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs.remove(at: index)
        discardState(for: tabID)
        liveTabIDs.removeAll { $0 == tabID }
        if selectedTabID == tabID {
            let neighbour = tabs[min(index, tabs.count - 1)]
            selectedTabID = neighbour.id
            markLive(neighbour.id)
        }
        persistTabs()
        onTabsClosed?([tabID])
    }

    func closeAll() {
        let replacement = Tab()
        for tabID in mediaPages.keys {
            stopAllMedia(in: tabID)
        }
        pageHistories = [:]
        tabsAwaitingPathRestore = []
        tabs = [replacement]
        selectedTabID = replacement.id
        liveTabIDs = [replacement.id]
        persistTabs()
    }

    func moveTab(_ tabID: UUID, to destinationTabID: UUID) {
        guard let sourceIndex = tabs.firstIndex(where: { $0.id == tabID }),
              let destinationIndex = tabs.firstIndex(where: { $0.id == destinationTabID }),
              sourceIndex != destinationIndex else { return }
        let tab = tabs.remove(at: sourceIndex)
        tabs.insert(tab, at: destinationIndex)
        persistTabs()
    }

    func updateTab(_ tabID: UUID, _ change: (inout Tab) -> Void) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        let previousDepth = tabs[index].path.count
        change(&tabs[index])
        if tabs[index].path.count < previousDepth {
            stopMediaLeftBehind(in: tabID)
        }
    }

    func updateSelectedTab(_ change: (inout Tab) -> Void) {
        updateTab(selectedTabID, change)
    }

    func markLive(_ tabID: UUID) {
        guard liveTabIDs.last != tabID else { return }
        liveTabIDs.removeAll { $0 == tabID }
        liveTabIDs.append(tabID)
        while liveTabIDs.count > configuration.liveTabLimit {
            // A playing tab stays mounted, so its player keeps its place in
            // the window and PiP can still restore into it.
            let evicted = liveTabIDs.dropLast().firstIndex { !hasPlayingMedia(in: $0) } ?? 0
            liveTabIDs.remove(at: evicted)
        }
    }
}

extension TabNavigationStore {
    private func discardState(for tabID: UUID) {
        stopAllMedia(in: tabID)
        discardSnapshot(for: tabID)
        pageHistories[tabID] = nil
        overlayPages[tabID] = nil
    }
}
