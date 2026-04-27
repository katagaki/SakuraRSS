import SwiftUI

struct FeedsListPage: View {

    @Environment(FeedManager.self) var feedManager
    @State private var isShowingAddFeed = false
    @State private var searchText = ""
    @State private var feedToEdit: Feed?
    @State private var feedToDelete: Feed?
    @State private var feedForRules: Feed?
    @State private var feedForListAssignment: Feed?
    @Namespace private var addFeedNamespace

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

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(FeedSection.allCases, id: \.self) { section in
                    let feeds = feedsForSection(section)
                    if !feeds.isEmpty {
                        Section {
                            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 16) {
                                ForEach(feeds) { feed in
                                    NavigationLink(value: feed) {
                                        FeedGridCell(feed: feed)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        feedContextMenu(for: feed)
                                    }
                                }
                            }
                        } header: {
                            Text(section.localizedTitle)
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                    }
                }
            }
            .padding()
            .animation(.smooth.speed(2.0), value: feedManager.feeds)
            .animation(.smooth.speed(2.0), value: searchText)
        }
        .navigationTitle("Shared.Feeds")
        .toolbarTitleDisplayMode(.inlineLarge)
        .searchable(text: $searchText, prompt: Text(String(localized: "FeedList.SearchPrompt", table: "Feeds")))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddFeed = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.glassProminent)
                .matchedTransitionSource(id: "addFeed", in: addFeedNamespace)
            }
        }
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .sheet(isPresented: $isShowingAddFeed) {
            AddFeedView()
                .presentationDetents([.medium, .large])
                .navigationTransition(.zoom(sourceID: "addFeed", in: addFeedNamespace))
        }
        .overlay {
            if feedManager.feeds.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "FeedList.Empty.Title", table: "Feeds"),
                          systemImage: "newspaper")
                } description: {
                    Text(String(localized: "FeedList.Empty.Description", table: "Feeds"))
                } actions: {
                    Button(String(localized: "FeedList.Empty.AddFeed", table: "Feeds")) {
                        isShowingAddFeed = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .sheet(item: $feedToEdit) { feed in
            FeedEditSheet(feed: feed)
                .environment(feedManager)
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled()
        }
        .sheet(item: $feedForRules) { feed in
            FeedRulesSheet(feed: feed)
                .environment(feedManager)
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled()
        }
        .alert(
            String(localized: "FeedMenu.Delete.Title", table: "Feeds"),
            isPresented: Binding(
                get: { feedToDelete != nil },
                set: { if !$0 { feedToDelete = nil } }
            )
        ) {
            Button(String(localized: "FeedMenu.Delete.Confirm", table: "Feeds"), role: .destructive) {
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
                Text(String(localized: "FeedMenu.Delete.Message.\(feed.title)", table: "Feeds"))
            }
        }
        .sheet(item: $feedForListAssignment) { feed in
            AddFeedToListSheet(feed: feed)
                .environment(feedManager)
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func feedContextMenu(for feed: Feed) -> some View {
        Button {
            feedManager.toggleMuted(feed)
        } label: {
            Label(
                feed.isMuted
                    ? String(localized: "FeedMenu.Unmute", table: "Feeds")
                    : String(localized: "FeedMenu.Mute", table: "Feeds"),
                systemImage: feed.isMuted
                    ? "bell" : "bell.slash"
            )
        }
        Button {
            feedForRules = feed
        } label: {
            Label(String(localized: "FeedMenu.Rules", table: "Feeds"),
                  systemImage: "list.bullet.rectangle")
        }
        Button {
            feedForListAssignment = feed
        } label: {
            Label(String(localized: "FeedMenu.AddToList", table: "Feeds"),
                  systemImage: "text.badge.plus")
        }
        Divider()
        Button {
            feedToEdit = feed
        } label: {
            Label(String(localized: "FeedMenu.Edit", table: "Feeds"),
                  systemImage: "pencil")
        }
        Button(role: .destructive) {
            feedToDelete = feed
        } label: {
            Label(String(localized: "FeedMenu.Delete", table: "Feeds"),
                  systemImage: "trash")
        }
    }
}
