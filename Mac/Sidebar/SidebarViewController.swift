import AppKit
import Hanami

final class SidebarViewController: NSViewController {

    let feedManager: FeedManager
    let outlineView = NSOutlineView()
    var nodes: [SidebarNode] = []
    var onSelectLocation: ((BrowserLocation) -> Void)?
    var onOpenInNewTab: ((BrowserLocation) -> Void)?
    private var selectedLocation: BrowserLocation?
    private var treeObserver: ChangeObserver?
    private var insightsObserver: NSObjectProtocol?
    private var showsTopics = UserDefaults.standard.bool(forKey: "Intelligence.ContentInsights.Enabled")
    var isApplyingSelection = false

    init(feedManager: FeedManager) {
        self.feedManager = feedManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Sidebar"))
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.style = .sourceList
        outlineView.floatsGroupRows = false
        outlineView.rowSizeStyle = .default
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.autosaveName = "BrowserSidebar"
        outlineView.autosaveExpandedItems = true
        let menu = NSMenu()
        menu.delegate = self
        outlineView.menu = menu
        let scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        view = scrollView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        treeObserver = ChangeObserver { [weak self] in
            guard let self else { return }
            _ = SidebarTreeBuilder(feedManager: self.feedManager).build()
        } onChange: { [weak self] in
            self?.reloadTree()
        }
        // Topics shows only while Content Insights is on, a setting rather
        // than data, so the tree is rebuilt when it changes.
        insightsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let showsTopics = UserDefaults.standard.bool(forKey: "Intelligence.ContentInsights.Enabled")
                guard showsTopics != self.showsTopics else { return }
                self.showsTopics = showsTopics
                self.reloadTree()
            }
        }
        reloadTree()
    }

    func select(_ location: BrowserLocation) {
        selectedLocation = location
        applySelection()
    }

    private func reloadTree() {
        nodes = SidebarTreeBuilder(feedManager: feedManager).build()
        outlineView.reloadData()
        for node in nodes where node.isGroup {
            outlineView.expandItem(node)
        }
        applySelection()
    }

    private func applySelection() {
        guard isViewLoaded else { return }
        isApplyingSelection = true
        defer { isApplyingSelection = false }
        guard let selectedLocation, let node = node(for: selectedLocation) else {
            outlineView.deselectAll(nil)
            return
        }
        for ancestor in ancestors(of: node) where !outlineView.isItemExpanded(ancestor) {
            outlineView.expandItem(ancestor)
        }
        let row = outlineView.row(forItem: node)
        guard row >= 0 else { return }
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        outlineView.scrollRowToVisible(row)
    }

    func node(for location: BrowserLocation) -> SidebarNode? {
        node(withIdentifier: location.persistenceToken)
    }

    func node(withIdentifier identifier: String, in candidates: [SidebarNode]? = nil) -> SidebarNode? {
        for node in candidates ?? nodes {
            if node.identifier == identifier { return node }
            if let match = self.node(withIdentifier: identifier, in: node.children) { return match }
        }
        return nil
    }

    /// Found in the tree rather than the outline view, which only knows the
    /// parents of rows inside expanded sections.
    private func ancestors(of target: SidebarNode, in candidates: [SidebarNode]? = nil) -> [SidebarNode] {
        for node in candidates ?? nodes {
            if node.children.contains(target) { return [node] }
            let path = ancestors(of: target, in: node.children)
            if !path.isEmpty { return [node] + path }
        }
        return []
    }
}
