import Foundation
import os

enum NLPProcessingCoordinator {

    #if DEBUG
    static let logger = Logger(subsystem: "com.tsubuzaki.SakuraRSS", category: "NLPCoordinator")
    #endif

    /// Processes unprocessed articles if any NLP feature is enabled.
    /// Called after feed refresh completes.
    static func processNewArticlesIfEnabled() async {
        let defaults = UserDefaults.standard
        let similarContentEnabled = defaults.bool(forKey: "Intelligence.SimilarContent.Enabled")
        let topicsPeopleEnabled = defaults.bool(forKey: "Intelligence.TopicsPeople.Enabled")
        guard similarContentEnabled || topicsPeopleEnabled else {
            #if DEBUG
            logger.debug("processNewArticlesIfEnabled: both features disabled, skipping")
            #endif
            return
        }

        let db = DatabaseManager.shared
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)

        #if DEBUG
        let startTime = Date()
        logger.debug("processNewArticlesIfEnabled: starting (similar=\(similarContentEnabled), topics=\(topicsPeopleEnabled))")
        #endif

        await Task.detached(priority: .utility) {
            var idsToProcess = Set<Int64>()
            if similarContentEnabled {
                if let ids = try? db.unprocessedSentimentArticleIDs(since: sevenDaysAgo, limit: 200) {
                    idsToProcess.formUnion(ids)
                }
            }
            if topicsPeopleEnabled {
                if let ids = try? db.unprocessedEntitiesArticleIDs(since: sevenDaysAgo, limit: 200) {
                    idsToProcess.formUnion(ids)
                }
            }

            #if DEBUG
            logger.debug("processNewArticlesIfEnabled: \(idsToProcess.count) articles to process")
            #endif

            let orderedIDs = Array(idsToProcess)
            for (index, id) in orderedIDs.enumerated() {
                guard let article = try? db.article(byID: id) else { continue }
                processArticleSync(article, similarContent: similarContentEnabled,
                                   topicsPeople: topicsPeopleEnabled)

                if index > 0 && index % 50 == 0 {
                    await Task.yield()
                }
            }

            #if DEBUG
            let elapsed = Date().timeIntervalSince(startTime)
            logger.debug("processNewArticlesIfEnabled: finished \(orderedIDs.count) articles in \(String(format: "%.2f", elapsed))s")
            #endif
        }.value
    }

    /// Processes a single article on-demand (e.g., from ArticleDetailView).
    static func processArticle(_ article: Article) async {
        let defaults = UserDefaults.standard
        let similarContentEnabled = defaults.bool(forKey: "Intelligence.SimilarContent.Enabled")
        let topicsPeopleEnabled = defaults.bool(forKey: "Intelligence.TopicsPeople.Enabled")

        await Task.detached(priority: .utility) {
            processArticleSync(article, similarContent: similarContentEnabled,
                               topicsPeople: topicsPeopleEnabled)
        }.value
    }

    private nonisolated static func processArticleSync(
        _ article: Article,
        similarContent: Bool,
        topicsPeople: Bool
    ) {
        let db = DatabaseManager.shared
        let text = [article.title, article.summary ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        #if DEBUG
        logger.debug("processArticleSync: article=\(article.id) title=\"\(article.title.prefix(60))\"")
        #endif

        if similarContent {
            if let score = NLPProcessor.sentimentScore(for: text) {
                try? db.updateSentimentScore(score, for: article.id)
            }
            try? db.markSentimentProcessed(articleId: article.id)
        }

        if topicsPeople {
            let entities = NLPProcessor.extractEntities(from: text)
            if !entities.isEmpty {
                try? db.insertEntities(
                    entities.map { (name: $0.name, type: $0.type) },
                    for: article.id
                )
            }
            try? db.markEntitiesProcessed(articleId: article.id)
        }
    }
}
