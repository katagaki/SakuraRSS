import SwiftUI
import TipKit

private struct HidesMarkAllReadToolbarKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var hidesMarkAllReadToolbar: Bool {
        get { self[HidesMarkAllReadToolbarKey.self] }
        set { self[HidesMarkAllReadToolbarKey.self] = newValue }
    }
}

struct ArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]
    let title: String
    let subtitle: String?
    let feedKey: String
    let isVideoFeed: Bool
    let isPodcastFeed: Bool
    let isInstagramFeed: Bool
    let isFeedViewDomain: Bool
    let isFeedCompactViewDomain: Bool
    let isTimelineViewDomain: Bool
    let titleDisplayMode: ToolbarTitleDisplayMode
    var anySummaryHidden: Bool
    var onRestoreSummaries: (() -> Void)?
    var onLoadMore: (() -> Void)?
    var onRefresh: (() async -> Void)?
    var onMarkAllRead: (() -> Void)?
    var scrollToTopTrigger: Int
    var headerView: AnyView?
    var additionalLeadingToolbar: AnyView?
    var effectiveStyleBinding: Binding<FeedDisplayStyle?>?

    @Environment(\.hidesMarkAllReadToolbar) private var hidesMarkAllReadToolbar
    @State private var displayStyle: FeedDisplayStyle
    @State private var isShowingMarkAllReadConfirmation = false
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .top
    private let viewStyleSwitcherTip = ViewStyleSwitcherTip()

    private var hasImages: Bool {
        articles.contains { $0.imageURL != nil }
    }

    private var hasAudioArticles: Bool {
        articles.contains { $0.audioURL != nil }
    }

    init(articles: [Article], title: String, subtitle: String? = nil, feedKey: String,
         isVideoFeed: Bool = false, isPodcastFeed: Bool = false,
         isInstagramFeed: Bool = false,
         isFeedViewDomain: Bool = false, isFeedCompactViewDomain: Bool = false,
         isTimelineViewDomain: Bool = false,
         titleDisplayMode: ToolbarTitleDisplayMode = .inline,
         anySummaryHidden: Bool = false,
         onRestoreSummaries: (() -> Void)? = nil,
         onLoadMore: (() -> Void)? = nil,
         onRefresh: (() async -> Void)? = nil,
         onMarkAllRead: (() -> Void)? = nil,
         scrollToTopTrigger: Int = 0,
         headerView: AnyView? = nil,
         additionalLeadingToolbar: AnyView? = nil,
         effectiveStyleBinding: Binding<FeedDisplayStyle?>? = nil) {
        self.articles = articles
        self.title = title
        self.subtitle = subtitle
        self.feedKey = feedKey
        self.isVideoFeed = isVideoFeed
        self.isPodcastFeed = isPodcastFeed
        self.isInstagramFeed = isInstagramFeed
        self.isFeedViewDomain = isFeedViewDomain
        self.isFeedCompactViewDomain = isFeedCompactViewDomain
        self.isTimelineViewDomain = isTimelineViewDomain
        self.titleDisplayMode = titleDisplayMode
        self.anySummaryHidden = anySummaryHidden
        self.onRestoreSummaries = onRestoreSummaries
        self.onLoadMore = onLoadMore
        self.onRefresh = onRefresh
        self.onMarkAllRead = onMarkAllRead
        self.scrollToTopTrigger = scrollToTopTrigger
        self.headerView = headerView
        self.additionalLeadingToolbar = additionalLeadingToolbar
        self.effectiveStyleBinding = effectiveStyleBinding
        let raw = UserDefaults.standard.string(forKey: "Display.Style.\(feedKey)")
        let defaultRaw = UserDefaults.standard.string(forKey: "Display.DefaultStyle") ?? FeedDisplayStyle.inbox.rawValue
        let fallback: FeedDisplayStyle
        if isPodcastFeed {
            fallback = .podcast
        } else if isVideoFeed {
            fallback = .video
        } else if isInstagramFeed {
            fallback = .photos
        } else if isTimelineViewDomain {
            fallback = .timeline
        } else if isFeedCompactViewDomain {
            fallback = .feedCompact
        } else if isFeedViewDomain {
            fallback = .feed
        } else {
            fallback = FeedDisplayStyle(rawValue: defaultRaw) ?? .inbox
        }
        self._displayStyle = State(initialValue: raw.flatMap(FeedDisplayStyle.init(rawValue:)) ?? fallback)
    }

    var body: some View {
        let effectiveStyle = effectiveDisplayStyle
        let showsInlineEmpty = effectiveStyle.supportsRichHeader && headerView != nil && articles.isEmpty
        let composedHeaderView: AnyView? = {
            guard let headerView else { return nil }
            guard showsInlineEmpty else { return headerView }
            return AnyView(
                VStack(spacing: 0) {
                    headerView
                    ContentUnavailableView {
                        Label(String(localized: "Empty.Title", table: "Articles"),
                              systemImage: "doc.text")
                    } description: {
                        Text(String(localized: "Empty.Description", table: "Articles"))
                    }
                }
            )
        }()
        ScrollViewReader { proxy in
            DisplayStyleContentView(
                style: effectiveStyle,
                articles: articles,
                onLoadMore: onLoadMore,
                onRefresh: onRefresh,
                headerView: composedHeaderView
            )
            .onChange(of: scrollToTopTrigger) { _, _ in
                guard let firstID = articles.first?.id else { return }
                withAnimation(.smooth.speed(2.0)) {
                    proxy.scrollTo(firstID, anchor: .top)
                }
            }
        }
        .sakuraBackground()
        .navigationTitle(title)
        .navigationSubtitle(subtitle ?? "")
        .toolbarTitleDisplayMode(titleDisplayMode)
        .toolbar {
            if !hidesMarkAllReadToolbar, markAllReadPosition == .top, let onMarkAllRead {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        isShowingMarkAllReadConfirmation = true
                    } label: {
                        Image(systemName: "envelope.open")
                            .font(.system(size: 14.0))
                    }
                    .popover(isPresented: $isShowingMarkAllReadConfirmation) {
                        VStack(spacing: 12) {
                            Text(String(localized: "MarkAllRead.Confirm", table: "Articles"))
                                .font(.body)
                            Button {
                                onMarkAllRead()
                                isShowingMarkAllReadConfirmation = false
                            } label: {
                                Text(String(localized: "MarkAllRead", table: "Articles"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(20)
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }
            if let additionalLeadingToolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    additionalLeadingToolbar
                }
                .sharedBackgroundVisibility(.hidden)
            }
            if anySummaryHidden {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        onRestoreSummaries?()
                    } label: {
                        Image(systemName: "text.line.3.summary")
                    }
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    DisplayStylePicker(
                        displayStyle: $displayStyle,
                        hasImages: hasImages,
                        showTimeline: feedKey != "all",
                        showPodcast: isPodcastFeed || hasAudioArticles
                    )
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .menuActionDismissBehavior(.disabled)
                .popoverTip(viewStyleSwitcherTip)
            }
        }
        .animation(.smooth.speed(2.0), value: displayStyle)
        .task(id: effectiveStyle) {
            effectiveStyleBinding?.wrappedValue = effectiveStyle
        }
        .onChange(of: displayStyle) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "Display.Style.\(feedKey)")
        }
        .onChange(of: feedKey) { _, newFeedKey in
            let raw = UserDefaults.standard.string(forKey: "Display.Style.\(newFeedKey)")
            let defaultRaw = UserDefaults.standard.string(
                forKey: "Display.DefaultStyle"
            ) ?? FeedDisplayStyle.inbox.rawValue
            let fallback: FeedDisplayStyle
            if isPodcastFeed {
                fallback = .podcast
            } else if isVideoFeed {
                fallback = .video
            } else if isInstagramFeed {
                fallback = .photos
            } else if isTimelineViewDomain {
                fallback = .timeline
            } else if isFeedCompactViewDomain {
                fallback = .feedCompact
            } else if isFeedViewDomain {
                fallback = .feed
            } else {
                fallback = FeedDisplayStyle(rawValue: defaultRaw) ?? .inbox
            }
            displayStyle = raw.flatMap(FeedDisplayStyle.init(rawValue:)) ?? fallback
        }
        .overlay {
            if effectiveStyle != .scroll, !showsInlineEmpty, articles.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Empty.Title", table: "Articles"),
                          systemImage: "doc.text")
                } description: {
                    Text(String(localized: "Empty.Description", table: "Articles"))
                }
            }
        }
    }

    /// Falls back to inbox when the chosen style isn't valid for the current feed.
    private var effectiveDisplayStyle: FeedDisplayStyle {
        if !hasImages && displayStyle.requiresImages {
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
