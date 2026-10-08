import Foundation

public nonisolated enum FeedDisplayStyleSection: CaseIterable, Sendable {
    case classic
    case feed
    case mediaFocused
    case grids
    case immersive

    public var localizedTitle: String {
        switch self {
        case .classic: String(localized: "StyleSection.Classic", table: "Articles")
        case .feed: String(localized: "StyleSection.Feed", table: "Articles")
        case .mediaFocused: String(localized: "StyleSection.MediaFocused", table: "Articles")
        case .grids: String(localized: "StyleSection.Grids", table: "Articles")
        case .immersive: String(localized: "StyleSection.Immersive", table: "Articles")
        }
    }

    public var styles: [FeedDisplayStyle] {
        switch self {
        case .classic: [.inbox, .compact, .timeline]
        case .feed: [.feed, .feedSingle, .feedGrid]
        case .mediaFocused: [.feedCompact, .photos, .video, .podcast]
        case .grids: [.magazine, .masonry, .grid]
        case .immersive: [.cards, .scroll]
        }
    }
}
