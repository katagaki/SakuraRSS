import SwiftUI
import Hanami

extension FollowingPage {

    var focusFilteredFeeds: [Feed] {
        guard applyFocus else { return feedManager.feeds }
        let focused = feedManager.focusedFeedIDs
        return feedManager.feeds.filter { focused.contains($0.id) }
    }

    var filteredFeeds: [Feed] {
        let base = focusFilteredFeeds
        if searchText.isEmpty {
            return base
        }
        return base.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.domain.localizedCaseInsensitiveContains(searchText)
        }
    }

    var sortedLists: [FeedList] {
        let base = applyFocus
            ? feedManager.lists.filter { feedManager.isListInFocus($0) }
            : feedManager.lists
        if searchText.isEmpty {
            return base.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }
        return base
            .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func feedsForSection(_ section: FeedSection) -> [Feed] {
        let feeds = filteredFeeds.filter { $0.feedSection == section }
        if section == .feeds {
            return feeds
        }
        return feeds.sorted {
            let domainCompare = $0.domain.localizedStandardCompare($1.domain)
            if domainCompare != .orderedSame { return domainCompare == .orderedAscending }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    @ViewBuilder
    var feedSectionsContent: some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            focusBanner
            listsSection
            ForEach(FeedSection.allCases, id: \.self) { section in
                feedSection(section)
            }
        }
    }

    @ViewBuilder
    var focusBanner: some View {
        if feedManager.isFocusActive, !isEditingFeeds, !isSelectingFeeds {
            HStack(spacing: 12) {
                Image(systemName: "moon.fill")
                    .foregroundStyle(.tint)
                Text(applyFocus
                    ? String(localized: "Focus.Banner.Active", table: "Feeds")
                    : String(localized: "Focus.Banner.ShowingAll", table: "Feeds"))
                    .font(.subheadline)
                Spacer()
                Button {
                    withAnimation(.smooth.speed(2.0)) {
                        isShowingAllDespiteFocus.toggle()
                    }
                } label: {
                    Text(applyFocus
                        ? String(localized: "Focus.Banner.ShowAll", table: "Feeds")
                        : String(localized: "Focus.Banner.ShowFocused", table: "Feeds"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(.thinMaterial, in: .rect(cornerRadius: 12))
        }
    }

    @ViewBuilder
    var listsSection: some View {
        let lists = sortedLists
        if !lists.isEmpty {
            Section {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 12) {
                    ForEach(lists) { list in
                        listCell(list)
                    }
                }
            } header: {
                Text(String(localized: "Section.Lists", table: "Settings"))
                    .font(.title3)
                    .fontWeight(.bold)
            }
        }
    }

    @ViewBuilder
    func listCell(_ list: FeedList) -> some View {
        if isEditingFeeds {
            FollowingListGridCell(
                list: list,
                isWiggling: true,
                onDelete: { listToDelete = list }
            )
            .dropDestination(for: FollowingFeedDragItem.self) { items, _ in
                addFeeds(items, to: list)
            }
            .id(list.id)
        } else {
            NavigationLink(value: list) {
                FollowingListGridCell(list: list)
            }
            .buttonStyle(.plain)
            .matchedSource(id: FollowingZoomID.list(list.id), in: followingNavigationNamespace)
            .id(list.id)
        }
    }

    @discardableResult
    func addFeeds(_ items: [FollowingFeedDragItem], to list: FeedList) -> Bool {
        var didAdd = false
        for item in items {
            guard let feed = feedManager.feedsByID[item.feedID] else { continue }
            feedManager.addFeedToList(list, feed: feed)
            didAdd = true
        }
        return didAdd
    }

    @ViewBuilder
    func feedSection(_ section: FeedSection) -> some View {
        let feeds = feedsForSection(section)
        if !feeds.isEmpty {
            Section {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 12) {
                    ForEach(feeds) { feed in
                        feedCell(feed)
                    }
                }
            } header: {
                feedSectionHeader(section)
            }
        }
    }

    @ViewBuilder
    func feedSectionHeader(_ section: FeedSection) -> some View {
        if isEditingFeeds || isSelectingFeeds {
            Text(section.localizedTitle)
                .font(.title3)
                .fontWeight(.bold)
        } else {
            NavigationLink(value: section) {
                HStack(spacing: 4) {
                    Text(section.localizedTitle)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .matchedSource(id: FollowingZoomID.section(section), in: followingNavigationNamespace)
        }
    }

    @ViewBuilder
    func feedCell(_ feed: Feed) -> some View {
        if isSelectingFeeds {
            FollowingFeedGridCell(
                feed: feed,
                isWiggling: true,
                isSelectMode: true,
                isSelected: selectedFeedIDs.contains(feed.id),
                onTap: { toggleSelection(feed) },
                editTransitionNamespace: feedEditNamespace
            )
            .id(feed.id)
        } else if isEditingFeeds {
            FollowingFeedGridCell(
                feed: feed,
                isWiggling: true,
                onDelete: { feedToDelete = feed },
                onTap: { feedToEdit = feed },
                editTransitionNamespace: feedEditNamespace
            )
            .draggable(FollowingFeedDragItem(feedID: feed.id))
            .id(feed.id)
        } else {
            NavigationLink(value: feed) {
                FollowingFeedGridCell(feed: feed, editTransitionNamespace: feedEditNamespace)
            }
            .buttonStyle(.plain)
            .matchedSource(id: FollowingZoomID.feed(feed.id), in: followingNavigationNamespace)
            .contextMenu {
                FollowingFeedGridContextMenu(
                    feed: feed,
                    feedToEdit: $feedToEdit,
                    feedForRules: $feedForRules,
                    feedToDelete: $feedToDelete
                )
            }
            // Keep .id after .contextMenu: lazy grids reuse the menu interaction and can
            // present the previously long-pressed feed's menu without an explicit identity.
            .id(feed.id)
        }
    }
}
