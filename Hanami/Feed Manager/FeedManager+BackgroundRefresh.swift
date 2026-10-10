import Foundation

public extension FeedManager {

    /// Stops starting new feeds well inside the ~30s `BGAppRefreshTask` budget.
    private static let backgroundRefreshBudget: Duration = .seconds(20)

    private static let backgroundAttemptsKey = "BackgroundRefresh.LastAttempts"

    /// Refreshes the stalest feeds that fit in one `BGAppRefreshTask` budget and
    /// returns how many eligible feeds were left over. The next run picks those
    /// up first, since the feeds refreshed this time become the freshest.
    /// `contentOnly: true` skips meta updates (title, description, podcast
    /// detection, Substack URL wrap, Fediverse probe, fetcher metadata refresh).
    func refreshFeedsInBackground(
        skipImageFetch: Bool,
        skipImagePreload: Bool
    ) async -> Int {
        let cooldownRaw = UserDefaults.standard.string(forKey: "BackgroundRefresh.Cooldown")
        let cooldownSeconds = (cooldownRaw.flatMap(FeedRefreshCooldown.init(rawValue:)) ?? .fiveMinutes).seconds
        let candidates = feeds.filter { !PetalRecipe.isPetalFeedURL($0.url) }
        let attempts = Self.loadBackgroundAttempts(keepingFeedIDs: Set(feeds.map(\.id)))
        let lastRefreshed = { (feed: Feed) in Self.stalenessDate(of: feed, attempts: attempts) }
        let eligible = filterByRefreshCooldown(
            candidates, cooldownSeconds: cooldownSeconds, lastRefreshed: lastRefreshed
        )
            .sorted { lastRefreshed($0) < lastRefreshed($1) }
        guard !eligible.isEmpty else {
            log("FeedRefresh.Background", "no feeds eligible")
            return 0
        }
        log("FeedRefresh.Background", "begin eligible=\(eligible.count)")
        let queues = partitionRefreshQueues(eligible)
        let deadline = ContinuousClock.now.advanced(by: Self.backgroundRefreshBudget)
        let options = BackgroundRefreshOptions(
            deadline: deadline,
            skipImageFetch: skipImageFetch,
            skipImagePreload: skipImagePreload
        )
        async let regular = runBudgetedRefresh(queues.regular, maxConcurrent: 6, options: options)
        async let slow = runBudgetedRefresh(
            queues.slow, maxConcurrent: FeedRefreshQueueLimits.throttled, options: options
        )
        async let xRefresh = runBudgetedRefresh(
            queues.x, maxConcurrent: FeedRefreshQueueLimits.throttled, options: options
        )
        async let instagramRefresh = runBudgetedRefresh(
            queues.instagram, maxConcurrent: FeedRefreshQueueLimits.throttled, options: options
        )
        let deferredCount = await regular + slow + xRefresh + instagramRefresh
        await MainActor.run {
            self.lastRefreshedAt = Date()
            self.scopedLastRefreshedAt = [:]
        }
        log("FeedRefresh.Background", "end eligible=\(eligible.count) deferred=\(deferredCount)")
        return deferredCount
    }

    /// Returns the number of feeds that weren't started before the deadline.
    private func runBudgetedRefresh(
        _ feeds: [Feed],
        maxConcurrent: Int,
        options: BackgroundRefreshOptions
    ) async -> Int {
        var deferredCount = 0
        var attemptedFeedIDs: [Int64] = []
        await withTaskGroup(of: Void.self) { group in
            var runningCount = 0
            var iterator = feeds.makeIterator()
            while true {
                while runningCount < maxConcurrent, !Task.isCancelled,
                      ContinuousClock.now < options.deadline, let feed = iterator.next() {
                    attemptedFeedIDs.append(feed.id)
                    group.addTask { [weak self] in
                        await self?.refreshFeedContent(feed, options: options)
                    }
                    runningCount += 1
                }
                guard await group.next() != nil else { break }
                runningCount -= 1
                if Task.isCancelled {
                    group.cancelAll()
                }
            }
            while iterator.next() != nil {
                deferredCount += 1
            }
        }
        Self.recordBackgroundAttempts(feedIDs: attemptedFeedIDs)
        return deferredCount
    }

    private func refreshFeedContent(_ feed: Feed, options: BackgroundRefreshOptions) async {
        guard !Task.isCancelled else { return }
        try? await refreshFeed(
            feed,
            updateTitle: false,
            reloadData: false,
            skipImageFetch: options.skipImageFetch,
            skipImagePreload: options.skipImagePreload,
            runNLP: false,
            contentOnly: true
        )
    }

    /// Failed fetches leave `lastFetched` alone, so the last attempt also counts;
    /// otherwise a dead feed would stay at the front of every run.
    private static func stalenessDate(of feed: Feed, attempts: [String: Double]) -> Date {
        let attemptedAt = attempts[String(feed.id)].map(Date.init(timeIntervalSince1970:)) ?? .distantPast
        return max(feed.lastFetched ?? .distantPast, attemptedAt)
    }

    private static func loadBackgroundAttempts(keepingFeedIDs feedIDs: Set<Int64>? = nil) -> [String: Double] {
        let stored = UserDefaults.standard.dictionary(forKey: backgroundAttemptsKey) as? [String: Double] ?? [:]
        guard let feedIDs else { return stored }
        let kept = stored.filter { Int64($0.key).map(feedIDs.contains) ?? false }
        if kept.count != stored.count {
            UserDefaults.standard.set(kept, forKey: backgroundAttemptsKey)
        }
        return kept
    }

    private static func recordBackgroundAttempts(feedIDs: [Int64]) {
        guard !feedIDs.isEmpty else { return }
        var attempts = loadBackgroundAttempts()
        let now = Date().timeIntervalSince1970
        for feedID in feedIDs {
            attempts[String(feedID)] = now
        }
        UserDefaults.standard.set(attempts, forKey: backgroundAttemptsKey)
    }
}

private nonisolated struct BackgroundRefreshOptions: Sendable {
    let deadline: ContinuousClock.Instant
    let skipImageFetch: Bool
    let skipImagePreload: Bool
}
