import AppIntents
import Foundation

struct BookmarkQuery: EntityQuery {

    func entities(for identifiers: [BookmarkEntity.ID]) async throws -> [BookmarkEntity] {
        let database = DatabaseManager.shared
        let articleIDs = identifiers.compactMap { Int64($0) }
        guard !articleIDs.isEmpty else { return [] }
        let results = (try? database.articles(withIDs: articleIDs)) ?? []
        return results
            .filter(\.isBookmarked)
            .map { article in
                BookmarkEntity(article: article, feedTitle: feedTitle(forFeedID: article.feedID))
            }
    }

    func suggestedEntities() async throws -> [BookmarkEntity] {
        let database = DatabaseManager.shared
        let results = (try? database.bookmarkedArticles()) ?? []
        return results.prefix(50).map { article in
            BookmarkEntity(article: article, feedTitle: feedTitle(forFeedID: article.feedID))
        }
    }

    private func feedTitle(forFeedID feedID: Int64) -> String? {
        try? DatabaseManager.shared.feed(byID: feedID)?.title
    }
}
