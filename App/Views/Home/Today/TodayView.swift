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
    @State private var refreshID: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TodayGreetingView()
                    .padding(.horizontal)
                    .padding(.top, 8)

                if !anySummaryVisible, !contentSections.isEmpty {
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

                ForEach(Array(contentSections.enumerated()), id: \.element) { index, section in
                    sectionView(section)
                    if index < contentSections.count - 1 {
                        sectionDivider
                    }
                }

                attributionFooter
            }
            .padding(.bottom, 24)
        }
        .sakuraBackground()
        .refreshable {
            await TodayWeatherService.shared.refresh(force: true)
            await loadData()
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
        case topThree
        case topicsAndPeople
        case bookmarks
        case recentlyViewed
    }

    private var anySummaryVisible: Bool {
        sleptVisible || afternoonVisible || todayVisible
    }

    private var contentSections: [ContentSection] {
        var sections: [ContentSection] = []
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
        case .topThree: topThreeTopicsSection
        case .topicsAndPeople: topicsAndPeopleSection
        case .bookmarks: bookmarksSection
        case .recentlyViewed: recentlyViewedSection
        }
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
        VStack {
            Divider()
            // swiftlint:disable:next line_length
            Text(LocalizedStringKey("\(prefix) [\(linkLabel)](https://developer.apple.com/weatherkit/data-source-attribution/)"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 16)
        .padding(.horizontal)
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

        await Task.detached {
            let recent = (try? database.recentlyAccessedArticles()) ?? []
            let bookmarks = (try? database.bookmarkedArticles()) ?? []

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
                recentArticles = recent
                bookmarkedArticles = bookmarks
                entitySections = sections
                allTopics = topics
                allPeople = people
            }
        }.value
    }
}
