import Foundation

extension FeedDiscovery {

    // MARK: - HTML Link Discovery

    func discoverFromHTML(domain: String) async -> [DiscoveredFeed] {
        guard let url = URL(string: "https://\(domain)") else { return [] }
        return await discoverFromHTML(url: url)
    }

    func discoverFromHTML(url: URL) async -> [DiscoveredFeed] {
        do {
            let (data, _) = try await URLSession.shared.data(for: .sakura(url: url))
            guard let html = String(data: data, encoding: .utf8) else { return [] }
            return extractFeedLinks(from: html, baseURL: url)
        } catch {
            return []
        }
    }

    func extractFeedLinks(from html: String, baseURL: URL) -> [DiscoveredFeed] {
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

    func resolveURL(_ href: String, base: URL) -> String? {
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

    func extractAttribute(_ name: String, from tag: String) -> String? {
        let pattern = "\(name)=\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        guard let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
              let range = Range(match.range(at: 1), in: tag) else { return nil }
        return String(tag[range])
    }
}
