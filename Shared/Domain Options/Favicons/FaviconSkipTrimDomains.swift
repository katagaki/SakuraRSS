import Foundation

/// Domains whose favicons should not have blank/white padding trimmed,
/// because the original image should be used as-is (e.g. profile photos).
/// Note: Circle icon domains (FaviconCircularDomains) automatically skip trimming.
nonisolated enum FaviconSkipTrimDomains {

    static let allowlistedDomains: Set<String> = []

    static func shouldSkipTrimming(feedDomain: String) -> Bool {
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
