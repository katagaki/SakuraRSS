import Foundation
import Hanami

extension TodayShortcutItem {

    /// Every shortcut Today can offer right now, in the default order.
    static func macItems(in feedManager: FeedManager) -> [TodayShortcutItem] {
        let followedSections = Set(feedManager.feeds.map(\.feedSection))
        let sections = FeedSection.allCases.filter { followedSections.contains($0) }
        let lists = feedManager.lists
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return sections.map { .feedSection($0) }
            + [.allContent, .bookmarks]
            + lists.map { .list($0.id) }
    }

    /// The Mac has no Following page, so it never offers that shortcut.
    var location: BrowserLocation? {
        switch self {
        case .following: nil
        case .allContent: .allContent
        case .bookmarks: .bookmarks
        case .topics: .topics
        case .feedSection(let section): .feedSection(section)
        case .list(let listID): .list(listID)
        }
    }
}
