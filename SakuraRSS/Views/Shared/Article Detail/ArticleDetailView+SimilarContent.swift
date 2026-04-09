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
    var similarContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("SimilarContent.Title", systemImage: "brain.head.profile")
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
        .padding(.top, 8)
        .padding(.bottom, 16)
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
    let item: SimilarArticleItem

    private let cardWidth: CGFloat = 160
    private let cardHeight: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardVisual
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.article.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    sentimentDot
                    Text(item.feedName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: cardWidth, alignment: .leading)
        }
    }

    @ViewBuilder
    private var cardVisual: some View {
        if let imageURL = item.article.imageURL, let url = URL(string: imageURL) {
            CachedAsyncImage(url: url) {
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
                    .frame(width: cardWidth * 0.45, height: cardWidth * 0.45)
            } else {
                Image(systemName: "doc.text")
                    .font(.system(size: cardWidth * 0.3, weight: .light))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var sentimentDot: some View {
        Circle()
            .fill(sentimentColor)
            .frame(width: 6, height: 6)
    }

    private var sentimentColor: Color {
        guard let sentiment = item.sentiment else { return .gray }
        if sentiment > 0.2 { return .green }
        if sentiment < -0.2 { return .red }
        return .gray
    }
}
