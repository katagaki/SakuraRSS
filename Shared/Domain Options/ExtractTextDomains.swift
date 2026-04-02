import Foundation

/// Domains that require WebView-based text extraction (JavaScript rendering)
/// instead of simple HTTP fetch, because their content is dynamically loaded.
nonisolated enum ExtractTextDomains {

    static let allowlistedDomains: Set<String> = [
        "apple.com"
    ]

    static func shouldExtractText(feedDomain: String) -> Bool {
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }

    static func shouldExtractText(for url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
