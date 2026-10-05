import SwiftUI
import Hanami

extension ArticleDetailView {

    @ViewBuilder
    var insightsSection: some View {
        if shouldShowInsightsSection {
            VStack(alignment: .leading, spacing: 16) {
                Divider()
                    .padding(.horizontal)

                Label(
                    String(localized: "Insights.Title", table: "Settings"),
                    systemImage: "sparkles"
                )
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)

                if isLoadingInsights {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .transition(.blurReplace)
                } else {
                    if !similarArticles.isEmpty {
                        similarContentSubsection
                    }

                    if !articleTopics.isEmpty {
                        entityChipsSubsection(
                            titleKey: String(localized: "SimilarContent.Topics", table: "Articles"),
                            types: ["organization", "place"],
                            names: articleTopics
                        )
                    }

                    if !articlePeople.isEmpty {
                        entityChipsSubsection(
                            titleKey: String(localized: "SimilarContent.People", table: "Articles"),
                            types: ["person"],
                            names: articlePeople
                        )
                    }
                }
            }
        }
    }

    private var shouldShowInsightsSection: Bool {
        guard contentInsightsEnabled else { return false }
        return isLoadingInsights || hasAnyInsights
    }

    private var hasAnyInsights: Bool {
        !similarArticles.isEmpty || !articleTopics.isEmpty || !articlePeople.isEmpty
    }

    @ViewBuilder
    private var similarContentSubsection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "SimilarContent.Title", table: "Articles"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(similarArticles) { item in
                        ArticleLink(article: item.article) {
                            SimilarArticleCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func entityChipsSubsection(
        titleKey: String,
        types: [String],
        names: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titleKey)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(names, id: \.self) { name in
                        NavigationLink(value: EntityDestination(name: name, types: types)) {
                            Text(name)
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

    /// Kicks off similar/topic/people loading off MainActor.
    func loadInsightsInBackground() {
        guard contentInsightsEnabled else { return }
        let currentArticle = article
        let feedsLookup = feedManager.feedsByID

        isLoadingInsights = true
        Task {
            async let similarTask = Self.similarArticleItems(
                currentArticle: currentArticle, feedsLookup: feedsLookup
            )
            async let entitiesTask = ContentInsights.entities(for: currentArticle)
            let loadedSimilar = await similarTask
            let loadedEntities = await entitiesTask

            similarArticles = loadedSimilar
            articleTopics = loadedEntities.topics
            articlePeople = loadedEntities.people
            isLoadingInsights = false
        }

        Task.detached(priority: .utility) {
            ContentInsights.processSentimentIfNeeded(for: currentArticle)
        }
    }

    fileprivate nonisolated static func similarArticleItems(
        currentArticle: Article,
        feedsLookup: [Int64: Feed]
    ) async -> [SimilarArticleItem] {
        let matches = await ContentInsights.similarContent(to: currentArticle, feedsLookup: feedsLookup)
        return await withTaskGroup(of: (Int, SimilarArticleItem).self) { group in
            for (index, match) in matches.enumerated() {
                group.addTask {
                    let icon: UIImage?
                    if let feed = match.feed {
                        icon = await Iconography.shared.icon(for: feed)
                    } else {
                        icon = nil
                    }
                    return (index, SimilarArticleItem(
                        id: match.article.id,
                        article: match.article,
                        feedName: match.feedName,
                        isCircleIcon: match.feed?.isCircleIcon ?? false,
                        sentiment: match.sentiment,
                        icon: icon
                    ))
                }
            }
            var results = [SimilarArticleItem?](repeating: nil, count: matches.count)
            for await (index, item) in group {
                results[index] = item
            }
            return results.compactMap { $0 }
        }
    }
}
