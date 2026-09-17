import Hanami
import Observation
import SwiftUI

@MainActor
@Observable
final class BrowserTabStore {

    /// Tabs beyond this many are torn down and rebuilt from their stored path
    /// when revisited, so twenty open feeds do not mean twenty live article lists.
    static let liveTabLimit = 4

    private(set) var tabs: [BrowserTab]
    private(set) var selectedTabID: UUID
    private(set) var liveTabIDs: [UUID]
    var visitCounts: [String: Int]

    /// Drives the chrome. Changed without an animation, or the toolbars
    /// cross-fade across the whole transition.
    private(set) var isShowingTabSwitcher = false

    /// Drives the geometry, and is what the transition animates.
    private(set) var isPageCollapsed = false

    /// Hands the card's snapshot the collapsed page's place. Flipped only once
    /// the spring has settled: swapping on a fraction of the duration leaves
    /// the page a few points short of the snapshot, and the two cross-fade
    /// visibly out of register.
    private(set) var isPageSwappedForSnapshot = false

    /// While a swipe-back is in flight the path has already popped, so the
    /// bottom bar would flip to the previous page before the gesture is
    /// committed, and stay wrong if the swipe is cancelled.
    private(set) var isInteractivelyPopping = false
    private var frozenCanGoBack: Bool?
    private var frozenPageIdentity: BrowserPageIdentity?

    /// Routed through the store rather than a preference: the switcher's
    /// NavigationStack does not propagate preferences out to the shell.
    private(set) var cardFrames: [UUID: CGRect] = [:]

    /// Frozen when a transition starts: cards keep reporting frames while the
    /// grid lays out, and a target that moves mid-flight makes the page jump.
    private(set) var collapseTarget: CGRect?

    /// What each tab has visited, indexed by depth in its path. A
    /// NavigationPath cannot be read back, so the browser keeps its own
    /// record to offer a back history.
    private(set) var pageHistories: [UUID: [BrowserPageIdentity]] = [:]

    /// Tabs whose stack has been read back from last session but not yet
    /// rebuilt: the rows behind it are looked up when the tab is first shown.
    var tabsAwaitingPathRestore: Set<UUID> = []

    private(set) var articleActions: [UUID: BrowserArticleActions] = [:]
    private(set) var bookmarksActions: [UUID: BrowserBookmarksActions] = [:]

    private(set) var markAllReadActions: [UUID: BrowserMarkAllReadAction] = [:]

    private(set) var snapshots: [UUID: UIImage] = [:]

    init(
        tabs: [BrowserTab] = [],
        selectedTabID: UUID? = nil,
        pageHistories: [UUID: [BrowserPageIdentity]] = [:]
    ) {
        // The label a tab card shows comes from the tab, not from its history,
        // so a tab that has not been rebuilt yet would call itself by its root.
        var restored = tabs.isEmpty ? [BrowserTab()] : tabs
        for index in restored.indices {
            restored[index].pageIdentity = pageHistories[restored[index].id]?.last
        }
        self.tabs = restored
        let selected = selectedTabID.flatMap { candidate in
            restored.contains { $0.id == candidate } ? candidate : nil
        }
        let resolved = selected ?? restored[0].id
        self.selectedTabID = resolved
        self.liveTabIDs = [resolved]
        self.visitCounts = BrowserTabStore.loadVisitCounts()
        self.pageHistories = pageHistories
        self.tabsAwaitingPathRestore = Set(
            pageHistories.filter { $0.value.count > 1 }.keys
        )
        loadPersistedSnapshots()
    }

    /// What the bottom bar should show: the pre-gesture state while a swipe
    /// back is in flight, the live state otherwise.
    var displayedTab: BrowserTab {
        guard isInteractivelyPopping else { return selectedTab }
        var tab = selectedTab
        tab.pageIdentity = frozenPageIdentity
        return tab
    }

    var displayedCanGoBack: Bool {
        frozenCanGoBack ?? selectedTab.canGoBack
    }

    func beginInteractivePop() {
        guard !isInteractivelyPopping else { return }
        frozenCanGoBack = selectedTab.canGoBack
        frozenPageIdentity = selectedTab.pageIdentity
        isInteractivelyPopping = true
    }

    /// A cancelled swipe leaves the revealed page's identity reported as the
    /// tab's own: it appeared, and nothing re-reports the page that never
    /// actually left. Put the frozen one back before unfreezing, or the bar
    /// flips to the previous page the moment the gesture is let go.
    func endInteractivePop(cancelled: Bool) {
        guard isInteractivelyPopping else { return }
        if cancelled, let index = tabs.firstIndex(where: { $0.id == selectedTabID }) {
            tabs[index].pageIdentity = frozenPageIdentity
        }
        isInteractivelyPopping = false
        frozenCanGoBack = nil
        frozenPageIdentity = nil
    }

    var selectedTab: BrowserTab {
        // Never subscripts: a lookup against an empty array is what crashed
        // while a tab was being removed.
        tabs.first { $0.id == selectedTabID } ?? tabs.first ?? BrowserTab()
    }

    /// Snapshots the visible page and files it against the selected tab.
    func setSnapshot(_ image: UIImage?, for tabID: UUID) {
        snapshots[tabID] = image
    }

    func setArticleActions(_ actions: BrowserArticleActions?, for tabID: UUID) {
        articleActions[tabID] = actions
    }

