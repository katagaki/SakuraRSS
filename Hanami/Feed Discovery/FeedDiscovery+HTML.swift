import Foundation

nonisolated private let feedLinkTagRegex = try? NSRegularExpression(
    pattern: #"<link\b[^>]*\btype\s*=\s*["']application/(?:(?:rss|atom|rdf)\+xml|feed\+json)[^"']*["'][^>]*>"#,
    options: .caseInsensitive
)

nonisolated private let feedAnchorRegex = try? NSRegularExpression(
    pattern: #"<a\s[^>]*href\s*=\s*["']([^"']*)["'][^>]*>(.*?)</a>"#,
    options: [.caseInsensitive, .dotMatchesLineSeparators]
)

nonisolated private let baseHrefRegex = try? NSRegularExpression(
    pattern: #"<base\b[^>]*\bhref\s*=\s*["']([^"']*)["']"#,
    options: .caseInsensitive
)

nonisolated private let tagAttributeRegexes: [String: NSRegularExpression] = {
    var regexes: [String: NSRegularExpression] = [:]
    for name in ["href", "title"] {
        let pattern = #"(?<![-\w])\#(name)\s*=\s*["']([^"']*)["']"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            regexes[name] = regex
        }
    }
    return regexes
}()

public extension FeedDiscovery {

    // MARK: - HTML Link Discovery

    func discoverFromHTML(domain: String) async -> [DiscoveredFeed] {
        guard let url = URL(string: "https://\(domain)") else { return [] }
        return await discoverFromHTML(url: url)
    }

    func discoverFromHTML(url: URL) async -> [DiscoveredFeed] {
        do {
            let (data, response) = try await URLSession.shared.data(for: .sakura(url: url))
            guard let html = HTMLDataDecoder.decode(data, response: response) else { return [] }
            return extractFeedLinks(from: html, baseURL: url)
        } catch {
            return []
        }
    }

    func extractFeedLinks(from html: String, baseURL: URL) -> [DiscoveredFeed] {
        let documentBase = documentBaseURL(in: html, fallback: baseURL)
        return feedLinkElements(in: html, siteURL: baseURL, base: documentBase)
            + feedAnchorElements(in: html, siteURL: baseURL, base: documentBase)
    }

    func resolveURL(_ href: String, base: URL) -> String? {
        let trimmed = RSSParser.decodeHTMLEntities(href)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed, relativeTo: base)?.absoluteURL.absoluteString
    }

    func extractAttribute(_ name: String, from tag: String) -> String? {
        let fallbackPattern = #"(?<![-\w])\#(NSRegularExpression.escapedPattern(for: name))"#
            + #"\s*=\s*["']([^"']*)["']"#
        guard let regex = tagAttributeRegexes[name] ?? (try? NSRegularExpression(
            pattern: fallbackPattern, options: .caseInsensitive
        )) else { return nil }
        let nsTag = tag as NSString
        guard let match = regex.firstMatch(
            in: tag, range: NSRange(location: 0, length: nsTag.length)
        ), match.numberOfRanges >= 2 else { return nil }
        return nsTag.substring(with: match.range(at: 1))
    }

    private func documentBaseURL(in html: String, fallback: URL) -> URL {
        guard let regex = baseHrefRegex else { return fallback }
        let nsHTML = html as NSString
        guard let match = regex.firstMatch(
            in: html, range: NSRange(location: 0, length: nsHTML.length)
        ), match.numberOfRanges >= 2 else { return fallback }
        let href = RSSParser.decodeHTMLEntities(nsHTML.substring(with: match.range(at: 1)))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !href.isEmpty, let resolved = URL(string: href, relativeTo: fallback) else {
            return fallback
        }
        return resolved.absoluteURL
    }

    private func feedLinkElements(
        in html: String, siteURL: URL, base: URL
    ) -> [DiscoveredFeed] {
        guard let regex = feedLinkTagRegex else { return [] }
        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        return matches.compactMap { match in
            let tag = nsHTML.substring(with: match.range)
            guard let href = extractAttribute("href", from: tag),
                  let feedURL = resolveURL(href, base: base) else { return nil }
            let rawTitle = extractAttribute("title", from: tag) ?? "RSS Feed"
            return DiscoveredFeed(
                title: RSSParser.decodeHTMLEntities(rawTitle),
                url: feedURL,
                siteURL: siteURL.absoluteString
            )
        }
    }

    private func feedAnchorElements(
        in html: String, siteURL: URL, base: URL
    ) -> [DiscoveredFeed] {
        guard let regex = feedAnchorRegex else { return [] }
        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        return matches.compactMap { match in
            guard match.numberOfRanges >= 3 else { return nil }
            let text = RSSParser.stripHTMLTags(nsHTML.substring(with: match.range(at: 2)))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercasedText = text.lowercased()
            guard lowercasedText == "rss feed" || lowercasedText == "rss" else { return nil }
            guard let feedURL = resolveURL(
                nsHTML.substring(with: match.range(at: 1)), base: base
            ) else { return nil }
            return DiscoveredFeed(title: text, url: feedURL, siteURL: siteURL.absoluteString)
        }
    }
}
