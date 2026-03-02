import SwiftUI

struct ArticleListView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]
    let title: String
    let feedKey: String
    let isYouTubeFeed: Bool

    @State private var displayStyle: FeedDisplayStyle

    init(articles: [Article], title: String, feedKey: String, isYouTube: Bool = false) {
        self.articles = articles
        self.title = title
        self.feedKey = feedKey
        self.isYouTubeFeed = isYouTube
        let raw = UserDefaults.standard.string(forKey: "displayStyle-\(feedKey)")
        let defaultRaw = UserDefaults.standard.string(forKey: "defaultDisplayStyle") ?? FeedDisplayStyle.inbox.rawValue
        let fallback = isYouTube ? .video : (FeedDisplayStyle(rawValue: defaultRaw) ?? .inbox)
        self._displayStyle = State(initialValue: raw.flatMap(FeedDisplayStyle.init(rawValue:)) ?? fallback)
    }

    var body: some View {
        Group {
            switch displayStyle {
            case .inbox:
                InboxStyleView(articles: articles)
            case .feed:
                FeedStyleView(articles: articles)
            case .magazine:
                MagazineStyleView(articles: articles)
            case .compact:
                CompactStyleView(articles: articles)
            case .video:
                VideoStyleView(articles: articles)
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
                        Label(String(localized: "Articles.Style.Magazine"), systemImage: "rectangle.grid.2x2")
                            .tag(FeedDisplayStyle.magazine)
                        Label(String(localized: "Articles.Style.Compact"), systemImage: "list.dash")
                            .tag(FeedDisplayStyle.compact)
                        if isYouTubeFeed {
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
}
