import Foundation

extension TodayTabItem {

    static func items(
        sections: [HomeSection],
        lists: [FeedList],
        topics: [String],
        configuration: HomeBarConfiguration
    ) -> [TodayTabItem] {
        var items: [TodayTabItem] = []

        if sections.contains(.all) {
            items.append(item(for: .all))
        }

        for kind in configuration.orderedItems where configuration.enabledItems.contains(kind) {
            switch kind {
            case .lists:
                items.append(contentsOf: lists.map(item(for:)))
            case .topics:
                items.append(contentsOf: topics.map(topicItem(name:)))
            default:
                if let homeSection = HomeSection(rawValue: kind.rawValue),
                   sections.contains(homeSection) {
                    items.append(item(for: homeSection))
                }
            }
        }
        return items
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
