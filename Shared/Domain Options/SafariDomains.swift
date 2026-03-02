import Foundation

/// Domains that should open Safari instead of the detail view
nonisolated enum SafariDomains {

    static let allowlistedDomains: Set<String> = [
        "reddit.com",
        "news.ycombinator.com",
        "news.yahoo.co.jp"
    ]

    static func shouldOpenInSafari(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
