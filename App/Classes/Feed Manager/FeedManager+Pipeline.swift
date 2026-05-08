import Foundation

extension FeedManager {

    nonisolated static func runStandardFeedPipeline(
        feed: Feed,
        database: DatabaseManager,
        options: StandardFeedPipelineOptions
    ) async throws {
        guard let parsedFeed = try await fetchAndParseStandardFeed(feed: feed) else { return }

        if !options.contentOnly,
           let generator = parsedFeed.generator,
           generator.lowercased().contains("substack"),
           !SubstackAuth.isWrappedFeedURL(feed.url) {
            try? database.updateFeedURL(id: feed.id, url: SubstackAuth.wrap(feed.url))
        }

        let articleTuples = await buildArticleInsertItems(
            for: parsedFeed,
            feed: feed,
            database: database,
            skipImageFetch: options.skipImageFetch
        )

        let feedTitleForIndex = parsedFeed.title.isEmpty ? feed.title : parsedFeed.title
        let insertedIDs = (try? database.insertArticles(
            feedID: feed.id, articles: articleTuples
        )) ?? []
        // swiftlint:disable:next line_length
        log("FeedRefresh.RSS", "inserted id=\(feed.id) new=\(insertedIDs.count)/\(articleTuples.count) metadataImages.from=parsed")

        await FeedManager.runPostInsertPipeline(
            insertedIDs: insertedIDs,
            feedTitle: feedTitleForIndex,
            skipImagePreload: options.skipImagePreload,
            runNLP: options.runNLP
        )

        try applyFirstFetchUpdates(
            feed: feed,
            parsed: parsedFeed,
            database: database,
            options: options
        )
        try database.updateFeedLastFetched(id: feed.id, date: Date())
        if !options.contentOnly {
            FeedManager.scheduleFediverseProbeIfNeeded(for: feed, database: database)
        }
        log("FeedRefresh.RSS", "pipeline complete id=\(feed.id)")
    }

    nonisolated private static func fetchAndParseStandardFeed(feed: Feed) async throws -> ParsedFeed? {
        guard let url = URL(string: feed.fetchURL) else {
            log("FeedRefresh.RSS", "invalid fetch URL id=\(feed.id) fetchURL=\(feed.fetchURL)")
            return nil
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
            return nil
        }
        // swiftlint:disable:next line_length
        log("FeedRefresh.RSS", "parsed id=\(feed.id) articles=\(parsed.articles.count) title=\(parsed.title) isPodcast=\(parsed.isPodcast)")
        return parsed
    }

    nonisolated private static func buildArticleInsertItems(
        for parsed: ParsedFeed,
        feed: Feed,
        database: DatabaseManager,
        skipImageFetch: Bool
    ) async -> [ArticleInsertItem] {
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
        return parsed.articles.map { article in
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
    }

    nonisolated private static func applyFirstFetchUpdates(
        feed: Feed,
        parsed: ParsedFeed,
        database: DatabaseManager,
        options: StandardFeedPipelineOptions
    ) throws {
        guard !options.contentOnly, feed.lastFetched == nil else { return }
        if parsed.isPodcast && !feed.isPodcast {
            try database.updateFeedIsPodcast(id: feed.id, isPodcast: true)
        } else if !parsed.isPodcast && feed.isPodcast {
            try database.updateFeedIsPodcast(id: feed.id, isPodcast: false)
        }
        if options.updateTitle, !feed.isTitleCustomized,
           !parsed.title.isEmpty, parsed.title != feed.title {
            try database.updateFeed(
                id: feed.id, title: parsed.title, category: feed.category
            )
        }
        if parsed.description != feed.feedDescription {
            try? database.updateFeedDescription(id: feed.id, description: parsed.description)
        }
    }

    /// Probes the feed's host for Fediverse `.well-known` endpoints once and
    /// persists the result. Skips feeds whose source is already known to live
    /// outside the Fediverse and feeds that have already been classified.
    nonisolated static func scheduleFediverseProbeIfNeeded(
        for feed: Feed,
        database: DatabaseManager
    ) {
        if feed.isFediverse != nil {
            log("FediverseDetector", "skip id=\(feed.id) reason=cached value=\(feed.isFediverse == true)")
            return
        }
        if feed.isKnownFediverseHost {
            log("FediverseDetector", "skip id=\(feed.id) reason=known-host domain=\(feed.domain)")
            return
        }
        if let exclusion = nonFediverseExclusion(for: feed) {
            log("FediverseDetector", "skip id=\(feed.id) reason=\(exclusion) domain=\(feed.domain)")
            return
        }
        log("FediverseDetector", "schedule id=\(feed.id) domain=\(feed.domain)")
        Task.detached(priority: .background) {
            guard let result = await FediverseDetector.detect(for: feed) else { return }
            do {
                try database.updateFeedIsFediverse(id: feed.id, isFediverse: result)
                log("FediverseDetector", "persist id=\(feed.id) isFediverse=\(result)")
            } catch {
                log("FediverseDetector", "persist failed id=\(feed.id) error=\(error.localizedDescription)")
            }
        }
    }

    /// Names the source family that disqualifies a feed from a Fediverse probe,
    /// used purely so the skip log line tells you *why* the probe didn't run.
    nonisolated private static func nonFediverseExclusion(for feed: Feed) -> String? {
        let predicates: [(predicate: (Feed) -> Bool, label: String)] = [
            ({ $0.isPodcast }, "podcast"),
            ({ $0.isXFeed }, "x"),
            ({ $0.isYouTubeFeed }, "youtube"),
            ({ $0.isInstagramFeed }, "instagram"),
            ({ $0.isVimeoFeed }, "vimeo"),
            ({ $0.isNiconicoFeed }, "niconico"),
            ({ $0.isBlueskyFeed }, "bluesky"),
            ({ $0.isRedditFeed }, "reddit"),
            ({ $0.isHackerNewsFeed }, "hackernews"),
            ({ $0.isNoteFeed }, "note"),
            ({ $0.isSubstackFeed }, "substack")
        ]
        return predicates.first(where: { $0.predicate(feed) })?.label
    }

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
}
