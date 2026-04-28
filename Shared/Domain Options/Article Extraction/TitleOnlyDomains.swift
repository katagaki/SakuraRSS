import Foundation

/// Domains where article titles should always be displayed
/// instead of summaries in feed views.
nonisolated enum TitleOnlyDomains: DomainExceptions {

    static let exceptionDomains: Set<String> = [
        "news.ycombinator.com"
    ]

    static func shouldPreferTitle(feedDomain: String) -> Bool {
        matches(feedDomain: feedDomain)
    }
}
