import SwiftUI
import TipKit

enum HomeSection: String, CaseIterable, Identifiable {
    case feed
    case social
    case videos
    case audio

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .feed: String(localized: "Shared.AllArticles")
        case .social: String(localized: "HomeSection.Social", table: "Feeds")
        case .videos: String(localized: "HomeSection.Videos", table: "Feeds")
        case .audio: String(localized: "HomeSection.Audio", table: "Feeds")
        }
    }

    var systemImage: String {
        switch self {
        case .feed: "square.stack"
        case .social: "person.2"
        case .videos: "play.rectangle"
        case .audio: "headphones"
        }
    }

    var feedSection: FeedSection? {
        switch self {
        case .feed: nil
        case .social: .social
        case .videos: .video
        case .audio: .audio
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

    var systemImage: String {
        switch self {
        case .section(let section): section.systemImage
        case .bookmarks: "bookmark"
        case .list: ""
        }
    }
}

struct AllArticlesView: View {

    @Environment(FeedManager.self) var feedManager

    @AppStorage("Home.SelectedSection") private var selectedSelection: HomeSelection = .section(.feed)
    @AppStorage("Articles.BatchingMode") private var batchingMode: BatchingMode = .day1
    @State private var loadedSinceDate: Date = BatchingMode.current().initialSinceDate()
    @State private var loadedCount: Int = BatchingMode.current().initialCount()
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("WhileYouSlept.DismissedDate") private var whileYouSleptDismissedDate: String = ""
    @AppStorage("TodaysSummary.DismissedDate") private var todaysSummaryDismissedDate: String = ""
    @AppStorage("Instagram.HideReels") private var hideInstagramReels: Bool = false
    @AppStorage("Articles.HideViewedContent") private var hideViewedContent: Bool = false
    @State private var visibility = ArticleVisibilityTracker()
    @State private var whileYouSleptAvailable = false
    @State private var todaysSummaryAvailable = false

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
            articles = feedManager.articles(limit: loadedCount)
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
        visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        await feedManager.refreshAllFeeds()
        visibility.extend(from: rawArticles, isEnabled: hideViewedContent)
    }

    private var loadMoreAction: (() -> Void)? {
        if let days = batchingMode.chunkDays {
            guard let next = feedManager.nextArticleChunk(before: loadedSinceDate, chunkDays: days) else {
                return nil
            }
            return { loadedSinceDate = next }
        }
        if let batch = batchingMode.batchSize {
            guard feedManager.hasMoreArticles(beyond: loadedCount) else { return nil }
            return { loadedCount += batch }
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
                switch section {
                case .feed:
                    feedTabContent
                case .social:
                    HomeSectionView(section: .social)
                case .videos:
                    HomeSectionView(section: .video)
                case .audio:
                    HomeSectionView(section: .audio)
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
                    Label(section.localizedTitle, systemImage: section.systemImage)
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
                selectedSelection = .section(.feed)
            }
        case .bookmarks:
            break
        case .list(let id):
            if !feedManager.lists.contains(where: { $0.id == id }) {
                selectedSelection = .section(.feed)
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
            title: HomeSection.feed.localizedTitle,
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
            }
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
            await performRefresh()
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
    }
}
