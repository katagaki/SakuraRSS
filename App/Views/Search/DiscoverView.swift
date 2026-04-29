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
            || !filteredTopics.isEmpty
            || !filteredPeople.isEmpty
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

                            if !filteredTopics.isEmpty || !filteredPeople.isEmpty {
                                topicsAndPeopleSection
                            }
                        }
                    }
                    .padding(.vertical)
                }
            } else {
                ContentUnavailableView {
                    Label(String(localized: "Discover.Empty", table: "Feeds"), systemImage: "sparkles")
                } description: {
                    Text(String(localized: "Discover.Empty.Description", table: "Feeds"))
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
            String(localized: "Discover.ClearHistory.Confirm", table: "Feeds"),
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Discover.ClearHistory.Confirm", table: "Feeds"), role: .destructive) {
                feedManager.clearAccessHistory()
                withAnimation {
                    recentArticles = []
                }
            }
        } message: {
            Text(String(localized: "Discover.ClearHistory.Message", table: "Feeds"))
        }
    }

    // MARK: - Recently Accessed

    @ViewBuilder
    private var recentlyAccessedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "Discover.RecentlyAccessed", table: "Feeds"))
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button(String(localized: "Discover.ClearHistory", table: "Feeds")) {
                    showingClearConfirmation = true
                }
                .font(.title3)
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

    private var filteredTopics: [(name: String, count: Int)] {
        allTopics.filter { $0.count > 1 }
    }

    private var filteredPeople: [(name: String, count: Int)] {
        allPeople.filter { $0.count > 1 }
    }

    @ViewBuilder
    private var topicsAndPeopleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Discover.TopicsAndPeople", table: "Feeds"))
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)

            FlowLayout(spacing: 8) {
                ForEach(filteredTopics, id: \.name) { topic in
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
                ForEach(filteredPeople, id: \.name) { person in
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

    // MARK: - Data Loading

    private func loadData() async {
        let database = DatabaseManager.shared
        let loadEntities = contentInsightsEnabled

        await Task.detached {
            let recent = (try? database.recentlyAccessedArticles()) ?? []

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
                for person in topPeople.prefix(3) {
                    let articles = (try? database.articlesForEntity(
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

private struct FlowLayout: Layout {

    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalHeight = currentY + lineHeight
        }
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
    }
}

/// Seeded RNG for deterministic daily shuffles.
private nonisolated struct DailyRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
