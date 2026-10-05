import Hanami
import SwiftUI

/// Content Insights under the content, as iOS shows them: similar content
/// from the past week, then the topics and people it mentions.
struct ReaderInsightsSection: View {

    let article: Article
    let feedManager: FeedManager
    let actions: TodayActions?
    @AppStorage("Intelligence.ContentInsights.Enabled") private var contentInsightsEnabled = false
    @State private var similarContent: [ContentInsights.SimilarContent] = []
    @State private var topics: [String] = []
    @State private var people: [String] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if contentInsightsEnabled && (isLoading || hasInsights) {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                    Label(String(localized: "Insights.Title", table: "Settings"), systemImage: "sparkles")
                        .font(.title3.bold())
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        if !similarContent.isEmpty {
                            subsection(String(localized: "SimilarContent.Title", table: "Articles")) {
                                SimilarContentRow(items: similarContent) { actions?.open(.article($0)) }
                            }
                        }
                        entityChips(String(localized: "SimilarContent.Topics", table: "Articles"), names: topics) {
                            .topic($0)
                        }
                        entityChips(String(localized: "SimilarContent.People", table: "Articles"), names: people) {
                            .person($0)
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
        .task(id: "\(article.id)|\(contentInsightsEnabled)") {
            guard contentInsightsEnabled else { return }
            await load()
        }
    }

    private var hasInsights: Bool {
        !similarContent.isEmpty || !topics.isEmpty || !people.isEmpty
    }

    private func load() async {
        isLoading = true
        let currentArticle = article
        async let similar = ContentInsights.similarContent(to: currentArticle, feedsLookup: feedManager.feedsByID)
        async let entities = ContentInsights.entities(for: currentArticle)
        similarContent = await similar
        let loadedEntities = await entities
        topics = loadedEntities.topics
        people = loadedEntities.people
        isLoading = false
        Task.detached(priority: .utility) {
            ContentInsights.processSentimentIfNeeded(for: currentArticle)
        }
    }

    private func subsection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    @ViewBuilder
    private func entityChips(
        _ title: String,
        names: [String],
        location: @escaping (String) -> BrowserLocation
    ) -> some View {
        if !names.isEmpty {
            subsection(title) {
                FlowLayout(spacing: 8) {
                    ForEach(names, id: \.self) { name in
                        Button { actions?.open(location(name)) } label: {
                            Text(name)
                                .font(.callout.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.quinary, in: .capsule)
                                .contentShape(.capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
