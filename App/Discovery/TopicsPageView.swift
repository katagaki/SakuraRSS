import SwiftUI
import Hanami

/// Topics and people, with the content each one runs through. Lifted out of
/// Today so the page that browses by subject is a place of its own.
struct TopicsPageView: View {

    @AppStorage("Intelligence.ContentInsights.Enabled") private var contentInsightsEnabled: Bool = false

    @State private var entitySections: [DiscoverEntitySection] = []
    @State private var allTopics: [(name: String, count: Int)] = []
    @State private var allPeople: [(name: String, count: Int)] = []
    @State private var hasLoaded = false

    private var filteredTopics: [(name: String, count: Int)] {
        allTopics.filter { $0.count > 1 }
    }

    private var filteredPeople: [(name: String, count: Int)] {
        allPeople.filter { $0.count > 1 }
    }

    private var hasContent: Bool {
        !entitySections.isEmpty || !filteredTopics.isEmpty || !filteredPeople.isEmpty
    }

    var body: some View {
        Group {
            if !contentInsightsEnabled {
                insightsDisabledView
            } else if !hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if hasContent {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(entitySections) { section in
                            DiscoverEntityCarousel(section: section)
                        }
                        if !filteredTopics.isEmpty || !filteredPeople.isEmpty {
                            allTopicsSection
                        }
                    }
                    .padding(.vertical)
                }
            } else {
                ContentUnavailableView {
                    Label(String(localized: "Topics.Empty", table: "Articles"), systemImage: "number")
                } description: {
                    Text(String(localized: "Topics.Empty.Description", table: "Articles"))
                }
            }
        }
        .navigationTitle(String(localized: "Location.Topics", table: "Browser"))
        .toolbarTitleDisplayMode(.inline)
        .sakuraBackground()
        .task { await load() }
    }

    @ViewBuilder
    private var allTopicsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Discover.TopicsAndPeople", table: "Feeds"))
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)

            TodayChipsFlow(topics: filteredTopics, people: filteredPeople)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var insightsDisabledView: some View {
        ContentUnavailableView {
            Label(String(localized: "Topics.Disabled", table: "Browser"), systemImage: "sparkles")
        } description: {
            Text(String(localized: "Topics.Disabled.Description", table: "Browser"))
        }
    }

    private func load() async {
        guard contentInsightsEnabled else {
            hasLoaded = true
            return
        }
        let database = DatabaseManager.shared
        let data = await Task.detached {
            DiscoverView.loadEntityData(database: database)
        }.value
        if Task.isCancelled { return }
        entitySections = data.sections
        allTopics = data.topics
        allPeople = data.people
        hasLoaded = true
    }
}
