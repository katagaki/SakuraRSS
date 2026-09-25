import Observation
import SwiftUI

/// A browser-style set of tabs, each with its own `NavigationPath`, that
/// remembers what every page called itself so the chrome can label stacks it
/// cannot read, restores each tab down to the page it was left on, and runs a
/// zoom transition into a tab switcher.
@Observable
public final class TabNavigationStore<Root: TabRoot, Identity: TabPageIdentity> {

    public typealias Tab = NavigationTab<Root, Identity>
    public typealias PathToken = Identity.PathToken

    @ObservationIgnored public let configuration: TabStoreConfiguration

    public internal(set) var tabs: [Tab]
    public internal(set) var selectedTabID: UUID
    public internal(set) var liveTabIDs: [UUID]
    public internal(set) var visitCounts: [String: Int]

    /// Drives the chrome. Changed without an animation, or the toolbars
    /// cross-fade across the whole transition.
    public internal(set) var isShowingTabSwitcher = false

    /// Drives the geometry, and is what the transition animates.
    public internal(set) var isPageCollapsed = false

    /// Hands the card's snapshot the collapsed page's place. Flipped only once
    /// the spring has settled: swapping on a fraction of the duration leaves
    /// the page a few points short of the snapshot, and the two cross-fade
    /// visibly out of register.
    public internal(set) var isPageSwappedForSnapshot = false

    /// While a swipe-back is in flight the path has already popped, so the
    /// chrome would flip to the previous page before the gesture is
    /// committed, and stay wrong if the swipe is cancelled.
    public internal(set) var isInteractivelyPopping = false
    var frozenCanGoBack: Bool?
    var frozenPageIdentity: Identity?

    /// Routed through the store rather than a preference: a switcher's
    /// NavigationStack does not propagate preferences out to the shell.
    public internal(set) var cardFrames: [UUID: CGRect] = [:]

    /// Frozen when a transition starts: cards keep reporting frames while the
    /// grid lays out, and a target that moves mid-flight makes the page jump.
    public internal(set) var collapseTarget: CGRect?

    /// What each tab has visited, indexed by depth in its path. A
    /// NavigationPath cannot be read back, so the store keeps its own record
    /// to offer a back history.
    public internal(set) var pageHistories: [UUID: [Identity]] = [:]

    /// Pages a tab is showing that never entered its path, newest last.
    public internal(set) var overlayPages: [UUID: [OverlayPage<Identity>]] = [:]

    /// Tabs whose stack has been read back from last session but not yet
    /// rebuilt: the pages behind it are looked up when the tab is first shown.
    public internal(set) var tabsAwaitingPathRestore: Set<UUID> = []

    public internal(set) var snapshots: [UUID: UIImage] = [:]

    /// Called with the identifiers of tabs that have just been closed, so
    /// state kept alongside the store can be let go of too.
    @ObservationIgnored public var onTabsClosed: (([UUID]) -> Void)?

    @ObservationIgnored var isPersistenceScheduled = false
    @ObservationIgnored var mediaPages: [UUID: [PathToken: MediaPage]] = [:]

    public init(
        configuration: TabStoreConfiguration,
        tabs: [Tab] = [],
        selectedTabID: UUID? = nil,
        pageHistories: [UUID: [Identity]] = [:]
    ) {
        self.configuration = configuration
        // The label a tab card shows comes from the tab, not from its history,
        // so a tab that has not been rebuilt yet would call itself by its root.
        var restored = tabs.isEmpty ? [Tab()] : tabs
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
        self.visitCounts = Self.loadVisitCounts(configuration: configuration)
        self.pageHistories = pageHistories
        self.tabsAwaitingPathRestore = Set(
            pageHistories.filter { $0.value.count > 1 }.keys
        )
        loadPersistedSnapshots()
    }

    public var selectedTab: Tab {
        // Never subscripts: a lookup against an empty array is what crashed
        // while a tab was being removed.
        tabs.first { $0.id == selectedTabID } ?? tabs.first ?? Tab()
    }

    public var canCloseTabs: Bool {
        tabs.count > 1
    }

    public func isLive(_ tabID: UUID) -> Bool {
        liveTabIDs.contains(tabID)
    }

    func tab(_ tabID: UUID) -> Tab? {
        tabs.first { $0.id == tabID }
    }
}
