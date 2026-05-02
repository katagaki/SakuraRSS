import Foundation

extension FeedManager {

    // MARK: - Feed Refresh

    /// Runs the full per-feed pipeline: fetch -> parse -> metadata images -> insert
    /// -> spotlight -> image preload -> NLP.
    func refreshFeed(
        _ feed: Feed,
        updateTitle: Bool = true,
        reloadData: Bool = true,
        skipImageFetch: Bool = false,
        skipImagePreload: Bool = false,
        runNLP: Bool = true
    ) async throws {
        // swiftlint:disable:next line_length
        log("FeedRefresh", "refreshFeed begin id=\(feed.id) title=\(feed.title) url=\(feed.url) reloadData=\(reloadData) skipImageFetch=\(skipImageFetch) skipImagePreload=\(skipImagePreload) runNLP=\(runNLP)")
        if PetalRecipe.isPetalFeedURL(feed.url) {
            log("FeedRefresh", "dispatch -> Petal id=\(feed.id)")
            try await refreshPetalFeed(
                feed,
                reloadData: reloadData,
                skipImagePreload: skipImagePreload,
                runNLP: runNLP
            )
            return
        }

        if let provider = FeedProviderRegistry.refreshableProvider(forFeedURL: feed.url) {
            guard provider.isEnabled else {
                log("FeedRefresh", "provider \(String(describing: provider)) disabled - skipping id=\(feed.id)")
                return
            }
            log("FeedRefresh", "dispatch -> provider=\(String(describing: provider)) id=\(feed.id)")
            try await provider.refresh(
                feed: feed,
                on: self,
                reloadData: reloadData,
                skipImagePreload: skipImagePreload,
                runNLP: runNLP
            )
            return
        }

        log("FeedRefresh", "dispatch -> standard RSS pipeline id=\(feed.id)")
        let database = database
        try await Task.detached {
            try await FeedManager.runStandardFeedPipeline(
                feed: feed,
                database: database,
                updateTitle: updateTitle,
                skipImageFetch: skipImageFetch,
                skipImagePreload: skipImagePreload,
                runNLP: runNLP
            )
        }.value
        await MainActor.run { self.bumpDataRevision() }
        if reloadData {
            await loadFromDatabaseInBackground(animated: true)
        }
        log("FeedRefresh", "refreshFeed end id=\(feed.id)")
    }

