import Foundation
import Hanami

struct SidebarTreeBuilder {

    let feedManager: FeedManager

    func build() -> [SidebarNode] {
        var nodes = [BrowserLocation.startPage, .allContent, .bookmarks].map { locationNode($0) }
        if !feedManager.lists.isEmpty {
            let lists = feedManager.lists
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { locationNode(.list($0.id)) }
            nodes.append(SidebarNode(.group(title: String(localized: "Tabs.Lists")), children: lists))
        }
        let sections = FeedSection.allCases.compactMap(sectionNode)
        if !sections.isEmpty {
            let title = String(localized: "Sidebar.Following", table: "Feeds")
            nodes.append(SidebarNode(.group(title: title), children: sections))
        }
        return nodes
    }

    private func sectionNode(_ section: FeedSection) -> SidebarNode? {
        let feeds = feedManager.feeds
            .filter { $0.feedSection == section }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        guard !feeds.isEmpty else { return nil }
        let unreadCount = feeds.reduce(0) { $0 + (feedManager.unreadCounts[$1.id] ?? 0) }
        return locationNode(
            .feedSection(section),
            unreadCount: unreadCount,
            children: feeds.map { locationNode(.feed($0.id), unreadCount: feedManager.unreadCounts[$0.id] ?? 0) }
        )
    }

    private func locationNode(
        _ location: BrowserLocation,
        unreadCount: Int = 0,
        children: [SidebarNode] = []
    ) -> SidebarNode {
        SidebarNode(
            .location(
                location,
                title: location.title(in: feedManager),
                symbolName: location.symbolName(in: feedManager),
                unreadCount: unreadCount
            ),
            children: children
        )
    }
}
