import Foundation

public extension FeedManager {

    /// `keeping` is content still open somewhere, which is never cleaned up.
    func deleteArticlesAndVacuum(
        olderThan date: Date?, includeBookmarks: Bool = false, keeping: Set<Int64> = []
    ) async {
        let cutoff = date ?? Date()
        UserDefaults.standard.set(cutoff.timeIntervalSince1970, forKey: "Content.CutoffDate")
        let database = database
        let deletedStatusSyncIDs: [String] = await Task.detached {
            var syncIDs: [String] = []
            if let date {
                syncIDs = (try? database.uploadedStatusSyncIDs(
                    olderThan: date, includeBookmarks: includeBookmarks, keeping: keeping)) ?? []
                try? database.deleteArticles(olderThan: date, includeBookmarks: includeBookmarks, keeping: keeping)
                try? database.clearImageCache(olderThan: date)
            } else {
                syncIDs = (try? database.allUploadedStatusSyncIDs(
                    includeBookmarks: includeBookmarks, keeping: keeping)) ?? []
                try? database.deleteAllArticlesOnly(includeBookmarks: includeBookmarks, keeping: keeping)
                try? database.clearImageCache()
            }
            try? database.vacuum()
            PodcastDownloadManager.cleanupOrphanedDownloads()
            return syncIDs
        }.value
        CloudSyncEngine.shared.noteItemStatusesDeleted(syncIDs: deletedStatusSyncIDs)
        SpotlightIndexer.removeAllArticles()
        await loadFromDatabaseInBackground()
    }
}
