import SwiftUI
import TipKit

enum HomeSection: String, CaseIterable, Identifiable {
    case all
    case feeds
    case podcasts
    case bluesky
    case instagram
    case mastodon
    case note
    case pixelfed
    case reddit
    case vimeo
    case x // swiftlint:disable:this identifier_name
    case youtube
    case niconico

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .all: String(localized: "Shared.AllArticles")
        case .feeds: String(localized: "FeedSection.Feeds", table: "Feeds")
        case .podcasts: String(localized: "FeedSection.Podcasts", table: "Feeds")
        case .bluesky: String(localized: "FeedSection.Bluesky", table: "Feeds")
        case .instagram: String(localized: "FeedSection.Instagram", table: "Feeds")
        case .mastodon: String(localized: "FeedSection.Mastodon", table: "Feeds")
        case .note: String(localized: "FeedSection.Note", table: "Feeds")
        case .pixelfed: String(localized: "FeedSection.Pixelfed", table: "Feeds")
        case .reddit: String(localized: "FeedSection.Reddit", table: "Feeds")
        case .vimeo: String(localized: "FeedSection.Vimeo", table: "Feeds")
        case .x: String(localized: "FeedSection.X", table: "Feeds")
        case .youtube: String(localized: "FeedSection.YouTube", table: "Feeds")
        case .niconico: String(localized: "FeedSection.Niconico", table: "Feeds")
        }
    }

    var systemImage: String? {
        switch self {
        case .all: "square.stack"
        case .feeds: "newspaper"
        case .podcasts: "headphones"
        default: nil
        }
    }

    var feedSection: FeedSection? {
        switch self {
        case .all: nil
        case .feeds: .feeds
        case .podcasts: .podcasts
        case .bluesky: .bluesky
        case .instagram: .instagram
        case .mastodon: .mastodon
        case .note: .note
        case .pixelfed: .pixelfed
        case .reddit: .reddit
        case .vimeo: .vimeo
        case .x: .x
        case .youtube: .youtube
        case .niconico: .niconico
        }
    }
}

/// Represents the selected view in the Home tab title menu.
/// Can be a static section, the bookmarks collection, or a user-created list.
enum HomeSelection: Hashable, RawRepresentable {
    case section(HomeSection)
    case bookmarks
    case list(Int64)

    var rawValue: String {
        switch self {
        case .section(let section): "section.\(section.rawValue)"
        case .bookmarks: "bookmarks"
        case .list(let id): "list.\(id)"
        }
    }

    init?(rawValue: String) {
        if rawValue == "bookmarks" {
            self = .bookmarks
            return
        }
        if rawValue.hasPrefix("section.") {
            let sectionRaw = String(rawValue.dropFirst("section.".count))
            if let section = HomeSection(rawValue: sectionRaw) {
                self = .section(section)
                return
            }
        } else if rawValue.hasPrefix("list.") {
            let idStr = String(rawValue.dropFirst("list.".count))
            if let id = Int64(idStr) {
                self = .list(id)
                return
            }
        }
        // Legacy: bare section names from before the HomeSelection wrapper.
        if let section = HomeSection(rawValue: rawValue) {
            self = .section(section)
            return
        }
        return nil
    }

    var localizedTitle: String {
        switch self {
        case .section(let section): section.localizedTitle
        case .bookmarks: String(localized: "Tabs.Bookmarks")
        case .list: ""
        }
    }

    var systemImage: String? {
        switch self {
        case .section(let section): section.systemImage
        case .bookmarks: "bookmark"
        case .list: nil
        }
    }
}

struct AllArticlesView: View {

    @Environment(FeedManager.self) var feedManager

    @AppStorage("Home.SelectedSection") private var selectedSelection: HomeSelection = .section(.all)
    @AppStorage("Articles.BatchingMode") private var storedBatchingMode: BatchingMode = .day1
    @AppStorage(DoomscrollingMode.storageKey) private var doomscrollingMode: Bool = false
    @State private var loadedSinceDate: Date = BatchingMode.current().initialSinceDate()
    @State private var loadedCount: Int = BatchingMode.current().initialCount()
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("WhileYouSlept.DismissedDate") private var whileYouSleptDismissedDate: String = ""
    @AppStorage("TodaysSummary.DismissedDate") private var todaysSummaryDismissedDate: String = ""
    @AppStorage("Instagram.HideReels") private var hideInstagramReels: Bool = false
    @AppStorage("Articles.HideViewedContent") private var storedHideViewedContent: Bool = false
    @State private var visibility = ArticleVisibilityTracker()
    @State private var scrollToTopTick: Int = 0
    @State private var whileYouSleptAvailable = false
    @State private var todaysSummaryAvailable = false

