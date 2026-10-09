import AppKit
import Hanami
import SwiftUI

final class ContentListViewController: NSViewController {

    let feedManager: FeedManager
    let revisions: WindowDataRevisions
    let tableView = ContentListTableView()
    /// What the page lists, after the Browsing settings have been applied.
    var articles: [Article] = []
    /// Everything the page's query returned.
    var allArticles: [Article] = []
    var presentation = ContentPresentation()
    let bookmarkBrowsing = BookmarkBrowsing()
    lazy var bookmarkBar = NSHostingView(rootView: BookmarkBrowsingBar(
        browsing: bookmarkBrowsing,
        showsScope: false,
        onExport: { [weak self] in self?.exportBookmarks() },
        onRemoveReadBookmarks: { [weak self] in self?.confirmRemovingReadBookmarks() }
    ))
    var bookmarkBrowsingObserver: ChangeObserver?
    var firstVisibleRow = 0
    nonisolated(unsafe) var scrollObserver: NSObjectProtocol?
    nonisolated(unsafe) var settingsObserver: NSObjectProtocol?
    nonisolated(unsafe) var pagePreferencesObserver: NSObjectProtocol?
    var onSelectArticle: ((Article?) -> Void)?
    var reportedArticleID: Int64?
    private(set) var displayStyle: FeedDisplayStyle = .inbox
    var onOpenInNewTab: ((BrowserLocation) -> Void)?
    var onOpenFullWidth: ((BrowserLocation) -> Void)?
    private(set) var location: BrowserLocation?
    private var dataObserver: ChangeObserver?
    private var readStateObserver: ChangeObserver?
    private var pendingDataReload: DispatchWorkItem?
    private var needsDataUpdate = false
    private var needsReadStateUpdate = false
    private let emptyStateView = NSHostingView(rootView: ContentEmptyStateView())

    init(feedManager: FeedManager, revisions: WindowDataRevisions) {
        self.feedManager = feedManager
        self.revisions = revisions
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        for observer in [scrollObserver, settingsObserver, pagePreferencesObserver].compactMap(\.self) {
            NotificationCenter.default.removeObserver(observer)
        }
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
        let stack = NSStackView(views: [bookmarkBar, scrollView])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.detachesHiddenViews = true
        bookmarkBar.isHidden = true
        for subview in [stack, emptyStateView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            bookmarkBar.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            emptyStateView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        ])
        // Content may already be loaded: the list is filled before its view is.
        emptyStateView.isHidden = location == nil || !articles.isEmpty
        emptyStateView.sizingOptions = []
        view = container
        observeScrolling(of: scrollView)
        observePresentationSettings()
        observeBookmarkBrowsing()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        dataObserver = ChangeObserver { [weak self] in
            _ = self?.revisions.dataRevision
        } onChange: { [weak self] in
            self?.dataDidChange()
        }
        readStateObserver = ChangeObserver { [weak self] in
            _ = self?.revisions.readStateRevision
        } onChange: { [weak self] in
            self?.readStateDidChange()
        }
    }

    /// While another page is showing in its place, changes wait for it to come back.
    override func viewDidAppear() {
        super.viewDidAppear()
        if needsDataUpdate {
            needsDataUpdate = false
            needsReadStateUpdate = false
            updateArticles()
        } else if needsReadStateUpdate {
            needsReadStateUpdate = false
            reloadVisibleRows()
        }
    }

    private func dataDidChange() {
        guard view.window != nil else {
            needsDataUpdate = true
            return
        }
        scheduleDataReload()
    }

    private func readStateDidChange() {
        guard view.window != nil else {
            needsReadStateUpdate = true
            return
        }
        reloadVisibleRows()
    }

    func show(_ location: BrowserLocation) {
        guard location != self.location else { return }
        self.location = location
        bookmarkBrowsing.searchText = ""
        showsBookmarkBar(for: location)
        reloadArticles(keepingSelection: false)
        tableView.scrollRowToVisible(0)
    }

    /// Selecting content marks it read, which bumps `dataRevision`; coalescing keeps
    /// arrowing through the list from re-running the query on every row.
    private func scheduleDataReload() {
        pendingDataReload?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.updateArticles()
        }
        pendingDataReload = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    /// Applies changed content as row insertions and removals, keeping the
    /// selection and the rows the reader is looking at where they are.
    func updateArticles() {
        guard let location else { return }
        pendingDataReload?.cancel()
        let reloaded = queriedArticles(for: location)
        let style = ContentStyleContext(location: location, articles: reloaded, feedManager: feedManager)?
            .effectiveStyle ?? .inbox
        guard style == displayStyle, !articles.isEmpty else {
            reloadArticles(keepingSelection: true)
            return
        }
        allArticles = reloaded
        presentation.absorb(reloaded, isRead: feedManager.isRead)
        applyRowChanges(to: presentation.present(reloaded))
        emptyStateView.isHidden = !articles.isEmpty
        reloadVisibleRows()
    }

    /// `keepingSelection` is false for a page that has just been opened, which
    /// also starts its Browsing settings over.
    func reloadArticles(keepingSelection: Bool) {
        guard let location else { return }
        pendingDataReload?.cancel()
        needsDataUpdate = false
        let selectedID = keepingSelection ? selectedArticle?.id : nil
        let reloaded = queriedArticles(for: location)
        let style = ContentStyleContext(location: location, articles: reloaded, feedManager: feedManager)?
            .effectiveStyle ?? .inbox
        if keepingSelection {
            presentation.absorb(reloaded, isRead: feedManager.isRead)
        } else {
            presentation.begin(
                with: reloaded,
                isRead: feedManager.isRead,
                settings: .current(for: location, in: feedManager)
            )
            firstVisibleRow = 0
        }
        allArticles = reloaded
        articles = presentation.present(reloaded)
        displayStyle = style
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
    func reloadVisibleRows() {
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
