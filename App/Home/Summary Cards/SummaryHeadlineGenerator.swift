import Foundation
import NaturalLanguage
import Hanami

struct SummaryHeadlineGenerator {

    let kind: SummaryCardKind
    let feedManager: FeedManager

    static let snippetCharLimit = HeadlineSummarizer.snippetCharLimit
    static let articleConsiderationLimit = HeadlineSummarizer.maxArticlesConsidered
    static let topEntityHintLimit = 10

    enum Outcome {
        case noContent
        case generated(headlines: [SummaryHeadline], partial: Bool, articleCount: Int)
        case failed(Error?)
    }

    static var personalizationEnabled: Bool {
        // Default ON: missing key means the user hasn't visited Settings yet.
        (UserDefaults.standard.object(forKey: "Intelligence.Personalization.Enabled") as? Bool) ?? true
    }

    func generate(for date: Date) async -> Outcome {
        let allArticles = eligibleArticles()
        if allArticles.count < 3 {
            log(
                "Summary",
                "no eligible articles to summarize (\(allArticles.count) after filter)"
            )
            return .noContent
        }

        let personalizationOn = Self.personalizationEnabled
        let feedAccessCounts = loadFeedAccessCounts(personalizationOn: personalizationOn, for: date)
        let sortedArticles = sortByEngagement(allArticles, feedAccessCounts: feedAccessCounts)
        let articles = Array(sortedArticles.prefix(Self.articleConsiderationLimit))
        let articlesByID = Dictionary(uniqueKeysWithValues: articles.map { ($0.id, $0) })
        let preferredFeeds = preferredFeedIDs(from: articles, feedAccessCounts: feedAccessCounts)
        let inputs = headlineInputs(for: articles, preferredFeedIDs: preferredFeeds)
        let instructions = composeInstructions(
            date: date,
            personalizationOn: personalizationOn,
            includePreferredHint: !preferredFeeds.isEmpty
        )
        let entityMap = await loadEntityMap(for: articles)

        let outcome = await HeadlineSummarizer.summarize(
            articles: inputs,
            instructions: instructions,
            entityMap: entityMap,
            preferredFeedIDs: preferredFeeds
        )
        let resolved = resolveHeadlines(events: outcome.events, articlesByID: articlesByID)
        guard !resolved.isEmpty else {
            return .failed(outcome.error)
        }
        let partial = outcome.error != nil
        try? DatabaseManager.shared.cacheSummaryHeadlines(
            resolved, ofType: kind.cacheType, for: date,
            partialGeneration: partial,
            articleCountAtGeneration: articles.count
        )
        return .generated(headlines: resolved, partial: partial, articleCount: articles.count)
    }

    private func eligibleArticles() -> [Article] {
        kind.articles(in: feedManager).filter { article in
            guard isPlainRSSArticle(article) else { return false }
            return BatchSummarizer.hasUsefulContent(
                title: article.title,
                summary: article.summary
            )
        }
    }

    private func loadFeedAccessCounts(personalizationOn: Bool, for date: Date) -> [Int64: Int] {
        guard personalizationOn else { return [:] }
        return (try? DatabaseManager.shared.feedAccessCounts(
            since: date.addingTimeInterval(-30 * 24 * 3600)
        )) ?? [:]
    }

    private func sortByEngagement(
        _ articles: [Article],
        feedAccessCounts: [Int64: Int]
    ) -> [Article] {
        guard !feedAccessCounts.isEmpty else { return articles }
        return articles.sorted { lhs, rhs in
            let lhsScore = feedAccessCounts[lhs.feedID] ?? 0
            let rhsScore = feedAccessCounts[rhs.feedID] ?? 0
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            let lhsDate = lhs.publishedDate ?? .distantPast
            let rhsDate = rhs.publishedDate ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    private func preferredFeedIDs(
        from articles: [Article],
        feedAccessCounts: [Int64: Int]
    ) -> Set<Int64> {
        guard !feedAccessCounts.isEmpty else { return [] }
        let candidateFeedIDs = Set(articles.map(\.feedID))
        let scored: [(feedID: Int64, count: Int)] = candidateFeedIDs.compactMap { feedID in
            let count = feedAccessCounts[feedID] ?? 0
            guard count > 0 else { return nil }
            return (feedID, count)
        }
        guard !scored.isEmpty else { return [] }
        let sorted = scored.sorted { $0.count > $1.count }
        let quartile = max(1, sorted.count / 4)
        return Set(sorted.prefix(quartile).map(\.feedID))
    }

    private func composeInstructions(
        date: Date,
        personalizationOn: Bool,
        includePreferredHint: Bool
    ) -> String {
        let template = String(localized: "SummaryHeadlines.SharedPrompt", table: "Home")
        let timeWindow = String(localized: kind.timeWindowPhrase)
        var baseInstructions = String(format: template, timeWindow)
        if includePreferredHint {
            let hint = String(localized: "SummaryHeadlines.PreferredHint", table: "Home")
            baseInstructions = "\(baseInstructions)\n\n\(hint)"
        }
        let topicHints = topEntityHints(for: date, personalizationOn: personalizationOn)
        guard !topicHints.isEmpty else { return baseInstructions }
        let prefix = String(localized: "SummaryHeadlines.TopicHintPrefix", table: "Home")
        return "\(baseInstructions)\n\n\(prefix)\n\(topicHints)"
    }

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

    private func headlineInputs(
        for articles: [Article],
        preferredFeedIDs: Set<Int64>
    ) -> [HeadlineSummarizer.Input] {
        articles.map { article in
            let feed = feedManager.feed(forArticle: article)
            let baseSource = feed?.title ?? ""
            let source = preferredFeedIDs.contains(article.feedID)
                ? "\(baseSource) ★"
                : baseSource
            let raw = article.summary ?? article.content ?? ""
            let snippet = String(raw.prefix(Self.snippetCharLimit))
            let body = "ID: \(article.id)\n[\(source)] \(article.title)\n\(snippet)"
            return HeadlineSummarizer.Input(
                articleID: article.id,
                feedID: article.feedID,
                description: body
            )
        }
    }

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

    private func topEntityHints(for date: Date, personalizationOn: Bool) -> String {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "Intelligence.ContentInsights.Enabled") else { return "" }

        let database = DatabaseManager.shared
        let topicsAndPlaces: [(name: String, count: Int)]
        let people: [(name: String, count: Int)]
        if personalizationOn {
            let thirtyDaysAgo = date.addingTimeInterval(-30 * 24 * 3600)
            topicsAndPlaces = (try? database.topAccessedEntities(
                types: ["organization", "place"], since: thirtyDaysAgo, limit: Self.topEntityHintLimit
            )) ?? []
            people = (try? database.topAccessedEntities(
                types: ["person"], since: thirtyDaysAgo, limit: Self.topEntityHintLimit
            )) ?? []
        } else {
            let sevenDaysAgo = date.addingTimeInterval(-7 * 24 * 3600)
            topicsAndPlaces = (try? database.topEntities(
                types: ["organization", "place"], since: sevenDaysAgo, limit: Self.topEntityHintLimit
            )) ?? []
            people = (try? database.topEntities(
                type: "person", since: sevenDaysAgo, limit: Self.topEntityHintLimit
            )) ?? []
        }

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
