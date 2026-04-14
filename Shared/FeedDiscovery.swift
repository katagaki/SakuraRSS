import Foundation

nonisolated struct DiscoveredFeed: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let url: String
    let siteURL: String
}

actor FeedDiscovery {

    static let shared = FeedDiscovery()

    private let commonPaths = [
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
        // Check for social media profile URLs first (fast path)
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

    // MARK: - HTML Link Discovery

    private func discoverFromHTML(domain: String) async -> [DiscoveredFeed] {
        guard let url = URL(string: "https://\(domain)") else { return [] }
        return await discoverFromHTML(url: url)
    }

    private func discoverFromHTML(url: URL) async -> [DiscoveredFeed] {

        do {
            let (data, _) = try await URLSession.shared.data(for: .sakura(url: url))
            guard let html = String(data: data, encoding: .utf8) else { return [] }
            return extractFeedLinks(from: html, baseURL: url)
        } catch {
            return []
        }
    }

    private func extractFeedLinks(from html: String, baseURL: URL) -> [DiscoveredFeed] {
        var feeds: [DiscoveredFeed] = []

        // 1. Standard <link> tags with RSS/Atom type
        let linkPattern = #"<link[^>]+type="application/(rss|atom)\+xml"[^>]*>"#
        if let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: .caseInsensitive) {
            let matches = linkRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches {
                guard let range = Range(match.range, in: html) else { continue }
                let tag = String(html[range])

                let href = extractAttribute("href", from: tag)
                let rawTitle = extractAttribute("title", from: tag) ?? "RSS Feed"
                let title = RSSParser().decodeHTMLEntities(rawTitle)

                if let href = href, let feedURL = resolveURL(href, base: baseURL) {
                    feeds.append(DiscoveredFeed(
                        title: title,
                        url: feedURL,
                        siteURL: baseURL.absoluteString
                    ))
                }
            }
        }

        // 2. <a> tags with "RSS Feed" or "RSS" in their link text
        let anchorPattern = #"<a\s[^>]*href="([^"]*)"[^>]*>(.*?)</a>"#
        let anchorOptions: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators]
        if let anchorRegex = try? NSRegularExpression(pattern: anchorPattern, options: anchorOptions) {
            let matches = anchorRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches {
                guard let hrefRange = Range(match.range(at: 1), in: html),
                      let textRange = Range(match.range(at: 2), in: html) else { continue }
                let href = String(html[hrefRange])
                let rawText = String(html[textRange])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let textLower = rawText.lowercased()
                guard textLower == "rss feed" || textLower == "rss" else { continue }

                if let feedURL = resolveURL(href, base: baseURL) {
                    feeds.append(DiscoveredFeed(
                        title: rawText,
                        url: feedURL,
                        siteURL: baseURL.absoluteString
                    ))
                }
            }
        }

        return feeds
    }

    private func resolveURL(_ href: String, base: URL) -> String? {
        guard !href.isEmpty else { return nil }
        if href.hasPrefix("http") {
            return href
        } else if href.hasPrefix("//") {
            return "https:" + href
        } else {
            return base.absoluteString.hasSuffix("/")
                ? base.absoluteString + href.dropFirst(href.hasPrefix("/") ? 1 : 0)
                : base.absoluteString + (href.hasPrefix("/") ? "" : "/") + href
        }
    }

    private func extractAttribute(_ name: String, from tag: String) -> String? {
        let pattern = "\(name)=\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        guard let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
              let range = Range(match.range(at: 1), in: tag) else { return nil }
        return String(tag[range])
    }

    // MARK: - RSS Suffix Probing

    /// For non-root URLs, tries appending `.rss` to the path.
    /// Works for sites like Reddit where /r/subreddit.rss is a valid feed.
    private func probeRSSSuffix(for url: URL) async -> DiscoveredFeed? {
        let path = url.path
        // Only try for non-root paths that don't already have a feed-like extension
        guard !path.isEmpty,
              path != "/",
              !path.hasSuffix(".rss"),
              !path.hasSuffix(".xml"),
              !path.hasSuffix(".atom") else {
            return nil
        }

        let trimmedPath = path.hasSuffix("/") ? String(path.dropLast()) : path
        guard let domain = url.host else { return nil }

        return await probeFeedAt(domain: domain, path: "\(trimmedPath).rss")
    }

    // MARK: - Common Path Probing

    private func probeCommonPaths(domain: String) async -> [DiscoveredFeed] {
        var results: [DiscoveredFeed] = []

        await withTaskGroup(of: DiscoveredFeed?.self) { group in
            for path in commonPaths {
                group.addTask {
                    await self.probeFeedAt(domain: domain, path: path)
                }
            }

            for await result in group {
                if let feed = result {
                    results.append(feed)
                }
            }
        }

        return results
    }

    private func probeFeedAt(domain: String, path: String) async -> DiscoveredFeed? {
        guard let url = URL(string: "https://\(domain)\(path)") else { return nil }

        do {
            var request = URLRequest.sakura(url: url, timeoutInterval: 10)
            request.httpMethod = "GET"

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
            let isXML = contentType.contains("xml") || contentType.contains("rss") || contentType.contains("atom")

            let looksLikeFeed: Bool = {
                guard !isXML else { return false }
                guard let prefix = String(data: data.prefix(500), encoding: .utf8) else { return false }
                return prefix.contains("<rss") || prefix.contains("<feed")
            }()

            if isXML || looksLikeFeed {
                let parser = RSSParser()
                if let parsed = parser.parse(data: data) {
                    return DiscoveredFeed(
                        title: parsed.title.isEmpty ? domain : parsed.title,
                        url: url.absoluteString,
                        siteURL: parsed.siteURL.isEmpty ? "https://\(domain)" : parsed.siteURL
                    )
                }
            }
        } catch {
            // Probe failed, not a feed
        }

        return nil
    }

    // MARK: - Social Media Feed Detection

    /// Detects Bluesky, Mastodon, X/Twitter, and Instagram profile URLs
    /// and constructs their feed URLs.
    private func detectSocialMediaFeed(url: URL) async -> DiscoveredFeed? {
        if let arXivFeed = detectArXivListFeed(url: url) {
            return arXivFeed
        }
        if UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds"),
           let xFeed = detectXProfileFeed(url: url) {
            return xFeed
        }
        if UserDefaults.standard.bool(forKey: "Labs.InstagramProfileFeeds"),
           let instagramFeed = detectInstagramProfileFeed(url: url) {
            return instagramFeed
        }
        if let youTubeFeed = detectYouTubePlaylistFeed(url: url) {
            return youTubeFeed
        }
        if let blueskyFeed = await detectBlueskyFeed(url: url) {
            return blueskyFeed
        }
        if let mastodonFeed = await detectMastodonFeed(url: url) {
            return mastodonFeed
        }
        return nil
    }

    /// Detects arXiv subject listing URLs and rewrites them to the matching
    /// RSS feed. arXiv publishes a standard RSS feed for each category
    /// (e.g. `https://arxiv.org/list/cs.AI/recent` →
    /// `https://rss.arxiv.org/rss/cs.AI`) so the normal RSS parser can handle
    /// refreshes.
    private func detectArXivListFeed(url: URL) -> DiscoveredFeed? {
        guard let category = ArXivHelper.extractCategoryFromListURL(url) else {
            return nil
        }
        return DiscoveredFeed(
            title: "arXiv \(category)",
            url: ArXivHelper.feedURL(forCategory: category),
            siteURL: "https://arxiv.org/list/\(category)/recent"
        )
    }

    /// Detects X/Twitter profile URLs and returns a pseudo-feed entry.
    /// The feed URL uses the `x-profile://` scheme so the app routes refresh
    /// through XProfileScraper instead of RSSParser.
    private func detectXProfileFeed(url: URL) -> DiscoveredFeed? {
        guard XProfileScraper.isXProfileURL(url),
              let handle = XProfileScraper.extractHandle(from: url) else {
            return nil
        }

        return DiscoveredFeed(
            title: "@\(handle)",
            url: XProfileScraper.feedURL(for: handle),
            siteURL: "https://x.com/\(handle)"
        )
    }

    /// Detects Instagram profile URLs and returns a pseudo-feed entry.
    /// The feed URL uses the `instagram-profile://` scheme so the app routes
    /// refresh through InstagramProfileScraper instead of RSSParser.
    private func detectInstagramProfileFeed(url: URL) -> DiscoveredFeed? {
        guard InstagramProfileScraper.isInstagramProfileURL(url),
              let handle = InstagramProfileScraper.extractHandle(from: url) else {
            return nil
        }

        return DiscoveredFeed(
            title: "@\(handle)",
            url: InstagramProfileScraper.feedURL(for: handle),
            siteURL: "https://www.instagram.com/\(handle)/"
        )
    }

    /// Detects YouTube playlist URLs and returns a pseudo-feed entry.
    /// The feed URL uses the `youtube-playlist://` scheme so the app routes
    /// refresh through YouTubePlaylistScraper instead of RSSParser.
    private func detectYouTubePlaylistFeed(url: URL) -> DiscoveredFeed? {
        guard YouTubePlaylistScraper.isYouTubePlaylistURL(url),
              let playlistID = YouTubePlaylistScraper.extractPlaylistID(from: url) else {
            return nil
        }

        return DiscoveredFeed(
            title: "YouTube Playlist",
            url: YouTubePlaylistScraper.feedURL(for: playlistID),
            siteURL: "https://www.youtube.com/playlist?list=\(playlistID)"
        )
    }

    /// Detects Bluesky profile URLs and constructs the RSS feed URL.
    /// Format: bsky.app/profile/<handle> → bsky.app/profile/<handle>/rss
    private func detectBlueskyFeed(url: URL) async -> DiscoveredFeed? {
        guard let host = url.host?.lowercased(),
              host == "bsky.app" || host.hasSuffix(".bsky.app") else {
            return nil
        }

        let path = url.path
        guard path.hasPrefix("/profile/") else { return nil }

        let afterProfile = String(path.dropFirst("/profile/".count))
        guard let handle = afterProfile.split(separator: "/").first,
              !handle.isEmpty else { return nil }

        return await probeFeedAt(domain: "bsky.app", path: "/profile/\(handle)/rss")
    }

    /// Detects Mastodon profile URLs and constructs the RSS feed URL.
    /// Format: <instance>/@<username> → <instance>/@<username>.rss
    private func detectMastodonFeed(url: URL) async -> DiscoveredFeed? {
        guard let host = url.host?.lowercased() else { return nil }

        let path = url.path
        guard path.hasPrefix("/@") else { return nil }

        let afterAt = String(path.dropFirst(2))
        guard let username = afterAt.split(separator: "/").first,
              !username.isEmpty else { return nil }

        return await probeFeedAt(domain: host, path: "/@\(username).rss")
    }
}
