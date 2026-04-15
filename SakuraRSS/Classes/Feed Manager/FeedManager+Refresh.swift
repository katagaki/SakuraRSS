import Foundation

extension FeedManager {

    // MARK: - Feed Refresh

    func refreshFeed(_ feed: Feed, updateTitle: Bool = true, reloadData: Bool = true) async throws {
        if PetalRecipe.isPetalFeedURL(feed.url) {
            try await refreshPetalFeed(feed, reloadData: reloadData)
            return
        }

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

            // Fall back to HTML metadata (og:image, twitter:image, etc.)
            // for new items the feed itself didn't tag with an image.
            // Existing items are skipped so we don't re-probe pages we've
            // already ingested on every refresh.
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

    /// Returns `[articleURL: imageURL]` for parsed items missing an
    /// image, by scraping each article page's HTML metadata.  Skips
    /// articles already in `skippingURLs` and caps concurrency so a
    /// feed with many imageless items doesn't flood a single host.
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
    /// acronym icons for those feeds.
    ///
    /// Icons are deliberately not refreshed here.  Forcing a favicon
    /// reload after add races with any icon the user has meanwhile
    /// picked from the edit sheet, which reads as the refresh
    /// clobbering their custom icon.  Rows pick up whatever is already
    /// in `FaviconCache` lazily the first time they render.
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
        notifyFaviconChange()
    }

}
