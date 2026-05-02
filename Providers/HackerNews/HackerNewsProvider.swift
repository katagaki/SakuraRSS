import Foundation

/// Identifies Hacker News (`news.ycombinator.com`) feeds and the per-item
/// thread URL that lives in the RSS `<comments>` element / summary link.
nonisolated enum HackerNewsProvider: RSSFeedProvider {

    static let host = "news.ycombinator.com"

    static var providerID: String { "hacker_news" }

    static func matchesFeedURL(_ feedURL: String) -> Bool {
        guard let url = URL(string: feedURL),
              let host = url.host?.lowercased() else { return false }
        return host == Self.host || host.hasSuffix(".\(Self.host)")
    }

    /// Returns the HN thread URL embedded in `summary` (the markdown link
    /// produced from the RSS `<comments>` element).
    static func threadURL(fromSummary summary: String) -> URL? {
        guard !summary.isEmpty,
              let regex = try? NSRegularExpression(
                pattern: #"\[[^\]]*\]\(([^)\s]+)\)"#
              ) else { return nil }
        let summaryString = summary as NSString
        let matches = regex.matches(
            in: summary, range: NSRange(location: 0, length: summaryString.length)
        )
        for match in matches where match.numberOfRanges >= 2 {
            let raw = summaryString.substring(with: match.range(at: 1))
            guard let url = URL(string: raw),
                  let host = url.host?.lowercased(),
                  host == Self.host || host.hasSuffix(".\(Self.host)"),
                  threadID(from: url) != nil else { continue }
            return url
        }
        return nil
    }

    /// Extracts the numeric `id` from a `news.ycombinator.com/item?id=NNN` URL.
    static func threadID(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.path == "/item" else { return nil }
        let value = components.queryItems?.first(where: { $0.name == "id" })?.value
        guard let value, !value.isEmpty, value.allSatisfy({ $0.isNumber }) else { return nil }
        return value
    }
}
