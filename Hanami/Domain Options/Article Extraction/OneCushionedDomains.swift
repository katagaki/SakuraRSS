import Foundation

/// Domains whose feed URLs gate the real article behind a "read more"
/// anchor, mapped to the CSS selector that locates that anchor.
public nonisolated enum OneCushionedDomains: DomainDefaults {

    public static let selectors: [String: String] = [
        "news.yahoo.co.jp": "a[data-ual-gotocontent=true]"
    ]

    public static var exceptionDomains: Set<String> { Set(selectors.keys) }

    public static func selector(for feedDomain: String) -> String? {
        matchedDomain(for: feedDomain).flatMap { selectors[$0] }
    }

    public static func selector(for url: URL) -> String? {
        matchedDomain(for: url).flatMap { selectors[$0] }
    }

    public static func isOneCushioned(feedDomain: String) -> Bool {
        matches(feedDomain: feedDomain)
    }

    public static func isOneCushioned(url: URL) -> Bool {
        matches(url: url)
    }
}
