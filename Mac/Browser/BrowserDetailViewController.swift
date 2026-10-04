import AppKit
import Hanami
import SwiftUI

/// Swaps the area beside the sidebar between Today, a content list with its
/// reader, and a single piece of content opened on its own.
final class BrowserDetailViewController: NSViewController {

    let feedManager: FeedManager
    let activity: BrowserPageActivity
    let contentSplitViewController: ContentSplitViewController
    private let todayViewController: TodaySplitViewController
    private let articleViewController: NSHostingController<ReaderPane>

    init(feedManager: FeedManager, activity: BrowserPageActivity, actions: TodayActions) {
        self.feedManager = feedManager
        self.activity = activity
        contentSplitViewController = ContentSplitViewController(feedManager: feedManager, activity: activity)
        todayViewController = TodaySplitViewController(feedManager: feedManager, actions: actions)
        articleViewController = NSHostingController(
            rootView: ReaderPane(article: nil, feed: nil, activity: activity, feedManager: feedManager)
        )
        articleViewController.sizingOptions = []
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = NSView()
    }

    func show(_ location: BrowserLocation) {
        switch location {
        case .startPage:
            display(todayViewController)
        case .article(let articleID):
            let article = feedManager.article(byID: articleID)
            if let article {
                feedManager.markRead(article)
            }
            articleViewController.rootView = ReaderPane(
                article: article,
                feed: article.flatMap { feedManager.feedsByID[$0.feedID] },
                activity: activity,
                feedManager: feedManager
            )
            display(articleViewController)
        default:
            contentSplitViewController.show(location)
            display(contentSplitViewController)
        }
    }

    private func display(_ child: NSViewController) {
        guard child.parent !== self else { return }
        for existing in children {
            existing.view.removeFromSuperview()
            existing.removeFromParent()
        }
        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(child.view)
        // Below the toolbar rather than under it, so the list's divider and
        // rows don't run up behind the toolbar's glass.
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}
