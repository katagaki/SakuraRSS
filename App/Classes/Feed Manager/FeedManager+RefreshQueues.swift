import Foundation

/// Hard ceiling on concurrent refresh tasks per queue. Each refresh runs four
/// independent queues (regular RSS, slow RSS, X, Instagram), so the total
/// concurrent in-flight refresh count tops out at 4 * `maxConcurrentPerQueue`.
enum FeedRefreshQueueLimits {
    static let maxConcurrentPerQueue = 4
}

/// Bucketed feeds for the four-queue refresh pipeline.
struct FeedRefreshQueues: Sendable {
    let regular: [Feed]
    let slow: [Feed]
    let x: [Feed]
    let instagram: [Feed]
}

extension FeedManager {

    /// Splits feeds into the four refresh queues. X and Instagram are routed by
    /// type; remaining feeds are routed by their last recorded refresh duration
    /// so feeds that exceeded the slow threshold last time end up on the slow
    /// queue this time.
    func partitionRefreshQueues(_ feeds: [Feed]) -> FeedRefreshQueues {
        let metrics = (try? database.allFeedRefreshMetrics()) ?? [:]
        let slowThresholdMs = FeedRefreshMetric.slowDurationThresholdMs

        var regular: [Feed] = []
        var slow: [Feed] = []
        var x: [Feed] = []
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
