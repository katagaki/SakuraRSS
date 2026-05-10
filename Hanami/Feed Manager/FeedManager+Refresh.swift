import Foundation

public extension FeedManager {

    // MARK: - Feed Refresh

    func refreshFeed(
        _ feed: Feed,
        updateTitle: Bool = true,
        reloadData: Bool = true,
        skipImageFetch: Bool = false,
        skipImagePreload: Bool = false,
        runNLP: Bool = true,
        contentOnly: Bool = false
    ) async throws {
        // swiftlint:disable:next line_length
        log("FeedRefresh", "refreshFeed begin id=\(feed.id) title=\(feed.title) url=\(feed.url) reloadData=\(reloadData) skipImageFetch=\(skipImageFetch) skipImagePreload=\(skipImagePreload) runNLP=\(runNLP) contentOnly=\(contentOnly)")
        let started = Date()
        var didPerformWork = false
        defer { recordRefreshMetricIfPerformed(performed: didPerformWork, feedID: feed.id, started: started) }

        if PetalRecipe.isPetalFeedURL(feed.url) {
            log("FeedRefresh", "dispatch -> Petal id=\(feed.id)")
            didPerformWork = true
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
            didPerformWork = true
            try await provider.refresh(
                feed: feed,
                on: self,
                options: FeedRefreshOptions(
                    reloadData: reloadData,
                    skipImagePreload: skipImagePreload,
                    runNLP: runNLP,
                    contentOnly: contentOnly
                )
            )
            return
        }

        didPerformWork = true
        try await runStandardRSSRefresh(
            feed: feed,
            options: StandardFeedPipelineOptions(
                updateTitle: updateTitle,
                skipImageFetch: skipImageFetch,
                skipImagePreload: skipImagePreload,
                runNLP: runNLP,
                contentOnly: contentOnly
            ),
            reloadData: reloadData
        )
        log("FeedRefresh", "refreshFeed end id=\(feed.id)")
    }

    private func runStandardRSSRefresh(
        feed: Feed,
        options: StandardFeedPipelineOptions,
        reloadData: Bool
    ) async throws {
        log("FeedRefresh", "dispatch -> standard RSS pipeline id=\(feed.id)")
        let database = database
        try await Task.detached {
            try await FeedManager.runStandardFeedPipeline(
                feed: feed,
                database: database,
                options: options
            )
        }.value
        if reloadData {
            await loadFromDatabaseInBackground(animated: true)
        }
    }

