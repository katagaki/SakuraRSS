import Foundation

/// Feed domains whose article URLs point to a stub page that gates the
/// real article behind a "read full article" link or button (common on
/// Japanese news aggregators such as news.yahoo.co.jp). Each entry maps
/// the domain to the CSS selector that locates the anchor whose `href`
/// points to the full article.
nonisolated enum OneCushionedDomains {

    static let selectors: [String: String] = [
        "news.yahoo.co.jp": "a[data-ual-gotocontent=true]"
    ]

    /// Returns the CSS selector for the "read article" anchor on the
    /// given domain, or `nil` when the domain is not one-cushioned.
    static func selector(for feedDomain: String) -> String? {
        let host = feedDomain.lowercased()
        if let selector = selectors[host] {
            return selector
        }
        for (source, selector) in selectors where host.hasSuffix(".\(source)") {
            return selector
        }
        return nil
    }

    static func selector(for url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        return selector(for: host)
    }

    static func isOneCushioned(feedDomain: String) -> Bool {
        selector(for: feedDomain) != nil
    }

    static func isOneCushioned(url: URL) -> Bool {
        selector(for: url) != nil
    }
}
