import Foundation

extension FeedDiscovery {

    // MARK: - Social Media Feed Detection

    /// Detects Bluesky, Mastodon, X/Twitter, and Instagram profile URLs
    /// and constructs their feed URLs.
    func detectSocialMediaFeed(url: URL) async -> DiscoveredFeed? {
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
        if let youTubeChannelFeed = await detectYouTubeChannelFeed(url: url) {
            return youTubeChannelFeed
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
    func detectArXivListFeed(url: URL) -> DiscoveredFeed? {
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
    func detectXProfileFeed(url: URL) -> DiscoveredFeed? {
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
    func detectInstagramProfileFeed(url: URL) -> DiscoveredFeed? {
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
    func detectYouTubePlaylistFeed(url: URL) -> DiscoveredFeed? {
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

    /// Detects YouTube channel URLs (`/channel/UC...`, `/@handle`, `/user/<name>`,
    /// `/c/<name>`) and returns a discovered feed that points at the public
    /// Atom feed (`/feeds/videos.xml?channel_id=UC...`). The Atom feed works
    /// directly with the generic RSS refresh pipeline, so the app fetches
    /// title and videos on first refresh just like any other RSS feed.
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
        } else if path.hasPrefix("/@") || path.hasPrefix("/user/") || path.hasPrefix("/c/") {
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

    /// Fetches a YouTube channel page and extracts the canonical channel ID
    /// from `<meta itemprop="identifier">` / `<meta itemprop="channelId">` /
    /// `<link rel="canonical">`. Returns `nil` on any failure — callers fall
    /// through to generic discovery.
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

    /// Pulls a `UC...` channel ID out of the YouTube channel page HTML using
    /// any of the several stable markers YouTube embeds.
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

    /// Best-effort fetch of the YouTube Atom feed's `<title>` so the
    /// discovered feed entry can show the real channel name immediately.
    /// Returns `nil` on any failure; generic refresh will fill it in on
    /// the subsequent initial refresh.
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

    /// Detects Bluesky profile URLs and constructs the RSS feed URL.
    /// Format: bsky.app/profile/<handle> → bsky.app/profile/<handle>/rss
    func detectBlueskyFeed(url: URL) async -> DiscoveredFeed? {
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
    func detectMastodonFeed(url: URL) async -> DiscoveredFeed? {
        guard let host = url.host?.lowercased() else { return nil }

        let path = url.path
        guard path.hasPrefix("/@") else { return nil }

        let afterAt = String(path.dropFirst(2))
        guard let username = afterAt.split(separator: "/").first,
              !username.isEmpty else { return nil }

        return await probeFeedAt(domain: host, path: "/@\(username).rss")
    }
}
