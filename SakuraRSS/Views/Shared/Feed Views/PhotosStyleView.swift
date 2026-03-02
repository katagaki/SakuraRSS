import SwiftUI

struct PhotosStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(articles) { article in
                    if article.isYouTubeURL {
                        Button {
                            feedManager.markRead(article)
                            YouTubeHelper.openInApp(url: article.url)
                        } label: {
                            PhotosArticleCard(article: article)
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink {
                            ArticleDetailView(article: article)
                        } label: {
                            PhotosArticleCard(article: article)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct PhotosArticleCard: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var favicon: UIImage?
    @State private var feedName: String?
    @State private var isYouTube = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile photo and feed name header
            HStack(spacing: 10) {
                if let favicon = favicon {
                    FaviconImage(favicon, size: 32, circle: true, skipInset: isYouTube)
                } else {
                    Circle()
                        .fill(.secondary.opacity(0.2))
                        .frame(width: 32, height: 32)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let feedName {
                        Text(feedName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    if let date = article.publishedDate {
                        Text(date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Edge-to-edge photo
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) {
                    Rectangle()
                        .fill(.secondary.opacity(0.1))
                        .aspectRatio(1, contentMode: .fit)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(contentMode: .fit)
            }

            // Article title below photo
            Text(article.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()
                .padding(.top, 4)
        }
        .task {
            if let feed = feedManager.feed(forArticle: article) {
                favicon = await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL)
                feedName = feed.title
                isYouTube = feed.isYouTube
            }
        }
    }
}
