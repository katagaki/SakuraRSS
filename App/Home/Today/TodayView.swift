import SwiftUI
import Hanami

/// Top-level Today tab content: greeting + weather, summary cards, topic
/// carousels, topics/people pills, bookmarks, and recently viewed.
struct TodayView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(TodayManager.self) var todayManager
    @AppStorage("Intelligence.ContentInsights.Enabled") var contentInsightsEnabled: Bool = false
    @Bindable var weatherService: TodayWeatherService = .shared

    @State var sleptHasSummary = false
    @State var afternoonHasSummary = false
    @State var todayHasSummary = false
    @State var sleptVisible = false
    @State var afternoonVisible = false
    @State var todayVisible = false

    @State var summaryRefreshTrigger: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TodayGreetingView()
                    .padding(.horizontal)

                if isWeatherShowing {
                    sectionDivider
                }

                if !anySummaryVisible, !isWeatherShowing,
                   !todayManager.hasLoadedInitially || !contentSections.isEmpty || showEmptyState {
                    sectionDivider
                }

                if anySummaryActive {
                    VStack(spacing: 0) {
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
                    }
                }

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
            .padding(.top, 8)
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

    private var isWeatherShowing: Bool {
        HomeLayout.usesPhoneTopBar
            && weatherService.lastError == nil
            && weatherService.weather != nil
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
        if !visibleUnreadPodcastEpisodes.isEmpty {
            sections.append(.listenNow)
        }
        if !visibleUnreadVideoEpisodes.isEmpty {
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

    /// Re-filters TodayManager's pre-fetched unread lists with the live read state so
    /// items mark-read'd in this session disappear without waiting for a full reload.
    private var visibleUnreadPodcastEpisodes: [Article] {
        todayManager.unreadPodcastEpisodes.filter { !feedManager.isRead($0) }
    }

    private var visibleUnreadVideoEpisodes: [Article] {
        todayManager.unreadVideoEpisodes.filter { !feedManager.isRead($0) }
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
            articles: visibleUnreadPodcastEpisodes
        ) { article in
            TodayPodcastCard(article: article)
        }
    }

    @ViewBuilder
    private var watchNowSection: some View {
        TodayCardCarousel(
            title: String(localized: "Today.WatchNow", table: "Home"),
            destination: nil,
            articles: visibleUnreadVideoEpisodes
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
        let markdown = "\(prefix) [\(linkLabel)](https://developer.apple.com/weatherkit/data-source-attribution/)"
        let attributed = (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
        VStack(spacing: 16) {
            Divider()
            Text(attributed)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }

}
