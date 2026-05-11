import Foundation
@preconcurrency import SQLite

public nonisolated struct CachedSummaryHeadlinesResult: Sendable {
    public let headlines: [SummaryHeadline]
    public let partialGeneration: Bool
    public let articleCountAtGeneration: Int

    public init(
        headlines: [SummaryHeadline],
        partialGeneration: Bool,
        articleCountAtGeneration: Int
    ) {
        self.headlines = headlines
        self.partialGeneration = partialGeneration
        self.articleCountAtGeneration = articleCountAtGeneration
    }
}

public nonisolated extension DatabaseManager {

    // MARK: - Summary Headlines Cache

    func cachedSummaryHeadlines(
        ofType type: SummaryCacheType,
        for date: Date
    ) throws -> CachedSummaryHeadlinesResult {
        let key = summaryHeadlineDateKey(for: date)
        let query = summaryHeadlines
            .filter(summaryHeadlineType == type.rawValue && summaryHeadlineDate == key)
            .order(summaryHeadlineOrdinal.asc)
        var results: [SummaryHeadline] = []
        var partial = false
        var articleCount = 0
        for row in try database.prepare(query) {
            let headline = row[summaryHeadlineText]
            let articleIDs = decodeIDs(row[summaryHeadlineArticleIDs])
            let feedIDs = decodeIDs(row[summaryHeadlineFeedIDs])
            let thumbnail = row[summaryHeadlineThumbnailURL]
            guard !articleIDs.isEmpty else { continue }
            partial = row[summaryHeadlinePartialGeneration] || partial
            articleCount = max(articleCount, row[summaryHeadlineArticleCountAtGeneration])
            results.append(
                SummaryHeadline(
                    headline: headline,
                    articleIDs: articleIDs,
                    thumbnailURL: thumbnail,
                    feedIDs: feedIDs
                )
            )
        }
        return CachedSummaryHeadlinesResult(
            headlines: results,
            partialGeneration: partial,
            articleCountAtGeneration: articleCount
        )
    }

    func clearCachedSummaryHeadlines(
        ofType type: SummaryCacheType,
        for date: Date
    ) throws {
        let key = summaryHeadlineDateKey(for: date)
        let query = summaryHeadlines
            .filter(summaryHeadlineType == type.rawValue && summaryHeadlineDate == key)
        try database.run(query.delete())
    }

    func cacheSummaryHeadlines(
        _ headlines: [SummaryHeadline],
        ofType type: SummaryCacheType,
        for date: Date,
        partialGeneration: Bool = false,
        articleCountAtGeneration: Int = 0
    ) throws {
        let key = summaryHeadlineDateKey(for: date)
        try database.transaction {
            let existing = summaryHeadlines
                .filter(summaryHeadlineType == type.rawValue && summaryHeadlineDate == key)
            try database.run(existing.delete())
            for (index, item) in headlines.enumerated() {
                try database.run(summaryHeadlines.insert(or: .replace,
                    summaryHeadlineType <- type.rawValue,
                    summaryHeadlineDate <- key,
                    summaryHeadlineOrdinal <- index,
                    summaryHeadlineText <- item.headline,
                    summaryHeadlineArticleIDs <- encodeIDs(item.articleIDs),
                    summaryHeadlineFeedIDs <- encodeIDs(item.feedIDs),
                    summaryHeadlineThumbnailURL <- item.thumbnailURL,
                    summaryHeadlinePartialGeneration <- partialGeneration,
                    summaryHeadlineArticleCountAtGeneration <- articleCountAtGeneration
                ))
            }
        }
    }

    func purgeAllSummaryHeadlines() throws {
        try database.run(summaryHeadlines.delete())
    }

    /// Wipes the summary_headlines cache when the running app's prompt
    /// version differs from the version that produced the cached rows.
    /// Runs every launch; cheap when versions match.
    func wipeSummaryHeadlinesIfPromptVersionChanged() {
        let key = "SummaryHeadlines.PromptVersion"
        let stored = UserDefaults.standard.object(forKey: key) as? Int
        let current = HeadlineSummarizer.promptVersion
        guard stored != current else { return }
        _ = try? database.run(summaryHeadlines.delete())
        UserDefaults.standard.set(current, forKey: key)
    }

    // MARK: - Encoding Helpers

    private func encodeIDs(_ ids: [Int64]) -> String {
        ids.map(String.init).joined(separator: ",")
    }

    private func decodeIDs(_ text: String) -> [Int64] {
        guard !text.isEmpty else { return [] }
        return text.split(separator: ",").compactMap { Int64($0) }
    }

    private func summaryHeadlineDateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
