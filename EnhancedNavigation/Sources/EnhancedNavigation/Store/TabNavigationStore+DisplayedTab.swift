import SwiftUI

/// What a tab's own chrome shows. Every mounted page can carry its own bar, so
/// these are read per tab rather than through the selection: a bar that
/// follows the selection is rebuilt, menus and all, on every tab switch, in
/// every tab, right as the switcher transition starts.
public extension TabNavigationStore {

    var displayedTab: Tab {
        displayedTab(for: selectedTabID)
    }

    var displayedCanGoBack: Bool {
        displayedCanGoBack(for: selectedTabID)
    }

    /// The pre-gesture state while a swipe back is in flight, the live state
    /// otherwise. The selection is only consulted mid-swipe, so a tab's bar
    /// does not otherwise depend on which tab is selected.
    func displayedTab(for tabID: UUID) -> Tab {
        var tab = tab(tabID) ?? Tab()
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
        return tab(tabID)?.canGoBack ?? false
    }

    /// The token of the page a tab's chrome is naming, for looking up the
    /// `PageSlot`s that page filled.
    func displayedPathToken(for tabID: UUID) -> PathToken? {
        displayedTab(for: tabID).pageIdentity?.pathToken
    }
}
