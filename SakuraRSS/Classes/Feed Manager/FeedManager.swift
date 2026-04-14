import CoreSpotlight
import Foundation
import SwiftUI
import UIKit
@preconcurrency import UserNotifications

@Observable
final class FeedManager {

    var feeds: [Feed] = []
    var articles: [Article] = []
    var lists: [FeedList] = []
    var isLoading = false
    private(set) var dataRevision: Int = 0
    private(set) var faviconRevision: Int = 0
    private(set) var unreadCounts: [Int64: Int] = [:]
    private(set) var feedsByID: [Int64: Feed] = [:]

    let database = DatabaseManager.shared

    init() {
        loadFromDatabase()
    }

    func loadFromDatabase() {
        do {
            feeds = try database.allFeeds()
            feedsByID = Dictionary(uniqueKeysWithValues: feeds.map { ($0.id, $0) })
            articles = try database.allArticles(limit: 200)
            unreadCounts = (try? database.allUnreadCounts()) ?? [:]
            lists = (try? database.allLists()) ?? []
            dataRevision += 1
        } catch {
            print("Failed to load from database: \(error)")
        }
    }

    func loadFromDatabaseInBackground() async {
        let dbm = database
        do {
            let (loadedFeeds, loadedArticles, loadedUnreadCounts, loadedLists) = try await Task.detached {
                let feeds = try dbm.allFeeds()
                let articles = try dbm.allArticles(limit: 200)
                let unreadCounts = (try? dbm.allUnreadCounts()) ?? [:]
                let lists = (try? dbm.allLists()) ?? []
                return (feeds, articles, unreadCounts, lists)
            }.value
            await MainActor.run {
                self.feeds = loadedFeeds
                self.feedsByID = Dictionary(uniqueKeysWithValues: loadedFeeds.map { ($0.id, $0) })
                self.articles = loadedArticles
                self.unreadCounts = loadedUnreadCounts
                self.lists = loadedLists
                self.dataRevision += 1
            }
        } catch {
            print("Failed to load from database: \(error)")
        }
    }

    /// Notify the UI that favicons may have changed so views re-fetch them.
    func notifyFaviconChange() {
        faviconRevision += 1
    }

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

    /// Applies a title/icon update from a social-feed scraper (X,
    /// Instagram, YouTube playlist).  Each scraper fetches a display
    /// name and optionally a profile photo; this helper centralizes
    /// the "install the photo on first fetch, honour user-customized
    /// titles, otherwise just sync the scraped title" logic the three
    /// paths share so the title-customization rule lives in exactly
    /// one place.
    func applyScraperMetadataRefresh(
        feed: Feed,
        scrapedTitle: String,
        profileImage: UIImage?
    ) async {
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
    }

    // MARK: - Feed Refresh

    func refreshFeed(_ feed: Feed, updateTitle: Bool = true, reloadData: Bool = true) async throws {
        if feed.isXFeed {
            guard UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds") else { return }
            try await refreshXFeed(feed, reloadData: reloadData)
            return
        }

        if feed.isInstagramFeed {
            guard UserDefaults.standard.bool(forKey: "Labs.InstagramProfileFeeds") else { return }
            try await refreshInstagramFeed(feed, reloadData: reloadData)
            return
        }

        if feed.isYouTubePlaylistFeed {
            try await refreshYouTubePlaylistFeed(feed, reloadData: reloadData)
            return
        }

        let database = database
        try await Task.detached {
            guard let url = URL(string: feed.url) else { return }
            let fetchURL = RedirectDomains.redirectedURL(url)

            let (data, _) = try await URLSession.shared.data(for: .sakura(url: fetchURL, timeoutInterval: 5))
            let parser = RSSParser()
            guard let parsed = parser.parse(data: data) else { return }

            // Some feeds ship items with no enclosure, media:thumbnail, or
            // inline <img> at all.  For any such item that's new to this
            // feed, fall back to the article page's HTML metadata
            // (`og:image`, `twitter:image`, etc.) so display styles that
            // need a thumbnail still have something to show.  Only new
            // items are probed — existing items already in the DB keep
            // whatever they have to avoid re-hitting the same pages on
            // every refresh.
            let existingURLs = (try? database.existingArticleURLs(forFeedID: feed.id)) ?? []
            let imageBackfills = await FeedManager.backfillMetadataImages(
                for: parsed.articles, skippingURLs: existingURLs
            )

            let articleTuples = parsed.articles.map { article in
                let resolvedImageURL = article.imageURL ?? imageBackfills[article.url]
                return ArticleInsertItem(
                    title: article.title,
                    url: article.url,
                    data: ArticleInsertData(
                        author: article.author,
                        summary: article.summary,
                        content: article.content,
                        imageURL: resolvedImageURL,
                        publishedDate: article.publishedDate,
                        audioURL: article.audioURL,
                        duration: article.duration
                    )
                )
            }

            try database.insertArticles(feedID: feed.id, articles: articleTuples)

            // Skip Spotlight indexing under Low Power Mode so feeds still
            // refresh while deferring the CoreSpotlight writes until LPM
            // turns off.  The next successful refresh outside LPM will
            // re-index the same articles.
            if !ProcessInfo.processInfo.isLowPowerModeEnabled {
                let feedTitleForIndex = parsed.title.isEmpty ? feed.title : parsed.title
                let articlesToIndex = try database.articles(forFeedID: feed.id, limit: articleTuples.count)
                SpotlightIndexer.indexArticles(articlesToIndex, feedTitle: feedTitleForIndex)
            }

            if parsed.isPodcast && !feed.isPodcast {
                try database.updateFeedIsPodcast(id: feed.id, isPodcast: true)
            } else if !parsed.isPodcast && feed.isPodcast {
                try database.updateFeedIsPodcast(id: feed.id, isPodcast: false)
            }
            // Respect user-customized titles: when the user has edited the
            // title via the edit sheet, the refresh should never silently
            // overwrite that override with whatever the remote feed
            // currently advertises.
            if updateTitle, !feed.isTitleCustomized,
               !parsed.title.isEmpty, parsed.title != feed.title {
                try database.updateFeed(id: feed.id, title: parsed.title, category: feed.category)
            }
            try database.updateFeedLastFetched(id: feed.id, date: Date())
        }.value
        if reloadData {
            await loadFromDatabaseInBackground()
        }
    }

