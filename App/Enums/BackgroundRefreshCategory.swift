import Foundation

nonisolated enum BackgroundRefreshCategory: String, CaseIterable, Sendable {
    case rss
    case reddit
    case youtube
    case rssSocial
    case x // swiftlint:disable:this identifier_name
    case instagram

    var taskID: String {
        "com.tsubuzaki.SakuraRSS.RefreshFeeds.\(rawValue)"
    }

    func includes(_ feed: Feed) -> Bool {
        switch self {
        case .rss:
            return !feed.isXFeed && !feed.isInstagramFeed && !feed.isRedditFeed
                && !feed.isYouTubeFeed && !feed.isBlueskyFeed && !feed.isFediverseFeed
                && !PetalRecipe.isPetalFeedURL(feed.url)
        case .reddit:
            return feed.isRedditFeed
        case .youtube:
            return feed.isYouTubeFeed
        case .rssSocial:
            return feed.isBlueskyFeed || feed.isFediverseFeed
        case .x:
            return feed.isXFeed
        case .instagram:
            return feed.isInstagramFeed
        }
    }
}
