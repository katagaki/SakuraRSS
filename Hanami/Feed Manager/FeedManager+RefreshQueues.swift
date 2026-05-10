import Foundation

/// Hard ceiling on concurrent refresh tasks per queue.
public enum FeedRefreshQueueLimits {
    public static let `default` = 8
    public static let fast = 24
    public static let throttled = 2
}

/// Bucketed feeds for the four-queue refresh pipeline.
public struct FeedRefreshQueues: Sendable {
    public let regular: [Feed]
    public let slow: [Feed]
    public let x: [Feed] // swiftlint:disable:this identifier_name
    public let instagram: [Feed]
}

public extension FeedManager {

    /// Splits feeds into the four refresh queues. X and Instagram are routed by
    /// type; remaining feeds are routed by their last recorded refresh duration
    /// so feeds that exceeded the slow threshold last time end up on the slow
    /// queue this time.
    func partitionRefreshQueues(_ feeds: [Feed]) -> FeedRefreshQueues {
        let metrics = (try? database.allFeedRefreshMetrics()) ?? [:]
        let slowThresholdMs = FeedRefreshMetric.slowDurationThresholdMs

        var regular: [Feed] = []
        var slow: [Feed] = []
        var x: [Feed] = [] // swiftlint:disable:this identifier_name
        var instagram: [Feed] = []

        for feed in feeds {
            if feed.isXFeed {
                x.append(feed)
            } else if feed.isInstagramFeed {
                instagram.append(feed)
            } else if let metric = metrics[feed.id] {
                if metric.lastDurationMs >= slowThresholdMs {
                    slow.append(feed)
                } else {
                    regular.append(feed)
                }
            } else if feed.isSlowRefreshFeed {
                slow.append(feed)
            } else {
                regular.append(feed)
            }
        }

        return FeedRefreshQueues(regular: regular, slow: slow, x: x, instagram: instagram)
    }
}
