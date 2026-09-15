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

    private(set) var articleActions: [UUID: BrowserArticleActions] = [:]

    private(set) var markAllReadActions: [UUID: BrowserMarkAllReadAction] = [:]

    private(set) var snapshots: [UUID: UIImage] = [:]

    init(tabs: [BrowserTab] = [], selectedTabID: UUID? = nil) {
        let restored = tabs.isEmpty ? [BrowserTab()] : tabs
        self.tabs = restored
        let selected = selectedTabID.flatMap { candidate in
            restored.contains { $0.id == candidate } ? candidate : nil
        }
        let resolved = selected ?? restored[0].id
        self.selectedTabID = resolved
        self.liveTabIDs = [resolved]
        self.visitCounts = BrowserTabStore.loadVisitCounts()
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

    func endInteractivePop() {
        guard isInteractivelyPopping else { return }
        isInteractivelyPopping = false
        frozenCanGoBack = nil
        frozenPageIdentity = nil
    }

    var selectedTab: BrowserTab {
        // Never subscripts: a lookup against an empty array is what crashed
        // while a tab was being removed.
        tabs.first { $0.id == selectedTabID } ?? tabs.first ?? BrowserTab()
    }

    private var selectedIndex: Int {
        tabs.firstIndex { $0.id == selectedTabID } ?? 0
    }

    /// Snapshots the visible page and files it against the selected tab.
    func setSnapshot(_ image: UIImage?, for tabID: UUID) {
        snapshots[tabID] = image
    }

    func setArticleActions(_ actions: BrowserArticleActions?, for tabID: UUID) {
        articleActions[tabID] = actions
    }

    func setMarkAllRead(_ action: BrowserMarkAllReadAction?, for tabID: UUID) {
        markAllReadActions[tabID] = action
    }

    func showTabSwitcher() {
        captureSelectedTabSnapshot()
        freezeCollapseTarget()
        setShowingTabSwitcherWithoutAnimation(true)
        withAnimation(BrowserTabSwitcher.transitionAnimation) {
            isPageCollapsed = true
        }
    }

    /// The chrome is handed back only once the page has landed: any earlier
    /// and the page's own bar fades in behind the switcher's.
    func hideTabSwitcher() {
        freezeCollapseTarget()
        withAnimation(BrowserTabSwitcher.transitionAnimation) {
            isPageCollapsed = false
        } completion: {
            self.setShowingTabSwitcherWithoutAnimation(false)
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
        tabs = [replacement]
        selectedTabID = replacement.id
        liveTabIDs = [replacement.id]
        persistTabs()
    }

    // MARK: - Navigation

    /// Pushes a location onto the selected tab, so moving between pages gets
    /// the system's push animation and its interactive back gesture rather
    /// than swapping the stack's root out from under itself.
    func navigate(to location: BrowserLocation) {
        let index = selectedIndex
        tabs[index].path.append(location)
        tabs[index].lastVisited = .now
        recordVisit(location)
        markLive(tabs[index].id)
    }

    func push<Value: Hashable>(_ value: Value) {
        let index = selectedIndex
        tabs[index].path.append(value)
        tabs[index].lastVisited = .now
    }

    func goBack() {
        let index = selectedIndex
        guard !tabs[index].path.isEmpty else { return }
        tabs[index].path.removeLast()
        tabs[index].lastVisited = .now
    }

    func popToRoot() {
        tabs[selectedIndex].path = NavigationPath()
    }

    func pathBinding(for tabID: UUID) -> Binding<NavigationPath> {
        Binding(
            get: { [weak self] in
                self?.tabs.first { $0.id == tabID }?.path ?? NavigationPath()
            },
            set: { [weak self] newPath in
                guard let self, let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
                tabs[index].path = newPath
                tabs[index].lastVisited = .now
            }
        )
    }

    func setPageIdentity(_ identity: BrowserPageIdentity?, for tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        if tabs[index].pageIdentity != identity {
            tabs[index].pageIdentity = identity
        }
        guard let identity else { return }
        recordHistory(identity, depth: tabs[index].path.count, for: tabID)
    }

    /// The entry at each depth is replaced rather than appended, so going back
    /// and down a different branch does not leave the old branch behind.
    private func recordHistory(_ identity: BrowserPageIdentity, depth: Int, for tabID: UUID) {
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
        let index = selectedIndex
        let current = tabs[index].path.count
        guard depth < current else { return }
        tabs[index].path.removeLast(current - depth)
        let history = pageHistories[tabs[index].id] ?? []
        tabs[index].pageIdentity = history.indices.contains(depth) ? history[depth] : nil
        tabs[index].lastVisited = .now
    }

    // MARK: - Liveness

    private func markLive(_ tabID: UUID) {
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
