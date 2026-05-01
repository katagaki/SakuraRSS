import Foundation

extension TodayTabItem {

    static func items(
        sections: [HomeSection],
        lists: [FeedList]
    ) -> [TodayTabItem] {
        let primaryOrder: [HomeSection] = [.all, .feeds, .podcasts]
        let primary = primaryOrder.filter { sections.contains($0) }
        let others = sections
            .filter { !primaryOrder.contains($0) }
            .sorted { lhs, rhs in
                lhs.localizedTitle.localizedCompare(rhs.localizedTitle) == .orderedAscending
            }

        var items: [TodayTabItem] = []
        for section in primary + others {
            items.append(
                TodayTabItem(
                    id: HomeSelection.section(section).rawValue,
                    title: section.todayTabTitle,
                    selection: .section(section)
                )
            )
        }
        for list in lists {
            items.append(
                TodayTabItem(
                    id: HomeSelection.list(list.id).rawValue,
                    title: list.name,
                    selection: .list(list.id)
                )
            )
        }
        return items
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