    private var batchingMode: BatchingMode {
        DoomscrollingMode.effectiveBatchingMode(storedBatchingMode)
    }

    private var hideViewedContent: Bool {
        DoomscrollingMode.effectiveHideViewedContent(storedHideViewedContent)
    }

    private var todayDateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private var anySummaryHidden: Bool {
        (whileYouSleptDismissedDate == todayDateKey && whileYouSleptAvailable)
        || (todaysSummaryDismissedDate == todayDateKey && todaysSummaryAvailable)
    }

    private var rawArticles: [Article] {
        var articles: [Article]
        if batchingMode.isCountBased {
            articles = feedManager.articles(
                limit: loadedCount,
                requireUnread: hideViewedContent
            )
        } else {
            articles = feedManager.articles(since: loadedSinceDate)
        }
        if hideInstagramReels {
            articles = articles.filter { !$0.url.contains("/reel/") }
        }
        return articles
    }

    private var displayedArticles: [Article] {
        visibility.filter(rawArticles, isEnabled: hideViewedContent)
    }

    private func performRefresh() async {
        guard !feedManager.isLoading else { return }
        feedManager.flushDebouncedReads()
        withAnimation(.smooth.speed(2.0)) {
            visibility.beginRefresh(from: rawArticles, isEnabled: hideViewedContent)
        }
        await feedManager.refreshAllFeeds()
        withAnimation(.smooth.speed(2.0)) {
            visibility.endRefresh(from: rawArticles, isEnabled: hideViewedContent)
        }
    }

    /// Kicks off a refresh and returns immediately so SwiftUI dismisses the
    /// pull-to-refresh indicator; in-flight progress shows via the toolbar donut.
    private func startRefreshWithoutBlocking() {
        guard !feedManager.isLoading else { return }
        feedManager.flushDebouncedReads()
        withAnimation(.smooth.speed(2.0)) {
            visibility.beginRefresh(from: rawArticles, isEnabled: hideViewedContent)
        }
        Task { @MainActor in
            await feedManager.refreshAllFeeds()
            withAnimation(.smooth.speed(2.0)) {
                visibility.endRefresh(from: rawArticles, isEnabled: hideViewedContent)
            }
        }
    }

    private func acceptPendingRefresh() {
        withAnimation(.smooth.speed(2.0)) {
            visibility.acceptPendingRefresh()
        }
        scrollToTopTick &+= 1
    }

    private var loadMoreAction: (() -> Void)? {
        if hideViewedContent && visibility.hasReachedEnd { return nil }
        if let days = batchingMode.chunkDays {
            guard let next = feedManager.nextArticleChunk(
                before: loadedSinceDate,
                chunkDays: days,
                requireUnread: hideViewedContent
            ) else {
                return nil
            }
            return { loadedSinceDate = next }
        }
        if let batch = batchingMode.batchSize {
            guard let next = feedManager.nextLoadedCount(
                after: loadedCount,
                batchSize: batch,
                requireUnread: hideViewedContent
            ) else {
                return nil
            }
            return { loadedCount = next }
        }
        return nil
    }

    private var currentTitle: String {
        switch selectedSelection {
        case .section(let section):
            return section.localizedTitle
        case .bookmarks:
            return String(localized: "Tabs.Bookmarks")
        case .list(let id):
            return feedManager.lists.first { $0.id == id }?.name
                ?? String(localized: "Shared.AllArticles")
        }
    }

    private let bookmarksSectionTip = BookmarksSectionTip()

