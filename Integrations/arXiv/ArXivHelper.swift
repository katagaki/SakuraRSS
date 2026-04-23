import Foundation

/// Helpers for detecting arXiv URLs and rewriting list pages to their RSS feeds.
nonisolated enum ArXivHelper {

    // MARK: - Host Detection

    static func isArXivHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "arxiv.org"
            || host == "www.arxiv.org"
            || host == "export.arxiv.org"
            || host == "rss.arxiv.org"
    }

    // MARK: - List URL → Feed URL

    static func isArXivListURL(_ url: URL) -> Bool {
        guard isArXivHost(url) else { return false }
        return extractCategoryFromListURL(url) != nil
    }

    static func extractCategoryFromListURL(_ url: URL) -> String? {
        guard isArXivHost(url) else { return nil }
        let components = url.path.split(separator: "/").map(String.init)
        guard components.count >= 2, components[0] == "list" else { return nil }
        let category = components[1]
        guard isValidCategory(category) else { return nil }
        return category
    }

    static func feedURL(forCategory category: String) -> String {
        "https://rss.arxiv.org/rss/\(category)"
    }

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

    static func isArXivAbstractURL(_ url: URL) -> Bool {
        guard isArXivHost(url) else { return false }
        return extractArXivID(from: url) != nil
    }

    /// Extracts the arXiv paper ID (handles new and legacy formats plus version suffix).
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
        if remainder.hasSuffix("/") {
            remainder = String(remainder.dropLast())
        }
        return remainder.isEmpty ? nil : remainder
    }

    static func pdfURL(forID arXivID: String) -> URL? {
        URL(string: "https://arxiv.org/pdf/\(arXivID).pdf")
    }

    static func pdfURL(forArticleURL urlString: String) -> URL? {
        guard let url = URL(string: urlString),
              let arXivID = extractArXivID(from: url) else {
            return nil
        }
        return pdfURL(forID: arXivID)
    }

    // MARK: - Validation

    private static func isValidCategory(_ category: String) -> Bool {
        guard !category.isEmpty, category.count <= 32 else { return false }
        let allowed = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
        return category.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
