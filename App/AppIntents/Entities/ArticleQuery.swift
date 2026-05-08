import AppIntents
import Foundation

struct ArticleQuery: EntityStringQuery {

    func entities(for identifiers: [ArticleEntity.ID]) async throws -> [ArticleEntity] {
        let database = DatabaseManager.shared
        let articleIDs = identifiers.compactMap { Int64($0) }
        guard !articleIDs.isEmpty else { return [] }
        let results = (try? database.articles(withIDs: articleIDs)) ?? []
        return results.map { article in
            ArticleEntity(article: article, feedTitle: feedTitle(forFeedID: article.feedID))
        }
    }

    func entities(matching string: String) async throws -> [ArticleEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try await suggestedEntities() }
        let database = DatabaseManager.shared
        let results = (try? database.searchArticles(query: trimmed)) ?? []
        return results.prefix(50).map { article in
            ArticleEntity(article: article, feedTitle: feedTitle(forFeedID: article.feedID))
        }
    }

    func suggestedEntities() async throws -> [ArticleEntity] {
        let database = DatabaseManager.shared
        let results = (try? database.allArticles(limit: 50)) ?? []
        return results.map { article in
            ArticleEntity(article: article, feedTitle: feedTitle(forFeedID: article.feedID))
        }
    }

    private func feedTitle(forFeedID feedID: Int64) -> String? {
        try? DatabaseManager.shared.feed(byID: feedID)?.title
    }
}
