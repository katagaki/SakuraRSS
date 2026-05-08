import Foundation
import SwiftUI

/// Owns the data shown by `TodayView`
@Observable
final class TodayManager {

    private(set) var entitySections: [DiscoverEntitySection] = []
    private(set) var allTopics: [(name: String, count: Int)] = []
    private(set) var allPeople: [(name: String, count: Int)] = []
    private(set) var bookmarkedArticles: [Article] = []
    private(set) var recentArticles: [Article] = []
    private(set) var unreadPodcastEpisodes: [Article] = []
    private(set) var unreadVideoEpisodes: [Article] = []
    private(set) var hasLoadedInitially: Bool = false

    private var lastLoadedRevision: Int = -1
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    /// Reloads only if the feed manager's data revision has advanced since
    /// the last successful load, or if no load has ever completed.
    @MainActor
    func loadIfStale(feeds: [Feed], dataRevision: Int, loadEntities: Bool) {
        guard !hasLoadedInitially || dataRevision != lastLoadedRevision else { return }
        load(feeds: feeds, dataRevision: dataRevision, loadEntities: loadEntities)
    }

    /// Forces a reload regardless of the data revision (e.g. pull-to-refresh).
    @MainActor
    func load(feeds: [Feed], dataRevision: Int, loadEntities: Bool) {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.performLoad(
                feeds: feeds,
                dataRevision: dataRevision,
                loadEntities: loadEntities
            )
        }
    }

    private nonisolated func performLoad(
        feeds: [Feed],
        dataRevision: Int,
        loadEntities: Bool
    ) async {
        let database = DatabaseManager.shared
        let articles = loadArticles(database: database, feeds: feeds)
        let entityData = loadEntities ? Self.loadEntityData(database: database) : .empty

        await MainActor.run {
            applyLoadedData(
                articles: articles,
                entityData: entityData,
                dataRevision: dataRevision
            )
        }
    }

    private nonisolated func loadArticles(
        database: DatabaseManager, feeds: [Feed]
    ) -> TodayArticleData {
        let podcastFeedIDs = feeds.filter { $0.isPodcast }.map { $0.id }
        let videoFeedIDs = feeds
            .filter { $0.isYouTubeFeed || $0.isVimeoFeed }
            .map { $0.id }
        return TodayArticleData(
            recent: (try? database.recentlyAccessedArticles()) ?? [],
            bookmarks: (try? database.bookmarkedArticles()) ?? [],
            podcastEpisodes: (try? database.articles(
                forFeedIDs: podcastFeedIDs,
                limit: 20,
                requireUnread: true
            )) ?? [],
            videoEpisodes: (try? database.articles(
                forFeedIDs: videoFeedIDs,
                limit: 20,
                requireUnread: true
            )) ?? []
        )
    }

    private nonisolated static func loadEntityData(database: DatabaseManager) -> DiscoverEntityData {
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        let topTopics = (try? database.topEntities(
            types: ["organization", "place"],
            since: sevenDaysAgo,
            limit: 50
        )) ?? []
        let topPeople = (try? database.topEntities(
            type: "person",
            since: sevenDaysAgo,
            limit: 50
        )) ?? []

        var sectionItems: [DiscoverEntitySection] = []
        for topic in topTopics.prefix(3) {
            let articles = (try? database.articlesForEntity(
                name: topic.name,
                types: ["organization", "place"],
                limit: 10
            )) ?? []
            if !articles.isEmpty {
                sectionItems.append(DiscoverEntitySection(
                    name: topic.name,
                    types: ["organization", "place"],
                    articles: articles
                ))
            }
        }
        return DiscoverEntityData(sections: sectionItems, topics: topTopics, people: topPeople)
    }

    @MainActor
    private func applyLoadedData(
        articles: TodayArticleData,
        entityData: DiscoverEntityData,
        dataRevision: Int
    ) {
        withAnimation(.smooth.speed(2.0)) {
            recentArticles = articles.recent
            bookmarkedArticles = articles.bookmarks
            unreadPodcastEpisodes = articles.podcastEpisodes
            unreadVideoEpisodes = articles.videoEpisodes
            entitySections = entityData.sections
            allTopics = entityData.topics
            allPeople = entityData.people
            hasLoadedInitially = true
            lastLoadedRevision = dataRevision
        }
    }
}

private struct TodayArticleData {
    let recent: [Article]
    let bookmarks: [Article]
    let podcastEpisodes: [Article]
    let videoEpisodes: [Article]
}
