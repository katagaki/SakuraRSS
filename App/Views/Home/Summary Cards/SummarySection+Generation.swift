import Foundation
import NaturalLanguage
import SwiftUI

extension SummarySection {

    static let snippetCharLimit = HeadlineSummarizer.snippetCharLimit
    static let articleConsiderationLimit = HeadlineSummarizer.maxArticlesConsidered
    static let topEntityHintLimit = 10

    func generateHeadlines(for date: Date) async {
        let allArticles = kind.articles(in: feedManager).filter { article in
            guard isPlainRSSArticle(article) else { return false }
            return BatchSummarizer.hasUsefulContent(
                title: article.title,
                summary: article.summary
            )
        }
        if allArticles.count < 5 {
            log(
                "Summary",
                "no eligible articles to summarize (\(allArticles.count) after filter); marking unavailable"
            )
            await markNoContentAvailable()
            return
        }

        await MainActor.run { isGenerating = true }

        let articles = Array(allArticles.prefix(Self.articleConsiderationLimit))
        let articlesByID = Dictionary(uniqueKeysWithValues: articles.map { ($0.id, $0) })
        let inputs = headlineInputs(for: articles)
        let instructions = composeInstructions(date: date)
        let entityMap = await loadEntityMap(for: articles)

        do {
            let events = try await HeadlineSummarizer.summarize(
                articles: inputs,
                instructions: instructions,
                entityMap: entityMap
            )
            let resolved = resolveHeadlines(events: events, articlesByID: articlesByID)
            await applyGenerated(resolved, for: date)
        } catch {
            await MainActor.run {
                isGenerating = false
                hasGenerated = true
                generationFailed = true
                generationError = error.localizedDescription
            }
        }
    }

    private func composeInstructions(date: Date) -> String {
        let template = String(localized: "SummaryHeadlines.SharedPrompt", table: "Home")
        let timeWindow = String(localized: kind.timeWindowPhrase)
        let baseInstructions = String(format: template, timeWindow)
        let topicHints = topEntityHints(for: date)
        guard !topicHints.isEmpty else { return baseInstructions }
        let prefix = String(localized: "SummaryHeadlines.TopicHintPrefix", table: "Home")
        return "\(baseInstructions)\n\n\(prefix)\n\(topicHints)"
    }

    private func applyGenerated(_ resolved: [SummaryHeadline], for date: Date) async {
        await MainActor.run {
            isGenerating = false
            hasGenerated = true
            guard !resolved.isEmpty else {
                generationFailed = true
                generationError = String(localized: "SummaryHeadlines.NoEventsExtracted", table: "Home")
                return
            }
            withAnimation(.smooth.speed(2.0)) { headlines = resolved }
            hasSummary = true
            try? DatabaseManager.shared.cacheSummaryHeadlines(
                resolved, ofType: kind.cacheType, for: date
            )
        }
    }

    /// Flips the section into the "no content" ContentUnavailableView state
    /// when no eligible articles exist (no feeds, all filtered out, or fewer
    /// than the minimum). Without this, the placeholder would spin forever.
    private func markNoContentAvailable() async {
        await MainActor.run {
            isGenerating = false
            hasGenerated = true
            generationFailed = true
            generationError = String(localized: "SummaryHeadlines.NoEventsExtracted", table: "Home")
        }
    }

    /// Plain RSS only; skip research papers, social, video, podcast, and
    /// aggregator feeds. Bluesky/Instagram/Fediverse are already excluded
    /// by the `feedSection == .feeds` check (they have their own sections);
    /// they're listed explicitly here as a guard against future provider
    /// changes.
    private func isPlainRSSArticle(_ article: Article) -> Bool {
        guard let feed = feedManager.feed(forArticle: article) else { return false }
        if feed.isResearchFeed
            || feed.isBlueskyFeed
            || feed.isInstagramFeed
            || feed.isFediverseFeed {
            return false
        }
        return feed.feedSection == .feeds
    }

    private func headlineInputs(for articles: [Article]) -> [HeadlineSummarizer.Input] {
        articles.map { article in
            let feed = feedManager.feed(forArticle: article)
            let source = feed?.title ?? ""
            let snippet = String((article.summary ?? "").prefix(Self.snippetCharLimit))
            let body = "ID: \(article.id)\n[\(source)] \(article.title)\n\(snippet)"
            return HeadlineSummarizer.Input(articleID: article.id, description: body)
        }
    }