    func setBookmarksActions(_ actions: BrowserBookmarksActions?, for tabID: UUID) {
        bookmarksActions[tabID] = actions
    }

    func setMarkAllRead(_ action: BrowserMarkAllReadAction?, for tabID: UUID) {
        markAllReadActions[tabID] = action
    }

    func showTabSwitcher() {
        captureSelectedTabSnapshot()
        freezeCollapseTarget()
        setShowingTabSwitcherWithoutAnimation(true)
        withAnimation(BrowserTabSwitcher.transitionAnimation, completionCriteria: .removed) {
            isPageCollapsed = true
        } completion: {
            // Not if the collapse was reversed while it ran: the completion
            // still fires, and the page is back at full screen by then.
            guard self.isPageCollapsed else { return }
            self.setPageSwappedWithoutAnimation(true)
        }
    }

    /// The chrome is handed back up front, mirroring the collapse. Waiting for
    /// the page to land leaves the switcher's own navigation bar blurring over
    /// the growing page, and swaps the bars under it at the very end, which
    /// nudges the page's content as it settles.
    func hideTabSwitcher() {
        freezeCollapseTarget()
        setPageSwappedWithoutAnimation(false)
        setShowingTabSwitcherWithoutAnimation(false)
        withAnimation(BrowserTabSwitcher.transitionAnimation) {
            isPageCollapsed = false
        }
    }

    private func setPageSwappedWithoutAnimation(_ isSwapped: Bool) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isPageSwappedForSnapshot = isSwapped
        }
    }

    /// Outside the transition: changes flushed in the same cycle are otherwise
    /// swept into it.
    private func setShowingTabSwitcherWithoutAnimation(_ isShowing: Bool) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isShowingTabSwitcher = isShowing
        }
    }

    /// The snapshot sits below the card's title row, so the page lands on that
    /// sub-rect. Derived from the card's width so the two cannot disagree.
    private func freezeCollapseTarget() {
        // Cleared, not left alone: a tab opened from the switcher has no frame
        // yet, and a stale one zooms out of the previously selected tab.
        guard let card = cardFrames[selectedTabID] else {
            collapseTarget = nil
            return
        }
        let previewHeight = card.width / BrowserTabCard.previewAspectRatio
        collapseTarget = CGRect(
            x: card.minX,
            y: card.maxY - previewHeight,
            width: card.width,
            height: previewHeight
        )
    }

    func setCardFrame(_ frame: CGRect, for tabID: UUID) {
        guard cardFrames[tabID] != frame else { return }
        cardFrames[tabID] = frame
    }

    func isLive(_ tabID: UUID) -> Bool {
        liveTabIDs.contains(tabID)
    }

    // MARK: - Tab lifecycle

    func select(_ tabID: UUID) {
        guard tabs.contains(where: { $0.id == tabID }) else { return }
        selectedTabID = tabID
        touch(tabID)
        markLive(tabID)
    }

    @discardableResult
    func openTab(at location: BrowserLocation = .startPage, inBackground: Bool = false) -> UUID {
        let tab = BrowserTab(location: location)
        tabs.append(tab)
        recordVisit(location)
        if !inBackground {
            selectedTabID = tab.id
            markLive(tab.id)
        }
        persistTabs()
        return tab.id
    }

    func close(_ tabID: UUID) {
        // The last tab stays: an empty stack has nothing to show, and emptying
        // `tabs` even momentarily takes every reader of `selectedTab` with it.
        guard tabs.count > 1, let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs.remove(at: index)
        discardSnapshot(for: tabID)
        markAllReadActions[tabID] = nil
        articleActions[tabID] = nil
        bookmarksActions[tabID] = nil
        pageHistories[tabID] = nil
        liveTabIDs.removeAll { $0 == tabID }
        if selectedTabID == tabID {
            let neighbour = tabs[min(index, tabs.count - 1)]
            selectedTabID = neighbour.id
            markLive(neighbour.id)
        }
        persistTabs()
    }

    var canCloseTabs: Bool {
        tabs.count > 1
    }

    func closeAll() {
        let replacement = BrowserTab()
        pageHistories = [:]
        tabsAwaitingPathRestore = []
        tabs = [replacement]
        selectedTabID = replacement.id
        liveTabIDs = [replacement.id]
        persistTabs()
    }

    func updateTab(_ tabID: UUID, _ change: (inout BrowserTab) -> Void) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        change(&tabs[index])
    }

    func updateSelectedTab(_ change: (inout BrowserTab) -> Void) {
        updateTab(selectedTabID, change)
    }

    /// Sets a tab's stack back the way it was left. Without the transaction
    /// the rebuilt stack pushes itself in, page by page, in front of the user.
    func setPageHistory(_ history: [BrowserPageIdentity], for tabID: UUID) {
        pageHistories[tabID] = history
    }

    func applyRestoredPath(
        _ path: NavigationPath,
        identity: BrowserPageIdentity?,
        for tabID: UUID
    ) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            tabs[index].path = path
            tabs[index].pageIdentity = identity
        }
    }

    // MARK: - Liveness

    func markLive(_ tabID: UUID) {
        liveTabIDs.removeAll { $0 == tabID }
        liveTabIDs.append(tabID)
        while liveTabIDs.count > BrowserTabStore.liveTabLimit {
            liveTabIDs.removeFirst()
        }
    }

    private func touch(_ tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[index].lastVisited = .now
    }
}
