import Foundation

extension FeedManager {

    // MARK: - Feed Refresh

    /// Runs the full per-feed pipeline: fetch -> parse -> metadata images -> insert
    /// -> spotlight -> image preload -> NLP. Insert always runs once the feed has
    /// been fetched, so a user-initiated stop only skips post-insert work for
    /// feeds in flight; feeds that have completed keep their articles.
    func refreshFeed(
        _ feed: Feed,
        updateTitle: Bool = true,
        reloadData: Bool = true,
        skipImageFetch: Bool = false,
        skipImagePreload: Bool = false,
        runNLP: Bool = true
    ) async throws {
        #if DEBUG
        print("[FeedRefresh] refreshFeed begin id=\(feed.id) title=\(feed.title) "
              + "url=\(feed.url) reloadData=\(reloadData) skipImageFetch=\(skipImageFetch) "
              + "skipImagePreload=\(skipImagePreload) runNLP=\(runNLP)")
        #endif
        if PetalRecipe.isPetalFeedURL(feed.url) {
            #if DEBUG
            print("[FeedRefresh] dispatch -> Petal id=\(feed.id)")
            #endif
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
                #if DEBUG
                print("[FeedRefresh] provider \(String(describing: provider)) "
                      + "disabled - skipping id=\(feed.id)")
                #endif
                return
            }
            #if DEBUG
            print("[FeedRefresh] dispatch -> provider=\(String(describing: provider)) "
                  + "id=\(feed.id)")
            #endif
            try await provider.refresh(
                feed: feed,
                on: self,
                reloadData: reloadData,
                skipImagePreload: skipImagePreload,
                runNLP: runNLP
            )
            return
        }

