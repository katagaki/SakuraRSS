import Foundation

extension HomeSectionBarItem {

    static func items(
        sections: [HomeSection],
        lists: [FeedList],
        topics: [String],
        configuration: HomeBarConfiguration
    ) -> [HomeSectionBarItem] {
        var items: [HomeSectionBarItem] = []

        if configuration.enabledItems.contains(.today) {
            items.append(item(for: .today))
        }

        if sections.contains(.all) {
            items.append(item(for: .all))
        }

        for kind in configuration.orderedItems where configuration.enabledItems.contains(kind) && kind != .today {
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

    private static func item(for section: HomeSection) -> HomeSectionBarItem {
        HomeSectionBarItem(
            id: HomeSelection.section(section).rawValue,
            title: section.barTitle,
            selection: .section(section)
        )
    }

    private static func item(for list: FeedList) -> HomeSectionBarItem {
        HomeSectionBarItem(
            id: HomeSelection.list(list.id).rawValue,
            title: list.name,
            selection: .list(list.id),
            listIconName: list.icon
        )
    }

    private static func topicItem(name: String) -> HomeSectionBarItem {
        HomeSectionBarItem(
            id: HomeSelection.topic(name).rawValue,
            title: name,
            selection: .topic(name)
        )
    }
}

private extension HomeSection {
    var barTitle: String {
        switch self {
        case .all:
            String(localized: "Sidebar.Following", table: "Feeds")
        default:
            localizedTitle
        }
    }
}
