import Foundation

/// Domains whose articles should always open in the browser rather than the in-app article detail view.
/// This replaces and extends `SafariDomains` with support for URL scheme overrides.
nonisolated enum OpenInBrowserDomains {

    struct DomainConfig {
        let domain: String
        /// Optional URL scheme to use instead of the original URL (e.g. "reddit://").
        /// When nil, the original article URL is opened as-is in the browser.
        let urlScheme: String?

        init(_ domain: String, urlScheme: String? = nil) {
            self.domain = domain
            self.urlScheme = urlScheme
        }
    }

    static let configurations: [DomainConfig] = [
        DomainConfig("news.ycombinator.com"),
        DomainConfig("news.yahoo.co.jp")
    ]

    private static let allowlistedDomains: Set<String> = Set(configurations.map(\.domain))

    static func shouldOpenInBrowser(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }

    static func shouldOpenInBrowser(feedDomain: String) -> Bool {
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }

    /// Returns the URL to open for a given article URL, applying any URL scheme overrides.
    static func browserURL(for articleURL: URL) -> URL? {
        guard let host = articleURL.host?.lowercased() else { return articleURL }
        for config in configurations {
            if host == config.domain || host.hasSuffix(".\(config.domain)") {
                if let scheme = config.urlScheme {
                    var components = URLComponents(url: articleURL, resolvingAgainstBaseURL: false)
                    components?.scheme = scheme.replacingOccurrences(of: "://", with: "")
                    return components?.url ?? articleURL
                }
                return articleURL
            }
        }
        return articleURL
    }
}
