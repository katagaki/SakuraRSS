import Foundation

/// Maps feed domains to alternative domains for favicon fetching.
/// For example, feeds served from a CDN subdomain can be mapped
/// to the main site so that the correct favicon is retrieved.
nonisolated enum FaviconAlternateDomains {

    static let mappings: [String: String] = [
        "feeds.bbci.co.uk": "bbc.co.uk",
        "news.ycombinator.com": "hnrss.org"
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
