import AppKit
import Hanami

final class BrowserSplitViewController: NSSplitViewController {

    let feedManager: FeedManager
    let sidebarViewController: SidebarViewController
    private(set) var detailViewController: BrowserDetailViewController!
    var onOpenLocation: ((BrowserLocation) -> Void)?
    var onOpenLocationInNewTab: ((BrowserLocation) -> Void)?
    var onReaderArticleChange: ((Article?) -> Void)?

    init(feedManager: FeedManager, activity: BrowserPageActivity, revisions: WindowDataRevisions) {
        self.feedManager = feedManager
        sidebarViewController = SidebarViewController(feedManager: feedManager, revisions: revisions)
        super.init(nibName: nil, bundle: nil)
        let actions = TodayActions(
            open: { [weak self] location in self?.onOpenLocation?(location) },
            openInNewTab: { [weak self] location in self?.onOpenLocationInNewTab?(location) }
        )
        detailViewController = BrowserDetailViewController(
            feedManager: feedManager,
            activity: activity,
            actions: actions,
            revisions: revisions
        )
        let contentList = detailViewController.contentSplitViewController.contentListViewController
        contentList.onOpenInNewTab = actions.openInNewTab
        contentList.onOpenFullWidth = actions.open
        detailViewController.contentSplitViewController.onReaderArticleChange = { [weak self] article in
            self?.onReaderArticleChange?(article)
        }
        sidebarViewController.onOpenInNewTab = actions.openInNewTab
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 360
        sidebarItem.canCollapse = true
        let detailItem = NSSplitViewItem(viewController: detailViewController)
        detailItem.minimumThickness = 640
        addSplitViewItem(sidebarItem)
        addSplitViewItem(detailItem)
        splitView.autosaveName = "BrowserSplitView"
    }

    func show(_ location: BrowserLocation) {
        sidebarViewController.select(location)
        detailViewController.show(location)
    }
}
