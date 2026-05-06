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

    // swiftlint:disable:next function_body_length
    private nonisolated func performLoad(
        feeds: [Feed],
        dataRevision: Int,
        loadEntities: Bool
    ) async {
        let database = DatabaseManager.shared
        let podcastFeedIDs = feeds.filter { $0.isPodcast }.map { $0.id }
        let videoFeedIDs = feeds
            .filter { $0.isYouTubeFeed || $0.isVimeoFeed }
            .map { $0.id }

        let recent = (try? database.recentlyAccessedArticles()) ?? []
        let bookmarks = (try? database.bookmarkedArticles()) ?? []
        let podcastEpisodes = (try? database.articles(
            forFeedIDs: podcastFeedIDs,
            limit: 20,
            requireUnread: true
        )) ?? []
        let videoEpisodes = (try? database.articles(
            forFeedIDs: videoFeedIDs,
            limit: 20,
            requireUnread: true
        )) ?? []

        var sections: [DiscoverEntitySection] = []
        var topics: [(name: String, count: Int)] = []
        var people: [(name: String, count: Int)] = []

        if loadEntities {
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

            topics = topTopics
            people = topPeople

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

            sections = sectionItems
        }

        await MainActor.run {
            withAnimation(.smooth.speed(2.0)) {
                recentArticles = recent
                bookmarkedArticles = bookmarks
                unreadPodcastEpisodes = podcastEpisodes
                unreadVideoEpisodes = videoEpisodes
                entitySections = sections
                allTopics = topics
                allPeople = people
                hasLoadedInitially = true
                lastLoadedRevision = dataRevision
            }
        }
    }
}
