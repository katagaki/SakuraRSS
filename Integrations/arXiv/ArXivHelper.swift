import Foundation

/// Helpers for detecting arXiv URLs and mapping them between list pages,
/// RSS feeds, abstract pages, and PDF downloads.
///
/// arXiv publishes standard RSS feeds that already contain paper titles and
/// abstracts, so a dedicated scraper isn't needed. Instead, when the user
/// adds an arXiv list URL (e.g. `https://arxiv.org/list/cs.AI/recent`) we
/// transparently rewrite it to the category's RSS feed
/// (`https://rss.arxiv.org/rss/cs.AI`) so the standard RSSParser can handle
/// refreshes.
nonisolated enum ArXivHelper {

    // MARK: - Host Detection

    /// Returns `true` if the URL's host is an arXiv-owned domain.
    static func isArXivHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "arxiv.org"
            || host == "www.arxiv.org"
            || host == "export.arxiv.org"
            || host == "rss.arxiv.org"
    }

    // MARK: - List URL → Feed URL

    /// Returns `true` if the URL points to an arXiv subject listing page,
    /// e.g. `https://arxiv.org/list/cs.AI/recent`.
    static func isArXivListURL(_ url: URL) -> Bool {
        guard isArXivHost(url) else { return false }
        return extractCategoryFromListURL(url) != nil
    }

    /// Extracts the arXiv subject category (e.g. `cs.AI`, `math.CO`,
    /// `physics.optics`) from a list URL. Returns `nil` if the URL isn't a
    /// valid list URL.
    static func extractCategoryFromListURL(_ url: URL) -> String? {
        guard isArXivHost(url) else { return nil }
        let components = url.path.split(separator: "/").map(String.init)
        // Expected shape: ["list", "<category>", ...]
        guard components.count >= 2, components[0] == "list" else { return nil }
        let category = components[1]
        guard isValidCategory(category) else { return nil }
        return category
    }

    /// Returns the RSS feed URL for a given arXiv subject category.
    static func feedURL(forCategory category: String) -> String {
        "https://rss.arxiv.org/rss/\(category)"
    }

    /// Returns `true` if the given URL string points to an arXiv RSS feed.
    static func isArXivFeedURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString), let host = url.host?.lowercased() else {
            return false
        }
        if host == "rss.arxiv.org" && url.path.hasPrefix("/rss/") {
            return true
        }
        if (host == "export.arxiv.org" || host == "arxiv.org") && url.path.hasPrefix("/rss/") {
            return true
        }
        return false
    }

    // MARK: - Abstract & PDF URLs

    /// Returns `true` if the URL points to an arXiv abstract page
    /// (`/abs/<id>`).
    static func isArXivAbstractURL(_ url: URL) -> Bool {
        guard isArXivHost(url) else { return false }
        return extractArXivID(from: url) != nil
    }

    /// Extracts the arXiv paper ID from an abstract or PDF URL.
    /// Handles both the new (`2411.12345`) and legacy (`hep-th/0601001`)
    /// identifier formats, plus any trailing version suffix (`v1`, `v2`, …).
    static func extractArXivID(from url: URL) -> String? {
        guard isArXivHost(url) else { return nil }
        let path = url.path
        let prefixes = ["/abs/", "/pdf/", "/html/"]
        guard let prefix = prefixes.first(where: { path.hasPrefix($0) }) else {
            return nil
        }
        var remainder = String(path.dropFirst(prefix.count))
        if remainder.hasSuffix(".pdf") {
            remainder = String(remainder.dropLast(4))
        }
        // Trim any trailing slash.
        if remainder.hasSuffix("/") {
            remainder = String(remainder.dropLast())
        }
        return remainder.isEmpty ? nil : remainder
    }

    /// Returns the canonical PDF URL for a given arXiv paper ID.
    static func pdfURL(forID arXivID: String) -> URL? {
        URL(string: "https://arxiv.org/pdf/\(arXivID).pdf")
    }

    /// Returns the canonical PDF URL for the article at the given URL string,
    /// if it refers to an arXiv abstract or PDF page.
    static func pdfURL(forArticleURL urlString: String) -> URL? {
        guard let url = URL(string: urlString),
              let arXivID = extractArXivID(from: url) else {
            return nil
        }
        return pdfURL(forID: arXivID)
    }

    // MARK: - Validation

    /// arXiv subject categories look like `cs`, `cs.AI`, `math.CO`,
    /// `physics.optics`, `hep-th`, etc. We accept the conservative superset of
    /// lowercase letters, digits, dots, and hyphens.
    private static func isValidCategory(_ category: String) -> Bool {
        guard !category.isEmpty, category.count <= 32 else { return false }
        let allowed = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
        return category.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
