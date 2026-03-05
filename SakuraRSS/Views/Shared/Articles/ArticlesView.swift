import SwiftUI
import TipKit

struct ArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]
    let title: String
    let feedKey: String
    let isVideoFeed: Bool
    let isPodcastFeed: Bool
    let isFeedViewDomain: Bool
    let isTimelineViewDomain: Bool
    var onLoadMore: (() -> Void)?

    @State private var displayStyle: FeedDisplayStyle
    private let viewStyleSwitcherTip = ViewStyleSwitcherTip()

    private var hasImages: Bool {
        articles.contains { $0.imageURL != nil }
    }

    private var hasAudioArticles: Bool {
        articles.contains { $0.audioURL != nil }
    }

    init(articles: [Article], title: String, feedKey: String,
         isVideoFeed: Bool = false, isPodcastFeed: Bool = false,
         isFeedViewDomain: Bool = false, isTimelineViewDomain: Bool = false,
         onLoadMore: (() -> Void)? = nil) {
        self.articles = articles
        self.title = title
        self.feedKey = feedKey
        self.isVideoFeed = isVideoFeed
        self.isPodcastFeed = isPodcastFeed
        self.isFeedViewDomain = isFeedViewDomain
        self.isTimelineViewDomain = isTimelineViewDomain
        self.onLoadMore = onLoadMore
        let raw = UserDefaults.standard.string(forKey: "Display.Style.\(feedKey)")
        let defaultRaw = UserDefaults.standard.string(forKey: "Display.DefaultStyle") ?? FeedDisplayStyle.inbox.rawValue
        let fallback: FeedDisplayStyle
        if isPodcastFeed {
            fallback = .podcast
        } else if isVideoFeed {
            fallback = .video
        } else if isTimelineViewDomain {
            fallback = .timeline
        } else if isFeedViewDomain {
            fallback = .feed
        } else {
            fallback = FeedDisplayStyle(rawValue: defaultRaw) ?? .inbox
        }
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
            case .podcast:
                PodcastStyleView(articles: articles, onLoadMore: onLoadMore)
            case .timeline:
                TimelineStyleView(articles: articles, onLoadMore: onLoadMore)
            case .cards:
                CardsStyleView(articles: articles)
            }
        }
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
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
                        if hasImages {
                            Label(String(localized: "Articles.Style.Cards"), systemImage: "square.stack.3d.up")
                                .tag(FeedDisplayStyle.cards)
                        }
                        if isVideoFeed {
                            Label(String(localized: "Articles.Style.Video"), systemImage: "play.rectangle")
                                .tag(FeedDisplayStyle.video)
                        }
                        if isPodcastFeed || hasAudioArticles {
                            Label(String(localized: "Articles.Style.Podcast"), systemImage: "headphones")
                                .tag(FeedDisplayStyle.podcast)
                        }
                        if feedKey != "all" {
                            Label(String(localized: "Articles.Style.Timeline"), systemImage: "clock")
                                .tag(FeedDisplayStyle.timeline)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .popoverTip(viewStyleSwitcherTip)
            }
        }
        .onChange(of: displayStyle) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "Display.Style.\(feedKey)")
        }
        .overlay {
            if articles.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Articles.Empty.Title"),
                          systemImage: "doc.text")
                } description: {
                    Text("Articles.Empty.Description")
                }
            }
        }
    }

    /// Falls back to inbox if the selected style requires images but none are available,
    /// or if podcast style is selected for a non-podcast feed.
    private var effectiveDisplayStyle: FeedDisplayStyle {
        if !hasImages && (displayStyle == .magazine || displayStyle == .photos || displayStyle == .cards) {
            return .inbox
        }
        if displayStyle == .podcast && !isPodcastFeed && !hasAudioArticles {
            return .inbox
        }
        if displayStyle == .timeline && feedKey == "all" {
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
                Text("Articles.LoadPrevious")
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
    }
}
