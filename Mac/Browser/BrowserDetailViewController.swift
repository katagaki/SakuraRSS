import AppKit
import Hanami
import SwiftUI

/// Swaps the area beside the sidebar between Today, a content list with its
/// reader, and a single piece of content opened on its own.
final class BrowserDetailViewController: NSViewController {

    let feedManager: FeedManager
    let activity: BrowserPageActivity
    private let actions: TodayActions
    private let revisions: WindowDataRevisions
    let contentSplitViewController: ContentSplitViewController
    private let todayViewController: TodaySplitViewController
    private let articleViewController: NSHostingController<ReaderPane>
    private let gridViewController: NSHostingController<ContentGridPage>
    private let topicsViewController: NSHostingController<TopicsPage>

    init(
        feedManager: FeedManager,
        activity: BrowserPageActivity,
        actions: TodayActions,
        revisions: WindowDataRevisions
    ) {
        self.feedManager = feedManager
        self.activity = activity
        self.revisions = revisions
        contentSplitViewController = ContentSplitViewController(
            feedManager: feedManager, activity: activity, revisions: revisions
        )
        todayViewController = TodaySplitViewController(feedManager: feedManager, actions: actions, revisions: revisions)
        gridViewController = NSHostingController(rootView: ContentGridPage(
            location: .allContent, style: .magazine, feedManager: feedManager, actions: actions, revisions: revisions
        ))
        gridViewController.sizingOptions = []
        topicsViewController = NSHostingController(rootView: TopicsPage(
            feedManager: feedManager, actions: actions, revisions: revisions
        ))
        topicsViewController.sizingOptions = []
        self.actions = actions
        contentSplitViewController.actions = actions
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
        case .topics:
            display(topicsViewController)
        case .article(let articleID):
            let article = feedManager.article(byID: articleID)
            if let article {
                feedManager.markRead(article)
            }
            articleViewController.rootView = ReaderPane(
                article: article,
                feed: article.flatMap { feedManager.feedsByID[$0.feedID] },
                activity: activity,
                feedManager: feedManager,
                actions: actions
            )
            display(articleViewController)
        default:
            showContent(at: location)
        }
    }

    /// After a style change, so the list re-reads its style or the page swaps
    /// between the list and a grid.
    func reloadStyle(at location: BrowserLocation) {
        contentSplitViewController.contentListViewController.reloadStyle()
        showContent(at: location)
    }

    private func showContent(at location: BrowserLocation) {
        let articles = ContentQuery(feedManager: feedManager).articles(for: location)
        let style = ContentStyleContext(location: location, articles: articles, feedManager: feedManager)?
            .effectiveStyle ?? .inbox
        if style.isListStyle {
            contentSplitViewController.show(location)
            display(contentSplitViewController)
        } else {
            gridViewController.rootView = ContentGridPage(
                location: location, style: style, feedManager: feedManager, actions: actions, revisions: revisions
            )
            display(gridViewController)
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
