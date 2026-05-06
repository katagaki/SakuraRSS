import Foundation

extension FeedDiscovery {

    // MARK: - Social Media Feed Detection

    /// Detects social media profile URLs and constructs their feed URLs.
    func detectSocialMediaFeed(url: URL) async -> DiscoveredFeed? {
        if let arXivFeed = detectArXivListFeed(url: url) {
            return arXivFeed
        }
        for provider in FeedProviderRegistry.all where provider.isEnabled {
            if let profile = provider as? any ProfileFeedProvider.Type,
               profile.isProfileURL(url),
               let discovered = await profile.discoveredFeed(forProfileURL: url) {
                return discovered
            }
        }
        if let youTubeChannelFeed = await detectYouTubeChannelFeed(url: url) {
            return youTubeChannelFeed
        }
        if let mastodonFeed = await detectMastodonFeed(url: url) {
            return mastodonFeed
        }
        return nil
    }

    /// Rewrites arXiv subject listing URLs to their matching RSS feed.
    func detectArXivListFeed(url: URL) -> DiscoveredFeed? {
        guard let category = ArXivProvider.extractCategoryFromListURL(url) else {
            return nil
        }
        return DiscoveredFeed(
            title: "arXiv \(category)",
            url: ArXivProvider.feedURL(forCategory: category),
            siteURL: "https://arxiv.org/list/\(category)/recent"
        )
    }

    /// Returns a discovered feed pointing at the channel's Atom feed.
    func detectYouTubeChannelFeed(url: URL) async -> DiscoveredFeed? {
        guard let host = url.host?.lowercased(),
              host == "youtube.com" || host == "www.youtube.com" || host == "m.youtube.com" else {
            return nil
        }

        let resolvedChannelID: String?
        let siteURL: String

        let path = url.path
        if path.hasPrefix("/channel/") {
            let rest = path.dropFirst("/channel/".count)
            let channelID = String(rest.split(separator: "/").first ?? "")
            guard channelID.hasPrefix("UC") else { return nil }
            resolvedChannelID = channelID
            siteURL = "https://www.youtube.com/channel/\(channelID)"
        } else if path.hasPrefix("/@") || path.hasPrefix("/user/") || path.hasPrefix("/c/")
                    || Self.isYouTubeVanityPath(path) {
            resolvedChannelID = await Self.resolveYouTubeChannelID(from: url)
            siteURL = url.absoluteString
        } else {
            return nil
        }

        guard let channelID = resolvedChannelID, !channelID.isEmpty else { return nil }

        let feedURL = "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelID)"
        let title = await Self.fetchYouTubeAtomTitle(feedURL: feedURL) ?? "YouTube Channel"
        return DiscoveredFeed(title: title, url: feedURL, siteURL: siteURL)
    }

    /// True for single-segment YouTube paths like `/Google` that act as
    /// vanity aliases for a channel (legacy form, no `@` or `c/` prefix).
    static func isYouTubeVanityPath(_ path: String) -> Bool {
        let segments = path.split(separator: "/").map(String.init)
        guard segments.count == 1, let segment = segments.first else { return false }
        let reserved: Set<String> = [
            "playlist", "watch", "results", "feed", "shorts", "live",
            "channel", "user", "c", "embed", "redirect", "hashtag", "post",
            "about", "account", "ads", "creators", "kids", "premium",
            "trending", "gaming", "music", "movies", "sports", "news",
            "learning", "fashion", "supported_browsers", "t", "view_play_list"
        ]
        return !reserved.contains(segment.lowercased())
    }

    /// Extracts the canonical `UC...` channel ID from a YouTube channel page.
    static func resolveYouTubeChannelID(from url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            return extractYouTubeChannelID(from: html)
        } catch {
            return nil
        }
    }

    /// Pulls a `UC...` channel ID out of YouTube channel page HTML.
    static func extractYouTubeChannelID(from html: String) -> String? {
        let patterns = [
            #"<meta itemprop="identifier" content="(UC[\w-]+)""#,
            #"<meta itemprop="channelId" content="(UC[\w-]+)""#,
            #"<link rel="canonical" href="https://www\.youtube\.com/channel/(UC[\w-]+)""#,
            #""channelId":"(UC[\w-]+)""#,
            #""externalId":"(UC[\w-]+)""#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(
                in: html, range: NSRange(html.startIndex..., in: html)
               ),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        return nil
    }

    /// Best-effort fetch of the YouTube Atom feed's `<title>`.
    static func fetchYouTubeAtomTitle(feedURL: String) async -> String? {
        guard let url = URL(string: feedURL) else { return nil }
        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let xml = String(data: data, encoding: .utf8) else { return nil }
            if let start = xml.range(of: "<title>"),
               let end = xml.range(
                of: "</title>", range: start.upperBound..<xml.endIndex
               ) {
                let raw = String(xml[start.upperBound..<end.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return raw.isEmpty ? nil : RSSParser().decodeHTMLEntities(raw)
            }
        } catch {
            return nil
        }
        return nil
    }

    /// Constructs a Mastodon profile RSS feed URL. Mastodon isn't a single
    /// provider (any compatible host counts), so detection lives here rather
    /// than on a `ProfileFeedProvider`.
    func detectMastodonFeed(url: URL) async -> DiscoveredFeed? {
        guard let host = url.host?.lowercased() else { return nil }

        let path = url.path
        guard path.hasPrefix("/@") else { return nil }

        let afterAt = String(path.dropFirst(2))
        guard let username = afterAt.split(separator: "/").first,
              !username.isEmpty else { return nil }

        return await Self.probeFeedAt(domain: host, path: "/@\(username).rss")
    }
}
