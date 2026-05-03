import SwiftUI

/// Top-level Today tab content: greeting + weather, summary cards, topic
/// carousels, topics/people pills, bookmarks, and recently viewed.
struct TodayView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("Intelligence.ContentInsights.Enabled") private var contentInsightsEnabled: Bool = false

    @State private var sleptHasSummary = false
    @State private var afternoonHasSummary = false
    @State private var todayHasSummary = false
    @State private var sleptVisible = false
    @State private var afternoonVisible = false
    @State private var todayVisible = false

    @State private var entitySections: [DiscoverEntitySection] = []
    @State private var allTopics: [(name: String, count: Int)] = []
    @State private var allPeople: [(name: String, count: Int)] = []
    @State private var bookmarkedArticles: [Article] = []
    @State private var recentArticles: [Article] = []
    @State private var unreadPodcastEpisodes: [Article] = []
    @State private var unreadVideoEpisodes: [Article] = []
    @State private var hasLoadedInitially = false
    @State private var refreshID: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TodayGreetingView()
                    .padding(.horizontal)
                    .padding(.top, 8)

                if !anySummaryVisible, !hasLoadedInitially || !contentSections.isEmpty || showEmptyState {
                    sectionDivider
                }

                WhileYouSleptView(
                    hasSummary: $sleptHasSummary, flatStyle: true,
                    isVisible: $sleptVisible
                )
                AfternoonBriefView(
                    hasSummary: $afternoonHasSummary,
                    isVisible: $afternoonVisible
                )
                TodaysSummaryView(
                    hasSummary: $todayHasSummary, flatStyle: true,
                    isVisible: $todayVisible
                )

                if !hasLoadedInitially {
                    loadingIndicator
                } else if showEmptyState {
                    emptyContentView
                } else {
                    ForEach(Array(contentSections.enumerated()), id: \.element) { index, section in
                        sectionView(section)
                        if index < contentSections.count - 1 {
                            sectionDivider
                        }
                    }
                }

                attributionFooter
            }
            .padding(.bottom, 24)
        }
        .sakuraBackground()
        .refreshable {
            startRefreshWithoutBlocking()
        }
        .task(id: refreshID) {
            await loadData()
        }
        .onAppear {
            refreshID += 1
        }
        .onChange(of: feedManager.dataRevision) {
            refreshID += 1
        }
    }

    // MARK: - Sections

    private enum ContentSection: Hashable {
        case listenNow
        case watchNow
        case topThree
        case topicsAndPeople
        case bookmarks
        case recentlyViewed
    }

    private var anySummaryVisible: Bool {
        sleptVisible || afternoonVisible || todayVisible
    }

    private var showEmptyState: Bool {
        hasLoadedInitially && !anySummaryVisible && contentSections.isEmpty
    }

    @ViewBuilder
    private var emptyContentView: some View {
        ContentUnavailableView {
            Label(String(localized: "Today.Empty.Title", table: "Home"), systemImage: "checkmark.circle")
        } description: {
            Text(String(localized: "Today.Empty.Description", table: "Home"))
        }
        .padding(.vertical, 32)
    }

    @ViewBuilder
    private var loadingIndicator: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(String(localized: "Today.Loading", table: "Home"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var contentSections: [ContentSection] {
        var sections: [ContentSection] = []
        if !unreadPodcastEpisodes.isEmpty {
            sections.append(.listenNow)
        }
        if !unreadVideoEpisodes.isEmpty {
            sections.append(.watchNow)
        }
        if contentInsightsEnabled, entitySections.prefix(3).contains(where: { !$0.articles.isEmpty }) {
            sections.append(.topThree)
        }
        if contentInsightsEnabled, !filteredTopics.isEmpty || !filteredPeople.isEmpty {
            sections.append(.topicsAndPeople)
        }
        if !bookmarkedArticles.isEmpty {
            sections.append(.bookmarks)
        }
        if !recentArticles.isEmpty {
            sections.append(.recentlyViewed)
        }
        return sections
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.horizontal)
    }

    @ViewBuilder
    private func sectionView(_ section: ContentSection) -> some View {
        switch section {
        case .listenNow: listenNowSection
        case .watchNow: watchNowSection
        case .topThree: topThreeTopicsSection
        case .topicsAndPeople: topicsAndPeopleSection
        case .bookmarks: bookmarksSection
        case .recentlyViewed: recentlyViewedSection
        }
    }

    @ViewBuilder
    private var listenNowSection: some View {
        TodayCardCarousel(
            title: String(localized: "Today.ListenNow", table: "Home"),
            destination: nil,
            articles: unreadPodcastEpisodes
        ) { article in
            TodayPodcastCard(article: article)
        }
    }

    @ViewBuilder
    private var watchNowSection: some View {
        TodayCardCarousel(
            title: String(localized: "Today.WatchNow", table: "Home"),
            destination: nil,
            articles: unreadVideoEpisodes
        )
    }

    @ViewBuilder
    private var topThreeTopicsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(entitySections.prefix(3)) { section in
                if !section.articles.isEmpty {
                    TodayCardCarousel(
                        title: section.name,
                        destination: EntityDestination(name: section.name, types: section.types),
                        articles: section.articles
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var topicsAndPeopleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Discover.TopicsAndPeople", table: "Feeds"))
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)

            TodayChipsFlow(
                topics: filteredTopics,
                people: filteredPeople
            )
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var bookmarksSection: some View {
        TodayCardCarousel(
            title: String(localized: "Today.Bookmarks", table: "Home"),
            destination: nil,
            articles: bookmarkedArticles
        )
    }

    @ViewBuilder
    private var recentlyViewedSection: some View {
        TodayCardCarousel(
            title: String(localized: "Discover.RecentlyAccessed", table: "Feeds"),
            destination: nil,
            articles: recentArticles
        )
    }

    @ViewBuilder
    private var attributionFooter: some View {
        let prefix = String(localized: "Today.WeatherAttribution.Prefix", table: "Home")
        let linkLabel = String(localized: "Today.WeatherAttribution.Link", table: "Home")
        VStack(spacing: 16) {
            Divider()
            // swiftlint:disable:next line_length
            Text(LocalizedStringKey("\(prefix) [\(linkLabel)](https://developer.apple.com/weatherkit/data-source-attribution/)"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }

    // MARK: - Refresh

    private var scopedRefreshState: ScopedRefreshState {
        feedManager.scopedRefreshes["section.all"] ?? ScopedRefreshState()
    }

    private func startRefreshWithoutBlocking() {
        guard !scopedRefreshState.hasActiveProgress else { return }
        feedManager.flushDebouncedReads()
        let feeds = feedManager.feeds
        Task { @MainActor in
            await feedManager.refreshFeeds(scope: "section.all", feeds: feeds)
            await loadData()
        }
    }

    // MARK: - Data

    private var filteredTopics: [(name: String, count: Int)] {
        let topics = allTopics.filter { $0.count > 1 }
        let topicCap = max(0, min(topics.count, 20 - min(allPeople.filter { $0.count > 1 }.count, 10)))
        return Array(topics.prefix(topicCap))
    }

    private var filteredPeople: [(name: String, count: Int)] {
        let people = allPeople.filter { $0.count > 1 }
        let remaining = max(0, 20 - filteredTopics.count)
        return Array(people.prefix(remaining))
    }

    // swiftlint:disable:next function_body_length
    private func loadData() async {
        let database = DatabaseManager.shared
        let loadEntities = contentInsightsEnabled
        let podcastFeedIDs = feedManager.feeds.filter { $0.isPodcast }.map { $0.id }
        let videoFeedIDs = feedManager.feeds
            .filter { $0.isYouTubeFeed || $0.isVimeoFeed }
            .map { $0.id }

        await Task.detached {
            let recent = (try? database.recentlyAccessedArticles()) ?? []
            let bookmarks = (try? database.bookmarkedArticles()) ?? []
            let podcastEpisodes = (try? database.articles(
                forFeedIDs: podcastFeedIDs,
                limit: 20,
                requireUnread: true
            )) ?? []
            let videoEpisodes = (try? database.articles(
                forFeedIDs: videoFeedIDs,
                limit: 20,
                requireUnread: true
            )) ?? []

            var sections: [DiscoverEntitySection] = []
            var topics: [(name: String, count: Int)] = []
            var people: [(name: String, count: Int)] = []

            if loadEntities {
                let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
                let topTopics = (try? database.topEntities(
                    types: ["organization", "place"],
                    since: sevenDaysAgo,
                    limit: 50
                )) ?? []
                let topPeople = (try? database.topEntities(
                    type: "person",
                    since: sevenDaysAgo,
                    limit: 50
                )) ?? []

                topics = topTopics
                people = topPeople

                var sectionItems: [DiscoverEntitySection] = []
                for topic in topTopics.prefix(3) {
                    let articles = (try? database.articlesForEntity(
                        name: topic.name,
                        types: ["organization", "place"],
                        limit: 10
                    )) ?? []
                    if !articles.isEmpty {
                        sectionItems.append(DiscoverEntitySection(
                            name: topic.name,
                            types: ["organization", "place"],
                            articles: articles
                        ))
                    }
                }

                sections = sectionItems
            }

            await MainActor.run {
                withAnimation(.smooth.speed(2.0)) {
                    recentArticles = recent
                    bookmarkedArticles = bookmarks
                    unreadPodcastEpisodes = podcastEpisodes
                    unreadVideoEpisodes = videoEpisodes
                    entitySections = sections
                    allTopics = topics
                    allPeople = people
                    hasLoadedInitially = true
                }
            }
        }.value
    }
}
