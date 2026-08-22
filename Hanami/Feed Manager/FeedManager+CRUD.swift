import Foundation
import UIKit

public extension FeedManager {

    // MARK: - Feed CRUD

    func addFeed(url: String, title: String, siteURL: String,
                 description: String = "", iconURL: String? = nil,
                 category: String? = nil, isPodcast: Bool = false) throws {
        guard !database.feedExists(url: url) else {
            throw FeedError.alreadyExists
        }
        let newHost = URL(string: siteURL)?.host
            ?? URL(string: url)?.host
            ?? ""
        if let key = FollowLimitSetDomains.limitKey(for: newHost),
           let limit = FollowLimitSetDomains.limits[key] {
            let current = feeds.filter { existing in
                FollowLimitSetDomains.limitKey(for: existing.domain) == key
            }.count
            if current >= limit {
                throw FeedError.followLimitExceeded(host: key, limit: limit)
            }
        }
        let feedID = try database.insertFeed(
            title: title, url: url, siteURL: siteURL,
            description: description, iconURL: iconURL,
            category: category, isPodcast: isPodcast
        )
        generateAcronymIcon(feedID: feedID, title: title)
        let newFeed = try? database.feed(byID: feedID)
        CloudSyncEngine.shared.noteFeedChanged(syncID: newFeed?.syncID)
        Task { await loadFromDatabaseInBackground() }
        if let newFeed {
            Task {
                try? await refreshFeed(newFeed)
                reloadWidgetTimelines()
            }
        }
    }

    func deleteFeed(_ feed: Feed) throws {
        let syncID = (try? database.feed(byID: feed.id))?.syncID ?? feed.syncID
        let articleIDs = (try? database.articles(forFeedID: feed.id)).map { $0.map(\.id) } ?? []
        try database.deleteFeed(id: feed.id)
        captureUserFeedDeletion(syncID: syncID)
        PodcastDownloadManager.cleanupOrphanedDownloads()
        SpotlightIndexer.removeArticles(feedID: feed.id, articleIDs: articleIDs)
        Task { await loadFromDatabaseInBackground() }
        reloadWidgetTimelines()
    }

    func toggleMuted(_ feed: Feed) {
        try? database.updateFeedMuted(id: feed.id, isMuted: !feed.isMuted)
        captureUserFeedEdit(feedID: feed.id)
        Task { await loadFromDatabaseInBackground() }
        reloadWidgetTimelines()
    }

    /// Installs the fetchd title + profile photo on the first refresh
    /// after add.  No-op once `feed.lastFetched != nil`.
    func applyFetcherMetadataRefresh(
        feed: Feed,
        fetchdTitle: String,
        profileImage: UIImage?
    ) async {
        guard feed.lastFetched == nil else { return }
        let effectiveTitle = feed.isTitleCustomized ? feed.title : fetchdTitle
        let shouldInstallProfilePhoto = profileImage != nil && feed.customIconURL == nil
        let database = database
        if shouldInstallProfilePhoto, let image = profileImage {
            await Iconography.shared.setCustomIcon(image, feedID: feed.id)
            try? await Task.detached {
                try database.updateFeedDetails(
                    id: feed.id, title: effectiveTitle, url: feed.url,
                    customIconURL: "photo",
                    isTitleCustomized: feed.isTitleCustomized
                )
            }.value
            await MainActor.run { self.notifyIconChange() }
        } else if feed.title != effectiveTitle {
            try? await Task.detached {
                try database.updateFeedDetails(
                    id: feed.id, title: effectiveTitle, url: feed.url,
                    customIconURL: feed.customIconURL,
                    isTitleCustomized: feed.isTitleCustomized
                )
            }.value
        }
    }

    func updateFeedDetails(_ feed: Feed, title: String, url: String,
                           customIconURL: String?) {
        let titleIsCustomized = feed.isTitleCustomized || title != feed.title
        try? database.updateFeedDetails(id: feed.id, title: title, url: url,
                                        customIconURL: customIconURL,
                                        isTitleCustomized: titleIsCustomized)
        captureUserFeedEdit(feedID: feed.id)
        if title != feed.title {
            generateAcronymIcon(feedID: feed.id, title: title)
        }
        Task { await loadFromDatabaseInBackground() }
        notifyIconChange()
    }

    func updateFeedDescription(_ feed: Feed, description: String) {
        guard description != feed.feedDescription else { return }
        try? database.updateFeedDescription(id: feed.id, description: description)
        captureUserFeedEdit(feedID: feed.id)
        Task { await loadFromDatabaseInBackground() }
    }

}
