import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    /// Persists a refresh-duration sample for the given feed, blending it into
    /// a running average so the slow-feed router can react to multiple samples.
    func recordFeedRefreshMetric(feedID: Int64, durationMs: Int) throws {
        let now = Date().timeIntervalSince1970
        if let existing = try database.pluck(feedRefreshMetrics.filter(metricFeedID == feedID)) {
            let priorCount = existing[metricSampleCount]
            let priorAverage = existing[metricAverageDurationMs]
            let nextCount = priorCount + 1
            let blendedAverage = ((priorAverage * Double(priorCount)) + Double(durationMs))
                / Double(nextCount)
            try database.run(feedRefreshMetrics.filter(metricFeedID == feedID).update(
                metricLastDurationMs <- durationMs,
                metricAverageDurationMs <- blendedAverage,
                metricSampleCount <- nextCount,
                metricLastRecordedAt <- now
            ))
        } else {
            try database.run(feedRefreshMetrics.insert(
                metricFeedID <- feedID,
                metricLastDurationMs <- durationMs,
                metricAverageDurationMs <- Double(durationMs),
                metricSampleCount <- 1,
                metricLastRecordedAt <- now
            ))
        }
    }

    func feedRefreshMetric(feedID: Int64) throws -> FeedRefreshMetric? {
        guard let row = try database.pluck(
            feedRefreshMetrics.filter(metricFeedID == feedID)
        ) else { return nil }
        return rowToFeedRefreshMetric(row)
    }

    /// Returns every recorded refresh metric, keyed by feed id.
    func allFeedRefreshMetrics() throws -> [Int64: FeedRefreshMetric] {
        var results: [Int64: FeedRefreshMetric] = [:]
        for row in try database.prepare(feedRefreshMetrics) {
            let metric = rowToFeedRefreshMetric(row)
            results[metric.feedID] = metric
        }
        return results
    }

    func deleteFeedRefreshMetric(feedID: Int64) throws {
        try database.run(feedRefreshMetrics.filter(metricFeedID == feedID).delete())
    }

    private func rowToFeedRefreshMetric(_ row: Row) -> FeedRefreshMetric {
        FeedRefreshMetric(
            feedID: row[metricFeedID],
            lastDurationMs: row[metricLastDurationMs],
            averageDurationMs: row[metricAverageDurationMs],
            sampleCount: row[metricSampleCount],
            lastRecordedAt: Date(timeIntervalSince1970: row[metricLastRecordedAt])
        )
    }
}
