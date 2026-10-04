import Foundation
import Hanami
import Observation

@Observable
final class TodayModel {

    private(set) var bookmarkedArticles: [Article] = []
    private(set) var recentArticles: [Article] = []
    private(set) var podcastEpisodes: [Article] = []
    private(set) var videoEpisodes: [Article] = []
    private(set) var hasLoaded = false

    var isEmpty: Bool {
        bookmarkedArticles.isEmpty && recentArticles.isEmpty && podcastEpisodes.isEmpty && videoEpisodes.isEmpty
    }

    func load(feeds: [Feed]) async {
        let podcastFeedIDs = feeds.filter(\.isPodcast).map(\.id)
        let videoFeedIDs = feeds.filter { $0.isYouTubeFeed || $0.isVimeoFeed }.map(\.id)
        let loaded = await Task.detached {
            let database = DatabaseManager.shared
            return (
                bookmarks: (try? database.bookmarkedArticles(limit: 20)) ?? [],
                recents: (try? database.recentlyAccessedArticles()) ?? [],
                podcasts: (try? database.articles(forFeedIDs: podcastFeedIDs, limit: 20, requireUnread: true)) ?? [],
                videos: (try? database.articles(forFeedIDs: videoFeedIDs, limit: 20, requireUnread: true)) ?? []
            )
        }.value
        guard !Task.isCancelled else { return }
        bookmarkedArticles = loaded.bookmarks
        recentArticles = loaded.recents
        podcastEpisodes = loaded.podcasts
        videoEpisodes = loaded.videos
        hasLoaded = true
    }
}
