import Foundation
import UIKit

extension FeedManager {

    // MARK: - Feed CRUD

    func addFeed(url: String, title: String, siteURL: String,
                 description: String = "", faviconURL: String? = nil,
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
            description: description, faviconURL: faviconURL,
            category: category, isPodcast: isPodcast
        )
        generateAcronymIcon(feedID: feedID, title: title)
        loadFromDatabase()
        if let feed = feedsByID[feedID] {
            Task {
                try? await refreshFeed(feed)
            }
        }
    }

    func deleteFeed(_ feed: Feed) throws {
        let articleIDs = (try? database.articles(forFeedID: feed.id)).map { $0.map(\.id) } ?? []
        try database.deleteFeed(id: feed.id)
        PodcastDownloadManager.cleanupOrphanedDownloads()
        SpotlightIndexer.removeArticles(feedID: feed.id, articleIDs: articleIDs)
        loadFromDatabase()
    }

    func toggleMuted(_ feed: Feed) {
        try? database.updateFeedMuted(id: feed.id, isMuted: !feed.isMuted)
        loadFromDatabase()
    }

    /// Installs the scraped title + profile photo on the first refresh
    /// after add.  No-op once `feed.lastFetched != nil`.
    func applyScraperMetadataRefresh(
        feed: Feed,
        scrapedTitle: String,
        profileImage: UIImage?
    ) async {
        guard feed.lastFetched == nil else { return }
        let effectiveTitle = feed.isTitleCustomized ? feed.title : scrapedTitle
        let shouldInstallProfilePhoto = profileImage != nil && feed.customIconURL == nil
        let database = database
        if shouldInstallProfilePhoto, let image = profileImage {
            await FaviconCache.shared.setCustomFavicon(
                image, feedID: feed.id, skipTrimming: true
            )
            try? await Task.detached {
                try database.updateFeedDetails(
                    id: feed.id, title: effectiveTitle, url: feed.url,
                    customIconURL: "photo",
                    isTitleCustomized: feed.isTitleCustomized
                )
            }.value
            await MainActor.run { self.notifyFaviconChange() }
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
        if title != feed.title {
            generateAcronymIcon(feedID: feed.id, title: title)
        }
        loadFromDatabase()
        notifyFaviconChange()
    }

}