    /// Probes article URLs that the parser couldn't find an image for and
    /// returns a `[articleURL: imageURL]` map of any HTML-metadata
    /// fallbacks (Open Graph, Twitter card, schema.org image) that were
    /// recovered.  Skips any article whose URL is in `skippingURLs` —
    /// those have already been ingested and don't need re-probing.
    ///
    /// Probes run in parallel but with a small concurrency cap so a feed
    /// dump of dozens of imageless items doesn't fan out into dozens of
    /// simultaneous HTTP requests against a single host.
    nonisolated static func backfillMetadataImages(
        for articles: [ParsedArticle],
        skippingURLs existingURLs: Set<String>
    ) async -> [String: String] {
        let candidates: [(articleURL: String, requestURL: URL)] = articles.compactMap { article in
            guard article.imageURL == nil,
                  !existingURLs.contains(article.url),
                  let url = URL(string: article.url),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else {
                return nil
            }
            return (article.url, url)
        }
        guard !candidates.isEmpty else { return [:] }

        let maxConcurrent = 4
        var results: [String: String] = [:]
        var index = 0
        while index < candidates.count {
            let batch = candidates[index..<min(index + maxConcurrent, candidates.count)]
            index += maxConcurrent
            await withTaskGroup(of: (String, String?).self) { group in
                for candidate in batch {
                    group.addTask {
                        let imageURL = await HTMLMetadataImage.fetchImageURL(
                            for: candidate.requestURL
                        )
                        return (candidate.articleURL, imageURL)
                    }
                }
                for await (articleURL, imageURL) in group {
                    if let imageURL { results[articleURL] = imageURL }
                }
            }
        }
        return results
    }

    func deleteAllArticlesAndRefresh() async {
        let database = database
        _ = try? await Task.detached { try database.deleteAllArticles() }.value
        SpotlightIndexer.removeAllArticles()
        await loadFromDatabaseInBackground()
        await refreshAllFeeds()
    }

    func reindexAllArticlesInSpotlight() {
        let database = database
        let allFeeds = feeds
        Task.detached(priority: .utility) {
            for feed in allFeeds {
                if let articles = try? database.articles(forFeedID: feed.id) {
                    SpotlightIndexer.indexArticles(articles, feedTitle: feed.title)
                }
            }
        }
    }

    func deleteArticlesAndVacuum(olderThan date: Date?) async {
        let cutoff = date ?? Date()
        UserDefaults.standard.set(cutoff.timeIntervalSince1970, forKey: "Content.CutoffDate")
        let database = database
        _ = try? await Task.detached {
            if let date {
                try database.deleteArticles(olderThan: date)
                try database.clearImageCache(olderThan: date)
            } else {
                try database.deleteAllArticlesOnly()
                try database.clearImageCache()
            }
            try database.vacuum()
            PodcastDownloadManager.cleanupOrphanedDownloads()
        }.value
        SpotlightIndexer.removeAllArticles()
        await loadFromDatabaseInBackground()
    }

