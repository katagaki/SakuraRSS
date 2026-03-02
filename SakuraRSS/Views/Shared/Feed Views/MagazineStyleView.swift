import SwiftUI

struct MagazineStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(articles) { article in
                    NavigationLink {
                        ArticleDetailView(article: article)
                    } label: {
                        MagazineArticleCard(article: article)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical)
        }
    }
}

struct MagazineArticleCard: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var favicon: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                Color.clear
                    .frame(height: 120)
                    .overlay {
                        CachedAsyncImage(url: url) {
                            Rectangle()
                                .fill(.secondary.opacity(0.1))
                        }
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(article.isRead ? .clear : .blue)
                    .frame(width: 6, height: 6)

                if let favicon = favicon {
                    FaviconImage(favicon, size: 14, cornerRadius: 2)
                }

                Spacer()
            }

            Text(article.title)
                .font(.subheadline)
                .fontWeight(article.isRead ? .regular : .semibold)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .foregroundStyle(article.isRead ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let date = article.publishedDate {
                Text(date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(.background)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .task {
            if let feed = feedManager.feed(forArticle: article) {
                favicon = await FaviconCache.shared.favicon(for: feed.domain)
            }
        }
    }
}
