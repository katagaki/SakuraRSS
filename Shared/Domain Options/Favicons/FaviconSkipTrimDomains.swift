import Foundation

/// Domains whose favicons should not have blank padding trimmed.
nonisolated enum FaviconSkipTrimDomains {

    static let allowlistedDomains: Set<String> = []

    static func shouldSkipTrimming(feedDomain: String) -> Bool {
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
