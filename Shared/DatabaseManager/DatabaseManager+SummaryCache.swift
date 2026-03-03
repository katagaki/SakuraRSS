import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    // MARK: - Summary Cache Types

    enum SummaryCacheType: String {
        case whileYouSlept = "whileYouSlept"
        case todaysSummary = "todaysSummary"
    }

    // MARK: - Daily Summary Cache

    func cachedSummary(ofType type: SummaryCacheType, for date: Date) throws -> String? {
        let key = summaryDateKey(for: date)
        let query = summaryCache.filter(summaryCacheType == type.rawValue && summaryCacheDate == key)
        guard let row = try database.pluck(query) else { return nil }
        return row[summaryCacheContent]
    }

    func clearCachedSummary(ofType type: SummaryCacheType, for date: Date) throws {
        let key = summaryDateKey(for: date)
        let query = summaryCache.filter(summaryCacheType == type.rawValue && summaryCacheDate == key)
        try database.run(query.delete())
    }

    func cacheSummary(_ content: String, ofType type: SummaryCacheType, for date: Date) throws {
        let key = summaryDateKey(for: date)
        try database.run(summaryCache.insert(or: .replace,
            summaryCacheType <- type.rawValue,
            summaryCacheDate <- key,
            summaryCacheContent <- content
        ))
    }

    private func summaryDateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
