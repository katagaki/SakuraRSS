import Foundation

/// Domains whose favicons should not have blank padding trimmed.
nonisolated enum FaviconSkipTrimDomains: DomainExceptions {

    static let exceptionDomains: Set<String> = []

    static func shouldSkipTrimming(feedDomain: String) -> Bool {
        matches(feedDomain: feedDomain)
    }
}
