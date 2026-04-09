import SwiftUI

struct SimilarArticleItem: Identifiable {
    let id: Int64
    let article: Article
    let feedName: String
    let sentiment: Double?
    let favicon: UIImage?
}

extension ArticleDetailView {

    @ViewBuilder
    var insightsSection: some View {
        if hasAnyInsights {
            VStack(alignment: .leading, spacing: 20) {
                Label("Insights.Title", systemImage: "sparkles")
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                if similarContentEnabled && !similarArticles.isEmpty {
                    similarContentSubsection
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private var hasAnyInsights: Bool {
        similarContentEnabled && !similarArticles.isEmpty
    }

    @ViewBuilder
    private var similarContentSubsection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("SimilarContent.Title", systemImage: "square.stack.3d.up")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(similarArticles) { item in
                        NavigationLink(value: item.article) {
                            SimilarArticleCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    func loadSimilarArticles() async -> [SimilarArticleItem] {
        let db = DatabaseManager.shared
        let feedsLookup = feedManager.feedsByID
        let currentArticle = article

        let rawMatches: [SimilarMatchData] = await Task.detached(priority: .utility) {
            guard let candidates = try? db.articlesInWindow(
                around: currentArticle, hours: 48, limit: 200
            ) else {
                return []
            }

            let similar = NLPProcessor.findSimilarArticles(
                to: currentArticle,
                candidates: candidates,
                maxResults: 8,
                maximumDistance: 1.5
            )

            var results: [SimilarMatchData] = []
            for match in similar {
                guard let matchArticle = try? db.article(byID: match.articleID) else { continue }
                let feed = feedsLookup[matchArticle.feedID]
                let sentiment = try? db.sentimentScore(for: match.articleID)
                results.append(SimilarMatchData(
                    article: matchArticle,
                    feedName: feed?.title ?? "",
                    feed: feed,
                    sentiment: sentiment
                ))
            }
            return results
        }.value

        // Favicons must be fetched on the main actor path (FaviconCache uses
        // main-actor state), so resolve them after the detached similarity work.
        var items: [SimilarArticleItem] = []
        for match in rawMatches {
            let favicon: UIImage?
            if let feed = match.feed {
                favicon = await FaviconCache.shared.favicon(for: feed)
            } else {
                favicon = nil
            }
            items.append(SimilarArticleItem(
                id: match.article.id,
                article: match.article,
                feedName: match.feedName,
                sentiment: match.sentiment,
                favicon: favicon
            ))
        }
        return items
    }
}

// Intermediate type so the detached task can return a single value type
// without tripping the large-tuple lint rule.
private struct SimilarMatchData: Sendable {
    let article: Article
    let feedName: String
    let feed: Feed?
    let sentiment: Double?
}

// MARK: - Card

private struct SimilarArticleCard: View {

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.zoomNamespace) private var zoomNamespace
    let item: SimilarArticleItem

    private let cardWidth: CGFloat = 240
    private let imageHeight: CGFloat = 135  // 16:9 widescreen

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardVisual
                .frame(width: cardWidth, height: imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                .zoomSource(id: item.article.id, namespace: zoomNamespace)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.article.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Text(item.feedName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: cardWidth, alignment: .leading)
        }
    }

    @ViewBuilder
    private var cardVisual: some View {
        if let imageURL = item.article.imageURL, let url = URL(string: imageURL) {
            CachedAsyncImage(url: url, alignment: .top) {
                thumbnailBackground
            }
        } else {
            thumbnailBackground
        }
    }

    @ViewBuilder
    private var thumbnailBackground: some View {
        let isDark = colorScheme == .dark
        let bgColor = item.favicon?.cardBackgroundColor(isDarkMode: isDark)
            ?? (isDark ? Color(white: 0.15) : Color(white: 0.9))

        ZStack {
            Rectangle()
                .fill(bgColor)

            if let favicon = item.favicon {
                Image(uiImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageHeight * 0.5, height: imageHeight * 0.5)
            } else {
                Image(systemName: "doc.text")
                    .font(.system(size: imageHeight * 0.35, weight: .light))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
