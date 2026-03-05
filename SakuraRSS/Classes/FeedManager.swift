import Foundation
import SwiftSoup
import SwiftUI
@preconcurrency import UserNotifications

@Observable
final class FeedManager {

    var feeds: [Feed] = []
    var articles: [Article] = []
    var isLoading = false
    private(set) var dataRevision: Int = 0
    private(set) var faviconRevision: Int = 0

    private let database = DatabaseManager.shared

    init() {
        loadFromDatabase()
    }

    func loadFromDatabase() {
        do {
            feeds = try database.allFeeds()
            articles = try database.allArticles(limit: 200)
            dataRevision += 1
        } catch {
            print("Failed to load from database: \(error)")
        }
    }

    func addFeed(url: String, title: String, siteURL: String,
                 description: String = "", faviconURL: String? = nil,
                 category: String? = nil, isPodcast: Bool = false) throws {
        let feedID = try database.insertFeed(
            title: title, url: url, siteURL: siteURL,
            description: description, faviconURL: faviconURL,
            category: category, isPodcast: isPodcast
        )
        generateAcronymIcon(feedID: feedID, title: title)
        loadFromDatabase()
    }

    func deleteFeed(_ feed: Feed) throws {
        try database.deleteFeed(id: feed.id)
        loadFromDatabase()
    }

    func toggleMuted(_ feed: Feed) {
        try? database.updateFeedMuted(id: feed.id, isMuted: !feed.isMuted)
        loadFromDatabase()
    }

    func updateFeedDetails(_ feed: Feed, title: String, url: String,
                           customIconURL: String?) {
        try? database.updateFeedDetails(id: feed.id, title: title, url: url,
                                        customIconURL: customIconURL)
        if title != feed.title {
            generateAcronymIcon(feedID: feed.id, title: title)
        }
        loadFromDatabase()
    }

    func refreshFeed(_ feed: Feed, updateTitle: Bool = true) async throws {
        guard let url = URL(string: feed.url) else { return }

        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = RSSParser()
        guard let parsed = parser.parse(data: data) else { return }

        for article in parsed.articles {
            try database.insertArticle(
                feedID: feed.id,
                title: article.title,
                url: article.url,
                data: ArticleInsertData(
                    author: article.author,
                    summary: article.summary,
                    content: article.content,
                    imageURL: article.imageURL,
                    publishedDate: article.publishedDate,
                    audioURL: article.audioURL,
                    duration: article.duration
                )
            )
        }

        if parsed.isPodcast && !feed.isPodcast {
            let siteURLString = parsed.siteURL.isEmpty ? feed.siteURL : parsed.siteURL
            let isSubstack = await Self.isSubstackSite(siteURLString)
            if !isSubstack {
                try database.updateFeedIsPodcast(id: feed.id, isPodcast: true)
            }
        }
        if updateTitle, !parsed.title.isEmpty, parsed.title != feed.title {
            try database.updateFeed(id: feed.id, title: parsed.title, category: feed.category)
        }
        try database.updateFeedLastFetched(id: feed.id, date: Date())
        loadFromDatabase()
    }

    func refreshAllFeeds() async {
        isLoading = true
        defer { isLoading = false }

        let currentFeeds = feeds
        await withTaskGroup(of: Void.self) { group in
            for feed in currentFeeds {
                group.addTask {
                    try? await self.refreshFeed(feed)
                }
            }
        }
        loadFromDatabase()
    }

    func refreshAllFeedsAndFavicons() async {
        isLoading = true
        defer { isLoading = false }

        let currentFeeds = feeds
        async let feedRefresh: Void = withTaskGroup(of: Void.self) { group in
            for feed in currentFeeds {
                group.addTask {
                    try? await self.refreshFeed(feed, updateTitle: false)
                }
            }
        }
        async let faviconRefresh: Void = FaviconCache.shared.refreshFavicons(
            for: currentFeeds.map { ($0.domain, $0.siteURL as String?) }
        )
        _ = await (feedRefresh, faviconRefresh)
        loadFromDatabase()
        regenerateAllAcronymIcons()
        loadFromDatabase()
        faviconRevision += 1
    }

