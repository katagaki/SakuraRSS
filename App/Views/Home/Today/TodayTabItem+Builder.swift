import Foundation

extension TodayTabItem {

    static func items(
        sections: [HomeSection],
        lists: [FeedList],
        topics: [String],
        configuration: HomeBarConfiguration
    ) -> [TodayTabItem] {
        var items: [TodayTabItem] = []
        for kind in configuration.orderedItems where configuration.enabledItems.contains(kind) {
            switch kind {
            case .following:
                if sections.contains(.all) {
                    items.append(item(for: .all))
                }
            case .feedSections:
                items.append(contentsOf: feedSectionItems(from: sections))
            case .lists:
                items.append(contentsOf: lists.map(item(for:)))
            case .topics:
                items.append(contentsOf: topics.map(topicItem(name:)))
            }
        }
        return items
    }

    private static func feedSectionItems(from sections: [HomeSection]) -> [TodayTabItem] {
        let primaryOrder: [HomeSection] = [.feeds, .podcasts]
        let primary = primaryOrder.filter { sections.contains($0) }
        let others = sections
            .filter { $0 != .all && !primaryOrder.contains($0) }
            .sorted { lhs, rhs in
                lhs.localizedTitle.localizedCompare(rhs.localizedTitle) == .orderedAscending
            }
        return (primary + others).map(item(for:))
    }

    private static func item(for section: HomeSection) -> TodayTabItem {
        TodayTabItem(
            id: HomeSelection.section(section).rawValue,
            title: section.todayTabTitle,
            selection: .section(section)
        )
    }

    private static func item(for list: FeedList) -> TodayTabItem {
        TodayTabItem(
            id: HomeSelection.list(list.id).rawValue,
            title: list.name,
            selection: .list(list.id)
        )
    }

    private static func topicItem(name: String) -> TodayTabItem {
        TodayTabItem(
            id: HomeSelection.topic(name).rawValue,
            title: name,
            selection: .topic(name)
        )
    }
}

private extension HomeSection {
    var todayTabTitle: String {
        switch self {
        case .all:
            String(localized: "Sidebar.Following", table: "Feeds")
        default:
            localizedTitle
        }
    }
}
