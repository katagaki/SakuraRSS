import Foundation

/// Domains whose feed URLs gate the real article behind a "read more"
/// anchor, mapped to the CSS selector that locates that anchor.
nonisolated enum OneCushionedDomains {

    static let selectors: [String: String] = [
        "news.yahoo.co.jp": "a[data-ual-gotocontent=true]"
    ]

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
