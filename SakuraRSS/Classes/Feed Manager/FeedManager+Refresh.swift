import Foundation

extension FeedManager {

    // MARK: - Feed Refresh

    func refreshFeed(
        _ feed: Feed,
        updateTitle: Bool = true,
        reloadData: Bool = true,
        skipImageFetch: Bool = false,
        imagePreloadCollector: ImagePreloadCollector? = nil
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

            let feedDomain = feed.domain
            let preparedArticles = parsed.articles.map { article in
                BodyPriorityDomains.applying(to: article, feedDomain: feedDomain)
            }

            let existingURLs = (try? database.existingArticleURLs(forFeedID: feed.id)) ?? []
            let metadataImages: [String: String]
            if skipImageFetch {
                metadataImages = [:]
            } else {
                metadataImages = await FeedManager.fetchMetadataImages(
                    for: preparedArticles, skippingURLs: existingURLs
                )
            }

            let redditImages: [String: String] = (!skipImageFetch && feed.isRedditFeed)
                ? await FeedManager.fetchRedditImages(forFeedURL: feed.url)
                : [:]

            let articleTuples = preparedArticles.map { article in
                let redditImage = FeedManager.redditImageURL(
                    for: article.url, in: redditImages
                )
                let resolvedImageURL = redditImage
                    ?? article.imageURL
                    ?? metadataImages[article.url]
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

            if !insertedIDs.isEmpty {
                let insertedArticles = (try? database.articles(withIDs: insertedIDs)) ?? []
                if !ProcessInfo.processInfo.isLowPowerModeEnabled {
                    let feedTitleForIndex = parsed.title.isEmpty ? feed.title : parsed.title
                    SpotlightIndexer.indexArticles(insertedArticles, feedTitle: feedTitleForIndex)
                }
                if let imagePreloadCollector {
                    let imageURLs = insertedArticles.compactMap { $0.imageURL }
                    if !imageURLs.isEmpty {
                        await imagePreloadCollector.add(imageURLs)
                    }
                }
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
            await loadFromDatabaseInBackground(animated: true)
        }
    }

    nonisolated static func fetchMetadataImages(
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

    /// Refreshes every feed, optionally chaining the NLP pass.
    func refreshAllFeeds(
        skipAuthenticatedScrapers: Bool = false,
        respectCooldown: Bool = false,
        skipImageFetch: Bool = false,
        skipImagePreload: Bool = false,
        runNLPAfter: Bool = false
    ) async {
        let cooldownSeconds: TimeInterval? = {
            guard respectCooldown else { return nil }
            let raw = UserDefaults.standard.string(forKey: "BackgroundRefresh.Cooldown")
            let cooldown = raw.flatMap(FeedRefreshCooldown.init(rawValue:)) ?? .fiveMinutes
            return cooldown.seconds
        }()
        let now = Date()

        let preloadModeRaw = UserDefaults.standard.string(
            forKey: "FeedRefresh.PreloadArticleImagesMode"
        )
        let preloadMode = preloadModeRaw
            .flatMap(FetchImagesMode.init(rawValue:)) ?? .wifiOnly
        let imagePreloadCollector: ImagePreloadCollector? = (
            !skipImagePreload && preloadMode != .off
        ) ? ImagePreloadCollector() : nil

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

        let slowFeeds = feedsToRefresh.filter { $0.isSlowRefreshFeed }
        let regularFeeds = feedsToRefresh.filter { !$0.isSlowRefreshFeed }

        await MainActor.run {
            isLoading = true
            refreshCompleted = 0
            refreshTotal = feedsToRefresh.count
            nlpCompleted = 0
            nlpTotal = 0
        }
        defer {
            Task { @MainActor in
                self.isLoading = false
                self.refreshCompleted = 0
                self.refreshTotal = 0
                self.nlpCompleted = 0
                self.nlpTotal = 0
                self.refreshTask = nil
            }
        }

        let work = Task { [weak self] in
            guard let self else { return }
            async let slow: Void = self.runBoundedRefresh(
                slowFeeds,
                maxConcurrent: 2,
                skipImageFetch: skipImageFetch,
                imagePreloadCollector: imagePreloadCollector
            )
            async let regular: Void = self.runBoundedRefresh(
                regularFeeds,
                maxConcurrent: 8,
                skipImageFetch: skipImageFetch,
                imagePreloadCollector: imagePreloadCollector
            )
            _ = await (slow, regular)

            if runNLPAfter, !Task.isCancelled,
               !ProcessInfo.processInfo.isLowPowerModeEnabled {
                await self.processNewArticlesWithProgress()
            }
        }
        await MainActor.run { self.refreshTask = work }
        _ = await work.value
        await loadFromDatabaseInBackground(animated: true)

        if let imagePreloadCollector, !Task.isCancelled {
            let urls = await imagePreloadCollector.drain()
            if !urls.isEmpty {
                let expensive: Bool
                switch preloadMode {
                case .always: expensive = false
                case .wifiOnly: expensive = await NetworkMonitor.currentPathIsExpensive() ?? true
                case .off: expensive = true
                }
                if !expensive {
                    Task.detached(priority: .utility) {
                        await FeedManager.preloadImages(urls: urls)
                    }
                }
            }
        }
    }

    fileprivate func runBoundedRefresh(
        _ feeds: [Feed],
        maxConcurrent: Int,
        skipImageFetch: Bool,
        imagePreloadCollector: ImagePreloadCollector?
    ) async {
        guard !feeds.isEmpty else { return }
        await withTaskGroup(of: Void.self) { group in
            var submitted = 0
            var iterator = feeds.makeIterator()
            while submitted < maxConcurrent, !Task.isCancelled, let feed = iterator.next() {
                group.addTask { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    try? await self.refreshFeed(
                        feed,
                        reloadData: false,
                        skipImageFetch: skipImageFetch,
                        imagePreloadCollector: imagePreloadCollector
                    )
                    if !Task.isCancelled {
                        await MainActor.run { self.refreshCompleted += 1 }
                    }
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
                        try? await self.refreshFeed(
                            feed,
                            reloadData: false,
                            skipImageFetch: skipImageFetch,
                            imagePreloadCollector: imagePreloadCollector
                        )
                        if !Task.isCancelled {
                            await MainActor.run { self.refreshCompleted += 1 }
                        }
                    }
                }
            }
        }
    }

    fileprivate func processNewArticlesWithProgress() async {
        await NLPProcessingCoordinator.processNewArticlesIfEnabled(
            onBegin: { [weak self] total in
                await MainActor.run { self?.nlpTotal = total }
            },
            onProgress: { [weak self] delta in
                await MainActor.run { self?.nlpCompleted += delta }
            }
        )
    }

    /// Refreshes feeds that have never been fetched.
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
        await loadFromDatabaseInBackground(animated: true)
    }

