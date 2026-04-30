import SwiftUI

struct FeedsListPage: View {

    @Environment(FeedManager.self) var feedManager
    @State private var isShowingAddFeed = false
    @State private var searchText = ""
    @State private var feedForEditSheet: FeedIDIdentifier?
    @State private var feedToDelete: Feed?
    @State private var isEditingFeeds = false
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

    var body: some View {
        ScrollView {
            feedSectionsContent
                .padding()
                .animation(.smooth.speed(2.0), value: feedManager.feeds)
                .animation(.smooth.speed(2.0), value: searchText)
                .animation(.smooth.speed(2.0), value: isEditingFeeds)
        }
        .navigationTitle("Shared.Feeds")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: Text(String(localized: "FeedList.SearchPrompt", table: "Feeds")))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditingFeeds {
                    Button(role: .confirm) {
                        isEditingFeeds = false
                    }
                } else {
                    Button {
                        isShowingAddFeed = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.glassProminent)
                    .matchedTransitionSource(id: "addFeed", in: addFeedNamespace)
                }
            }
            if !isEditingFeeds {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "FeedList.Edit", table: "Feeds")) {
                        isEditingFeeds = true
                    }
                    .disabled(feedManager.feeds.isEmpty)
                }
            }
        }
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
        .sheet(item: $feedForEditSheet) { wrapper in
            FeedEditSheet(feedID: wrapper.id)
                .environment(feedManager)
                .zoomTransition(sourceID: wrapper.id, in: feedEditNamespace)
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
        if isEditingFeeds {
            FeedGridCell(
                feed: feed,
                isWiggling: true,
                onDelete: { feedToDelete = feed },
                onTap: { feedForEditSheet = FeedIDIdentifier(id: feed.id) },
                editTransitionNamespace: feedEditNamespace
            )
            .id(feed.id)
        } else {
            NavigationLink(value: feed) {
                FeedGridCell(feed: feed)
            }
            .buttonStyle(.plain)
            .id(feed.id)
        }
    }
}
