import SwiftUI

struct FollowingPage: View {

    @Environment(FeedManager.self) var feedManager
    @State private var searchText = ""
    @State private var isPresentingAddFeedSheet = false
    @State private var isPresentingEditFeedSheet = false
    @State private var feedToEdit: Feed?
    @State private var feedToDelete: Feed?
    @State private var isEditingFeeds = false
    @State private var isSelectingFeeds = false
    @State private var selectedFeedIDs: Set<Int64> = []
    @State private var isPresentingBulkEditSheet = false
    @State private var isPresentingBulkDeleteAlert = false
    @Namespace private var addFeedNamespace
    @Namespace private var feedEditNamespace

    var filteredFeeds: [Feed] {
        if searchText.isEmpty {
            return feedManager.feeds
        }
        return feedManager.feeds.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.domain.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func feedsForSection(_ section: FeedSection) -> [Feed] {
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

    private let gridColumns = [GridItem(.adaptive(minimum: 80), spacing: 16)]

    private var selectedFeeds: [Feed] {
        selectedFeedIDs.compactMap { feedManager.feedsByID[$0] }
    }

    var body: some View {
        ZStack {
            ScrollView {
                feedSectionsContent
                    .padding()
                    .animation(.smooth.speed(2.0), value: feedManager.feeds)
                    .animation(.smooth.speed(2.0), value: searchText)
                    .animation(.smooth.speed(2.0), value: isEditingFeeds)
                    .animation(.smooth.speed(2.0), value: isSelectingFeeds)
                    .animation(.smooth.speed(2.0), value: selectedFeedIDs)
            }
        }
        .navigationTitle("Shared.Feeds")
        .toolbarTitleDisplayMode(.inlineLarge)
        .searchable(text: $searchText, prompt: Text(String(localized: "FeedList.SearchPrompt", table: "Feeds")))
        .toolbar { toolbarContent }
        .sakuraBackground()
        .overlay { emptyStateOverlay }
        .sheet(isPresented: $isPresentingAddFeedSheet) {
            AddFeedView()
                .environment(feedManager)
                .presentationDetents([.large])
                .navigationTransition(.zoom(sourceID: "addFeed", in: addFeedNamespace))
        }
        .sheet(item: $feedToEdit) { feed in
            EditFeedSheet(feedID: feed.id)
                .environment(feedManager)
                .navigationTransition(.zoom(sourceID: feed.id, in: feedEditNamespace))
        }
        .sheet(isPresented: $isPresentingBulkEditSheet) {
            BulkEditFeedSheet(feedIDs: selectedFeedIDs)
                .environment(feedManager)
        }
        .alert(
            String(localized: "FeedMenu.Unfollow.Title", table: "Feeds"),
            isPresented: Binding(
                get: { feedToDelete != nil },
                set: { if !$0 { feedToDelete = nil } }
            )
        ) {
            Button(String(localized: "FeedMenu.Unfollow.Confirm", table: "Feeds"), role: .destructive) {
                if let feed = feedToDelete {
                    withAnimation(.smooth.speed(2.0)) {
                        try? feedManager.deleteFeed(feed)
                    }
                    feedToDelete = nil
                }
            }
            Button("Shared.Cancel", role: .cancel) {
                feedToDelete = nil
            }
        } message: {
            if let feed = feedToDelete {
                Text(String(localized: "FeedMenu.Unfollow.Message.\(feed.title)", table: "Feeds"))
            }
        }
        .alert(
            String(localized: "FeedList.BulkDelete.Title", table: "Feeds"),
            isPresented: $isPresentingBulkDeleteAlert
        ) {
            Button(String(localized: "FeedMenu.Unfollow.Confirm", table: "Feeds"), role: .destructive) {
                deleteSelectedFeeds()
            }
            Button("Shared.Cancel", role: .cancel) { }
        } message: {
            Text(String(
                localized: "FeedList.BulkDelete.Message.\(selectedFeedIDs.count)",
                table: "Feeds"
            ))
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !isEditingFeeds {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(String(localized: "FeedList.Edit", table: "Feeds"),
                       systemImage: "pencil") {
                    isEditingFeeds = true
                }
                .labelStyle(.iconOnly)
                .disabled(feedManager.feeds.isEmpty)
            }
        }
        if isSelectingFeeds && !selectedFeedIDs.isEmpty {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isPresentingBulkDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
                .accessibilityLabel(String(localized: "FeedList.Selection.Delete", table: "Feeds"))
                Button {
                    isPresentingBulkEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel(String(localized: "FeedList.Selection.Edit", table: "Feeds"))
            }
            #if !os(visionOS)
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            #endif
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if isEditingFeeds {
                if isSelectingFeeds {
                    Button(role: .cancel) {
                        toggleSelectMode()
                    }
                } else {
                    Button {
                        toggleSelectMode()
                    } label: {
                        Text(String(localized: "FeedList.Select", table: "Feeds"))
                    }
                    Button(role: .confirm) {
                        exitEditMode()
                    }
                }
            } else {
                Button {
                    isPresentingAddFeedSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .compatibleGlassProminentButtonStyle()
                .matchedTransitionSource(id: "addFeed", in: addFeedNamespace)
            }
        }
    }

    @ViewBuilder
    private var emptyStateOverlay: some View {
        if feedManager.feeds.isEmpty {
            ContentUnavailableView {
                Label(String(localized: "FeedList.Empty.Title", table: "Feeds"),
                      systemImage: "newspaper")
            } description: {
                Text(String(localized: "FeedList.Empty.Description", table: "Feeds"))
            } actions: {
                Button(String(localized: "FeedList.Empty.AddFeed", table: "Feeds")) {
                    isPresentingAddFeedSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private var feedSectionsContent: some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            ForEach(FeedSection.allCases, id: \.self) { section in
                feedSection(section)
            }
        }
    }

    @ViewBuilder
    private func feedSection(_ section: FeedSection) -> some View {
        let feeds = feedsForSection(section)
        if !feeds.isEmpty {
            Section {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 12) {
                    ForEach(feeds) { feed in
                        feedCell(feed)
                    }
                }
            } header: {
                Text(section.localizedTitle)
                    .font(.title3)
                    .fontWeight(.bold)
            }
        }
    }

    @ViewBuilder
    private func feedCell(_ feed: Feed) -> some View {
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
                onTap: {
                    feedToEdit = feed
                    isPresentingEditFeedSheet = true
                },
                editTransitionNamespace: feedEditNamespace
            )
            .id(feed.id)
        } else {
            NavigationLink(value: feed) {
                FollowingFeedGridCell(feed: feed)
            }
            .buttonStyle(.plain)
            .id(feed.id)
        }
    }

    private func toggleSelection(_ feed: Feed) {
        withAnimation(.smooth.speed(2.0)) {
            if selectedFeedIDs.contains(feed.id) {
                selectedFeedIDs.remove(feed.id)
            } else {
                selectedFeedIDs.insert(feed.id)
            }
        }
    }

    private func toggleSelectMode() {
        if isSelectingFeeds {
            isSelectingFeeds = false
            selectedFeedIDs = []
        } else {
            isSelectingFeeds = true
        }
    }

    private func exitEditMode() {
        isSelectingFeeds = false
        selectedFeedIDs = []
        isEditingFeeds = false
    }

    private func deleteSelectedFeeds() {
        let feedsToDelete = selectedFeeds
        withAnimation(.smooth.speed(2.0)) {
            for feed in feedsToDelete {
                try? feedManager.deleteFeed(feed)
            }
            selectedFeedIDs = []
            isSelectingFeeds = false
        }
    }
}
