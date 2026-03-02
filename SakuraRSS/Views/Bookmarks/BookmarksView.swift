import SwiftUI

struct BookmarksView: View {

    @Environment(FeedManager.self) var feedManager
    @State private var bookmarkedArticles: [Article] = []
    @State private var displayStyle: FeedDisplayStyle

    private var hasImages: Bool {
        bookmarkedArticles.contains { $0.imageURL != nil }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "displayStyle-bookmarks")
        let defaultRaw = UserDefaults.standard.string(forKey: "defaultDisplayStyle") ?? FeedDisplayStyle.inbox.rawValue
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
                        Text(String(localized: "Bookmarks.Empty.Description"))
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
                    }
                }
            }
            .navigationTitle(String(localized: "Tabs.Bookmarks"))
            .scrollContentBackground(.hidden)
            .sakuraBackground()
            .toolbar {
                if !bookmarkedArticles.isEmpty {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu {
                            Picker(String(localized: "Articles.DisplayStyle"), selection: $displayStyle) {
                                Label(String(localized: "Articles.Style.Inbox"), systemImage: "tray")
                                    .tag(FeedDisplayStyle.inbox)
                                Label(String(localized: "Articles.Style.Feed"), systemImage: "newspaper")
                                    .tag(FeedDisplayStyle.feed)
                                if hasImages {
                                    Label(String(localized: "Articles.Style.Magazine"), systemImage: "rectangle.grid.2x2")
                                        .tag(FeedDisplayStyle.magazine)
                                }
                                Label(String(localized: "Articles.Style.Compact"), systemImage: "list.dash")
                                    .tag(FeedDisplayStyle.compact)
                                if hasImages {
                                    Label(String(localized: "Articles.Style.Photos"), systemImage: "photo.stack")
                                        .tag(FeedDisplayStyle.photos)
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                        }
                    }
                }
            }
            .onChange(of: displayStyle) { _, newValue in
                UserDefaults.standard.set(newValue.rawValue, forKey: "displayStyle-bookmarks")
            }
            .onAppear {
                bookmarkedArticles = (try? DatabaseManager.shared.bookmarkedArticles()) ?? []
            }
        }
    }

    private var effectiveDisplayStyle: FeedDisplayStyle {
        if !hasImages && (displayStyle == .magazine || displayStyle == .photos) {
            return .inbox
        }
        return displayStyle
    }
}
