import SwiftUI

struct BookmarksView: View {

    @Environment(FeedManager.self) var feedManager
    @State private var bookmarkedArticles: [Article] = []
    @State private var displayStyle: FeedDisplayStyle
    @Namespace private var cardZoom

    private var hasImages: Bool {
        bookmarkedArticles.contains { $0.imageURL != nil }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "Display.DefaultBookmarksStyle")
        let defaultRaw = UserDefaults.standard.string(forKey: "Display.DefaultStyle") ?? FeedDisplayStyle.inbox.rawValue
        let fallback = FeedDisplayStyle(rawValue: defaultRaw) ?? .inbox
        self._displayStyle = State(initialValue: raw.flatMap(FeedDisplayStyle.init(rawValue:)) ?? fallback)
    }

    var body: some View {
        let effectiveStyle = effectiveDisplayStyle
        NavigationStack {
            Group {
                if bookmarkedArticles.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "Bookmarks.Empty.Title"),
                              systemImage: "bookmark")
                    } description: {
                        Text("Bookmarks.Empty.Description")
                    }
                } else {
                    switch effectiveStyle {
                    case .inbox:
                        InboxStyleView(articles: bookmarkedArticles)
                    case .feed:
                        FeedStyleView(articles: bookmarkedArticles)
                    case .magazine:
                        MagazineStyleView(articles: bookmarkedArticles)
                    case .compact:
                        CompactStyleView(articles: bookmarkedArticles)
                    case .video:
                        VideoStyleView(articles: bookmarkedArticles)
                    case .photos:
                        PhotosStyleView(articles: bookmarkedArticles)
                    case .podcast:
                        PodcastStyleView(articles: bookmarkedArticles)
                    case .timeline:
                        TimelineStyleView(articles: bookmarkedArticles)
                    case .cards:
                        CardsStyleView(articles: bookmarkedArticles)
                    }
                }
            }
            .navigationTitle(String(localized: "Tabs.Bookmarks"))
            .toolbarTitleDisplayMode(.inlineLarge)
            .scrollContentBackground(.hidden)
            .sakuraBackground()
            .toolbar {
                if !bookmarkedArticles.isEmpty {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu {
                            Picker(String(localized: "Articles.DisplayStyle"), selection: $displayStyle) {
                                Label(String(localized: "Articles.Style.Inbox"), systemImage: "tray")
                                    .tag(FeedDisplayStyle.inbox)
                                Label(String(localized: "Articles.Style.Compact"), systemImage: "list.dash")
                                    .tag(FeedDisplayStyle.compact)
                                if hasImages {
                                    Label(
                                        String(localized: "Articles.Style.Magazine"),
                                        systemImage: "rectangle.grid.2x2"
                                    )
                                        .tag(FeedDisplayStyle.magazine)
                                }
                                Label(String(localized: "Articles.Style.Feed"), systemImage: "newspaper")
                                    .tag(FeedDisplayStyle.feed)
                                if hasImages {
                                    Label(String(localized: "Articles.Style.Photos"), systemImage: "photo.stack")
                                        .tag(FeedDisplayStyle.photos)
                                }
                                Label(String(localized: "Articles.Style.Timeline"), systemImage: "clock")
                                    .tag(FeedDisplayStyle.timeline)
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                        }
                        .menuActionDismissBehavior(.disabled)

                        Menu {
                            Button(role: .destructive) {
                                try? DatabaseManager.shared.removeReadBookmarks()
                                bookmarkedArticles = (try? DatabaseManager.shared.bookmarkedArticles()) ?? []
                            } label: {
                                Label(String(localized: "Bookmarks.DeleteAllRead"),
                                      systemImage: "bookmark.slash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .onChange(of: displayStyle) { _, newValue in
                UserDefaults.standard.set(newValue.rawValue, forKey: "Display.DefaultBookmarksStyle")
            }
            .environment(\.zoomNamespace, cardZoom)
            .navigationDestination(for: Article.self) { article in
                Group {
                    if article.isPodcastEpisode {
                        PodcastEpisodeView(article: article)
                    } else {
                        ArticleDetailView(article: article)
                    }
                }
                .zoomTransition(sourceID: article.id, in: cardZoom)
            }
            .onAppear {
                bookmarkedArticles = (try? DatabaseManager.shared.bookmarkedArticles()) ?? []
            }
        }
    }

    private var effectiveDisplayStyle: FeedDisplayStyle {
        if !hasImages && (displayStyle == .magazine || displayStyle == .photos || displayStyle == .cards) {
            return .inbox
        }
        if displayStyle == .podcast {
            return .inbox
        }
        return displayStyle
    }
}
