import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    // MARK: - Summary Headlines Cache

    func cachedSummaryHeadlines(
        ofType type: SummaryCacheType,
        for date: Date
    ) throws -> [SummaryHeadline] {
        let key = summaryHeadlineDateKey(for: date)
        let query = summaryHeadlines
            .filter(summaryHeadlineType == type.rawValue && summaryHeadlineDate == key)
            .order(summaryHeadlineOrdinal.asc)
        var results: [SummaryHeadline] = []
        for row in try database.prepare(query) {
            let headline = row[summaryHeadlineText]
            let articleIDs = decodeIDs(row[summaryHeadlineArticleIDs])
            let feedIDs = decodeIDs(row[summaryHeadlineFeedIDs])
            let thumbnail = row[summaryHeadlineThumbnailURL]
            guard !articleIDs.isEmpty else { continue }
            results.append(
                SummaryHeadline(
                    headline: headline,
                    articleIDs: articleIDs,
                    thumbnailURL: thumbnail,
                    feedIDs: feedIDs
                )
            )
        }
        return results
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
        for date: Date
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
                    summaryHeadlineThumbnailURL <- item.thumbnailURL
                ))
            }
        }
    }

    func purgeAllSummaryHeadlines() throws {
        try database.run(summaryHeadlines.delete())
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
