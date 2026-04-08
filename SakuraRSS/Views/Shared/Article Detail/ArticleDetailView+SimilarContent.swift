import SwiftUI

struct SimilarArticleItem: Identifiable {
    let id: Int64
    let article: Article
    let feedName: String
    let sentiment: Double?
}

extension ArticleDetailView {

    @ViewBuilder
    var similarContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("SimilarContent.Title", systemImage: "brain.head.profile")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(similarArticles) { item in
                    NavigationLink(value: item.article) {
                        HStack(spacing: 10) {
                            sentimentDot(item.sentiment)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.article.title)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                    .foregroundStyle(.primary)
                                Text(item.feedName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if item.id != similarArticles.last?.id {
                        Divider()
                            .padding(.leading, 36)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    func loadSimilarArticles() async -> [SimilarArticleItem] {
        let db = DatabaseManager.shared
        let feedsLookup = feedManager.feedsByID
        let currentArticle = article

        return await Task.detached(priority: .utility) {
            guard let candidates = try? db.articlesInWindow(
                around: currentArticle, hours: 48, limit: 200
            ) else { return [SimilarArticleItem]() }

            let similar = NLPProcessor.findSimilarArticles(
                to: currentArticle,
                candidates: candidates,
                maxResults: 8,
                maximumDistance: 1.5
            )

            var items: [SimilarArticleItem] = []
            for match in similar {
                guard let matchArticle = try? db.article(byID: match.articleID) else { continue }
                let feedName = feedsLookup[matchArticle.feedID]?.title ?? ""
                let sentiment = try? db.sentimentScore(for: match.articleID)
                items.append(SimilarArticleItem(
                    id: match.articleID,
                    article: matchArticle,
                    feedName: feedName,
                    sentiment: sentiment
                ))
            }
            return items
        }.value
    }

    @ViewBuilder
    private func sentimentDot(_ sentiment: Double?) -> some View {
        Circle()
            .fill(sentimentColor(sentiment))
            .frame(width: 8, height: 8)
    }

    private func sentimentColor(_ sentiment: Double?) -> Color {
        guard let sentiment else { return .gray }
        if sentiment > 0.2 { return .green }
        if sentiment < -0.2 { return .red }
        return .gray
    }
}
