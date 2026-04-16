import Foundation

nonisolated struct DiscoveredFeed: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let url: String
    let siteURL: String
}

actor FeedDiscovery {

    static let shared = FeedDiscovery()

    let commonPaths = [
        "/feed",
        "/feed/",
        "/rss",
        "/rss/",
        "/rss.xml",
        "/feed.xml",
        "/feed.rss",
        "/atom.xml",
        "/atom",
        "/index.xml",
        "/index.rss",
        "/_rss",
        "/.rss",
        "/feed/atom",
        "/feed/rss2",
        "/feeds/posts/default",
        "/blog/feed",
        "/blog/rss",
        "/blog/feed.xml",
        "/blog/rss.xml",
        "/blog/atom.xml",
        "/blog/index.xml",
        "/?feed=rss2",
        "/?format=rss",
        "/blog?format=rss",
        "/history.rss"
    ]

    func discoverFeeds(forDomain domain: String) async -> [DiscoveredFeed] {
        var results: [DiscoveredFeed] = []

        let htmlFeeds = await discoverFromHTML(domain: domain)
        results.append(contentsOf: htmlFeeds)

        if results.isEmpty {
            let probeFeeds = await probeCommonPaths(domain: domain)
            results.append(contentsOf: probeFeeds)
        }

        var seen = Set<String>()
        return results.filter { seen.insert($0.url).inserted }
    }

    func discoverFeeds(fromPageURL pageURL: URL) async -> [DiscoveredFeed] {
        if let socialFeed = await detectSocialMediaFeed(url: pageURL) {
            return [socialFeed]
        }

        let feeds = await discoverFromHTML(url: pageURL)
        if !feeds.isEmpty { return feeds }

        if let rssFeed = await probeRSSSuffix(for: pageURL) {
            return [rssFeed]
        }

        return await probeCommonPaths(domain: pageURL.host ?? "")
    }
}
