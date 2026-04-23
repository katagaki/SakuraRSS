import Foundation

/// Maps feed domains to alternative domains for favicon fetching.
nonisolated enum FaviconAlternateDomains {

    static let mappings: [String: String] = [
        "feeds.bbci.co.uk": "bbc.co.uk",
        "news.ycombinator.com": "hnrss.org",
        "rssfeed.azure.status.microsoft": "microsoft.com",
        "status.azure.com": "microsoft.com"
    ]

    /// Returns the mapped domain for favicon fetching, or the original domain if no mapping exists.
    static func faviconDomain(for feedDomain: String) -> String {
        let host = feedDomain.lowercased()
        if let mapped = mappings[host] {
            return mapped
        }
        for (source, destination) in mappings where host.hasSuffix(".\(source)") {
            return destination
        }
        return host
    }
}
