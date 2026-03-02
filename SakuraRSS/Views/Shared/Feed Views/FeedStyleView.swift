import SwiftUI

struct FeedStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]

    var body: some View {
        List(articles) { article in
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
        .listStyle(.plain)
    }
}

struct FeedArticleRow: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var favicon: UIImage?
    @State private var feedName: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let favicon = favicon {
                FaviconImage(favicon, size: 32, circle: true)
            } else {
                Circle()
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    if let feedName {
                        Text(feedName)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    if !article.isRead {
                        Circle()
                            .fill(.blue)
                            .frame(width: 6, height: 6)
                    }

                    Spacer()

                    if let date = article.publishedDate {
                        Text(date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(article.isRead ? .regular : .semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                if let summary = article.summary {
                    Text(summary)
                        .font(.subheadline)
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
                favicon = await FaviconCache.shared.favicon(for: feed.domain)
                feedName = feed.title
            }
        }


    }
}
