import Foundation

/// Identifies arXiv content (RSS feeds, list pages, abstract pages) and
/// exposes per-paper PDF URLs for the article actions UI.
nonisolated enum ArXivProvider: RSSFeedProvider, ResearchFeedProvider {

    static var providerID: String { "arxiv" }

    static var domains: Set<String> { ["arxiv.org"] }

    static func matchesFeedURL(_ feedURL: String) -> Bool {
        guard let url = URL(string: feedURL),
              matchesHost(url.host) else { return false }
        return url.path.hasPrefix("/rss/")
    }

    // MARK: - List URL → Feed URL

    static func extractCategoryFromListURL(_ url: URL) -> String? {
        guard matchesHost(url.host) else { return nil }
        let components = url.path.split(separator: "/").map(String.init)
        guard components.count >= 2, components[0] == "list" else { return nil }
        let category = components[1]
        guard isValidCategory(category) else { return nil }
        return category
    }

    static func feedURL(forCategory category: String) -> String {
        "https://rss.arxiv.org/rss/\(category)"
    }

    // MARK: - Abstract URLs

    static func isAbstractURL(_ url: URL) -> Bool {
        guard matchesHost(url.host) else { return false }
        return extractArXivID(from: url) != nil
    }

    /// Extracts the arXiv paper ID from `/abs/`, `/pdf/`, or `/html/` URLs.
    /// Handles legacy and new ID formats plus version suffix.
    static func extractArXivID(from url: URL) -> String? {
        guard matchesHost(url.host) else { return nil }
        let path = url.path
        let prefixes = ["/abs/", "/pdf/", "/html/"]
        guard let prefix = prefixes.first(where: { path.hasPrefix($0) }) else {
            return nil
        }
        var remainder = String(path.dropFirst(prefix.count))
        if remainder.hasSuffix(".pdf") {
            remainder = String(remainder.dropLast(4))
        }
        if remainder.hasSuffix("/") {
            remainder = String(remainder.dropLast())
        }
        return remainder.isEmpty ? nil : remainder
    }

    // MARK: - ResearchFeedProvider

    static func pdfURL(forArticleURL articleURL: String) -> URL? {
        guard let url = URL(string: articleURL),
              let arXivID = extractArXivID(from: url) else {
            return nil
        }
        return URL(string: "https://arxiv.org/pdf/\(arXivID).pdf")
    }

    // MARK: - Validation

    private static func isValidCategory(_ category: String) -> Bool {
        guard !category.isEmpty, category.count <= 32 else { return false }
        let allowed = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
        return category.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
