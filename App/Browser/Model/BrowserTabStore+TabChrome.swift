import SwiftUI

/// What a tab's own bottom bar shows. Every mounted page carries a bar, so
/// these are read per tab rather than through the selection: a bar that
/// follows the selection is rebuilt, menus and all, on every tab switch,
/// in every tab, right as the switcher transition starts.
extension BrowserTabStore {

    /// The pre-gesture state while a swipe back is in flight, the live state
    /// otherwise. The selection is only consulted mid-swipe, so a tab's bar
    /// does not otherwise depend on which tab is selected.
    func displayedTab(for tabID: UUID) -> BrowserTab {
        var tab = tabs.first { $0.id == tabID } ?? BrowserTab()
        let overlayPage = overlayPages[tabID]?.last
        let isPopping = isInteractivelyPopping && tabID == selectedTabID
        guard isPopping || overlayPage != nil else { return tab }
        tab.pageIdentity = overlayPage?.identity ?? frozenPageIdentity
        return tab
    }

    func displayedCanGoBack(for tabID: UUID) -> Bool {
        if overlayPages[tabID]?.last != nil { return true }
        if isInteractivelyPopping, tabID == selectedTabID, let frozenCanGoBack {
            return frozenCanGoBack
        }
        return tabs.first { $0.id == tabID }?.canGoBack ?? false
    }

    /// The visible page's own progress, and nothing while a page deeper in
    /// the stack is the one working.
    func displayedProgress(for tabID: UUID) -> BrowserAddressProgress? {
        pageProgress[tabID]?.value(forPageAt: displayedTab(for: tabID).pageIdentity?.pathToken)
    }

    /// Pages behind the current one, nearest first, paired with the depth to
    /// pop back to.
    func backHistory(for tabID: UUID) -> [(depth: Int, identity: BrowserPageIdentity)] {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return [] }
        let history = pageHistories[tabID] ?? []
        let current = tab.path.count
        guard current > 0 else { return [] }
        return (0..<min(current, history.count))
            .reversed()
            .map { (depth: $0, identity: history[$0]) }
    }
}
