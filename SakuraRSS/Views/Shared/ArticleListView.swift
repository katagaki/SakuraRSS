import SwiftUI

struct ArticleListView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]
    let title: String
    let feedKey: String
    let isVideoFeed: Bool
    var onLoadMore: (() -> Void)?

    @State private var displayStyle: FeedDisplayStyle

    private var hasImages: Bool {
        articles.contains { $0.imageURL != nil }
    }

    init(articles: [Article], title: String, feedKey: String,
         isVideoFeed: Bool = false, onLoadMore: (() -> Void)? = nil) {
        self.articles = articles
        self.title = title
        self.feedKey = feedKey
        self.isVideoFeed = isVideoFeed
        self.onLoadMore = onLoadMore
        let raw = UserDefaults.standard.string(forKey: "displayStyle-\(feedKey)")
        let defaultRaw = UserDefaults.standard.string(forKey: "defaultDisplayStyle") ?? FeedDisplayStyle.inbox.rawValue
        let fallback = isVideoFeed ? .video : (FeedDisplayStyle(rawValue: defaultRaw) ?? .inbox)
        self._displayStyle = State(initialValue: raw.flatMap(FeedDisplayStyle.init(rawValue:)) ?? fallback)
    }

    var body: some View {
        let effectiveStyle = effectiveDisplayStyle
        Group {
            switch effectiveStyle {
            case .inbox:
                InboxStyleView(articles: articles, onLoadMore: onLoadMore)
            case .feed:
                FeedStyleView(articles: articles, onLoadMore: onLoadMore)
            case .magazine:
                MagazineStyleView(articles: articles, onLoadMore: onLoadMore)
            case .compact:
                CompactStyleView(articles: articles, onLoadMore: onLoadMore)
            case .video:
                VideoStyleView(articles: articles, onLoadMore: onLoadMore)
            case .photos:
                PhotosStyleView(articles: articles, onLoadMore: onLoadMore)
            }
        }
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .navigationTitle(title)
        .toolbar {
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
                        if isVideoFeed {
                            Label(String(localized: "Articles.Style.Video"), systemImage: "play.rectangle")
                                .tag(FeedDisplayStyle.video)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
            }
        }
        .onChange(of: displayStyle) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "displayStyle-\(feedKey)")
        }
        .overlay {
            if articles.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Articles.Empty.Title"),
                          systemImage: "doc.text")
                } description: {
                    Text(String(localized: "Articles.Empty.Description"))
                }
            }
        }
    }

    /// Falls back to inbox if the selected style requires images but none are available.
    private var effectiveDisplayStyle: FeedDisplayStyle {
        if !hasImages && (displayStyle == .magazine || displayStyle == .photos) {
            return .inbox
        }
        return displayStyle
    }
}

struct LoadPreviousArticlesButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                Text(String(localized: "Articles.LoadPrevious"))
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
    }
}