    /// Returns a per-article entity name set for clustering. Reads from the
    /// `nlp_entities` table when Content Insights has populated it, then
    /// fills in any gaps with in-memory NLTagger extraction so clustering
    /// works even when Content Insights is disabled.
    private func loadEntityMap(for articles: [Article]) async -> [Int64: Set<String>] {
        let ids = articles.map(\.id)
        let dbMap = (try? DatabaseManager.shared.entities(forArticleIDs: ids)) ?? [:]
        let missing = articles.filter { (dbMap[$0.id] ?? []).isEmpty }
        if missing.isEmpty {
            log("Summary", "entityMap: \(dbMap.count) articles from DB; no fallback needed")
            return dbMap
        }
        log(
            "Summary",
            "entityMap: \(dbMap.count) from DB, \(missing.count) need in-memory extraction"
        )
        let extracted = await Self.extractEntitiesInMemory(for: missing)
        var merged = dbMap
        for (id, entities) in extracted where !entities.isEmpty {
            merged[id] = entities
        }
        return merged
    }

    nonisolated private static func extractEntitiesInMemory(
        for articles: [Article]
    ) async -> [Int64: Set<String>] {
        await Task.detached(priority: .utility) {
            let tagger = NLTagger(tagSchemes: [.nameType])
            var result: [Int64: Set<String>] = [:]
            for article in articles {
                let summary = article.summary ?? ""
                let text = article.title + " " + summary
                let entities = NLPProcessor.extractEntities(from: text, using: tagger)
                result[article.id] = Set(entities.map { $0.name.lowercased() })
            }
            return result
        }.value
    }

    /// Top topics + people from the past week. Empty when Content Insights
    /// is off or no entities were extracted.
    private func topEntityHints(for date: Date) -> String {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "Intelligence.ContentInsights.Enabled") else { return "" }

        let database = DatabaseManager.shared
        let sevenDaysAgo = date.addingTimeInterval(-7 * 24 * 3600)
        let topicsAndPlaces = (try? database.topEntities(
            types: ["organization", "place"], since: sevenDaysAgo, limit: Self.topEntityHintLimit
        )) ?? []
        let people = (try? database.topEntities(
            type: "person", since: sevenDaysAgo, limit: Self.topEntityHintLimit
        )) ?? []

        var ranked = topicsAndPlaces + people
        ranked.sort { lhs, rhs in lhs.count > rhs.count }
        let trimmed = Array(ranked.prefix(Self.topEntityHintLimit))
        return trimmed.map(\.name).joined(separator: ", ")
    }

    private func resolveHeadlines(
        events: [HeadlineSummarizer.ResolvedEvent],
        articlesByID: [Int64: Article]
    ) -> [SummaryHeadline] {
        events.compactMap { event in
            guard isPlausibleHeadline(event.headline) else { return nil }
            let groupArticles = event.articleIDs.compactMap { articlesByID[$0] }
            guard !groupArticles.isEmpty else { return nil }
            let articleIDs = groupArticles.map(\.id)
            var feedIDs: [Int64] = []
            var seenFeedIDs: Set<Int64> = []
            for article in groupArticles where !seenFeedIDs.contains(article.feedID) {
                seenFeedIDs.insert(article.feedID)
                feedIDs.append(article.feedID)
            }
            return SummaryHeadline(
                headline: event.headline,
                articleIDs: articleIDs,
                thumbnailURL: pickThumbnail(from: groupArticles),
                feedIDs: feedIDs
            )
        }
    }

    /// Rejects topic-list outputs the model occasionally regurgitates from
    /// the priority hint section.
    private func isPlausibleHeadline(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let separators = CharacterSet(charactersIn: ",;・、")
        let segments = trimmed
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard segments.count >= 3 else { return true }
        let shortSegments = segments.filter { segment in
            segment.split { $0.isWhitespace }.count <= 2
        }
        return Double(shortSegments.count) / Double(segments.count) < 0.7
    }

    private func pickThumbnail(from articles: [Article]) -> String? {
        let candidates = articles.compactMap { $0.imageURL }
            .filter { !$0.isEmpty }
        return candidates.randomElement()
    }
}