    private func recordRefreshMetricIfPerformed(performed: Bool, feedID: Int64, started: Date) {
        guard performed else { return }
        let durationMs = max(0, Int(Date().timeIntervalSince(started) * 1000))
        let database = self.database
        Task.detached(priority: .utility) {
            do {
                try database.recordFeedRefreshMetric(feedID: feedID, durationMs: durationMs)
                log("FeedRefresh", "metric recorded id=\(feedID) durationMs=\(durationMs)")
            } catch {
                log("FeedRefresh", "metric record failed id=\(feedID) error=\(error.localizedDescription)")
            }
        }
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

    func deleteArticlesAndVacuum(olderThan date: Date?, includeBookmarks: Bool = false) async {
        let cutoff = date ?? Date()
        UserDefaults.standard.set(cutoff.timeIntervalSince1970, forKey: "Content.CutoffDate")
        let database = database
        _ = try? await Task.detached {
            if let date {
                try database.deleteArticles(olderThan: date, includeBookmarks: includeBookmarks)
                try database.clearImageCache(olderThan: date)
            } else {
                try database.deleteAllArticlesOnly(includeBookmarks: includeBookmarks)
                try database.clearImageCache()
            }
            try database.vacuum()
            PodcastDownloadManager.cleanupOrphanedDownloads()
        }.value
        SpotlightIndexer.removeAllArticles()
        await loadFromDatabaseInBackground()
    }

    func refreshAllFeeds(
        skipAuthenticatedFetchers: Bool = false,
        respectCooldown: Bool = false,
        skipImageFetch: Bool = false,
        skipImagePreload: Bool = false,
        runNLPAfter: Bool = false
    ) async {
        // swiftlint:disable:next line_length
        log("FeedRefresh.All", "begin total=\(feeds.count) skipAuthenticatedFetchers=\(skipAuthenticatedFetchers) respectCooldown=\(respectCooldown) skipImageFetch=\(skipImageFetch) skipImagePreload=\(skipImagePreload) runNLPAfter=\(runNLPAfter)")
        let cooldownSeconds = computeRefreshCooldownSeconds(respectCooldown: respectCooldown)
        let feedsToRefresh = filterFeedsForRefresh(
            feeds: feeds,
            skipAuthenticatedFetchers: skipAuthenticatedFetchers,
            cooldownSeconds: cooldownSeconds
        )
        guard !feedsToRefresh.isEmpty else {
            // swiftlint:disable:next line_length
            log("FeedRefresh.All", "no feeds eligible after filter (cooldown=\(cooldownSeconds.map { String(Int($0)) } ?? "off")s)")
            return
        }

        let queues = partitionRefreshQueues(feedsToRefresh)
        // swiftlint:disable:next line_length
        log("FeedRefresh.All", "eligible=\(feedsToRefresh.count) regular=\(queues.regular.count) slow=\(queues.slow.count) x=\(queues.x.count) instagram=\(queues.instagram.count)")

        await MainActor.run {
            isLoading = true
            refreshCompleted = 0
            refreshTotal = feedsToRefresh.count
            pendingRefreshFeedIDs = feedsToRefresh.map { $0.id }
            refreshingFeedIDs = []
        }

        let effectiveSkipPreload = await resolveEffectiveSkipPreload(skipImagePreload: skipImagePreload)
        let work = makeRefreshAllTask(
            queues: queues,
            skipImageFetch: skipImageFetch,
            effectiveSkipPreload: effectiveSkipPreload,
            runNLPAfter: runNLPAfter
        )
        await MainActor.run { self.refreshTask = work }
        _ = await work.value
        await loadFromDatabaseInBackground(animated: true)
        let finalCompleted = await finalizeRefreshAll()
        log("FeedRefresh.All", "end completed=\(finalCompleted)/\(feedsToRefresh.count)")
    }

    private func computeRefreshCooldownSeconds(respectCooldown: Bool) -> TimeInterval? {
        guard respectCooldown else { return nil }
        let raw = UserDefaults.standard.string(forKey: "BackgroundRefresh.Cooldown")
        let cooldown = raw.flatMap(FeedRefreshCooldown.init(rawValue:)) ?? .fiveMinutes
        return cooldown.seconds
    }

    private func filterFeedsForRefresh(
        feeds: [Feed],
        skipAuthenticatedFetchers: Bool,
        cooldownSeconds: TimeInterval?
    ) -> [Feed] {
        let now = Date()
        return feeds.filter { feed in
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
    }

    private func resolveEffectiveSkipPreload(skipImagePreload: Bool) async -> Bool {
        if skipImagePreload { return true }
        let preloadModeRaw = UserDefaults.standard.string(
            forKey: "FeedRefresh.PreloadArticleImagesMode"
        )
        let preloadMode = preloadModeRaw.flatMap(FetchImagesMode.init(rawValue:)) ?? .wifiOnly
        switch preloadMode {
        case .always: return false
        case .wifiOnly: return await NetworkMonitor.currentPathIsExpensive() ?? true
        case .off: return true
        }
    }

    private func makeRefreshAllTask(
        queues: FeedRefreshQueues,
        skipImageFetch: Bool,
        effectiveSkipPreload: Bool,
        runNLPAfter: Bool
    ) -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }
            async let regular: Void = self.runBoundedRefresh(
                queues.regular,
                maxConcurrent: FeedRefreshQueueLimits.default,
                skipImageFetch: skipImageFetch,
                skipImagePreload: effectiveSkipPreload,
                runNLP: runNLPAfter
            )
            async let slow: Void = self.runBoundedRefresh(
                queues.slow,
                maxConcurrent: FeedRefreshQueueLimits.default,
                skipImageFetch: skipImageFetch,
                skipImagePreload: effectiveSkipPreload,
                runNLP: runNLPAfter
            )
            async let xRefresh: Void = self.runBoundedRefresh(
                queues.x,
                maxConcurrent: FeedRefreshQueueLimits.throttled,
                skipImageFetch: skipImageFetch,
                skipImagePreload: effectiveSkipPreload,
                runNLP: runNLPAfter
            )
            async let instagramRefresh: Void = self.runBoundedRefresh(
                queues.instagram,
                maxConcurrent: FeedRefreshQueueLimits.throttled,
                skipImageFetch: skipImageFetch,
                skipImagePreload: effectiveSkipPreload,
                runNLP: runNLPAfter
            )
            _ = await (regular, slow, xRefresh, instagramRefresh)
        }
    }

    private func finalizeRefreshAll() async -> Int {
        await MainActor.run { () -> Int in
            let completed = self.refreshCompleted
            self.lastRefreshedAt = Date()
            self.scopedLastRefreshedAt = [:]
            self.isLoading = false
            self.refreshCompleted = 0
            self.refreshTotal = 0
            self.pendingRefreshFeedIDs = []
            self.refreshingFeedIDs = []
            self.refreshTask = nil
            return completed
        }
    }

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

    func refreshAllFeedsAndIcons() async {
        let currentFeeds = feeds
        log("FeedRefresh.AllAndIcons", "begin count=\(currentFeeds.count)")
        await MainActor.run {
            isLoading = true
            refreshCompleted = 0
            refreshTotal = currentFeeds.count
            pendingRefreshFeedIDs = currentFeeds.map { $0.id }
            refreshingFeedIDs = []
        }

        let queues = partitionRefreshQueues(currentFeeds)
        let maxConcurrent = FeedRefreshQueueLimits.default
        let work = Task { [weak self] in
            guard let self else { return }
            async let regular: Void = self.runTitleSafeBoundedRefresh(
                queues.regular, maxConcurrent: maxConcurrent
            )
            async let slow: Void = self.runTitleSafeBoundedRefresh(
                queues.slow, maxConcurrent: maxConcurrent
            )
            async let xRefresh: Void = self.runTitleSafeBoundedRefresh(
                queues.x, maxConcurrent: maxConcurrent
            )
            async let instagramRefresh: Void = self.runTitleSafeBoundedRefresh(
                queues.instagram, maxConcurrent: maxConcurrent
            )
            async let iconRefresh: Void = Iconography.shared.refreshIcons(
                for: currentFeeds.map { ($0.domain, $0.siteURL as String?) }
            )
            _ = await (regular, slow, xRefresh, instagramRefresh, iconRefresh)
        }
        await MainActor.run { self.refreshTask = work }
        _ = await work.value
        await loadFromDatabaseInBackground(animated: true)
        regenerateAllAcronymIcons()
        notifyIconChange()
        let finalCompleted = await MainActor.run { () -> Int in
            let completed = self.refreshCompleted
            self.lastRefreshedAt = Date()
            self.scopedLastRefreshedAt = [:]
            self.isLoading = false
            self.refreshCompleted = 0
            self.refreshTotal = 0
            self.pendingRefreshFeedIDs = []
            self.refreshingFeedIDs = []
            self.refreshTask = nil
            return completed
        }
        log("FeedRefresh.AllAndIcons", "end completed=\(finalCompleted)/\(currentFeeds.count)")
    }

    /// Cancels the in-flight refresh task. Feeds whose RSS fetch has already
    /// completed run their pipeline through to insert; feeds still waiting on
    /// the network drop their work. Awaits the refresh task so any pipelines
    /// already past the network round-trip can flush their inserts, then
    /// reloads from the database so the gathered articles bump `dataRevision`
    /// and surface in the UI.
    @MainActor
    func cancelRefresh() {
        log("FeedRefresh", "cancelRefresh hadTask=\(refreshTask != nil) completed=\(refreshCompleted)/\(refreshTotal)")
        let task = refreshTask
        refreshTask?.cancel()
        refreshTask = nil
        isLoading = false
        refreshCompleted = 0
        refreshTotal = 0
        pendingRefreshFeedIDs = []
        refreshingFeedIDs = []
        Task {
            if let task {
                _ = await task.value
            }
            await self.loadFromDatabaseInBackground(animated: true)
        }
    }

}