    func todayArticles() -> [Article] {
        _ = dataRevision
        let startOfToday = Calendar.current.startOfDay(for: Date())
        var all = (try? database.allArticles(since: startOfToday)) ?? []
        let muted = mutedFeedIDs
        if !muted.isEmpty {
            all = all.filter { !muted.contains($0.feedID) }
        }
        return applyAllRules(all)
    }

    func overnightArticles() -> [Article] {
        _ = dataRevision
        let calendar = Calendar.current
        let now = Date()
        let midnight = calendar.startOfDay(for: now)
        let allOvernight = (try? database.allArticles(from: midnight, to: now)) ?? []
        return filterExcludingPodcastsAndVideos(allOvernight)
    }

    func todaySummaryArticles() -> [Article] {
        _ = dataRevision
        let midnight = Calendar.current.startOfDay(for: Date())
        let allToday = (try? database.allArticles(from: midnight, to: Date())) ?? []
        return filterExcludingPodcastsAndVideos(allToday)
    }

    private func filterExcludingPodcastsAndVideos(_ articles: [Article]) -> [Article] {
        let excludedFeedIDs = Set(feeds.filter { feed in
            feed.isMuted || feed.isPodcast || VideoDomains.shouldPreferVideo(feedDomain: feed.domain)
        }.map(\.id))
        return articles.filter { !excludedFeedIDs.contains($0.feedID) }
    }

    func olderArticles(limit: Int = 200) -> [Article] {
        _ = dataRevision
        let startOfToday = Calendar.current.startOfDay(for: Date())
        var all = (try? database.allArticles(before: startOfToday, limit: limit)) ?? []
        let muted = mutedFeedIDs
        if !muted.isEmpty {
            all = all.filter { !muted.contains($0.feedID) }
        }
        return applyAllRules(all)
    }

    func articles(for feed: Feed, limit: Int? = nil) -> [Article] {
        _ = dataRevision
        let all = (try? database.articles(forFeedID: feed.id, limit: limit)) ?? []
        return applyRules(all, feedID: feed.id)
    }

    func articleCount(for feed: Feed) -> Int {
        _ = dataRevision
        return (try? database.articleCount(forFeedID: feed.id)) ?? 0
    }

    func markRead(_ article: Article) {
        try? database.markArticleRead(id: article.id, read: true)
        loadFromDatabase()
        updateBadgeCount()
    }

    func toggleRead(_ article: Article) {
        try? database.markArticleRead(id: article.id, read: !article.isRead)
        loadFromDatabase()
        updateBadgeCount()
    }

    func toggleBookmark(_ article: Article) {
        try? database.toggleBookmark(id: article.id)
        loadFromDatabase()
    }

    func markAllRead(feed: Feed) {
        try? database.markAllRead(feedID: feed.id)
        loadFromDatabase()
        updateBadgeCount()
    }

    func markAllRead() {
        try? database.markAllRead()
        loadFromDatabase()
        updateBadgeCount()
    }

    func unreadCount(for feed: Feed) -> Int {
        _ = dataRevision
        return (try? database.unreadCount(forFeedID: feed.id)) ?? 0
    }

    func totalUnreadCount() -> Int {
        _ = dataRevision
        let mutedFeedIDs = Set(feeds.filter(\.isMuted).map(\.id))
        if mutedFeedIDs.isEmpty {
            return (try? database.totalUnreadCount()) ?? 0
        }
        return feeds.filter { !$0.isMuted }.reduce(0) { total, feed in
            total + ((try? database.unreadCount(forFeedID: feed.id)) ?? 0)
        }
    }

    private var mutedFeedIDs: Set<Int64> {
        Set(feeds.filter(\.isMuted).map(\.id))
    }

    private func applyRules(_ articles: [Article], feedID: Int64) -> [Article] {
        let keywords = (try? database.rules(forFeedID: feedID, type: "muted_keyword")) ?? []
        let authors = Set((try? database.rules(forFeedID: feedID, type: "muted_author")) ?? [])
        guard !keywords.isEmpty || !authors.isEmpty else { return articles }
        return articles.filter { article in
            if let author = article.author, authors.contains(author) {
                return false
            }
            for keyword in keywords {
                if article.title.localizedCaseInsensitiveContains(keyword) {
                    return false
                }
                if let summary = article.summary,
                   summary.localizedCaseInsensitiveContains(keyword) {
                    return false
                }
            }
            return true
        }
    }