        #if DEBUG
        print("[FeedRefresh] dispatch -> standard RSS pipeline id=\(feed.id)")
        #endif
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
        #if DEBUG
        print("[FeedRefresh] refreshFeed end id=\(feed.id)")
        #endif
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
            #if DEBUG
            print("[FeedRefresh.RSS] invalid fetch URL id=\(feed.id) "
                  + "fetchURL=\(feed.fetchURL)")
            #endif
            return
        }
        let fetchURL = RedirectDomains.redirectedURL(url)
        #if DEBUG
        print("[FeedRefresh.RSS] fetch begin id=\(feed.id) url=\(fetchURL.absoluteString)")
        #endif

        var request = URLRequest.sakura(url: fetchURL, timeoutInterval: 5)
        if feed.isSubstackFeed, let host = fetchURL.host,
           let cookieHeader = SubstackAuth.cookieHeader(for: host) {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let contentType = (response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Type") ?? "unknown"
        #if DEBUG
        print("[FeedRefresh.RSS] fetch ok id=\(feed.id) bytes=\(data.count) "
              + "status=\(statusCode) contentType=\(contentType)")
        #endif
        let parser = RSSParser()
        guard let parsed = parser.parse(data: data) else {
            #if DEBUG
            let bodyHint = bodyContentHint(data: data)
            print("[FeedRefresh.RSS] parse failed id=\(feed.id) "
                  + "status=\(statusCode) contentType=\(contentType) "
                  + "bytes=\(data.count) hint=\(bodyHint)")
            #endif
            return
        }
        #if DEBUG
        print("[FeedRefresh.RSS] parsed id=\(feed.id) articles=\(parsed.articles.count) "
              + "title=\(parsed.title) isPodcast=\(parsed.isPodcast)")
        #endif

        if let generator = parsed.generator,
           generator.lowercased().contains("substack"),
           !SubstackAuth.isWrappedFeedURL(feed.url) {
            try? database.updateFeedURL(id: feed.id, url: SubstackAuth.wrap(feed.url))
        }

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

        let feedTitleForIndex = parsed.title.isEmpty ? feed.title : parsed.title
        let insertedIDs = (try? database.insertArticles(
            feedID: feed.id, articles: articleTuples
        )) ?? []
        #if DEBUG
        print("[FeedRefresh.RSS] inserted id=\(feed.id) "
              + "new=\(insertedIDs.count)/\(articleTuples.count) "
              + "metadataImages=\(metadataImages.count) "
              + "redditImages=\(redditImages.count)")
        #endif

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
        }
        try database.updateFeedLastFetched(id: feed.id, date: Date())
        #if DEBUG
        print("[FeedRefresh.RSS] pipeline complete id=\(feed.id)")
        #endif
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
        #if DEBUG
        print("[FeedRefresh.PostInsert] begin feedTitle=\(feedTitle) "
              + "count=\(insertedArticles.count) skipImagePreload=\(skipImagePreload) "
              + "runNLP=\(runNLP)")
        #endif

        if !ProcessInfo.processInfo.isLowPowerModeEnabled {
            SpotlightIndexer.indexArticles(insertedArticles, feedTitle: feedTitle)
            #if DEBUG
            print("[FeedRefresh.PostInsert] spotlight indexed feedTitle=\(feedTitle) "
                  + "count=\(insertedArticles.count)")
            #endif
        }
        if Task.isCancelled {
            #if DEBUG
            print("[FeedRefresh.PostInsert] cancelled before image preload "
                  + "feedTitle=\(feedTitle)")
            #endif
            return
        }

        if !skipImagePreload {
            let imageURLs = insertedArticles.compactMap { $0.imageURL }
            if !imageURLs.isEmpty {
                #if DEBUG
                print("[FeedRefresh.PostInsert] preloading images "
                      + "feedTitle=\(feedTitle) count=\(imageURLs.count)")
                #endif
                await FeedManager.preloadImages(urls: imageURLs)
            }
        }
        if Task.isCancelled {
            #if DEBUG
            print("[FeedRefresh.PostInsert] cancelled before NLP feedTitle=\(feedTitle)")
            #endif
            return
        }

        if runNLP {
            #if DEBUG
            print("[FeedRefresh.PostInsert] queuing NLP feedTitle=\(feedTitle) "
                  + "count=\(insertedIDs.count)")
            #endif
            await NLPProcessingCoordinator.processArticles(ids: insertedIDs)
        }
        #if DEBUG
        print("[FeedRefresh.PostInsert] end feedTitle=\(feedTitle)")
        #endif
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

    /// Runs each feed's full pipeline concurrently in a bounded queue. Articles for
    /// completed feeds are visible immediately; if cancellation comes mid-refresh,
    /// every feed that has already finished its pipeline keeps its inserted articles.
    func refreshAllFeeds(
        skipAuthenticatedFetchers: Bool = false,
        respectCooldown: Bool = false,
        skipImageFetch: Bool = false,
        skipImagePreload: Bool = false,
        runNLPAfter: Bool = false
    ) async {
        #if DEBUG
        print("[FeedRefresh.All] begin total=\(feeds.count) "
              + "skipAuthenticatedFetchers=\(skipAuthenticatedFetchers) "
              + "respectCooldown=\(respectCooldown) "
              + "skipImageFetch=\(skipImageFetch) "
              + "skipImagePreload=\(skipImagePreload) runNLPAfter=\(runNLPAfter)")
        #endif
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
            if let cooldownSeconds,
               let lastFetched = feed.lastFetched,
               now.timeIntervalSince(lastFetched) < cooldownSeconds {
                return false
            }
            return true
        }
        guard !feedsToRefresh.isEmpty else {
            #if DEBUG
            print("[FeedRefresh.All] no feeds eligible after filter (cooldown="
                  + "\(cooldownSeconds.map { String(Int($0)) } ?? "off")s)")
            #endif
            return
        }

        let slowFeeds = feedsToRefresh.filter { $0.isSlowRefreshFeed }
        let regularFeeds = feedsToRefresh.filter { !$0.isSlowRefreshFeed }
        #if DEBUG
        print("[FeedRefresh.All] eligible=\(feedsToRefresh.count) "
              + "slow=\(slowFeeds.count) regular=\(regularFeeds.count)")
        #endif

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
        #if DEBUG
        print("[FeedRefresh.All] end completed=\(refreshCompleted)/\(refreshTotal)")
        #endif
    }

    fileprivate func runBoundedRefresh(
        _ feeds: [Feed],
        maxConcurrent: Int,
        skipImageFetch: Bool,
        skipImagePreload: Bool,
        runNLP: Bool
    ) async {
        guard !feeds.isEmpty else { return }
        #if DEBUG
        print("[FeedRefresh.Bounded] begin count=\(feeds.count) "
              + "maxConcurrent=\(maxConcurrent)")
        #endif
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
        #if DEBUG
        print("[FeedRefresh.Bounded] end count=\(feeds.count)")
        #endif
    }

    /// Refreshes feeds that have never been fetched.
    func refreshUnfetchedFeeds() async {
        let unfetched = feeds.filter { $0.lastFetched == nil }
        guard !unfetched.isEmpty else {
            #if DEBUG
            print("[FeedRefresh.Unfetched] no unfetched feeds")
            #endif
            return
        }
        #if DEBUG
        print("[FeedRefresh.Unfetched] begin count=\(unfetched.count)")
        #endif

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
        #if DEBUG
        print("[FeedRefresh.Unfetched] end count=\(unfetched.count)")
        #endif
    }

    func refreshAllFeedsAndFavicons() async {
        let currentFeeds = feeds
        #if DEBUG
        print("[FeedRefresh.AllAndFavicons] begin count=\(currentFeeds.count)")
        #endif
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
        #if DEBUG
        print("[FeedRefresh.AllAndFavicons] end completed=\(refreshCompleted)/"
              + "\(refreshTotal)")
        #endif
    }

    /// Cancels the in-flight refresh task. Feeds whose RSS fetch has already
    /// completed run their pipeline through to insert; feeds still waiting on
    /// the network drop their work. Triggers a database reload so any articles
    /// collected up to the cancel point appear immediately.
    @MainActor
    func cancelRefresh() {
        #if DEBUG
        print("[FeedRefresh] cancelRefresh hadTask=\(refreshTask != nil) "
              + "completed=\(refreshCompleted)/\(refreshTotal)")
        #endif
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
