import SwiftUI

struct FeedListView: View {

    @Environment(FeedManager.self) var feedManager
    @State private var isShowingAddFeed = false
    @State private var searchText = ""

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
        NavigationStack {
            List {
                if !feedManager.feeds.isEmpty {
                    NavigationLink {
                        AllArticlesView()
                    } label: {
                        Label {
                            HStack {
                                Text(String(localized: "Shared.AllArticles"))
                                Spacer()
                                let count = feedManager.totalUnreadCount()
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(.red)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                            }
                        } icon: {
                            Image(systemName: "tray.full")
                        }
                    }
                }

                Section {
                    ForEach(filteredFeeds) { feed in
                        NavigationLink {
                            FeedArticlesView(feed: feed)
                        } label: {
                            FeedRowView(feed: feed)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let feed = filteredFeeds[index]
                            try? feedManager.deleteFeed(feed)
                        }
                    }
                } header: {
                    if !feedManager.feeds.isEmpty {
                        Text(String(localized: "Shared.Feeds"))
                    }
                }
            }
            .navigationTitle(String(localized: "Shared.Feeds"))
            .searchable(text: $searchText, prompt: Text(String(localized: "FeedList.SearchPrompt")))
            .refreshable {
                await feedManager.refreshAllFeeds()
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
                AddFeedView()
                    .presentationDetents([.medium, .large])
            }
            .overlay {
                if feedManager.feeds.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "FeedList.Empty.Title"),
                              systemImage: "newspaper")
                    } description: {
                        Text(String(localized: "FeedList.Empty.Description"))
                    } actions: {
                        Button(String(localized: "FeedList.Empty.AddFeed")) {
                            isShowingAddFeed = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
}

struct FeedRowView: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed
    @State private var favicon: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            if let favicon = favicon {
                Image(uiImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "dot.radiowaves.up.forward")
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(feed.title)
                    .lineLimit(1)
                Text(feed.domain)
                    .font(.caption)
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
                    .background(.red)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .task {
            favicon = await FaviconCache.shared.favicon(for: feed.domain)
        }
    }
}
