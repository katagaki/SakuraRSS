import Foundation

extension FeedManager {

    // swiftlint:disable function_body_length
    /// Refreshes the supplied feeds and tracks progress under `scope` so each
    /// home section, list, or feed view can show its own donut without
    /// stepping on the global refresh counters used by background refresh.
    func refreshFeeds(
        scope: String,
        feeds: [Feed],
        skipImagePreload: Bool? = nil,
        runNLP: Bool = false
    ) async {
        guard !feeds.isEmpty else { return }
        let alreadyRunning = await MainActor.run { self.scopedRefreshTasks[scope] != nil }
        guard !alreadyRunning else {
            log("FeedRefresh.Scoped", "skip - already running scope=\(scope)")
            return
        }

        log("FeedRefresh.Scoped", "begin scope=\(scope) count=\(feeds.count)")
        await MainActor.run {
            scopedRefreshes[scope] = ScopedRefreshState(
                total: feeds.count,
                completed: 0,
                refreshingFeedIDs: [],
                pendingFeedIDs: feeds.map { $0.id }
            )
        }

        let effectiveSkipPreload: Bool
        if let skipImagePreload {
            effectiveSkipPreload = skipImagePreload
        } else {
            let preloadModeRaw = UserDefaults.standard.string(
                forKey: "FeedRefresh.PreloadArticleImagesMode"
            )
            let preloadMode = preloadModeRaw
                .flatMap(FetchImagesMode.init(rawValue:)) ?? .wifiOnly
            switch preloadMode {
            case .always: effectiveSkipPreload = false
            case .wifiOnly: effectiveSkipPreload = await NetworkMonitor.currentPathIsExpensive() ?? true
            case .off: effectiveSkipPreload = true
            }
        }

        let queues = partitionRefreshQueues(feeds)

        let work = Task { [weak self] in
            guard let self else { return }
            async let regular: Void = self.runScopedBoundedRefresh(
                queues.regular,
                scope: scope,
                maxConcurrent: FeedRefreshQueueLimits.maxConcurrentPerQueue,
                skipImagePreload: effectiveSkipPreload,
                runNLP: runNLP
            )
            async let slow: Void = self.runScopedBoundedRefresh(
                queues.slow,
                scope: scope,
                maxConcurrent: FeedRefreshQueueLimits.maxConcurrentPerQueue,
                skipImagePreload: effectiveSkipPreload,
                runNLP: runNLP
            )
            async let xRefresh: Void = self.runScopedBoundedRefresh(
                queues.x,
                scope: scope,
                maxConcurrent: FeedRefreshQueueLimits.maxConcurrentPerQueue,
                skipImagePreload: effectiveSkipPreload,
                runNLP: runNLP
            )
            async let instagramRefresh: Void = self.runScopedBoundedRefresh(
                queues.instagram,
                scope: scope,
                maxConcurrent: FeedRefreshQueueLimits.maxConcurrentPerQueue,
                skipImagePreload: effectiveSkipPreload,
                runNLP: runNLP
            )
            _ = await (regular, slow, xRefresh, instagramRefresh)
        }
        await MainActor.run { self.scopedRefreshTasks[scope] = work }
        _ = await work.value
        await loadFromDatabaseInBackground(animated: true)
        await MainActor.run {
            var updatedTimestamps = self.scopedLastRefreshedAt
            updatedTimestamps[scope] = Date()
            self.scopedLastRefreshedAt = updatedTimestamps
            self.scopedRefreshes[scope] = nil
            self.scopedRefreshTasks[scope] = nil
        }
        log("FeedRefresh.Scoped", "end scope=\(scope)")
    }
    // swiftlint:enable function_body_length

    @MainActor
    func cancelScopedRefresh(scope: String) {
        log("FeedRefresh.Scoped", "cancel scope=\(scope)")
        scopedRefreshTasks[scope]?.cancel()
        scopedRefreshTasks[scope] = nil
        scopedRefreshes[scope] = nil
        Task { await self.loadFromDatabaseInBackground(animated: true) }
    }

    fileprivate func runScopedBoundedRefresh(
        _ feeds: [Feed],
        scope: String,
        maxConcurrent: Int,
        skipImagePreload: Bool,
        runNLP: Bool
    ) async {
        guard !feeds.isEmpty else { return }
        await withTaskGroup(of: Void.self) { group in
            var submitted = 0
            var iterator = feeds.makeIterator()
            while submitted < maxConcurrent, !Task.isCancelled, let feed = iterator.next() {
                group.addTask { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    await self.markScopedRefreshStarted(scope: scope, feedID: feed.id)
                    try? await self.refreshFeed(
                        feed,
                        reloadData: false,
                        skipImagePreload: skipImagePreload,
                        runNLP: runNLP
                    )
                    await self.markScopedRefreshFinished(
                        scope: scope,
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
                        await self.markScopedRefreshStarted(scope: scope, feedID: feed.id)
                        try? await self.refreshFeed(
                            feed,
                            reloadData: false,
                            skipImagePreload: skipImagePreload,
                            runNLP: runNLP
                        )
                        await self.markScopedRefreshFinished(
                            scope: scope,
                            feedID: feed.id,
                            cancelled: Task.isCancelled
                        )
                    }
                }
            }
        }
    }

    @MainActor
    private func markScopedRefreshStarted(scope: String, feedID: Int64) {
        guard var state = scopedRefreshes[scope] else { return }
        state.pendingFeedIDs.removeAll { $0 == feedID }
        state.refreshingFeedIDs.insert(feedID)
        scopedRefreshes[scope] = state
    }

    @MainActor
    private func markScopedRefreshFinished(
        scope: String,
        feedID: Int64,
        cancelled: Bool
    ) {
        guard var state = scopedRefreshes[scope] else { return }
        state.refreshingFeedIDs.remove(feedID)
        if !cancelled {
            state.completed += 1
        }
        scopedRefreshes[scope] = state
    }
}
