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
    let titleDisplayMode: ToolbarTitleDisplayMode
    var anySummaryHidden: Bool
    var onRestoreSummaries: (() -> Void)?
    var onLoadMore: (() -> Void)?
    var onRefresh: (() async -> Void)?
    var onMarkAllRead: (() -> Void)?

    @State private var displayStyle: FeedDisplayStyle
    @State private var isShowingMarkAllReadConfirmation = false
    @AppStorage("Articles.HideRead") private var hideRead = false
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
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
         titleDisplayMode: ToolbarTitleDisplayMode = .inline,
         anySummaryHidden: Bool = false,
         onRestoreSummaries: (() -> Void)? = nil,
         onLoadMore: (() -> Void)? = nil,
         onRefresh: (() async -> Void)? = nil,
         onMarkAllRead: (() -> Void)? = nil) {
        self.articles = articles
        self.title = title
        self.feedKey = feedKey
        self.isVideoFeed = isVideoFeed
        self.isPodcastFeed = isPodcastFeed
        self.isFeedViewDomain = isFeedViewDomain
        self.isTimelineViewDomain = isTimelineViewDomain
        self.titleDisplayMode = titleDisplayMode
        self.anySummaryHidden = anySummaryHidden
        self.onRestoreSummaries = onRestoreSummaries
        self.onLoadMore = onLoadMore
        self.onRefresh = onRefresh
        self.onMarkAllRead = onMarkAllRead
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

    private var hideReadSupported: Bool {
        let style = effectiveDisplayStyle
        return style == .inbox || style == .magazine || style == .compact
    }

    private var visibleArticles: [Article] {
        if hideRead && hideReadSupported {
            return articles.filter { !$0.isRead }
        }
        return articles
    }

    var body: some View {
        let effectiveStyle = effectiveDisplayStyle
        Group {
            switch effectiveStyle {
            case .inbox:
                InboxStyleView(articles: visibleArticles, onLoadMore: onLoadMore)
            case .feed:
                FeedStyleView(articles: visibleArticles, onLoadMore: onLoadMore)
            case .magazine:
                MagazineStyleView(articles: visibleArticles, onLoadMore: onLoadMore)
            case .compact:
                CompactStyleView(articles: visibleArticles, onLoadMore: onLoadMore)
            case .video:
                VideoStyleView(articles: visibleArticles, onLoadMore: onLoadMore)
            case .photos:
                PhotosStyleView(articles: visibleArticles, onLoadMore: onLoadMore)
            case .podcast:
                PodcastStyleView(articles: visibleArticles, onLoadMore: onLoadMore)
            case .timeline:
                TimelineStyleView(articles: visibleArticles, onLoadMore: onLoadMore)
            case .cards:
                CardsStyleView(articles: visibleArticles, onRefresh: onRefresh)
            }
        }
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .navigationTitle(title)
        .toolbarTitleDisplayMode(titleDisplayMode)
        .toolbar {
            if anySummaryHidden {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        onRestoreSummaries?()
                    } label: {
                        Image(systemName: "apple.intelligence")
                    }
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItemGroup(placement: .topBarTrailing) {
                if markAllReadPosition == .top, let onMarkAllRead {
                    Button {
                        isShowingMarkAllReadConfirmation = true
                    } label: {
                        Image(systemName: "envelope.open")
                            .font(.system(size: 14.0))
                    }
                    .popover(isPresented: $isShowingMarkAllReadConfirmation) {
                        VStack(spacing: 12) {
                            Text("Articles.MarkAllRead.Confirm")
                                .font(.body)
                            Button {
                                onMarkAllRead()
                                isShowingMarkAllReadConfirmation = false
                            } label: {
                                Text("Articles.MarkAllRead")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(20)
                        .presentationCompactAdaptation(.popover)
                    }
                }
                Menu {
                    Picker(String(localized: "Articles.DisplayStyle"), selection: $displayStyle) {
                        Label(String(localized: "Articles.Style.Inbox"), systemImage: "tray")
                            .tag(FeedDisplayStyle.inbox)
                        Label(String(localized: "Articles.Style.Compact"), systemImage: "list.dash")
                            .tag(FeedDisplayStyle.compact)
                        if hasImages {
                            Label(String(localized: "Articles.Style.Magazine"), systemImage: "rectangle.grid.2x2")
                                .tag(FeedDisplayStyle.magazine)
                        }
                        Label(String(localized: "Articles.Style.Feed"), systemImage: "newspaper")
                            .tag(FeedDisplayStyle.feed)
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
                    if hideReadSupported {
                        Section {
                            Toggle(String(localized: "Articles.HideRead"), isOn: $hideRead)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .menuActionDismissBehavior(.disabled)
                .popoverTip(viewStyleSwitcherTip)
            }
        }
        .animation(.smooth.speed(2.0), value: displayStyle)
        .animation(.smooth.speed(2.0), value: hideRead)
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
            } else if visibleArticles.isEmpty && hideRead {
                ContentUnavailableView {
                    Label(String(localized: "Articles.AllRead.Title"),
                          systemImage: "checkmark.circle")
                } description: {
                    Text("Articles.AllRead.Description")
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
        Button {
            withAnimation(.smooth.speed(2.0)) {
                action()
            }
        } label: {
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
