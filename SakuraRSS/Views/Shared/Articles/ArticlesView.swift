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

    @Environment(\.hidesMarkAllReadToolbar) private var hidesMarkAllReadToolbar
    @State private var displayStyle: FeedDisplayStyle
    @State private var isShowingMarkAllReadConfirmation = false
    @AppStorage("Articles.HideRead") private var hideRead = false
    @AppStorage("Display.ScrollMarkAsRead") private var scrollMarkAsRead: Bool = false
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
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
         onMarkAllRead: (() -> Void)? = nil) {
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

    private var hideReadSupported: Bool {
        // Hiding read items conflicts with mark-as-read-on-scroll: rows would
        // disappear as they pass the viewport edge and yank the scroll
        // position. Force the toggle off while that setting is enabled.
        guard !scrollMarkAsRead else { return false }
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
            DisplayStyleContentView(
                style: effectiveStyle,
                articles: visibleArticles,
                onLoadMore: onLoadMore,
                onRefresh: onRefresh
            )
        }
        .scrollContentBackground(.hidden)
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
            if anySummaryHidden {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        onRestoreSummaries?()
                    } label: {
                        Image(systemName: "apple.intelligence")
                    }
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    DisplayStylePicker(
                        displayStyle: $displayStyle,
                        hasImages: hasImages,
                        showTimeline: feedKey != "all",
                        showVideo: isVideoFeed,
                        showPodcast: isPodcastFeed || hasAudioArticles
                    )
                    if hideReadSupported {
                        Section {
                            Toggle(String(localized: "HideRead", table: "Articles"), isOn: $hideRead)
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
            if effectiveStyle != .scroll {
                if articles.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "Empty.Title", table: "Articles"),
                              systemImage: "doc.text")
                    } description: {
                        Text(String(localized: "Empty.Description", table: "Articles"))
                    }
                } else if visibleArticles.isEmpty && hideRead {
                    ContentUnavailableView {
                        Label(String(localized: "AllRead.Title", table: "Articles"),
                              systemImage: "checkmark.circle")
                    } description: {
                        Text(String(localized: "AllRead.Description", table: "Articles"))
                    }
                }
            }
        }
    }

    /// Falls back to inbox if the selected style requires images but none are available,
    /// or if podcast style is selected for a non-podcast feed.
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

struct LoadPreviousArticlesButton: View {

    let action: () -> Void

    @AppStorage("Articles.AutoLoadWhileScrolling") private var autoLoadWhileScrolling: Bool = false
    @State private var isVisible: Bool = false

    var body: some View {
        Group {
            if autoLoadWhileScrolling {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(String(localized: "LoadPrevious.Loading", table: "Articles"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .onScrollVisibilityChange(threshold: 0.1) { visible in
                    let wasVisible = isVisible
                    isVisible = visible
                    if visible && !wasVisible {
                        triggerLoad()
                    }
                }
            } else {
                Button {
                    withAnimation(.smooth.speed(2.0)) {
                        action()
                    }
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text(String(localized: "LoadPrevious", table: "Articles"))
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
    }

    private func triggerLoad() {
        Task { @MainActor in
            withAnimation(.smooth.speed(2.0)) {
                action()
            }
        }
    }
}
