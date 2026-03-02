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
        "/blog?format=rss"
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
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return [] }
            return extractFeedLinks(from: html, baseURL: url)
        } catch {
            return []
        }
    }

    private func extractFeedLinks(from html: String, baseURL: URL) -> [DiscoveredFeed] {
        var feeds: [DiscoveredFeed] = []

        let pattern = #"<link[^>]+type="application/(rss|atom)\+xml"[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return feeds
        }

        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        for match in matches {
            guard let range = Range(match.range, in: html) else { continue }
            let tag = String(html[range])

            let href = extractAttribute("href", from: tag)
            let rawTitle = extractAttribute("title", from: tag) ?? "RSS Feed"
            let title = RSSParser().decodeHTMLEntities(rawTitle)

            if let href = href {
                let feedURL: String
                if href.hasPrefix("http") {
                    feedURL = href
                } else if href.hasPrefix("//") {
                    feedURL = "https:" + href
                } else {
                    feedURL = baseURL.absoluteString.hasSuffix("/")
                        ? baseURL.absoluteString + href.dropFirst(href.hasPrefix("/") ? 1 : 0)
                        : baseURL.absoluteString + (href.hasPrefix("/") ? "" : "/") + href
                }

                feeds.append(DiscoveredFeed(
                    title: title,
                    url: feedURL,
                    siteURL: baseURL.absoluteString
                ))
            }
        }

        return feeds
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
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 10

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
}
