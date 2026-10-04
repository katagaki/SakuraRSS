import AppKit
import Hanami
import SwiftUI

/// The content list beside its reader, for every location that lists content.
final class ContentSplitViewController: NSSplitViewController {

    let feedManager: FeedManager
    let activity: BrowserPageActivity
    let contentListViewController: ContentListViewController
    private let readerViewController: NSHostingController<ReaderPane>

    init(feedManager: FeedManager, activity: BrowserPageActivity) {
        self.feedManager = feedManager
        self.activity = activity
        contentListViewController = ContentListViewController(feedManager: feedManager)
        readerViewController = NSHostingController(
            rootView: ReaderPane(article: nil, feed: nil, activity: activity, feedManager: feedManager)
        )
        // Left on, the hosting controller resizes the window to fit whatever the
        // reader shows, shrinking it to the height of the empty state.
        readerViewController.sizingOptions = []
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let listItem = NSSplitViewItem(contentListWithViewController: contentListViewController)
        listItem.minimumThickness = 280
        listItem.maximumThickness = 520
        let readerItem = NSSplitViewItem(viewController: readerViewController)
        readerItem.minimumThickness = 360
        addSplitViewItem(listItem)
        addSplitViewItem(readerItem)
        splitView.autosaveName = "ContentSplitView"
        contentListViewController.onSelectArticle = { [weak self] article in
            self?.showReader(for: article)
        }
    }

    func show(_ location: BrowserLocation) {
        contentListViewController.show(location)
    }

    private func showReader(for article: Article?) {
        readerViewController.rootView = ReaderPane(
            article: article,
            feed: article.flatMap { feedManager.feedsByID[$0.feedID] },
            activity: activity,
            feedManager: feedManager
        )
    }
}
