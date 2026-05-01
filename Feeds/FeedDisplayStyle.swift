import Foundation

nonisolated enum FeedDisplayStyle: String, CaseIterable, Sendable {
    case inbox
    case feed
    case feedCompact
    case magazine
    case masonry
    case compact
    case video
    case photos
    case podcast
    case timeline
    case cards
    case grid
    case scroll

    var localizedName: String {
        switch self {
        case .inbox: String(localized: "Style.Inbox", table: "Articles")
        case .feed: String(localized: "Style.Feed", table: "Articles")
        case .feedCompact: String(localized: "Style.FeedCompact", table: "Articles")
        case .magazine: String(localized: "Style.Magazine", table: "Articles")
        case .masonry: String(localized: "Style.Masonry", table: "Articles")
        case .compact: String(localized: "Style.Compact", table: "Articles")
        case .video: String(localized: "Style.Video", table: "Articles")
        case .photos: String(localized: "Style.Photos", table: "Articles")
        case .podcast: String(localized: "Style.Podcast", table: "Articles")
        case .timeline: String(localized: "Style.Timeline", table: "Articles")
        case .cards: String(localized: "Style.Cards", table: "Articles")
        case .grid: String(localized: "Style.Grid", table: "Articles")
        case .scroll: String(localized: "Style.Scroll", table: "Articles")
        }
    }

    var requiresImages: Bool {
        switch self {
        case .magazine, .masonry, .photos, .cards, .grid: true
        default: false
        }
    }

    /// Styles whose scroll container can host the in-content rich feed header.
    /// Cards/Scroll layouts manage their own immersive scrolling, so they
    /// surface the feed identity through the navigation bar instead.
    var supportsRichHeader: Bool {
        switch self {
        case .cards, .scroll: false
        default: true
        }
    }
}
