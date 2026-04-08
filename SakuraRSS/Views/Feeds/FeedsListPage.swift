import SwiftUI

struct FeedsListPage: View {

    @Environment(FeedManager.self) var feedManager
    var onNavigateToFeed: ((Feed) -> Void)?
    @State private var isShowingAddFeed = false
    @State private var searchText = ""
    @State private var lastAddedFeedURL: String?
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
        filteredFeeds.filter { $0.feedSection == section }
    }

    @ViewBuilder
    private func feedRows(for feeds: [Feed]) -> some View {
        ForEach(feeds) { feed in
            NavigationLink(value: feed) {
                FeedRowView(feed: feed)
            }
            .contextMenu {
                feedContextMenu(for: feed)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    feedToDelete = feed
                } label: {
                    Label("FeedMenu.Delete", systemImage: "trash")
                }
                Button {
                    feedForListAssignment = feed
                } label: {
                    Label("FeedMenu.AddToList", systemImage: "text.badge.plus")
                }
                .tint(.purple)
            }
        }
        .onDelete { indexSet in
            for index in indexSet {
                let feed = feeds[index]
                try? feedManager.deleteFeed(feed)
            }
        }
    }

    var body: some View {
        List {
            ForEach(FeedSection.allCases, id: \.self) { section in
                let feeds = feedsForSection(section)
                if !feeds.isEmpty {
                    Section(section.localizedTitle) {
                        feedRows(for: feeds)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .navigationTitle("Shared.Feeds")
        .toolbarTitleDisplayMode(.inlineLarge)
        .searchable(text: $searchText, prompt: Text("FeedList.SearchPrompt"))
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
            if let url = lastAddedFeedURL,
               let feed = feedManager.feeds.first(where: { $0.url == url }) {
                lastAddedFeedURL = nil
                onNavigateToFeed?(feed)
                Task {
                    try? await feedManager.refreshFeed(feed)
                }
            }
        } content: {
            AddFeedView { url in
                lastAddedFeedURL = url
            }
            .presentationDetents([.medium, .large])
            .navigationTransition(.zoom(sourceID: "addFeed", in: addFeedNamespace))
        }
        .overlay {
            if feedManager.feeds.isEmpty {
                ContentUnavailableView {
                    Label("FeedList.Empty.Title",
                          systemImage: "newspaper")
                } description: {
                    Text("FeedList.Empty.Description")
                } actions: {
                    Button("FeedList.Empty.AddFeed") {
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
            "FeedMenu.Delete.Title",
            isPresented: Binding(
                get: { feedToDelete != nil },
                set: { if !$0 { feedToDelete = nil } }
            )
        ) {
            Button("FeedMenu.Delete.Confirm", role: .destructive) {
                if let feed = feedToDelete {
                    try? feedManager.deleteFeed(feed)
                    feedToDelete = nil
                }
            }
            Button("Shared.Cancel", role: .cancel) {
                feedToDelete = nil
            }
        } message: {
            if let feed = feedToDelete {
                Text("FeedMenu.Delete.Message.\(feed.title)")
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
                    ? String(localized: "FeedMenu.Unmute")
                    : String(localized: "FeedMenu.Mute"),
                systemImage: feed.isMuted
                    ? "bell" : "bell.slash"
            )
        }
        Button {
            feedForRules = feed
        } label: {
            Label("FeedMenu.Rules",
                  systemImage: "list.bullet.rectangle")
        }
        Button {
            feedForListAssignment = feed
        } label: {
            Label("FeedMenu.AddToList",
                  systemImage: "text.badge.plus")
        }
        Divider()
        Button {
            feedToEdit = feed
        } label: {
            Label("FeedMenu.Edit",
                  systemImage: "pencil")
        }
        Button(role: .destructive) {
            feedToDelete = feed
        } label: {
            Label("FeedMenu.Delete",
                  systemImage: "trash")
        }
    }
}

struct FeedRowView: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed
    @State private var favicon: UIImage?

    private var iconCornerRadius: CGFloat {
        if feed.isPodcast { return 8 }
        if feed.isVideoFeed { return 0 }
        return 4
    }

    var body: some View {
        HStack(spacing: 12) {
            if let favicon = favicon {
                FaviconImage(favicon, size: 32,
                             cornerRadius: iconCornerRadius,
                             circle: feed.isCircleIcon,
                             skipInset: feed.isVideoFeed || feed.isPodcast || feed.isXFeed || feed.isInstagramFeed
                                || FullFaviconDomains.shouldUseFullImage(feedDomain: feed.domain))
            } else if let data = feed.acronymIcon, let acronym = UIImage(data: data) {
                FaviconImage(acronym, size: 32,
                             cornerRadius: iconCornerRadius,
                             circle: feed.isCircleIcon,
                             skipInset: true)
            } else {
                InitialsAvatarView(
                    feed.title,
                    size: 32,
                    circle: feed.isCircleIcon,
                    cornerRadius: iconCornerRadius
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(feed.title)
                        .font(.body)
                        .lineLimit(1)
                    if feed.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(feed.domain)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            let count = feedManager.unreadCount(for: feed)
            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.tertiary)
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
            }
        }
        .task {
            favicon = await loadFavicon()
        }
        .onChange(of: feedManager.faviconRevision) {
            Task {
                favicon = await loadFavicon()
            }
        }
    }

    private func loadFavicon() async -> UIImage? {
        await FaviconCache.shared.favicon(for: feed)
    }
}
