import Foundation

/// Domains where article titles should always be displayed
/// instead of summaries in feed views.
nonisolated enum TitleOnlyDomains {

    static let allowlistedDomains: Set<String> = [
        "news.ycombinator.com"
    ]

    static func shouldPreferTitle(feedDomain: String) -> Bool {
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
