import Foundation
import NaturalLanguage
import os

enum NLPProcessingCoordinator {

    #if DEBUG
    nonisolated static let logger = Logger(subsystem: "com.tsubuzaki.SakuraRSS", category: "NLPCoordinator")
    #endif

    nonisolated private static let chunkSize = 20

    /// Processes unprocessed articles if Content Insights is enabled.
    /// `onProgress` is coalesced per chunk to avoid MainActor hitches.
    static func processNewArticlesIfEnabled(
        onBegin: @escaping @Sendable (Int) async -> Void = { _ in },
        onProgress: @escaping @Sendable (Int) async -> Void = { _ in }
    ) async {
        let defaults = UserDefaults.standard
        let contentInsightsEnabled = defaults.bool(forKey: "Intelligence.ContentInsights.Enabled")
        guard contentInsightsEnabled else {
            #if DEBUG
            logger.debug("processNewArticlesIfEnabled: content insights disabled, skipping")
            #endif
            return
        }

        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            #if DEBUG
            logger.debug("processNewArticlesIfEnabled: Low Power Mode is on, deferring")
            #endif
            return
        }

        let database = DatabaseManager.shared
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)

        #if DEBUG
        let startTime = Date()
        logger.debug("processNewArticlesIfEnabled: starting")
        #endif

        await Task.detached(priority: .utility) {
            let toProcess = (try? database.unprocessedNLPArticles(since: sevenDaysAgo, limit: 200)) ?? []

            #if DEBUG
            logger.debug("processNewArticlesIfEnabled: \(toProcess.count) articles to process")
            #endif

            await onBegin(toProcess.count)

            // Reuse taggers across articles; NLTagger construction is expensive.
            let sentimentTagger = NLTagger(tagSchemes: [.sentimentScore])
            let nameTagger = NLTagger(tagSchemes: [.nameType])

            var processedSinceYield = 0
            for pending in toProcess {
                if Task.isCancelled { break }
                if let article = try? database.article(byID: pending.id) {
                    processArticleSync(
                        article,
                        sentimentTagger: pending.needsSentiment ? sentimentTagger : nil,
                        nameTagger: pending.needsEntities ? nameTagger : nil,
                        runSentiment: pending.needsSentiment,
                        runEntities: pending.needsEntities
                    )
                }
                processedSinceYield += 1
                if processedSinceYield >= chunkSize {
                    await onProgress(processedSinceYield)
                    processedSinceYield = 0
                    await Task.yield()
                }
            }
            if processedSinceYield > 0 {
                await onProgress(processedSinceYield)
            }

            #if DEBUG
            let elapsed = Date().timeIntervalSince(startTime)
            logger.debug("processNewArticlesIfEnabled: finished \(toProcess.count) articles in \(String(format: "%.2f", elapsed))s")
            #endif
        }.value
    }

    /// Processes a single article on-demand.
    static func processArticle(_ article: Article) async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "Intelligence.ContentInsights.Enabled") else { return }

        await Task.detached(priority: .userInitiated) {
            processArticleSync(article)
        }.value
    }

    /// Processes the given article IDs inline as part of a per-feed refresh pipeline.
    /// Skipped when content insights are disabled or in Low Power Mode.
    nonisolated static func processArticles(ids: [Int64]) async {
        guard !ids.isEmpty else { return }
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "Intelligence.ContentInsights.Enabled") else { return }
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return }

        let database = DatabaseManager.shared
        let sentimentTagger = NLTagger(tagSchemes: [.sentimentScore])
        let nameTagger = NLTagger(tagSchemes: [.nameType])

        for id in ids {
            if Task.isCancelled { return }
            guard let article = try? database.article(byID: id) else { continue }
            processArticleSync(
                article,
                sentimentTagger: sentimentTagger,
                nameTagger: nameTagger
            )
            await Task.yield()
        }
    }

    /// Extracts sentiment and entities for an article; reuses taggers when supplied.
    private nonisolated static func processArticleSync(
        _ article: Article,
        sentimentTagger: NLTagger? = nil,
        nameTagger: NLTagger? = nil,
        runSentiment: Bool = true,
        runEntities: Bool = true
    ) {
        let database = DatabaseManager.shared
        let text = [article.title, article.summary ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        #if DEBUG
        logger.debug("processArticleSync: article=\(article.id) title=\"\(article.title.prefix(60))\"")
        #endif

        if runSentiment {
            let sentiment: Double?
            if let sentimentTagger {
                sentiment = NLPProcessor.sentimentScore(for: text, using: sentimentTagger)
            } else {
                sentiment = NLPProcessor.sentimentScore(for: text)
            }
            if let sentiment {
                try? database.updateSentimentScore(sentiment, for: article.id)
            }
            try? database.markSentimentProcessed(articleId: article.id)
        }

        if runEntities {
            let entities: [NLPProcessor.EntityResult]
            if let nameTagger {
                entities = NLPProcessor.extractEntities(from: text, using: nameTagger)
            } else {
                entities = NLPProcessor.extractEntities(from: text)
            }
            if !entities.isEmpty {
                try? database.insertEntities(
                    entities.map { (name: $0.name, type: $0.type) },
                    for: article.id
                )
            }
            try? database.markEntitiesProcessed(articleId: article.id)
        }
    }
}
