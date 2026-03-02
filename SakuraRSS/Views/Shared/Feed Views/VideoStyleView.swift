import SwiftUI

struct VideoStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 24) {
                ForEach(articles) { article in
                    Button {
                        feedManager.markRead(article)
                        YouTubeHelper.openInApp(url: article.url)
                    } label: {
                        VideoArticleCard(article: article)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom)
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
                Color.clear
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay {
                        CachedAsyncImage(url: url) {
                            Rectangle()
                                .fill(.secondary.opacity(0.15))
                        }
                    }
                    .clipped()
            } else {
                Rectangle()
                    .fill(.secondary.opacity(0.15))
                    .aspectRatio(16 / 9, contentMode: .fit)
            }

            // Channel avatar + title + metadata
            HStack(alignment: .top, spacing: 12) {
                if let favicon = favicon {
                    FaviconImage(favicon, size: 36, circle: true, skipInset: true)
                } else {
                    Circle()
                        .fill(.secondary.opacity(0.2))
                        .frame(width: 36, height: 36)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.body)
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
            .padding(.horizontal, 16)
        }
        .task {
            if let feed = feedManager.feed(forArticle: article) {
                favicon = await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL)
                feedName = feed.title
            }
        }
    }
}
