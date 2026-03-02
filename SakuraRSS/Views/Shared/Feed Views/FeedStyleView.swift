import SwiftUI

struct FeedStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]

    var body: some View {
        List(articles) { article in
            if article.isYouTubeURL {
                Button {
                    feedManager.markRead(article)
                    YouTubeHelper.openInApp(url: article.url)
                } label: {
                    FeedArticleRow(article: article)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                .listRowSeparator(.visible)
            } else {
                ZStack {
                    NavigationLink {
                        ArticleDetailView(article: article)
                    } label: {
                        EmptyView()
                    }
                    .opacity(0)

                    FeedArticleRow(article: article)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                .listRowSeparator(.visible)
            }
        }
        .listStyle(.plain)
    }
}

struct FeedArticleRow: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var favicon: UIImage?
    @State private var feedName: String?
    @State private var isYouTube = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let favicon = favicon {
                FaviconImage(favicon, size: 40, circle: true, skipInset: isYouTube)
            } else if let feedName {
                InitialsAvatarView(feedName, size: 40, circle: true)
            } else {
                Circle()
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    if let feedName {
                        Text(feedName)
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    if let date = article.publishedDate {
                        Text("·")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text(date, style: .relative)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !article.isRead {
                        Circle()
                            .fill(.blue)
                            .frame(width: 8, height: 8)
                    }
                }

                if let summary = article.summary {
                    Text(summary)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }

                if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) {
                        Color.secondary.opacity(0.1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 4)
                }
            }
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
