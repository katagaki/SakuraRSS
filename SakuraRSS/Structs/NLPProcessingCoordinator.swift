import Foundation
import NaturalLanguage
import os

enum NLPProcessingCoordinator {

    #if DEBUG
    nonisolated static let logger = Logger(subsystem: "com.tsubuzaki.SakuraRSS", category: "NLPCoordinator")
    #endif

    /// Number of articles processed per chunk before yielding back to the
    /// cooperative scheduler.  Keeps main-thread hitches short when this
    /// coordinator runs concurrently with scrolling.
    nonisolated private static let chunkSize = 20

    /// Processes unprocessed articles if Content Insights is enabled.
    /// `onBegin` fires once with the total; `onProgress` fires per article.
    static func processNewArticlesIfEnabled(
        onBegin: @escaping @Sendable (Int) async -> Void = { _ in },
        onProgress: @escaping @Sendable () async -> Void = { }
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

            // Reuse a single sentiment tagger and a single name-type tagger
            // across every article in this pass.  NLTagger construction is
            // measurably expensive; setting `.string` on an existing tagger
            // is cheap.
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
                await onProgress()
                processedSinceYield += 1
                if processedSinceYield >= chunkSize {
                    processedSinceYield = 0
                    await Task.yield()
                }
            }

            #if DEBUG
            let elapsed = Date().timeIntervalSince(startTime)
            logger.debug("processNewArticlesIfEnabled: finished \(toProcess.count) articles in \(String(format: "%.2f", elapsed))s")
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
    /// Content Insights is enabled - the hybrid similarity ranker relies on
    /// entities being present, so both passes always run together.
    ///
    /// When `sentimentTagger` and `nameTagger` are supplied, they are reused
    /// across articles by the batch caller.  The single-article path
    /// constructs fresh taggers on each call.  `runSentiment` / `runEntities`
    /// let the batch caller skip passes that have already been completed
    /// for this article on a previous run.
    private nonisolated static func processArticleSync(
        _ article: Article,
        sentimentTagger: NLTagger? = nil,
        nameTagger: NLTagger? = nil,
        runSentiment: Bool = true,
        runEntities: Bool = true
    ) {
        let db = DatabaseManager.shared
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
                try? db.updateSentimentScore(sentiment, for: article.id)
            }
            try? db.markSentimentProcessed(articleId: article.id)
        }

        if runEntities {
            let entities: [NLPProcessor.EntityResult]
            if let nameTagger {
                entities = NLPProcessor.extractEntities(from: text, using: nameTagger)
            } else {
                entities = NLPProcessor.extractEntities(from: text)
            }
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
