import AppKit
import Hanami

final class ContentListViewController: NSViewController {

    let feedManager: FeedManager
    let tableView = NSTableView()
    var articles: [Article] = []
    var onSelectArticle: ((Article?) -> Void)?
    var reportedArticleID: Int64?
    var onOpenInNewTab: ((BrowserLocation) -> Void)?
    private var location: BrowserLocation?
    private var dataObserver: ChangeObserver?
    private var readStateObserver: ChangeObserver?
    private let emptyLabel = NSTextField(labelWithString: String(localized: "Empty.Title", table: "Articles"))

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
        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        emptyLabel.font = .preferredFont(forTextStyle: .title3)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])
        view = scrollView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        dataObserver = ChangeObserver { [weak self] in
            _ = self?.feedManager.dataRevision
        } onChange: { [weak self] in
            self?.reloadArticles(keepingSelection: true)
        }
        readStateObserver = ChangeObserver { [weak self] in
            _ = self?.feedManager.readMaskRevision
        } onChange: { [weak self] in
            guard let self else { return }
            self.tableView.reloadData(
                forRowIndexes: IndexSet(integersIn: 0..<self.articles.count),
                columnIndexes: IndexSet(integer: 0)
            )
        }
    }

    func show(_ location: BrowserLocation) {
        guard location != self.location else { return }
        self.location = location
        reloadArticles(keepingSelection: false)
        tableView.scrollRowToVisible(0)
    }

    private func reloadArticles(keepingSelection: Bool) {
        guard let location else { return }
        let selectedID = keepingSelection ? selectedArticle?.id : nil
        articles = ContentQuery(feedManager: feedManager).articles(for: location)
        tableView.reloadData()
        emptyLabel.isHidden = !articles.isEmpty
        if let selectedID, let row = articles.firstIndex(where: { $0.id == selectedID }) {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        } else if !keepingSelection {
            reportedArticleID = nil
            onSelectArticle?(nil)
        }
    }

    var selectedArticle: Article? {
        articles.indices.contains(tableView.selectedRow) ? articles[tableView.selectedRow] : nil
    }
}
