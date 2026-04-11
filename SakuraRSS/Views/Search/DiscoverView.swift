import SwiftUI

struct DiscoverView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("Intelligence.ContentInsights.Enabled") private var contentInsightsEnabled: Bool = false

    @State private var recentArticles: [Article] = []
    @State private var entitySections: [DiscoverEntitySection] = []
    @State private var allTopics: [(name: String, count: Int)] = []
    @State private var allPeople: [(name: String, count: Int)] = []
    @State private var showingClearConfirmation = false
    @State private var refreshID = 0

    private var hasContent: Bool {
        !recentArticles.isEmpty
            || !entitySections.isEmpty
            || !allTopics.isEmpty
            || !allPeople.isEmpty
    }

    var body: some View {
        Group {
            if hasContent {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if !recentArticles.isEmpty {
                            recentlyAccessedSection
                        }

                        if contentInsightsEnabled {
                            ForEach(entitySections) { section in
                                entitySection(section)
                            }

                            if !allTopics.isEmpty || !allPeople.isEmpty {
                                topicsAndPeopleSection
                            }
                        }
                    }
                    .padding(.vertical)
                }
            } else {
                ContentUnavailableView {
                    Label("Discover.Empty", systemImage: "sparkles")
                } description: {
                    Text("Discover.Empty.Description")
                }
            }
        }
        .task(id: refreshID) {
            await loadData()
        }
        .onAppear {
            refreshID += 1
        }
        .confirmationDialog(
            "Discover.ClearHistory.Confirm",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discover.ClearHistory.Confirm", role: .destructive) {
                feedManager.clearAccessHistory()
                withAnimation {
                    recentArticles = []
                }
            }
        } message: {
            Text("Discover.ClearHistory.Message")
        }
    }

    // MARK: - Recently Accessed

    @ViewBuilder
    private var recentlyAccessedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Discover.RecentlyAccessed")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button("Discover.ClearHistory") {
                    showingClearConfirmation = true
                }
                .font(.subheadline)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(recentArticles) { article in
                        DiscoverArticleCard(article: article)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Entity Sections (Topics & People Carousels)

    @ViewBuilder
    private func entitySection(_ section: DiscoverEntitySection) -> some View {
        if !section.articles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                NavigationLink(value: EntityDestination(name: section.name, types: section.types)) {
                    HStack(spacing: 4) {
                        Text(section.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(section.articles) { article in
                            DiscoverArticleCard(article: article)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Topics & People Pills

    @ViewBuilder
    private var topicsAndPeopleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Discover.TopicsAndPeople")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(allTopics, id: \.name) { topic in
                        NavigationLink(value: EntityDestination(name: topic.name, types: ["organization", "place"])) {
                            Text(topic.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.regularMaterial, in: Capsule())
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(allPeople, id: \.name) { person in
                        NavigationLink(value: EntityDestination(name: person.name, types: ["person"])) {
                            Text(person.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.regularMaterial, in: Capsule())
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        let db = DatabaseManager.shared
        let loadEntities = contentInsightsEnabled

        await Task.detached {
            let recent = (try? db.recentlyAccessedArticles()) ?? []

            var sections: [DiscoverEntitySection] = []
            var topics: [(name: String, count: Int)] = []
            var people: [(name: String, count: Int)] = []

            if loadEntities {
                let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
                let topTopics = (try? db.topEntities(
                    types: ["organization", "place"],
                    since: sevenDaysAgo,
                    limit: 50
                )) ?? []
                let topPeople = (try? db.topEntities(
                    type: "person",
                    since: sevenDaysAgo,
                    limit: 50
                )) ?? []

                topics = topTopics
                people = topPeople

                // Build entity sections from top 3 of each
                var sectionItems: [DiscoverEntitySection] = []
                for topic in topTopics.prefix(3) {
                    let articles = (try? db.articlesForEntity(
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
                for person in topPeople.prefix(3) {
                    let articles = (try? db.articlesForEntity(
                        name: person.name,
                        types: ["person"],
                        limit: 10
                    )) ?? []
                    if !articles.isEmpty {
                        sectionItems.append(DiscoverEntitySection(
                            name: person.name,
                            types: ["person"],
                            articles: articles
                        ))
                    }
                }

                // Daily-deterministic shuffle
                sectionItems = Self.dailyShuffled(sectionItems)
                sections = sectionItems
            }

            await MainActor.run {
                recentArticles = recent
                entitySections = sections
                allTopics = topics
                allPeople = people
            }
        }.value
    }

    // MARK: - Daily Deterministic Shuffle

    private nonisolated static func dailyShuffled(_ items: [DiscoverEntitySection]) -> [DiscoverEntitySection] {
        guard items.count > 1 else { return items }
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let year = calendar.component(.year, from: Date())
        var rng = DailyRNG(seed: UInt64(year * 1000 + day))
        var result = items
        result.shuffle(using: &rng)
        return result
    }
}

// MARK: - Supporting Types

struct DiscoverEntitySection: Identifiable {
    let name: String
    let types: [String]
    let articles: [Article]

    var id: String { name }
}

/// A simple seeded random number generator for deterministic daily shuffles.
private nonisolated struct DailyRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
