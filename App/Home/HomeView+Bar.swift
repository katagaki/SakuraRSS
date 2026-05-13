import SwiftUI
import Hanami

extension HomeView {

    func performMarkAllRead() {
        switch selectedSelection {
        case .section(let section):
            if let feedSection = section.feedSection {
                feedManager.markAllRead(for: feedSection)
            } else {
                feedManager.markAllRead()
            }
        case .list(let id):
            if let list = feedManager.lists.first(where: { $0.id == id }) {
                feedManager.markAllRead(for: list)
            }
        case .topic(let name):
            let entries = feedManager.preloadedArticleEntries(forTopic: name)
            let articles = feedManager.articles(withPreloadedIDs: entries.map(\.id))
            for article in articles where !feedManager.isRead(article) {
                feedManager.markRead(article)
            }
        }
    }

    var availableSections: [HomeSection] {
        HomeSection.allCases.filter { section in
            guard let feedSection = section.feedSection else { return true }
            return feedManager.hasFeeds(for: feedSection)
        }
    }

    var tabItems: [HomeSectionBarItem] {
        HomeSectionBarItem.items(
            sections: availableSections,
            lists: feedManager.lists,
            topics: topTopics,
            configuration: barConfiguration
        )
    }

    var isTodaySelected: Bool {
        if case .section(.today) = selectedSelection { return true }
        return false
    }

    /// Surfaces the refresh that the toolbar donut should display. Only fires
    /// for the app startup preload (non-scoped global refresh), which has no
    /// per-section donut anywhere, and for Today's pull-to-refresh, which
    /// uses the `section.all` scope but is rendered by `TodayView` and so
    /// has no section-level donut of its own. Section pull-to-refreshes are
    /// surfaced by `HomeSectionView` instead.
    var homeRefreshState: ScopedRefreshState {
        if isTodaySelected,
           let scoped = feedManager.scopedRefreshes["section.all"],
           scoped.hasActiveProgress {
            return scoped
        }
        if feedManager.hasActiveRefreshProgress {
            return ScopedRefreshState(
                total: feedManager.refreshTotal,
                completed: feedManager.refreshCompleted,
                refreshingFeedIDs: feedManager.refreshingFeedIDs,
                pendingFeedIDs: feedManager.pendingRefreshFeedIDs,
                isStopping: feedManager.isStopping
            )
        }
        return ScopedRefreshState()
    }

    /// Cancels the refresh tracked by `homeRefreshState` and forces Today's
    /// data to reload alongside the database revision bump driven by the
    /// underlying cancel calls, so neither Today summaries nor section
    /// preloaded entries are left stale.
    func cancelHomeRefresh() {
        if isTodaySelected, feedManager.scopedRefreshes["section.all"] != nil {
            feedManager.cancelScopedRefresh(scope: "section.all")
        } else {
            feedManager.cancelRefresh()
        }
        todayManager.load(
            feeds: feedManager.feeds,
            dataRevision: feedManager.dataRevision,
            loadEntities: contentInsightsEnabled
        )
    }

    func reloadBarConfiguration() {
        barConfiguration = .load()
    }

    func loadTopTopicsIfNeeded() async {
        guard barConfiguration.enabledItems.contains(.topics) else {
            topTopics = []
            validateTopicSelection()
            return
        }
        let limit = barConfiguration.topicCount.rawValue
        let database = DatabaseManager.shared
        let topics: [String] = await Task.detached {
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
            let results = (try? database.topEntities(
                types: ["organization", "place"],
                since: sevenDaysAgo,
                limit: limit
            )) ?? []
            return results.map(\.name)
        }.value
        topTopics = topics
        validateTopicSelection()
    }

    func validateTopicSelection() {
        if case .topic(let name) = selectedSelection, !topTopics.contains(name) {
            selectedSelection = .section(.all)
        }
    }

    func validateBarSelection() {
        let items = tabItems
        guard !items.isEmpty else { return }
        if !items.contains(where: { $0.matches(selectedSelection) }),
           let first = items.first {
            selectedSelection = first.selection
        }
    }
}
