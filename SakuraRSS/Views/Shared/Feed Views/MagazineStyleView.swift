import SwiftUI

struct MagazineStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(articles) { article in
                    if article.isYouTubeURL {
                        Button {
                            feedManager.markRead(article)
                            YouTubeHelper.openInApp(url: article.url)
                        } label: {
                            MagazineArticleCard(article: article)
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink {
                            ArticleDetailView(article: article)
                        } label: {
                            MagazineArticleCard(article: article)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom)
        }
    }
}

struct MagazineArticleCard: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var favicon: UIImage?
    @State private var feedName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                    Color.clear
                        .frame(height: 120)
                        .overlay {
                            CachedAsyncImage(url: url) {
                                Rectangle()
                                    .fill(.secondary.opacity(0.15))
                            }
                        }
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.secondary.opacity(0.15))
                        .frame(height: 120)
                }

                if let favicon = favicon {
                    FaviconImage(favicon, size: 20, cornerRadius: 4)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .padding(6)
                } else if let feedName {
                    InitialsAvatarView(feedName, size: 20, cornerRadius: 4)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .padding(6)
                }
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(article.isRead ? .clear : .blue)
                    .frame(width: 6, height: 6)

                Text(article.title)
                    .font(.caption)
                    .fontWeight(article.isRead ? .regular : .semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(article.isRead ? .secondary : .primary)

                Spacer(minLength: 0)
            }

            if let date = article.publishedDate {
                Text(date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(6)
        .background(.background)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .task {
            if let feed = feedManager.feed(forArticle: article) {
                feedName = feed.title
                favicon = await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL)
            }
        }
    }
}
