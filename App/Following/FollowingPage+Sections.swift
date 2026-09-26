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

    /// Groups the filtered feeds by section once, so each section doesn't
    /// re-filter and re-sort the whole feed list on every body evaluation.
    var feedsBySection: [FeedSection: [Feed]] {
        var grouped = Dictionary(grouping: filteredFeeds, by: \.feedSection)
        for (section, feeds) in grouped where section != .feeds {
            grouped[section] = feeds.sorted {
                let domainCompare = $0.domain.localizedStandardCompare($1.domain)
                if domainCompare != .orderedSame { return domainCompare == .orderedAscending }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        }
        return grouped
    }

    @ViewBuilder
    var feedSectionsContent: some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            focusBanner
            let groupedFeeds = feedsBySection
            ForEach(FeedSection.allCases, id: \.self) { section in
                feedSection(section, feeds: groupedFeeds[section] ?? [])
            }
        }
    }

    @ViewBuilder
    var focusBanner: some View {
        if feedManager.isFocusEffective, !isEditingFeeds, !isSelectingFeeds {
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
    func feedSection(_ section: FeedSection, feeds: [Feed]) -> some View {
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