    var body: some View {
        Group {
            switch selectedSelection {
            case .section(let section):
                if let feedSection = section.feedSection {
                    HomeSectionView(section: feedSection)
                } else {
                    feedTabContent
                }
            case .bookmarks:
                BookmarksContentView()
            case .list(let id):
                if let list = feedManager.lists.first(where: { $0.id == id }) {
                    ListSectionView(list: list)
                } else {
                    feedTabContent
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if selectedSelection != .bookmarks {
                TipView(bookmarksSectionTip)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
        }
        .navigationTitle(currentTitle)
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbarTitleMenu {
            ForEach(availableSections) { section in
                Button {
                    withAnimation(.smooth.speed(2.0)) {
                        selectedSelection = .section(section)
                    }
                } label: {
                    if let systemImage = section.systemImage {
                        Label(section.localizedTitle, systemImage: systemImage)
                    } else {
                        Text(section.localizedTitle)
                    }
                }
            }

            Divider()
            Button {
                withAnimation(.smooth.speed(2.0)) {
                    selectedSelection = .bookmarks
                }
                bookmarksSectionTip.invalidate(reason: .actionPerformed)
            } label: {
                Label("Tabs.Bookmarks", systemImage: "bookmark")
            }

            if !feedManager.lists.isEmpty {
                Divider()
                ForEach(feedManager.lists) { list in
                    Button {
                        withAnimation(.smooth.speed(2.0)) {
                            selectedSelection = .list(list.id)
                        }
                    } label: {
                        Label(list.name, systemImage: list.icon)
                    }
                }
            }
        }
        .onChange(of: availableSections) {
            validateSelection()
        }
        .onChange(of: feedManager.lists) {
            validateSelection()
        }
        .onChange(of: batchingMode) { _, newMode in
            loadedSinceDate = newMode.initialSinceDate()
            loadedCount = newMode.initialCount()
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
        .onChange(of: doomscrollingMode) { _, _ in
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
        .onAppear {
            refreshBookmarksTip()
        }
        .onChange(of: feedManager.dataRevision) {
            refreshBookmarksTip()
        }
    }

    private func refreshBookmarksTip() {
        let count = (try? DatabaseManager.shared.bookmarkedCount()) ?? 0
        BookmarksSectionTip.bookmarkCount = count
    }

    private func validateSelection() {
        switch selectedSelection {
        case .section(let section):
            if !availableSections.contains(section) {
                selectedSelection = .section(.all)
            }
        case .bookmarks:
            break
        case .list(let id):
            if !feedManager.lists.contains(where: { $0.id == id }) {
                selectedSelection = .section(.all)
            }
        }
    }

    private var availableSections: [HomeSection] {
        HomeSection.allCases.filter { section in
            guard let feedSection = section.feedSection else { return true }
            return feedManager.hasFeeds(for: feedSection)
        }
    }

    private var feedTabContent: some View {
        ArticlesView(
            articles: displayedArticles,
            title: HomeSection.all.localizedTitle,
            feedKey: "all",
            anySummaryHidden: anySummaryHidden,
            onRestoreSummaries: {
                withAnimation(.smooth.speed(2.0)) {
                    whileYouSleptDismissedDate = ""
                    todaysSummaryDismissedDate = ""
                }
            },
            onLoadMore: loadMoreAction,
            onRefresh: {
                await performRefresh()
            },
            onMarkAllRead: {
                feedManager.markAllRead()
            },
            scrollToTopTrigger: scrollToTopTick
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                WhileYouSleptView(
                    hasSummary: $whileYouSleptAvailable
                )
                TodaysSummaryView(
                    hasSummary: $todaysSummaryAvailable
                )
            }
            .animation(.smooth.speed(2.0), value: whileYouSleptDismissedDate)
            .animation(.smooth.speed(2.0), value: todaysSummaryDismissedDate)
            .padding(.bottom, 8)
        }
        .refreshable {
            startRefreshWithoutBlocking()
        }
        .markAllReadToolbar(show: markAllReadPosition == .bottom) {
            feedManager.markAllRead()
        }
        .trackArticleVisibility(
            $visibility,
            hideViewedContent: hideViewedContent,
            loadedSinceDate: loadedSinceDate,
            loadedCount: loadedCount,
            rawArticles: { rawArticles }
        )
        .trackBackgroundRefresh(
            $visibility,
            isLoading: feedManager.isLoading,
            hideViewedContent: hideViewedContent,
            rawArticles: { rawArticles }
        )
        .refreshPromptOverlay(isVisible: visibility.hasPendingRefresh) {
            acceptPendingRefresh()
        }
    }
}
