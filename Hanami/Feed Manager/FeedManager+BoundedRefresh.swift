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