    func refreshAllFeedsAndFavicons() async {
        let currentFeeds = feeds
        await MainActor.run {
            isLoading = true
            refreshCompleted = 0
            refreshTotal = currentFeeds.count
        }
        defer {
            Task { @MainActor in
                self.isLoading = false
                self.refreshCompleted = 0
                self.refreshTotal = 0
                self.refreshTask = nil
            }
        }

        let maxConcurrent = 8
        let work = Task { [weak self] in
            guard let self else { return }
            async let feedRefresh: Void = withTaskGroup(of: Void.self) { group in
                var submitted = 0
                var iterator = currentFeeds.makeIterator()
                while submitted < maxConcurrent, !Task.isCancelled, let feed = iterator.next() {
                    group.addTask {
                        guard !Task.isCancelled else { return }
                        try? await self.refreshFeed(feed, updateTitle: false, reloadData: false)
                        if !Task.isCancelled {
                            await MainActor.run { self.refreshCompleted += 1 }
                        }
                    }
                    submitted += 1
                }
                while await group.next() != nil {
                    if Task.isCancelled {
                        group.cancelAll()
                        continue
                    }
                    if let feed = iterator.next() {
                        group.addTask {
                            guard !Task.isCancelled else { return }
                            try? await self.refreshFeed(feed, updateTitle: false, reloadData: false)
                            if !Task.isCancelled {
                                await MainActor.run { self.refreshCompleted += 1 }
                            }
                        }
                    }
                }
            }
            async let faviconRefresh: Void = FaviconCache.shared.refreshFavicons(
                for: currentFeeds.map { ($0.domain, $0.siteURL as String?) }
            )
            _ = await (feedRefresh, faviconRefresh)
        }
        await MainActor.run { self.refreshTask = work }
        _ = await work.value
        await loadFromDatabaseInBackground(animated: true)
        regenerateAllAcronymIcons()
        notifyFaviconChange()
    }

    /// Cancels the in-flight refresh task; `defer` in the refresh method tears down UI state.
    @MainActor
    func cancelRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        isLoading = false
        refreshCompleted = 0
        refreshTotal = 0
        nlpCompleted = 0
        nlpTotal = 0
    }

}
