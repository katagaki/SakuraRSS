import Hanami
import SwiftUI

/// Topics and people from Content Insights, with content for the busiest
/// topics, as iOS's Topics page shows them.
struct TopicsPage: View {

    let feedManager: FeedManager
    let actions: TodayActions
    let revisions: WindowDataRevisions
    @AppStorage("Intelligence.ContentInsights.Enabled") private var contentInsightsEnabled = false
    @State private var model = TopicsModel()

    var body: some View {
        Group {
            if !contentInsightsEnabled {
                ContentUnavailableView(
                    String(localized: "Topics.Disabled", table: "Browser"),
                    systemImage: "sparkles",
                    description: Text(String(localized: "Topics.Disabled.Description", table: "Browser"))
                )
            } else if !model.hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.isEmpty {
                ContentUnavailableView(
                    String(localized: "Topics.Empty", table: "Articles"),
                    systemImage: "number",
                    description: Text(String(localized: "Topics.Empty.Description", table: "Articles"))
                )
            } else {
                content
            }
        }
        .task(id: "\(contentInsightsEnabled)|\(revisions.dataRevision)") {
            guard contentInsightsEnabled else { return }
            await model.load()
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(model.sections) { section in
                    TodayCardRow(
                        title: section.name,
                        articles: section.articles,
                        feedManager: feedManager,
                        actions: actions
                    )
                }
                if !model.topics.isEmpty || !model.people.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "Discover.TopicsAndPeople", table: "Feeds"))
                            .font(.title3)
                            .fontWeight(.bold)
                        FlowLayout {
                            ForEach(model.topics, id: \.name) { topic in
                                TopicChip(name: topic.name, count: topic.count, symbolName: "number") {
                                    actions.open(.topic(topic.name))
                                }
                            }
                            ForEach(model.people, id: \.name) { person in
                                TopicChip(name: person.name, count: person.count, symbolName: "person") {
                                    actions.open(.person(person.name))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 24)
        }
    }
}
