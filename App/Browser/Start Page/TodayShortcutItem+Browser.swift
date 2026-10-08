import SwiftUI
import Hanami

extension TodayShortcutItem {

    /// Every shortcut Today can offer right now, in the default order.
    static func browserItems(in feedManager: FeedManager) -> [TodayShortcutItem] {
        let feeds = feedManager.isFocusEffective
            ? feedManager.feeds.filter { feedManager.focusedFeedIDs.contains($0.id) }
            : feedManager.feeds
        let followedSections = Set(feeds.map(\.feedSection))
        let sections = FeedSection.allCases.filter { followedSections.contains($0) }
        let lists = (feedManager.isFocusEffective
            ? feedManager.lists.filter { feedManager.isListInFocus($0) }
            : feedManager.lists)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return [.following]
            + sections.map { .feedSection($0) }
            + [.allContent, .bookmarks, .topics]
            + lists.map { .list($0.id) }
    }

    var browserLocation: BrowserLocation? {
        switch self {
        case .following: .feeds
        case .allContent: .allContent
        case .bookmarks: nil
        case .topics: .topics
        case .feedSection(let section): .feedSection(section)
        case .list(let listID): .list(listID)
        }
    }

    func browserTitle(in feedManager: FeedManager) -> String {
        switch self {
        case .following: String(localized: "Tabs.Feeds")
        case .allContent: String(localized: "Location.AllContent", table: "Browser")
        case .bookmarks: String(localized: "Location.Bookmarks", table: "Browser")
        case .topics: String(localized: "Location.Topics", table: "Browser")
        case .feedSection(let section): section.localizedTitle
        case .list(let listID): feedManager.lists.first { $0.id == listID }?.name ?? ""
        }
    }

    func browserSymbolName(in feedManager: FeedManager) -> String {
        switch self {
        case .following: "dot.radiowaves.up.forward"
        case .allContent: "tray.full"
        case .bookmarks: "bookmark"
        case .topics: "number"
        case .feedSection(let section): section.browserSymbolName
        case .list(let listID): feedManager.lists.first { $0.id == listID }?.icon ?? "list.bullet"
        }
    }
}
