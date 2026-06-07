import SwiftUI
import Hanami

@MainActor
enum HomeRefreshScope {

    static func key(for selection: HomeSelection) -> String {
        switch selection {
        case .section(.today):
            return "section.today"
        case .section(let section):
            if let feedSection = section.feedSection {
                return "section.\(feedSection.rawValue)"
            }
            return "section.all"
        case .list(let id):
            return "list.\(id)"
        case .topic(let name):
            return "topic.\(name)"
        }
    }

    static func activeKey(feedManager: FeedManager, selection: HomeSelection) -> String? {
        let scopeKey = key(for: selection)
        if feedManager.scopedRefreshes[scopeKey]?.hasActiveProgress == true {
            return scopeKey
        }
        return feedManager.scopedRefreshes.first { $0.value.hasActiveProgress }?.key
    }

    static func state(feedManager: FeedManager, selection: HomeSelection) -> ScopedRefreshState {
        if let scopeKey = activeKey(feedManager: feedManager, selection: selection),
           let scoped = feedManager.scopedRefreshes[scopeKey] {
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

    static func cancel(
        feedManager: FeedManager,
        todayManager: TodayManager,
        selection: HomeSelection,
        loadEntities: Bool
    ) {
        if let scope = activeKey(feedManager: feedManager, selection: selection) {
            feedManager.cancelScopedRefresh(scope: scope)
        } else {
            feedManager.cancelRefresh()
        }
        todayManager.load(
            feeds: feedManager.feeds,
            dataRevision: feedManager.dataRevision,
            loadEntities: loadEntities
        )
    }
}
