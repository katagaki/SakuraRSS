import Foundation

/// What Content Insights shows under a piece of content: the topics and
/// people it mentions, and similar content from the past week. Everything
/// runs off the main actor and caches its results in the database.
public nonisolated enum ContentInsights {

    public struct SimilarContent: Sendable {
        public let article: Article
        public let feedName: String
        public let feed: Feed?
        public let sentiment: Double?
    }

    public static func entities(for article: Article) async -> (topics: [String], people: [String]) {
        let database = DatabaseManager.shared
        return await Task.detached(priority: .userInitiated) {
            processEntitiesIfNeeded(for: article, database: database)
            guard let rows = try? database.entities(forArticleID: article.id) else {
                return (topics: [String](), people: [String]())
            }
            var topics: [String] = []
            var people: [String] = []
            var seenTopics = Set<String>()
            var seenPeople = Set<String>()
            for row in rows {
                let key = row.name.lowercased()
                switch row.type {
                case "person":
                    if seenPeople.insert(key).inserted { people.append(row.name) }
                case "organization", "place":
                    if seenTopics.insert(key).inserted { topics.append(row.name) }
                default:
                    break
                }
            }
            return (topics: topics, people: people)
        }.value
    }

    /// Ordered by hybrid similarity score.
    public static func similarContent(to article: Article, feedsLookup: [Int64: Feed]) async -> [SimilarContent] {
        await Task.detached(priority: .userInitiated) {
            await computeSimilarContent(to: article, feedsLookup: feedsLookup)
        }.value
    }

    public static func processSentimentIfNeeded(for article: Article) {
        let database = DatabaseManager.shared
        guard (try? database.isSentimentProcessed(articleId: article.id)) != true else { return }
        if let score = NLPProcessor.sentimentScore(for: sourceText(of: article)) {
            try? database.updateSentimentScore(score, for: article.id)
        }
        try? database.markSentimentProcessed(articleId: article.id)
    }

    private static func computeSimilarContent(
        to article: Article,
        feedsLookup: [Int64: Feed]
    ) async -> [SimilarContent] {
        let database = DatabaseManager.shared
        if (try? database.isSimilarComputed(articleId: article.id)) == true {
            // An empty cache means it was computed earlier with no matches.
            let cachedIDs = (try? database.cachedSimilarArticleIDs(forSourceID: article.id))?.map(\.id) ?? []
            return similarContent(withIDs: cachedIDs, feedsLookup: feedsLookup, database: database)
        }
        guard let candidates = try? database.articlesInWindow(around: article, hours: 168, limit: 82),
              !candidates.isEmpty else {
            try? database.cacheSimilarArticles([], forSourceID: article.id)
            return []
        }
        processEntitiesIfNeeded(for: article, database: database)
        let sourceEntities: Set<String> = (try? database.entities(forArticleID: article.id))
            .map { Set($0.map { $0.name.lowercased() }) } ?? []
        let entityMap = (try? database.entities(forArticleIDs: candidates.map(\.id))) ?? [:]
        let pairs = candidates.map { candidate in
            (article: candidate, entities: entityMap[candidate.id] ?? [])
        }
        let similar = await NLPProcessor.findSimilarArticlesHybrid(
            to: article,
            sourceEntities: sourceEntities,
            candidates: pairs,
            maxResults: 8,
            minimumScore: 0.35
        )
        // Persist `1 - score` as distance so lower-is-better matches the cache reader.
        try? database.cacheSimilarArticles(
            similar.map { (id: $0.articleID, distance: 1.0 - $0.score) },
            forSourceID: article.id
        )
        return similarContent(withIDs: similar.map(\.articleID), feedsLookup: feedsLookup, database: database)
    }

    private static func similarContent(
        withIDs articleIDs: [Int64],
        feedsLookup: [Int64: Feed],
        database: DatabaseManager
    ) -> [SimilarContent] {
        articleIDs.compactMap { articleID in
            guard let match = try? database.article(byID: articleID) else { return nil }
            let feed = feedsLookup[match.feedID]
            return SimilarContent(
                article: match,
                feedName: feed?.title ?? "",
                feed: feed,
                sentiment: try? database.sentimentScore(for: articleID)
            )
        }
    }

    private static func processEntitiesIfNeeded(for article: Article, database: DatabaseManager) {
        guard (try? database.isEntitiesProcessed(articleId: article.id)) != true else { return }
        let extracted = NLPProcessor.extractEntities(from: sourceText(of: article))
        if !extracted.isEmpty {
            try? database.insertEntities(extracted.map { (name: $0.name, type: $0.type) }, for: article.id)
        }
        try? database.markEntitiesProcessed(articleId: article.id)
    }

    private static func sourceText(of article: Article) -> String {
        [article.title, article.summary ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
