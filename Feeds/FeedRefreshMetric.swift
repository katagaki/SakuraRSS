import Foundation

/// Cached refresh-duration sample for a feed. Used to route slow feeds to a
/// dedicated refresh queue on subsequent refreshes.
nonisolated struct FeedRefreshMetric: Sendable, Hashable {
    let feedID: Int64
    var lastDurationMs: Int
    var averageDurationMs: Double
    var sampleCount: Int
    var lastRecordedAt: Date

    /// Threshold in milliseconds above which a feed is considered slow.
    static let slowDurationThresholdMs: Int = 3_000

    var isSlow: Bool {
        lastDurationMs >= Self.slowDurationThresholdMs
    }
}
