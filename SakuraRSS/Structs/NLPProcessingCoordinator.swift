import Foundation
import os

enum NLPProcessingCoordinator {

    #if DEBUG
    nonisolated static let logger = Logger(subsystem: "com.tsubuzaki.SakuraRSS", category: "NLPCoordinator")
    #endif

    /// Processes unprocessed articles if Content Insights is enabled.
    /// Called after feed refresh completes.
    static func processNewArticlesIfEnabled() async {
        let defaults = UserDefaults.standard
        let contentInsightsEnabled = defaults.bool(forKey: "Intelligence.ContentInsights.Enabled")
        guard contentInsightsEnabled else {
            #if DEBUG
            logger.debug("processNewArticlesIfEnabled: content insights disabled, skipping")
            #endif
            return
        }

        let db = DatabaseManager.shared
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)

        #if DEBUG
        let startTime = Date()
        logger.debug("processNewArticlesIfEnabled: starting")
        #endif

        await Task.detached(priority: .userInitiated) {
            var idsToProcess = Set<Int64>()
            if let ids = try? db.unprocessedSentimentArticleIDs(since: sevenDaysAgo, limit: 200) {
                idsToProcess.formUnion(ids)
            }
            if let ids = try? db.unprocessedEntitiesArticleIDs(since: sevenDaysAgo, limit: 200) {
                idsToProcess.formUnion(ids)
            }

            #if DEBUG
            logger.debug("processNewArticlesIfEnabled: \(idsToProcess.count) articles to process")
            #endif

            let orderedIDs = Array(idsToProcess)
            for (index, id) in orderedIDs.enumerated() {
                guard let article = try? db.article(byID: id) else { continue }
                processArticleSync(article)

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
        guard defaults.bool(forKey: "Intelligence.ContentInsights.Enabled") else { return }

        await Task.detached(priority: .userInitiated) {
            processArticleSync(article)
        }.value
    }

    /// Extracts sentiment and entities for an article. Called only when
    /// Content Insights is enabled — the hybrid similarity ranker relies on
    /// entities being present, so both passes always run together.
    private nonisolated static func processArticleSync(_ article: Article) {
        let db = DatabaseManager.shared
        let text = [article.title, article.summary ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        #if DEBUG
        logger.debug("processArticleSync: article=\(article.id) title=\"\(article.title.prefix(60))\"")
        #endif

        if let score = NLPProcessor.sentimentScore(for: text) {
            try? db.updateSentimentScore(score, for: article.id)
        }
        try? db.markSentimentProcessed(articleId: article.id)

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
