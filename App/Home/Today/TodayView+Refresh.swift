import SwiftUI
import Hanami

extension TodayView {

    // MARK: - Refresh

    var scopedRefreshState: ScopedRefreshState {
        feedManager.scopedRefreshes["section.today"] ?? ScopedRefreshState()
    }

    func startRefreshWithoutBlocking() {
        guard !scopedRefreshState.hasActiveProgress,
              !feedManager.hasActiveRefreshProgress else { return }
        feedManager.flushDebouncedReads()
        let feeds = feedManager.feeds
        let loadEntities = contentInsightsEnabled
        Task { @MainActor in
            await feedManager.refreshFeeds(scope: "section.today", feeds: feeds, runNLP: loadEntities)
            todayManager.load(
                feeds: feedManager.feeds,
                dataRevision: feedManager.dataRevision,
                loadEntities: loadEntities
            )
        }
    }

    // MARK: - Data

    /// Re-filters TodayManager's pre-fetched unread lists with the live read state so
    /// items mark-read'd in this session disappear without waiting for a full reload.
    var visibleEpisodes: TodayVisibleEpisodes {
        TodayVisibleEpisodes(
            podcasts: todayManager.unreadPodcastEpisodes.filter { !feedManager.isRead($0) },
            videos: todayManager.unreadVideoEpisodes.filter { !feedManager.isRead($0) }
        )
    }
}
