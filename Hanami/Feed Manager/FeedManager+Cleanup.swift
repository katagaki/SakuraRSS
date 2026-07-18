import Foundation

public extension FeedManager {

    func deleteArticlesAndVacuum(olderThan date: Date?, includeBookmarks: Bool = false) async {
        let cutoff = date ?? Date()
        UserDefaults.standard.set(cutoff.timeIntervalSince1970, forKey: "Content.CutoffDate")
        let database = database
        let deletedStatusSyncIDs: [String] = await Task.detached {
            var syncIDs: [String] = []
            if let date {
                syncIDs = (try? database.uploadedStatusSyncIDs(
                    olderThan: date, includeBookmarks: includeBookmarks)) ?? []
                try? database.deleteArticles(olderThan: date, includeBookmarks: includeBookmarks)
                try? database.clearImageCache(olderThan: date)
            } else {
                syncIDs = (try? database.allUploadedStatusSyncIDs(includeBookmarks: includeBookmarks)) ?? []
                try? database.deleteAllArticlesOnly(includeBookmarks: includeBookmarks)
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
