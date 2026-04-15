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
        // Enforce per-host follow caps for authenticated scraper feeds
        // (X, Instagram).  Unbounded follows on these hosts translate
        // into rate-limit / account-lock pressure at refresh time, so
        // the cap is applied at insert to keep the fleet small enough
        // for the 30-minute refresh cadence to stay safe.
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
        // Fetch the feed's articles in the background
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

    /// Applies the title + profile photo fetched by a social-feed
    /// scraper (X, Instagram, YouTube playlist) on the *first* refresh
    /// of a freshly-added feed.  Once `feed.lastFetched != nil` this
    /// helper is a no-op: every subsequent refresh leaves the title
    /// and icon alone, so user edits from the edit sheet are the sole
    /// source of truth after add.
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
        // A user-driven title change (from the edit sheet) flips the
        // `isTitleCustomized` flag so future refreshes won't overwrite
        // it.  If the user never touched the title we leave the existing
        // flag alone — that way a user who previously customized and is
        // now only editing the URL or icon doesn't accidentally clear
        // their override.
        let titleIsCustomized = feed.isTitleCustomized || title != feed.title
        try? database.updateFeedDetails(id: feed.id, title: title, url: url,
                                        customIconURL: customIconURL,
                                        isTitleCustomized: titleIsCustomized)
        if title != feed.title {
            generateAcronymIcon(feedID: feed.id, title: title)
        }
        loadFromDatabase()
        // Feed rows cache their favicon in @State from a one-shot
        // `.task`, so without a revision bump they keep showing the
        // pre-edit icon until they scroll off-screen and back.  Users
        // see the stale image after pull-to-refresh and conclude the
        // refresh clobbered their override, when really the edit just
        // never propagated.  Bump the revision so every visible row
        // re-queries `FaviconCache.favicon(for: feed)` and picks up
        // the newly-saved custom icon.
        notifyFaviconChange()
    }

}