    /// Fetches and parses an RSS feed, resolves images, inserts new articles,
    /// runs the post-insert pipeline, and updates feed metadata.
    nonisolated static func runStandardFeedPipeline( // swiftlint:disable:this function_body_length
        feed: Feed,
        database: DatabaseManager,
        updateTitle: Bool,
        skipImageFetch: Bool,
        skipImagePreload: Bool,
        runNLP: Bool
    ) async throws {
        guard let url = URL(string: feed.fetchURL) else {
            log("FeedRefresh.RSS", "invalid fetch URL id=\(feed.id) fetchURL=\(feed.fetchURL)")
            return
        }
        let fetchURL = RedirectDomains.redirectedURL(url)
        log("FeedRefresh.RSS", "fetch begin id=\(feed.id) url=\(fetchURL.absoluteString)")

        var request = URLRequest.sakura(url: fetchURL, timeoutInterval: 5)
        if feed.isSubstackFeed, let host = fetchURL.host,
           let cookieHeader = SubstackAuth.cookieHeader(for: host) {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let contentType = (response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Type") ?? "unknown"
        // swiftlint:disable:next line_length
        log("FeedRefresh.RSS", "fetch ok id=\(feed.id) bytes=\(data.count) status=\(statusCode) contentType=\(contentType)")
        let parser = RSSParser()
        guard let parsed = parser.parse(data: data) else {
            let bodyHint = bodyContentHint(data: data)
            // swiftlint:disable:next line_length
            log("FeedRefresh.RSS", "parse failed id=\(feed.id) status=\(statusCode) contentType=\(contentType) bytes=\(data.count) hint=\(bodyHint)")
            return
        }
        // swiftlint:disable:next line_length
        log("FeedRefresh.RSS", "parsed id=\(feed.id) articles=\(parsed.articles.count) title=\(parsed.title) isPodcast=\(parsed.isPodcast)")

        if let generator = parsed.generator,
           generator.lowercased().contains("substack"),
           !SubstackAuth.isWrappedFeedURL(feed.url) {
            try? database.updateFeedURL(id: feed.id, url: SubstackAuth.wrap(feed.url))
        }

        let existingURLs = (try? database.existingArticleURLs(forFeedID: feed.id)) ?? []
        let metadataImages: [String: String]
        if skipImageFetch {
            metadataImages = [:]
        } else {
            metadataImages = await FeedManager.fetchMetadataImages(
                for: parsed.articles, skippingURLs: existingURLs
            )
        }

        let redditImages: [String: String] = (!skipImageFetch && feed.isRedditFeed)
            ? await FeedManager.fetchRedditImages(forFeedURL: feed.url)
            : [:]

        let articleTuples = parsed.articles.map { article in
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

        let feedTitleForIndex = parsed.title.isEmpty ? feed.title : parsed.title
        let insertedIDs = (try? database.insertArticles(
            feedID: feed.id, articles: articleTuples
        )) ?? []
        // swiftlint:disable:next line_length
        log("FeedRefresh.RSS", "inserted id=\(feed.id) new=\(insertedIDs.count)/\(articleTuples.count) metadataImages=\(metadataImages.count) redditImages=\(redditImages.count)")

        await FeedManager.runPostInsertPipeline(
            insertedIDs: insertedIDs,
            feedTitle: feedTitleForIndex,
            skipImagePreload: skipImagePreload,
            runNLP: runNLP
        )

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
            if parsed.description != feed.feedDescription {
                try? database.updateFeedDescription(id: feed.id, description: parsed.description)
            }
        }
        try database.updateFeedLastFetched(id: feed.id, date: Date())
        log("FeedRefresh.RSS", "pipeline complete id=\(feed.id)")
    }

    /// Spotlight indexing, image preloading, and NLP for the articles a feed
    /// just inserted. Runs as the tail of the per-feed pipeline so each feed
    /// finishes its work end-to-end before the next stage of the queue starts.
    nonisolated static func runPostInsertPipeline(
        insertedIDs: [Int64],
        feedTitle: String,
        skipImagePreload: Bool,
        runNLP: Bool
    ) async {
        guard !insertedIDs.isEmpty else { return }
        let database = DatabaseManager.shared
        let insertedArticles = (try? database.articles(withIDs: insertedIDs)) ?? []
        if insertedArticles.isEmpty { return }
        // swiftlint:disable:next line_length
        log("FeedRefresh.PostInsert", "begin feedTitle=\(feedTitle) count=\(insertedArticles.count) skipImagePreload=\(skipImagePreload) runNLP=\(runNLP)")

        if !ProcessInfo.processInfo.isLowPowerModeEnabled {
            SpotlightIndexer.indexArticles(insertedArticles, feedTitle: feedTitle)
            log("FeedRefresh.PostInsert", "spotlight indexed feedTitle=\(feedTitle) count=\(insertedArticles.count)")
        }
        if Task.isCancelled {
            log("FeedRefresh.PostInsert", "cancelled before image preload feedTitle=\(feedTitle)")
            return
        }

        if !skipImagePreload {
            let imageURLs = insertedArticles.compactMap { $0.imageURL }
            if !imageURLs.isEmpty {
                log("FeedRefresh.PostInsert", "preloading images feedTitle=\(feedTitle) count=\(imageURLs.count)")
                await FeedManager.preloadImages(urls: imageURLs)
            }
        }
        if Task.isCancelled {
            log("FeedRefresh.PostInsert", "cancelled before NLP feedTitle=\(feedTitle)")
            return
        }

        if runNLP {
            log("FeedRefresh.PostInsert", "queuing NLP feedTitle=\(feedTitle) count=\(insertedIDs.count)")
            await NLPProcessingCoordinator.processArticles(ids: insertedIDs)
        }
        log("FeedRefresh.PostInsert", "end feedTitle=\(feedTitle)")
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

    // swiftlint:disable:next function_body_length
    func refreshAllFeeds(
        skipAuthenticatedFetchers: Bool = false,
        respectCooldown: Bool = false,
        skipImageFetch: Bool = false,
        skipImagePreload: Bool = false,
        runNLPAfter: Bool = false
    ) async {
        // swiftlint:disable:next line_length
        log("FeedRefresh.All", "begin total=\(feeds.count) skipAuthenticatedFetchers=\(skipAuthenticatedFetchers) respectCooldown=\(respectCooldown) skipImageFetch=\(skipImageFetch) skipImagePreload=\(skipImagePreload) runNLPAfter=\(runNLPAfter)")
        let cooldownSeconds: TimeInterval? = {
            guard respectCooldown else { return nil }
            let raw = UserDefaults.standard.string(forKey: "BackgroundRefresh.Cooldown")
            let cooldown = raw.flatMap(FeedRefreshCooldown.init(rawValue:)) ?? .fiveMinutes
            return cooldown.seconds
        }()
        let now = Date()
        let currentFeeds = feeds
        let feedsToRefresh = currentFeeds.filter { feed in
            if skipAuthenticatedFetchers, feed.isXFeed || feed.isInstagramFeed {
                return false
            }
            let domainTimeout = RefreshTimeoutDomains.refreshTimeout(for: feed.domain)
            let effectiveCooldown = domainTimeout ?? cooldownSeconds
            if let effectiveCooldown,
               let lastFetched = feed.lastFetched,
               now.timeIntervalSince(lastFetched) < effectiveCooldown {
                return false
            }
            return true
        }
        guard !feedsToRefresh.isEmpty else {
            // swiftlint:disable:next line_length
            log("FeedRefresh.All", "no feeds eligible after filter (cooldown=\(cooldownSeconds.map { String(Int($0)) } ?? "off")s)")
            return
        }

        let slowFeeds = feedsToRefresh.filter { $0.isSlowRefreshFeed }
        let regularFeeds = feedsToRefresh.filter { !$0.isSlowRefreshFeed }
        log("FeedRefresh.All", "eligible=\(feedsToRefresh.count) slow=\(slowFeeds.count) regular=\(regularFeeds.count)")

        await MainActor.run {
            isLoading = true
            refreshCompleted = 0
            refreshTotal = feedsToRefresh.count
        }
        defer {
            Task { @MainActor in
                self.isLoading = false
                self.refreshCompleted = 0
                self.refreshTotal = 0
                self.refreshTask = nil
                self.lastRefreshedAt = Date()
            }
        }

        let preloadModeRaw = UserDefaults.standard.string(
            forKey: "FeedRefresh.PreloadArticleImagesMode"
        )
        let preloadMode = preloadModeRaw
            .flatMap(FetchImagesMode.init(rawValue:)) ?? .wifiOnly
        let effectiveSkipPreload: Bool
        if skipImagePreload {
            effectiveSkipPreload = true
        } else {
            switch preloadMode {
            case .always: effectiveSkipPreload = false
            case .wifiOnly: effectiveSkipPreload = await NetworkMonitor.currentPathIsExpensive() ?? true
            case .off: effectiveSkipPreload = true
            }
        }

        let work = Task { [weak self] in
            guard let self else { return }
            async let slow: Void = self.runBoundedRefresh(
                slowFeeds,
                maxConcurrent: 2,
                skipImageFetch: skipImageFetch,
                skipImagePreload: effectiveSkipPreload,
                runNLP: runNLPAfter
            )
            async let regular: Void = self.runBoundedRefresh(
                regularFeeds,
                maxConcurrent: 8,
                skipImageFetch: skipImageFetch,
                skipImagePreload: effectiveSkipPreload,
                runNLP: runNLPAfter
            )
            _ = await (slow, regular)
        }
        await MainActor.run { self.refreshTask = work }
        _ = await work.value
        await loadFromDatabaseInBackground(animated: true)
        log("FeedRefresh.All", "end completed=\(refreshCompleted)/\(refreshTotal)")
    }

    fileprivate func runBoundedRefresh(
        _ feeds: [Feed],
        maxConcurrent: Int,
        skipImageFetch: Bool,
        skipImagePreload: Bool,
        runNLP: Bool
    ) async {
        guard !feeds.isEmpty else { return }
        log("FeedRefresh.Bounded", "begin count=\(feeds.count) maxConcurrent=\(maxConcurrent)")
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
                        skipImagePreload: skipImagePreload,
                        runNLP: runNLP
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
                            skipImagePreload: skipImagePreload,
                            runNLP: runNLP
                        )
                        if !Task.isCancelled {
                            await MainActor.run { self.refreshCompleted += 1 }
                        }
                    }
                }
            }
        }
        log("FeedRefresh.Bounded", "end count=\(feeds.count)")
    }

    /// Refreshes feeds that have never been fetched.
    func refreshUnfetchedFeeds() async {
        let unfetched = feeds.filter { $0.lastFetched == nil }
        guard !unfetched.isEmpty else {
            log("FeedRefresh.Unfetched", "no unfetched feeds")
            return
        }
        log("FeedRefresh.Unfetched", "begin count=\(unfetched.count)")

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
        log("FeedRefresh.Unfetched", "end count=\(unfetched.count)")
    }

    // swiftlint:disable:next function_body_length
    func refreshAllFeedsAndIcons() async {
        let currentFeeds = feeds
        log("FeedRefresh.AllAndIcons", "begin count=\(currentFeeds.count)")
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
                self.lastRefreshedAt = Date()
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
                        try? await self.refreshFeed(
                            feed,
                            updateTitle: false,
                            reloadData: false
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
                        group.addTask {
                            guard !Task.isCancelled else { return }
                            try? await self.refreshFeed(
                                feed,
                                updateTitle: false,
                                reloadData: false
                            )
                            if !Task.isCancelled {
                                await MainActor.run { self.refreshCompleted += 1 }
                            }
                        }
                    }
                }
            }
            async let iconRefresh: Void = IconCache.shared.refreshIcons(
                for: currentFeeds.map { ($0.domain, $0.siteURL as String?) }
            )
            _ = await (feedRefresh, iconRefresh)
        }
        await MainActor.run { self.refreshTask = work }
        _ = await work.value
        await loadFromDatabaseInBackground(animated: true)
        regenerateAllAcronymIcons()
        notifyIconChange()
        log("FeedRefresh.AllAndIcons", "end completed=\(refreshCompleted)/\(refreshTotal)")
    }

    /// Cancels the in-flight refresh task. Feeds whose RSS fetch has already
    /// completed run their pipeline through to insert; feeds still waiting on
    /// the network drop their work. Triggers a database reload so any articles
    /// collected up to the cancel point appear immediately.
    @MainActor
    func cancelRefresh() {
        log("FeedRefresh", "cancelRefresh hadTask=\(refreshTask != nil) completed=\(refreshCompleted)/\(refreshTotal)")
        refreshTask?.cancel()
        refreshTask = nil
        isLoading = false
        refreshCompleted = 0
        refreshTotal = 0
        Task { await self.loadFromDatabaseInBackground(animated: true) }
    }

    /// Classifies a non-XML response body so parse-failure logs show why
    /// (e.g. YouTube returning an HTML 500 page instead of an Atom feed).
    nonisolated static func bodyContentHint(data: Data) -> String {
        if data.isEmpty { return "empty" }
        let prefix = data.prefix(512)
        guard let snippet = String(data: prefix, encoding: .utf8)
                ?? String(data: prefix, encoding: .isoLatin1) else {
            return "binary"
        }
        let trimmed = snippet
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if trimmed.hasPrefix("<!doctype html") || trimmed.hasPrefix("<html") {
            return "html"
        }
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            return "json"
        }
        if trimmed.hasPrefix("<?xml") || trimmed.hasPrefix("<rss")
            || trimmed.hasPrefix("<feed") || trimmed.hasPrefix("<atom") {
            return "xml-malformed"
        }
        return "other:" + String(trimmed.prefix(60))
    }

}
