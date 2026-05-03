import Foundation

/// Maps feed domains to alternative domains for icon fetching.
nonisolated enum FeedIconAlternateDomains: DomainExceptions {

    static let mappings: [String: String] = [
        "feeds.bbci.co.uk": "bbc.co.uk",
        "news.ycombinator.com": "hnrss.org",
        "rssfeed.azure.status.microsoft": "microsoft.com",
        "status.azure.com": "microsoft.com",
        "githubstatus.com": "github.com"
    ]

    static var exceptionDomains: Set<String> { Set(mappings.keys) }

    /// Returns the mapped domain for icon fetching, or the original domain if no mapping exists.
    static func iconDomain(for feedDomain: String) -> String {
        guard let source = matchedDomain(for: feedDomain),
              let destination = mappings[source] else { return feedDomain.lowercased() }
        return destination
    }
}
