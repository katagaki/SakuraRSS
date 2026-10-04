import AppKit
import Hanami
import SwiftUI

final class BrowserSplitViewController: NSSplitViewController {

    let feedManager: FeedManager
    let sidebarViewController: SidebarViewController
    let contentListViewController: ContentListViewController
    private let readerViewController: NSHostingController<ReaderPane>

    init(feedManager: FeedManager) {
        self.feedManager = feedManager
        sidebarViewController = SidebarViewController(feedManager: feedManager)
        contentListViewController = ContentListViewController(feedManager: feedManager)
        readerViewController = NSHostingController(rootView: ReaderPane(article: nil, feed: nil))
        super.init(nibName: nil, bundle: nil)
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
        let listItem = NSSplitViewItem(contentListWithViewController: contentListViewController)
        listItem.minimumThickness = 280
        listItem.maximumThickness = 520
        let readerItem = NSSplitViewItem(viewController: readerViewController)
        readerItem.minimumThickness = 360
        addSplitViewItem(sidebarItem)
        addSplitViewItem(listItem)
        addSplitViewItem(readerItem)
        splitView.autosaveName = "BrowserSplitView.Reader"
        contentListViewController.onSelectArticle = { [weak self] article in
            self?.showReader(for: article)
        }
    }

    func show(_ location: BrowserLocation) {
        sidebarViewController.select(location)
        contentListViewController.show(location)
    }

    private func showReader(for article: Article?) {
        readerViewController.rootView = ReaderPane(
            article: article,
            feed: article.flatMap { feedManager.feedsByID[$0.feedID] }
        )
    }
}