    /// Refreshes every feed.
    ///
    /// - Parameters:
    ///   - skipAuthenticatedScrapers: When `true`, X and Instagram
    ///     profile feeds are skipped entirely.  Pass this from background
    ///     refresh tasks.  Both scrapers' cookies now live in Keychain and
    ///     so are technically available in the background, but hitting the
    ///     Instagram/X APIs from a locked device at a fixed scheduler
    ///     cadence is itself a strong bot-like signal — a stronger signal
    ///     than anything else in the request fingerprint — so those
    ///     scrapes are reserved for foreground use.  X additionally still
    ///     depends on a JS-bundle query-ID fetch that is unreliable in a
    ///     `BGAppRefreshTask`.
    ///   - respectCooldown: When `true`, feeds whose `lastFetched` is
    ///     within the user-configured `BackgroundRefresh.Cooldown`
    ///     window are skipped.  Feeds that have never been fetched
    ///     (`lastFetched == nil`) always refresh.  Pass this from
    ///     automatic triggers (background refresh, app startup,
    ///     foreground re-enter).  Leave `false` for explicit user
    ///     actions like pull-to-refresh, which should always refresh
    ///     everything.
    func refreshAllFeeds(
        skipAuthenticatedScrapers: Bool = false,
        respectCooldown: Bool = false
    ) async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        let cooldownSeconds: TimeInterval? = {
            guard respectCooldown else { return nil }
            let raw = UserDefaults.standard.string(forKey: "BackgroundRefresh.Cooldown")
            let cooldown = raw.flatMap(FeedRefreshCooldown.init(rawValue:)) ?? .fiveMinutes
            return cooldown.seconds
        }()
        let now = Date()

        let currentFeeds = feeds
        await withTaskGroup(of: Void.self) { group in
            for feed in currentFeeds {
                if skipAuthenticatedScrapers, feed.isXFeed || feed.isInstagramFeed {
                    continue
                }
                if let cooldownSeconds,
                   let lastFetched = feed.lastFetched,
                   now.timeIntervalSince(lastFetched) < cooldownSeconds {
                    // Inside the cooldown window.  A nil lastFetched
                    // means the feed has never been refreshed (new or
                    // freshly imported), so it always proceeds.
                    continue
                }
                group.addTask {
                    try? await self.refreshFeed(feed, reloadData: false)
                }
            }
        }
        await loadFromDatabaseInBackground()
    }

    /// Refreshes feeds that have never been fetched (e.g. added by the share
    /// extension while the main app was in the background).  Also generates
    /// acronym icons and fetches favicons for those feeds.
    func refreshUnfetchedFeeds() async {
        let unfetched = feeds.filter { $0.lastFetched == nil }
        guard !unfetched.isEmpty else { return }

        // Generate acronym icons the share extension doesn't create.
        for feed in unfetched {
            generateAcronymIcon(feedID: feed.id, title: feed.title)
        }

        // Fetch articles for the new feeds.
        await withTaskGroup(of: Void.self) { group in
            for feed in unfetched {
                group.addTask {
                    try? await self.refreshFeed(feed, reloadData: false)
                }
            }
        }
        await loadFromDatabaseInBackground()

        // Clear any stale favicon failures and notify the UI so
        // FeedRowViews re-fetch their icons.
        let entries = unfetched.map { ($0.domain, $0.siteURL as String?) }
        await FaviconCache.shared.clearFailedLookups(for: entries)
        faviconRevision += 1
    }

    func refreshAllFeedsAndFavicons() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        let currentFeeds = feeds
        async let feedRefresh: Void = withTaskGroup(of: Void.self) { group in
            for feed in currentFeeds {
                group.addTask {
                    try? await self.refreshFeed(feed, updateTitle: false, reloadData: false)
                }
            }
        }
        async let faviconRefresh: Void = FaviconCache.shared.refreshFavicons(
            for: currentFeeds.map { ($0.domain, $0.siteURL as String?) }
        )
        _ = await (feedRefresh, faviconRefresh)
        await loadFromDatabaseInBackground()
        regenerateAllAcronymIcons()
        faviconRevision += 1
    }

    // MARK: - Badge

    func updateBadgeCount() {
        let mode = UserDefaults.standard.string(forKey: "Display.UnreadBadgeMode") ?? "none"
        let center = UNUserNotificationCenter.current()
        guard mode == "homeScreenAndHomeTab" || mode == "homeScreenOnly" else {
            Task { try? await center.setBadgeCount(0) }
            return
        }
        Task {
            let settings = await center.notificationSettings()
            guard settings.badgeSetting == .enabled else { return }
            let count = self.totalUnreadCount()
            try? await center.setBadgeCount(count)
        }
    }

    // MARK: - Lookups

    var mutedFeedIDs: Set<Int64> {
        Set(feeds.filter(\.isMuted).map(\.id))
    }

    func feed(forArticle article: Article) -> Feed? {
        feedsByID[article.feedID]
    }

    func article(byID id: Int64) -> Article? {
        articles.first { $0.id == id } ?? (try? database.article(byID: id))
    }

    // MARK: - Acronym Icons

    func generateAcronymIcon(feedID: Int64, title: String) {
        guard let image = InitialsAvatarView.renderToImage(name: title),
              let pngData = image.pngData() else { return }
        try? database.updateFeedAcronymIcon(id: feedID, data: pngData)
    }

    func regenerateAllAcronymIcons() {
        for feed in feeds {
            generateAcronymIcon(feedID: feed.id, title: feed.title)
        }
    }

}

enum FeedError: LocalizedError {
    case alreadyExists
    case followLimitExceeded(host: String, limit: Int)

    var errorDescription: String? {
        switch self {
        case .alreadyExists:
            String(localized: "FeedError.AlreadyExists")
        case .followLimitExceeded(let host, let limit):
            String(localized: "FeedError.FollowLimitExceeded \(host) \(limit)")
        }
    }
}
