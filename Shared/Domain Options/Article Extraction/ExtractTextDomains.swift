import Foundation

/// Domains that require WebView-based text extraction because content is dynamically loaded.
nonisolated enum ExtractTextDomains: DomainDefaults {

    static let exceptionDomains: Set<String> = [
        "apple.com",
        "france24.com"
    ]

    static func shouldExtractText(feedDomain: String) -> Bool {
        matches(feedDomain: feedDomain)
    }

    static func shouldExtractText(for url: URL) -> Bool {
        matches(url: url)
    }
}
