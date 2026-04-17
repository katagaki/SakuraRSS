import Foundation

extension FeedManager {

    // MARK: - Feed Refresh

    func refreshFeed(
        _ feed: Feed,
        updateTitle: Bool = true,
        reloadData: Bool = true,
        skipImageBackfill: Bool = false
    ) async throws {
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

            let existingURLs = (try? database.existingArticleURLs(forFeedID: feed.id)) ?? []
            let imageBackfills: [String: String]
            if skipImageBackfill {
                imageBackfills = [:]
            } else {
                imageBackfills = await FeedManager.backfillMetadataImages(
                    for: parsed.articles, skippingURLs: existingURLs
                )
            }

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

            let insertedIDs = try database.insertArticles(feedID: feed.id, articles: articleTuples)

            if !insertedIDs.isEmpty, !ProcessInfo.processInfo.isLowPowerModeEnabled {
                let feedTitleForIndex = parsed.title.isEmpty ? feed.title : parsed.title
                let articlesToIndex = try database.articles(withIDs: insertedIDs)
                SpotlightIndexer.indexArticles(articlesToIndex, feedTitle: feedTitleForIndex)
            }

            if feed.lastFetched == nil {
                if parsed.isPodcast && !feed.isPodcast {
                    try database.updateFeedIsPodcast(id: feed.id, isPodcast: true)
                } else if !parsed.isPodcast && feed.isPodcast {
                    try database.updateFeedIsPodcast(id: feed.id, isPodcast: false)
                }
                if updateTitle, !feed.isTitleCustomized,
                   !parsed.title.isEmpty, parsed.title != feed.title {
                    try database.updateFeed(
                        id: feed.id, title: parsed.title, category: feed.category
                    )
                }
            }
            try database.updateFeedLastFetched(id: feed.id, date: Date())
        }.value
        if reloadData {
            await loadFromDatabaseInBackground()
        }
    }

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

    /// Refreshes every feed.  `skipAuthenticatedScrapers` omits X and
    /// Instagram profile feeds (pass from background refresh tasks).
    /// `respectCooldown` skips feeds whose `lastFetched` is within the
    /// `BackgroundRefresh.Cooldown` window; feeds with nil `lastFetched`
    /// always refresh.  `skipImageBackfill` disables the HTML metadata
    /// image lookup per article (cellular-safe background paths set
    /// this when the user has the Wi-Fi-only backfill preference on).
    func refreshAllFeeds(
        skipAuthenticatedScrapers: Bool = false,
        respectCooldown: Bool = false,
        skipImageBackfill: Bool = false
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
        let feedsToRefresh = currentFeeds.filter { feed in
            if skipAuthenticatedScrapers, feed.isXFeed || feed.isInstagramFeed {
                return false
            }
            if let cooldownSeconds,
               let lastFetched = feed.lastFetched,
               now.timeIntervalSince(lastFetched) < cooldownSeconds {
                return false
            }
            return true
        }
        // Bounded concurrency so libraries with 100+ feeds don't spawn
        // 100+ simultaneous URLSession tasks.  Empirically past ~8
        // in-flight fetches end-to-end wall time stops improving on
        // cellular and regresses on Wi-Fi due to contention with the
        // main-actor reload work; 8 matches the parallelism already
        // used by `backfillMetadataImages`.
        let maxConcurrent = 8
        await withTaskGroup(of: Void.self) { group in
            var submitted = 0
            var iterator = feedsToRefresh.makeIterator()
            while submitted < maxConcurrent, let feed = iterator.next() {
                group.addTask {
                    try? await self.refreshFeed(
                        feed,
                        reloadData: false,
                        skipImageBackfill: skipImageBackfill
                    )
                }
                submitted += 1
            }
            while await group.next() != nil {
                if let feed = iterator.next() {
                    group.addTask {
                        try? await self.refreshFeed(
                            feed,
                            reloadData: false,
                            skipImageBackfill: skipImageBackfill
                        )
                    }
                }
            }
        }
        await loadFromDatabaseInBackground()
    }

    /// Refreshes feeds that have never been fetched (e.g. added by the
    /// share extension while the main app was in the background).
    func refreshUnfetchedFeeds() async {
        let unfetched = feeds.filter { $0.lastFetched == nil }
        guard !unfetched.isEmpty else { return }

        for feed in unfetched {
            generateAcronymIcon(feedID: feed.id, title: feed.title)
        }

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
        let maxConcurrent = 8
        async let feedRefresh: Void = withTaskGroup(of: Void.self) { group in
            var submitted = 0
            var iterator = currentFeeds.makeIterator()
            while submitted < maxConcurrent, let feed = iterator.next() {
                group.addTask {
                    try? await self.refreshFeed(feed, updateTitle: false, reloadData: false)
                }
                submitted += 1
            }
            while await group.next() != nil {
                if let feed = iterator.next() {
                    group.addTask {
                        try? await self.refreshFeed(feed, updateTitle: false, reloadData: false)
                    }
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
