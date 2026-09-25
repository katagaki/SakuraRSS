import EnhancedNavigation
import Observation
import SwiftUI

/// The controls each tab's visible page has handed the address bar. Kept
/// apart from the tab store, one property per kind, so a page republishing
/// its progress does not redraw every menu that reads another kind.
@Observable
final class BrowserPageSlots {

    private(set) var articleActions: [UUID: BrowserPageSlot<BrowserArticleActions>] = [:]
    private(set) var bookmarksActions: [UUID: BrowserPageSlot<BrowserBookmarksActions>] = [:]
    private(set) var followingActions: [UUID: BrowserPageSlot<BrowserFollowingActions>] = [:]
    private(set) var startPageActions: [UUID: BrowserPageSlot<BrowserStartPageActions>] = [:]
    private(set) var markAllReadActions: [UUID: BrowserPageSlot<BrowserMarkAllReadAction>] = [:]
    private(set) var displayStyleOptions: [UUID: BrowserPageSlot<BrowserDisplayStyleOptions>] = [:]
    private(set) var pageProgress: [UUID: BrowserPageSlot<BrowserAddressProgress>] = [:]

    func setSlot(_ report: BrowserPageSlotReport, token: BrowserPathToken?, for tabID: UUID) {
        switch report {
        case .markAllRead(let action):
            BrowserPageSlot.fill(&markAllReadActions[tabID], with: action, from: token)
        case .article(let actions):
            BrowserPageSlot.fill(&articleActions[tabID], with: actions, from: token)
        case .bookmarks(let actions):
            BrowserPageSlot.fill(&bookmarksActions[tabID], with: actions, from: token)
        case .following(let actions):
            BrowserPageSlot.fill(&followingActions[tabID], with: actions, from: token)
        case .startPage(let actions):
            BrowserPageSlot.fill(&startPageActions[tabID], with: actions, from: token)
        case .displayStyle(let options):
            BrowserPageSlot.fill(&displayStyleOptions[tabID], with: options, from: token)
        case .progress(let progress):
            BrowserPageSlot.fill(&pageProgress[tabID], with: progress, from: token)
        }
    }

    func discard(_ tabIDs: [UUID]) {
        for tabID in tabIDs {
            markAllReadActions[tabID] = nil
            displayStyleOptions[tabID] = nil
            pageProgress[tabID] = nil
            articleActions[tabID] = nil
            bookmarksActions[tabID] = nil
            followingActions[tabID] = nil
            startPageActions[tabID] = nil
        }
    }

    /// The visible page's own progress, and nothing while a page deeper in
    /// the stack is the one working.
    func displayedProgress(for tabID: UUID, in store: BrowserTabStore) -> BrowserAddressProgress? {
        pageProgress[tabID]?.value(forPageAt: store.displayedPathToken(for: tabID))
    }
}
