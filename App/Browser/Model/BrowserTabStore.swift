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
    private(set) var frozenCanGoBack: Bool?
    private(set) var frozenPageIdentity: BrowserPageIdentity?

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

    /// Pages a tab is showing that never entered its path, newest last.
    var overlayPages: [UUID: [BrowserOverlayPage]] = [:]

    /// Tabs whose stack has been read back from last session but not yet
    /// rebuilt: the rows behind it are looked up when the tab is first shown.
    var tabsAwaitingPathRestore: Set<UUID> = []

    private(set) var articleActions: [UUID: BrowserPageSlot<BrowserArticleActions>] = [:]
    private(set) var bookmarksActions: [UUID: BrowserPageSlot<BrowserBookmarksActions>] = [:]
    private(set) var followingActions: [UUID: BrowserPageSlot<BrowserFollowingActions>] = [:]

    private(set) var markAllReadActions: [UUID: BrowserPageSlot<BrowserMarkAllReadAction>] = [:]

    private(set) var displayStyleOptions: [UUID: BrowserPageSlot<BrowserDisplayStyleOptions>] = [:]

    private(set) var pageProgress: [UUID: BrowserPageSlot<BrowserAddressProgress>] = [:]

    private(set) var snapshots: [UUID: UIImage] = [:]

    @ObservationIgnored var isPersistenceScheduled = false

    @ObservationIgnored var mediaPages: [UUID: [BrowserPathToken: BrowserMediaPage]] = [:]

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

    var displayedTab: BrowserTab {
        displayedTab(for: selectedTabID)
    }

    var displayedCanGoBack: Bool {
        displayedCanGoBack(for: selectedTabID)
    }

    var displayedProgress: BrowserAddressProgress? {
        displayedProgress(for: selectedTabID)
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
        stopMediaLeftBehind(in: selectedTabID)
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

    func setSlot(_ report: BrowserPageSlotReport, token: BrowserPathToken?, for tabID: UUID) {
        switch report {
        case .markAllRead(let action):
            fill(&markAllReadActions[tabID], with: action, from: token)
        case .article(let actions):
            fill(&articleActions[tabID], with: actions, from: token)
        case .bookmarks(let actions):
            fill(&bookmarksActions[tabID], with: actions, from: token)
        case .following(let actions):
            fill(&followingActions[tabID], with: actions, from: token)
        case .displayStyle(let options):
            fill(&displayStyleOptions[tabID], with: options, from: token)
        case .progress(let progress):
            fill(&pageProgress[tabID], with: progress, from: token)
        }
    }

    /// A page only empties the slot it filled itself: a page below the visible
    /// one goes on reporting, and its nil would otherwise take the controls
    /// away from the page the bar is naming.
    private func fill<Value>(
        _ slot: inout BrowserPageSlot<Value>?,
        with value: Value?,
        from token: BrowserPathToken?
    ) {
        if let value {
            slot = BrowserPageSlot(token: token, value: value)
        } else if slot?.token == token {
            slot = nil
        }
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
        setShowingTabSwitcherWithoutAnimation(false)
        // A tick later: the page re-lays itself out around its own bars the
        // moment the chrome comes back, and doing that in the same pass as
        // the swap drops its content by a bar's height in the first frame of
        // the growth. Behind the snapshot it costs nothing.
        Task { @MainActor in
            self.setPageSwappedWithoutAnimation(false)
            withAnimation(BrowserTabSwitcher.transitionAnimation) {
                self.isPageCollapsed = false
            }
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

    private func freezeCollapseTarget() {
        // Cleared, not left alone: a tab opened from the switcher has no frame
        // yet, and a stale one zooms out of the previously selected tab.
        collapseTarget = cardFrames[selectedTabID]
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
        stopAllMedia(in: tabID)
        discardSnapshot(for: tabID)
        markAllReadActions[tabID] = nil
        displayStyleOptions[tabID] = nil
        pageProgress[tabID] = nil
        articleActions[tabID] = nil
        bookmarksActions[tabID] = nil
        followingActions[tabID] = nil
        pageHistories[tabID] = nil
        overlayPages[tabID] = nil
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

    func updateTab(_ tabID: UUID, _ change: (inout BrowserTab) -> Void) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        let previousDepth = tabs[index].path.count
        change(&tabs[index])
        if tabs[index].path.count < previousDepth {
            stopMediaLeftBehind(in: tabID)
        }
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
        guard liveTabIDs.last != tabID else { return }
        liveTabIDs.removeAll { $0 == tabID }
        liveTabIDs.append(tabID)
        while liveTabIDs.count > BrowserTabStore.liveTabLimit {
            // A playing tab stays mounted, so its player keeps its place in
            // the window and PiP can still restore into it.
            let evicted = liveTabIDs.dropLast().firstIndex { !hasPlayingMedia(in: $0) } ?? 0
            liveTabIDs.remove(at: evicted)
        }
    }
}
