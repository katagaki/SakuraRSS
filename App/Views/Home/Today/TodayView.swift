import SwiftUI

/// Top-level Today tab content: greeting + weather, summary cards, topic
/// carousels, topics/people pills, bookmarks, and recently viewed.
struct TodayView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(TodayManager.self) var todayManager
    @AppStorage("Intelligence.ContentInsights.Enabled") private var contentInsightsEnabled: Bool = false

    @State private var sleptHasSummary = false
    @State private var afternoonHasSummary = false
    @State private var todayHasSummary = false
    @State private var sleptVisible = false
    @State private var afternoonVisible = false
    @State private var todayVisible = false

    @State private var summaryRefreshTrigger: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TodayGreetingView()
                    .padding(.horizontal)
                    .padding(.top, 8)

                if !anySummaryVisible,
                   !todayManager.hasLoadedInitially || !contentSections.isEmpty || showEmptyState {
                    sectionDivider
                }

                WhileYouSleptView(
                    hasSummary: $sleptHasSummary, flatStyle: true,
                    isVisible: $sleptVisible,
                    refreshTrigger: summaryRefreshTrigger
                )
                AfternoonBriefView(
                    hasSummary: $afternoonHasSummary,
                    isVisible: $afternoonVisible,
                    refreshTrigger: summaryRefreshTrigger
                )
                TodaysSummaryView(
                    hasSummary: $todayHasSummary, flatStyle: true,
                    isVisible: $todayVisible,
                    refreshTrigger: summaryRefreshTrigger
                )

                if anySummaryVisible,
                   !todayManager.hasLoadedInitially || !contentSections.isEmpty || showEmptyState {
                    sectionDivider
                }

                if !todayManager.hasLoadedInitially {
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
        #if os(visionOS)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    startRefreshWithoutBlocking()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        #endif
        .task(id: feedManager.dataRevision) {
            todayManager.loadIfStale(
                feeds: feedManager.feeds,
                dataRevision: feedManager.dataRevision,
                loadEntities: contentInsightsEnabled
            )
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
        todayManager.hasLoadedInitially && !anySummaryVisible && contentSections.isEmpty
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
        if !todayManager.unreadPodcastEpisodes.isEmpty {
            sections.append(.listenNow)
        }
        if !todayManager.unreadVideoEpisodes.isEmpty {
            sections.append(.watchNow)
        }
        if contentInsightsEnabled,
           todayManager.entitySections.prefix(3).contains(where: { !$0.articles.isEmpty }) {
            sections.append(.topThree)
        }
        if contentInsightsEnabled, !filteredTopics.isEmpty || !filteredPeople.isEmpty {
            sections.append(.topicsAndPeople)
        }
        if !todayManager.bookmarkedArticles.isEmpty {
            sections.append(.bookmarks)
        }
        if !todayManager.recentArticles.isEmpty {
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
            articles: todayManager.unreadPodcastEpisodes
        ) { article in
            TodayPodcastCard(article: article)
        }
    }

    @ViewBuilder
    private var watchNowSection: some View {
        TodayCardCarousel(
            title: String(localized: "Today.WatchNow", table: "Home"),
            destination: nil,
            articles: todayManager.unreadVideoEpisodes
        )
    }

    @ViewBuilder
    private var topThreeTopicsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(todayManager.entitySections.prefix(3)) { section in
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
            articles: todayManager.bookmarkedArticles
        )
    }

    @ViewBuilder
    private var recentlyViewedSection: some View {
        TodayCardCarousel(
            title: String(localized: "Discover.RecentlyAccessed", table: "Feeds"),
            destination: nil,
            articles: todayManager.recentArticles
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
        summaryRefreshTrigger += 1
        let feeds = feedManager.feeds
        let loadEntities = contentInsightsEnabled
        Task { @MainActor in
            await feedManager.refreshFeeds(scope: "section.all", feeds: feeds)
            todayManager.load(
                feeds: feedManager.feeds,
                dataRevision: feedManager.dataRevision,
                loadEntities: loadEntities
            )
        }
    }

    // MARK: - Data

    private var filteredTopics: [(name: String, count: Int)] {
        let topics = todayManager.allTopics.filter { $0.count > 1 }
        let peopleCount = todayManager.allPeople.filter { $0.count > 1 }.count
        let topicCap = max(0, min(topics.count, 20 - min(peopleCount, 10)))
        return Array(topics.prefix(topicCap))
    }

    private var filteredPeople: [(name: String, count: Int)] {
        let people = todayManager.allPeople.filter { $0.count > 1 }
        let remaining = max(0, 20 - filteredTopics.count)
        return Array(people.prefix(remaining))
    }
}
