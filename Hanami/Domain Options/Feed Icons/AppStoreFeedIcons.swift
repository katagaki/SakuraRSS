import Foundation

public nonisolated enum AppStoreFeedIcons: DomainDefaults {
    public static let appIDs: [String: Int] = [
        "x.com": 333903271,
        "twitter.com": 333903271,
        "reddit.com": 1064216828,
        "bsky.app": 6444370199,
        "note.com": 906581110,
        "substack.com": 1581650857
    ]

    public static var exceptionDomains: Set<String> { Set(appIDs.keys) }

    public static func appID(for domain: String) -> Int? {
        guard let matched = matchedDomain(for: domain) else { return nil }
        return appIDs[matched]
    }

    public static func appID(for feed: Feed) -> Int? {
        if feed.isSubstackFeed { return appIDs["substack.com"] }
        return appID(for: feed.domain)
    }
}
