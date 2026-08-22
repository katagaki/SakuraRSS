import Foundation

public extension FeedManager {

    func connectCloudSync() {
        let engine = CloudSyncEngine.shared
        engine.onRemoteChangesApplied = { [weak self] insertedNewFeeds in
            Task { @MainActor [weak self] in
                await self?.handleRemoteSyncChanges(insertedNewFeeds: insertedNewFeeds)
            }
        }
        engine.onRemoteFeedDeleted = { [weak self] feed in
            Task { @MainActor [weak self] in
                self?.applyRemoteFeedDeletion(feed)
            }
        }
        ProviderSessionEvents.onSessionEstablished = { [weak self] service in
            Task { @MainActor [weak self] in
                await self?.refreshIcons(forProvider: service)
            }
        }
        engine.startIfEnabled()
    }

    /// Stamps a user-driven edit so it wins sync conflicts, and queues the
    /// feed for upload. Reads the sync ID from the database because in-memory
    /// `Feed` values can predate the engine's backfill.
    func captureUserFeedEdit(feedID: Int64) {
        try? database.setFeedUserModifiedAt(feedID: feedID, date: Date())
        let syncID = (try? database.feed(byID: feedID))?.syncID
        CloudSyncEngine.shared.noteFeedChanged(syncID: syncID)
    }

    /// Records the deletion for sync. Call after the local row is gone.
    func captureUserFeedDeletion(syncID: String?) {
        guard let syncID else { return }
        try? database.insertSyncTombstone(syncID: syncID)
        CloudSyncEngine.shared.noteFeedDeleted(syncID: syncID)
    }

    private func handleRemoteSyncChanges(insertedNewFeeds: Bool) async {
        await loadFromDatabaseInBackground()
        guard insertedNewFeeds else { return }
        let newFeeds = feeds.filter { $0.lastFetched == nil }
        for feed in newFeeds where feed.acronymIcon == nil && feed.customIconURL == nil {
            generateAcronymIcon(feedID: feed.id, title: feed.title)
        }
        guard !newFeeds.isEmpty else { return }
        notifyIconChange()
        Task { [weak self] in
            await self?.refreshIcons(for: newFeeds)
        }
        Task { [weak self] in
            for feed in newFeeds {
                try? await self?.refreshFeed(feed)
            }
        }
    }

    /// Mirrors `deleteFeed(_:)` minus the tombstone: the deletion originated
    /// remotely, so queueing it again would echo it back to CloudKit.
    private func applyRemoteFeedDeletion(_ feed: Feed) {
        let articleIDs = (try? database.articles(forFeedID: feed.id)).map { $0.map(\.id) } ?? []
        try? database.deleteFeed(id: feed.id)
        PodcastDownloadManager.cleanupOrphanedDownloads()
        SpotlightIndexer.removeArticles(feedID: feed.id, articleIDs: articleIDs)
        Task { await loadFromDatabaseInBackground() }
    }
}
