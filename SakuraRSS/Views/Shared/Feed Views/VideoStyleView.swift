import SwiftUI

struct VideoStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 24) {
                ForEach(articles) { article in
                    NavigationLink {
                        ArticleDetailView(article: article)
                    } label: {
                        VideoArticleCard(article: article)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical)
        }
    }
}

struct VideoArticleCard: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var favicon: UIImage?
    @State private var feedName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) {
                    Rectangle()
                        .fill(.secondary.opacity(0.15))
                }
                .aspectRatio(16 / 9, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.secondary.opacity(0.15))
                    .aspectRatio(16 / 9, contentMode: .fill)
            }

            // Channel avatar + title + metadata
            HStack(alignment: .top, spacing: 12) {
                if let favicon = favicon {
                    FaviconImage(favicon, size: 36, circle: true)
                } else {
                    Circle()
                        .fill(.secondary.opacity(0.2))
                        .frame(width: 36, height: 36)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(article.isRead ? .regular : .semibold)
                        .foregroundStyle(article.isRead ? .secondary : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 4) {
                        if let feedName {
                            Text(feedName)
                        }
                        if let date = article.publishedDate {
                            Text("·")
                            Text(date, style: .relative)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
        }
        .task {
            if let feed = feedManager.feed(forArticle: article) {
                favicon = await FaviconCache.shared.favicon(for: feed.domain)
                feedName = feed.title
            }
        }
    }
}
