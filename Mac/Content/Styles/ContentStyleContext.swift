import Foundation
import Hanami

/// Everything that decides a page's display style, worked out the way iOS's
/// content views do: the saved choice, else a style implied by the kind of
/// feed, else the default, then narrowed to what the content can show.
struct ContentStyleContext {

    let key: String
    let isPodcast: Bool
    let isVideo: Bool
    let isInstagram: Bool
    let isTimelineDomain: Bool
    let isFeedCompactDomain: Bool
    let isFeedDomain: Bool
    let hasImages: Bool
    let hasAudio: Bool

    init?(location: BrowserLocation, articles: [Article], feedManager: FeedManager) {
        guard let key = location.styleKey else { return nil }
        self.key = key
        let feed: Feed? = if case .feed(let feedID) = location { feedManager.feedsByID[feedID] } else { nil }
        let section: FeedSection? = if case .feedSection(let section) = location { section } else { nil }
        isPodcast = feed?.isPodcast ?? (section == .podcasts)
        isVideo = feed?.isVideoFeed ?? [.youtube, .vimeo, .niconico].contains(section)
        isInstagram = feed?.isInstagramFeed ?? false
        isTimelineDomain = feed?.isTimelineViewDomain ?? false
        isFeedCompactDomain = feed?.isFeedCompactViewDomain ?? false
        isFeedDomain = feed?.isFeedViewDomain ?? [.x, .fediverse, .bluesky].contains(section)
        hasImages = articles.contains { $0.imageURL != nil }
        hasAudio = articles.contains { $0.audioURL != nil }
    }

    var storedStyle: FeedDisplayStyle {
        if let raw = UserDefaults.standard.string(forKey: "Display.Style.\(key)"),
           let style = FeedDisplayStyle(rawValue: raw) {
            return style
        }
        if isPodcast { return .podcast }
        if isVideo { return .video }
        if isInstagram { return .photos }
        if isTimelineDomain { return .timeline }
        if isFeedCompactDomain { return .feedCompact }
        if isFeedDomain { return .feed }
        let defaultRaw = UserDefaults.standard.string(forKey: "Display.DefaultStyle") ?? ""
        return FeedDisplayStyle(rawValue: defaultRaw) ?? .inbox
    }

    var effectiveStyle: FeedDisplayStyle {
        let style = storedStyle
        return isAvailable(style) ? style : .inbox
    }

    func isAvailable(_ style: FeedDisplayStyle) -> Bool {
        if style.requiresImages && !hasImages { return false }
        if style == .podcast && !(isPodcast || hasAudio) { return false }
        if style == .timeline && key == "all" { return false }
        return true
    }

    func save(_ style: FeedDisplayStyle) {
        UserDefaults.standard.set(style.rawValue, forKey: "Display.Style.\(key)")
    }

    /// The groups iOS's style picker shows, without the styles this page can't use.
    var menuSections: [(title: String, styles: [FeedDisplayStyle])] {
        let groups: [(String.LocalizationValue, [FeedDisplayStyle])] = [
            ("StyleSection.Classic", [.inbox, .compact, .timeline]),
            ("StyleSection.MediaFocused", [.feed, .feedCompact, .photos, .video, .podcast]),
            ("StyleSection.Grids", [.magazine, .masonry, .grid]),
            ("StyleSection.Immersive", [.cards, .scroll])
        ]
        return groups.compactMap { title, styles in
            let available = styles.filter(isAvailable)
            return available.isEmpty ? nil : (String(localized: title, table: "Articles"), available)
        }
    }
}

extension BrowserLocation {

    /// iOS's keys, so a style picked on one device means the same on the other.
    var styleKey: String? {
        switch self {
        case .allContent: "all"
        case .feedSection(let section): "home.\(section.rawValue)"
        case .feed(let feedID): String(feedID)
        case .list(let listID): "list.\(listID)"
        case .bookmarks: "bookmarks"
        case .search: "search"
        case .startPage, .article: nil
        }
    }
}

extension FeedDisplayStyle {

    /// Styles laid out as a list beside the reader, as iOS's reader split does.
    var isListStyle: Bool {
        switch self {
        case .inbox, .compact, .timeline, .feed, .feedCompact: true
        default: false
        }
    }
}
