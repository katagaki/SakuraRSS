import Foundation

public extension FeedManager {

    func runTitleSafeBoundedRefresh(
        _ feeds: [Feed],
        maxConcurrent: Int
    ) async {
        guard !feeds.isEmpty else { return }
        await withTaskGroup(of: Void.self) { group in
            var submitted = 0
            var iterator = feeds.makeIterator()
            while submitted < maxConcurrent, !Task.isCancelled, let feed = iterator.next() {
                group.addTask { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    await self.markRefreshStarted(feedID: feed.id)
                    try? await self.refreshFeed(
                        feed,
                        updateTitle: false,
                        reloadData: false
                    )
                    await self.markRefreshFinished(
                        feedID: feed.id,
                        cancelled: Task.isCancelled
                    )
                }
                submitted += 1
            }
            while await group.next() != nil {
                if Task.isCancelled {
                    group.cancelAll()
                    continue
                }
                if let feed = iterator.next() {
                    group.addTask { [weak self] in
                        guard let self, !Task.isCancelled else { return }
                        await self.markRefreshStarted(feedID: feed.id)
                        try? await self.refreshFeed(
                            feed,
                            updateTitle: false,
                            reloadData: false
                        )
                        await self.markRefreshFinished(
                            feedID: feed.id,
                            cancelled: Task.isCancelled
                        )
                    }
                }
            }
        }
    }

    func runBoundedRefresh(
        _ feeds: [Feed],
        maxConcurrent: Int,
        skipImageFetch: Bool,
        skipImagePreload: Bool,
        runNLP: Bool
    ) async {
        guard !feeds.isEmpty else { return }
        log("FeedRefresh.Bounded", "begin count=\(feeds.count) maxConcurrent=\(maxConcurrent)")
        await withTaskGroup(of: Void.self) { group in
            var submitted = 0
            var iterator = feeds.makeIterator()
            while submitted < maxConcurrent, !Task.isCancelled, let feed = iterator.next() {
                group.addTask { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    await self.markRefreshStarted(feedID: feed.id)
                    try? await self.refreshFeed(
                        feed,
                        reloadData: false,
                        skipImageFetch: skipImageFetch,
                        skipImagePreload: skipImagePreload,
                        runNLP: runNLP
                    )
                    await self.markRefreshFinished(
                        feedID: feed.id,
                        cancelled: Task.isCancelled
                    )
                }
                submitted += 1
            }
            while await group.next() != nil {
                if Task.isCancelled {
                    group.cancelAll()
                    continue
                }
                if let feed = iterator.next() {
                    group.addTask { [weak self] in
                        guard let self, !Task.isCancelled else { return }
                        await self.markRefreshStarted(feedID: feed.id)
                        try? await self.refreshFeed(
                            feed,
                            reloadData: false,
                            skipImageFetch: skipImageFetch,
                            skipImagePreload: skipImagePreload,
                            runNLP: runNLP
                        )
                        await self.markRefreshFinished(
                            feedID: feed.id,
                            cancelled: Task.isCancelled
                        )
                    }
                }
            }
        }
        log("FeedRefresh.Bounded", "end count=\(feeds.count)")
    }

    /// Refreshes only the feeds matching the given background category.
    /// `contentOnly: true` suppresses all meta updates (title, description,
    /// podcast detection, Substack URL wrap, Fediverse probe, fetcher metadata
    /// refresh) so the work fits inside a `BGAppRefreshTask` budget.
    func refreshFeeds(
        in category: BackgroundRefreshCategory,
        skipImageFetch: Bool,
        skipImagePreload: Bool
    ) async {
        let matching = feeds.filter(category.includes)
        let cooldownRaw = UserDefaults.standard.string(forKey: "BackgroundRefresh.Cooldown")
        let cooldownSeconds = (cooldownRaw.flatMap(FeedRefreshCooldown.init(rawValue:)) ?? .fiveMinutes).seconds
        let eligible = filterByRefreshCooldown(matching, cooldownSeconds: cooldownSeconds)
        guard !eligible.isEmpty else {
            log("FeedRefresh.Category", "category=\(category.rawValue) no feeds eligible")
            return
        }
        log("FeedRefresh.Category", "category=\(category.rawValue) begin count=\(eligible.count)")
        let maxConcurrent = category == .x || category == .instagram ? 2 : 6
        await withTaskGroup(of: Void.self) { group in
            var submitted = 0
            var iterator = eligible.makeIterator()
            while submitted < maxConcurrent, !Task.isCancelled, let feed = iterator.next() {
                group.addTask { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    try? await self.refreshFeed(
                        feed,
                        updateTitle: false,
                        reloadData: false,
                        skipImageFetch: skipImageFetch,
                        skipImagePreload: skipImagePreload,
                        runNLP: false,
                        contentOnly: true
                    )
                }
                submitted += 1
            }
            while await group.next() != nil {
                if Task.isCancelled {
                    group.cancelAll()
                    continue
                }
                if let feed = iterator.next() {
                    group.addTask { [weak self] in
                        guard let self, !Task.isCancelled else { return }
                        try? await self.refreshFeed(
                            feed,
                            updateTitle: false,
                            reloadData: false,
                            skipImageFetch: skipImageFetch,
                            skipImagePreload: skipImagePreload,
                            runNLP: false,
                            contentOnly: true
                        )
                    }
                }
            }
        }
        await MainActor.run {
            self.lastRefreshedAt = Date()
            self.scopedLastRefreshedAt = [:]
        }
        log("FeedRefresh.Category", "category=\(category.rawValue) end count=\(eligible.count)")
    }

    @MainActor
    func markRefreshStarted(feedID: Int64) {
        pendingRefreshFeedIDs.removeAll { $0 == feedID }
        refreshingFeedIDs.insert(feedID)
    }

    @MainActor
    func markRefreshFinished(feedID: Int64, cancelled: Bool) {
        refreshingFeedIDs.remove(feedID)
        if !cancelled {
            refreshCompleted += 1
        }
    }
}
