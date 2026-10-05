import Foundation
import Hanami

struct SidebarTreeBuilder {

    let feedManager: FeedManager

    func build() -> [SidebarNode] {
        var nodes = [locationNode(.startPage), locationNode(.allContent), bookmarksNode()]
        if UserDefaults.standard.bool(forKey: "Intelligence.ContentInsights.Enabled") {
            nodes.append(locationNode(.topics))
        }
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

    /// Bookmarks, with its folders and then the tags in use beneath it. Counts
    /// and tags come from one query each rather than one per row.
    private func bookmarksNode() -> SidebarNode {
        let folderCounts = feedManager.bookmarkCountsByFolderID()
        let folders = feedManager.bookmarkFolders
            .filter { $0.parentFolderID == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { locationNode(.bookmarkFolder($0.id), unreadCount: folderCounts[$0.id] ?? 0) }
        let tags = feedManager.bookmarkTagsInUse()
            .sorted { $0.tag.name.localizedStandardCompare($1.tag.name) == .orderedAscending }
            .map { locationNode(.bookmarkTag($0.tag.id), title: $0.tag.name, unreadCount: $0.count) }
        return locationNode(.bookmarks, children: folders + tags)
    }

    private func sectionNode(_ section: FeedSection) -> SidebarNode? {
        let feeds = feedManager.feeds
            .filter { $0.feedSection == section }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        guard !feeds.isEmpty else { return nil }
        let unreadCount = feeds.reduce(0) { $0 + countedUnread(for: $1) }
        return locationNode(
            .feedSection(section),
            unreadCount: unreadCount,
            children: feeds.map { locationNode(.feed($0.id), unreadCount: countedUnread(for: $0)) }
        )
    }

    /// What the Dock badge counts: muted feeds count nothing, and hidden reels are left out.
    private func countedUnread(for feed: Feed) -> Int {
        feed.isMuted ? 0 : feedManager.effectiveUnreadCount(forFeedID: feed.id)
    }

    private func locationNode(
        _ location: BrowserLocation,
        title: String? = nil,
        unreadCount: Int = 0,
        children: [SidebarNode] = []
    ) -> SidebarNode {
        SidebarNode(
            .location(
                location,
                title: title ?? location.title(in: feedManager),
                symbolName: location.symbolName(in: feedManager),
                unreadCount: unreadCount
            ),
            children: children
        )
    }
}
