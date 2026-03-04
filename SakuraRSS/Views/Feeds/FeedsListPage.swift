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

    var filteredFeeds: [Feed] {
        if searchText.isEmpty {
            return feedManager.feeds
        }
        return feedManager.feeds.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.domain.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(filteredFeeds) { feed in
                    NavigationLink(value: feed) {
                        FeedRowView(feed: feed)
                    }
                    .listRowBackground(Color.clear)
                    .contextMenu {
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
                            Label(String(localized: "FeedMenu.Rules"),
                                  systemImage: "list.bullet.rectangle")
                        }
                        Divider()
                        Button {
                            feedToEdit = feed
                        } label: {
                            Label(String(localized: "FeedMenu.Edit"),
                                  systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            feedToDelete = feed
                        } label: {
                            Label(String(localized: "FeedMenu.Delete"),
                                  systemImage: "trash")
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let feed = filteredFeeds[index]
                        try? feedManager.deleteFeed(feed)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(String(localized: "Shared.Feeds"))
        .toolbarTitleDisplayMode(.inlineLarge)
        .searchable(text: $searchText, prompt: Text("FeedList.SearchPrompt"))
        .refreshable {
            await feedManager.refreshAllFeedsAndFavicons()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddFeed = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.glassProminent)
            }
        }
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .sheet(isPresented: $isShowingAddFeed) {
            if let url = lastAddedFeedURL,
               let feed = feedManager.feeds.first(where: { $0.url == url }) {
                lastAddedFeedURL = nil
                Task {
                    try? await feedManager.refreshFeed(feed)
                    if let refreshed = feedManager.feeds.first(where: { $0.url == url }) {
                        onNavigateToFeed?(refreshed)
                    }
                }
            }
        } content: {
            AddFeedView { url in
                lastAddedFeedURL = url
            }
            .presentationDetents([.medium, .large])
        }
        .overlay {
            if feedManager.feeds.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "FeedList.Empty.Title"),
                          systemImage: "newspaper")
                } description: {
                    Text("FeedList.Empty.Description")
                } actions: {
                    Button(String(localized: "FeedList.Empty.AddFeed")) {
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
        .confirmationDialog(
            String(localized: "FeedMenu.Delete.Title"),
            isPresented: Binding(
                get: { feedToDelete != nil },
                set: { if !$0 { feedToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "FeedMenu.Delete.Confirm"), role: .destructive) {
                if let feed = feedToDelete {
                    try? feedManager.deleteFeed(feed)
                    feedToDelete = nil
                }
            }
            Button(String(localized: "Shared.Cancel"), role: .cancel) {
                feedToDelete = nil
            }
        } message: {
            if let feed = feedToDelete {
                Text("FeedMenu.Delete.Message.\(feed.title)")
            }
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
                             circle: feed.isVideoFeed && !feed.isPodcast,
                             skipInset: feed.isVideoFeed || feed.isPodcast
                                || FullFaviconDomains.shouldUseFullImage(feedDomain: feed.domain))
            } else {
                InitialsAvatarView(
                    feed.title,
                    size: 32,
                    circle: feed.isVideoFeed && !feed.isPodcast,
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
                    if feed.isPodcast {
                        Image(systemName: "headphones")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if feed.isVideoFeed {
                        Image(systemName: "play.rectangle.fill")
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
        .onChange(of: feedManager.dataRevision) {
            Task {
                favicon = await loadFavicon()
            }
        }
    }

    private func loadFavicon() async -> UIImage? {
        if let customURL = feed.customIconURL {
            if customURL == "photo" {
                return await FaviconCache.shared.customFavicon(feedID: feed.id)
            }
            if let url = URL(string: customURL),
               let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                return image
            }
        }
        return await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL)
    }
}
