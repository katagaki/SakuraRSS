import AppKit
import Hanami
import SwiftUI

final class ContentListViewController: NSViewController {

    let feedManager: FeedManager
    let tableView = ContentListTableView()
    var articles: [Article] = []
    var onSelectArticle: ((Article?) -> Void)?
    var reportedArticleID: Int64?
    private(set) var displayStyle: FeedDisplayStyle = .inbox
    var onOpenInNewTab: ((BrowserLocation) -> Void)?
    var onOpenFullWidth: ((BrowserLocation) -> Void)?
    private(set) var location: BrowserLocation?
    private var dataObserver: ChangeObserver?
    private var readStateObserver: ChangeObserver?
    private var pendingDataReload: DispatchWorkItem?
    private let emptyStateView = NSHostingView(rootView: ContentEmptyStateView())

    init(feedManager: FeedManager) {
        self.feedManager = feedManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Content"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .inset
        tableView.usesAutomaticRowHeights = true
        tableView.dataSource = self
        tableView.delegate = self
        let menu = NSMenu()
        menu.delegate = self
        tableView.menu = menu
        tableView.target = self
        tableView.doubleAction = #selector(openSelectedFullWidth)
        tableView.onShortcut = { [weak self] shortcut in
            self?.handle(shortcut)
        }
        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        // Beside the scroll view rather than inside it: a scroll view lays
        // out its own subviews and ignores constraints on extra ones.
        let container = NSView()
        for subview in [scrollView, emptyStateView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(subview)
            NSLayoutConstraint.activate([
                subview.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                subview.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                subview.topAnchor.constraint(equalTo: container.topAnchor),
                subview.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }
        // Content may already be loaded: the list is filled before its view is.
        emptyStateView.isHidden = location == nil || !articles.isEmpty
        emptyStateView.sizingOptions = []
        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        dataObserver = ChangeObserver { [weak self] in
            _ = self?.feedManager.dataRevision
        } onChange: { [weak self] in
            self?.scheduleDataReload()
        }
        readStateObserver = ChangeObserver { [weak self] in
            _ = self?.feedManager.readMaskRevision
        } onChange: { [weak self] in
            self?.reloadVisibleRows()
        }
    }

    func show(_ location: BrowserLocation) {
        guard location != self.location else { return }
        self.location = location
        reloadArticles(keepingSelection: false)
        tableView.scrollRowToVisible(0)
    }

    /// Selecting content marks it read, which bumps `dataRevision`; coalescing keeps
    /// arrowing through the list from re-running the query on every row.
    private func scheduleDataReload() {
        pendingDataReload?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.reloadArticles(keepingSelection: true)
        }
        pendingDataReload = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func reloadArticles(keepingSelection: Bool) {
        guard let location else { return }
        pendingDataReload?.cancel()
        let selectedID = keepingSelection ? selectedArticle?.id : nil
        let reloaded = ContentQuery(feedManager: feedManager).articles(for: location)
        let style = ContentStyleContext(location: location, articles: reloaded, feedManager: feedManager)?
            .effectiveStyle ?? .inbox
        let keepsRows = keepingSelection && style == displayStyle && reloaded.map(\.id) == articles.map(\.id)
        articles = reloaded
        displayStyle = style
        if keepsRows {
            reloadVisibleRows()
            return
        }
        tableView.reloadData()
        emptyStateView.isHidden = !articles.isEmpty
        if let selectedID, let row = articles.firstIndex(where: { $0.id == selectedID }) {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        } else if !keepingSelection {
            reportedArticleID = nil
            onSelectArticle?(nil)
        }
    }

    /// Re-reads the page's style after it's been changed from a menu.
    func reloadStyle() {
        reloadArticles(keepingSelection: true)
    }

    /// Rows scrolled out of view are configured afresh when they come back.
    private func reloadVisibleRows() {
        let visibleRows = tableView.rows(in: tableView.visibleRect)
        guard visibleRows.length > 0 else { return }
        tableView.reloadData(
            forRowIndexes: IndexSet(integersIn: visibleRows.location..<NSMaxRange(visibleRows)),
            columnIndexes: IndexSet(integer: 0)
        )
    }

    var selectedArticle: Article? {
        articles.indices.contains(tableView.selectedRow) ? articles[tableView.selectedRow] : nil
    }
}
