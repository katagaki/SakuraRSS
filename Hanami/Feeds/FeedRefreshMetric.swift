import Foundation

/// Cached refresh-duration sample for a feed. Used to route slow feeds to a
/// dedicated refresh queue on subsequent refreshes.
public nonisolated struct FeedRefreshMetric: Sendable, Hashable {
    public let feedID: Int64
    public var lastDurationMs: Int
    public var averageDurationMs: Double
    public var sampleCount: Int
    public var lastRecordedAt: Date

    /// Threshold in milliseconds above which a feed is considered slow.
    public static let slowDurationThresholdMs: Int = 3_000

    public var isSlow: Bool {
        lastDurationMs >= Self.slowDurationThresholdMs
    }
}