    private func applyAllRules(_ articles: [Article]) -> [Article] {
        var rulesByFeed: [Int64: (keywords: [String], authors: Set<String>)] = [:]
        var result: [Article] = []
        for article in articles {
            if rulesByFeed[article.feedID] == nil {
                let keywords = (try? database.rules(forFeedID: article.feedID, type: "muted_keyword")) ?? []
                let authors = Set((try? database.rules(forFeedID: article.feedID, type: "muted_author")) ?? [])
                rulesByFeed[article.feedID] = (keywords, authors)
            }
            let rules = rulesByFeed[article.feedID]!
            guard !rules.keywords.isEmpty || !rules.authors.isEmpty else {
                result.append(article)
                continue
            }
            if let author = article.author, rules.authors.contains(author) {
                continue
            }
            var matched = false
            for keyword in rules.keywords {
                if article.title.localizedCaseInsensitiveContains(keyword) {
                    matched = true
                    break
                }
                if let summary = article.summary,
                   summary.localizedCaseInsensitiveContains(keyword) {
                    matched = true
                    break
                }
            }
            if !matched {
                result.append(article)
            }
        }
        return result
    }

    func updateBadgeCount() {
        let badgeEnabled = UserDefaults.standard.bool(forKey: "BackgroundRefresh.BadgeEnabled")
        let center = UNUserNotificationCenter.current()
        guard badgeEnabled else {
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

    func feed(forArticle article: Article) -> Feed? {
        feeds.first { $0.id == article.feedID }
    }

    func article(byID id: Int64) -> Article? {
        articles.first { $0.id == id } ?? (try? database.article(byID: id))
    }

    // MARK: - Feed Rules

    func mutedKeywords(for feed: Feed) -> [String] {
        (try? database.rules(forFeedID: feed.id, type: "muted_keyword")) ?? []
    }

    func mutedAuthors(for feed: Feed) -> [String] {
        (try? database.rules(forFeedID: feed.id, type: "muted_author")) ?? []
    }

    func saveMutedKeywords(_ keywords: [String], for feed: Feed) {
        try? database.replaceRules(feedID: feed.id, type: "muted_keyword", values: keywords)
    }

    func saveMutedAuthors(_ authors: [String], for feed: Feed) {
        try? database.replaceRules(feedID: feed.id, type: "muted_author", values: authors)
    }

    func uniqueAuthors(for feed: Feed) -> [String] {
        let allArticles = (try? database.articles(forFeedID: feed.id)) ?? []
        var seen = Set<String>()
        var result: [String] = []
        for article in allArticles {
            if let author = article.author, !author.isEmpty, seen.insert(author).inserted {
                result.append(author)
            }
        }
        return result
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

    // MARK: - OPML Export

    func exportOPML() -> String {
        OPMLManager.shared.generateOPML(from: feeds)
    }

    // MARK: - OPML Import

    func importOPML(data: Data, overwrite: Bool) throws -> Int {
        let opmlFeeds = OPMLManager.shared.parseOPML(data: data)
        guard !opmlFeeds.isEmpty else { return 0 }

        if overwrite {
            let existing = try database.allFeeds()
            for feed in existing {
                try database.deleteFeed(id: feed.id)
            }
        }

        var added = 0
        for opmlFeed in opmlFeeds {
            if database.feedExists(url: opmlFeed.xmlURL) {
                continue
            }
            let feedID = try database.insertFeed(
                title: opmlFeed.title,
                url: opmlFeed.xmlURL,
                siteURL: opmlFeed.htmlURL,
                description: opmlFeed.description,
                category: opmlFeed.category
            )
            generateAcronymIcon(feedID: feedID, title: opmlFeed.title)
            added += 1
        }

        loadFromDatabase()
        return added
    }

    // MARK: - Substack Detection

    private static func isSubstackSite(_ siteURL: String) async -> Bool {
        guard let url = URL(string: siteURL) else { return false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return false }
            let doc = try SwiftSoup.parse(html)
            guard let head = doc.head() else { return false }
            return try head.html().contains("substackcdn.com")
        } catch {
            return false
        }
    }
}
