import SwiftUI

struct FeedStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]

    var body: some View {
        List(articles) { article in
            NavigationLink {
                ArticleDetailView(article: article)
            } label: {
                FeedArticleRow(article: article)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        }
        .listStyle(.plain)
    }
}

struct FeedArticleRow: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var favicon: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                Circle()
                    .fill(article.isRead ? .clear : .blue)
                    .frame(width: 8, height: 8)
                    .padding(.leading, -4)
                    .padding(.top, 6)

                if let favicon = favicon {
                    FaviconImage(favicon, size: 20, cornerRadius: 3)
                        .padding(.top, 2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(article.isRead ? .regular : .semibold)
                        .lineLimit(2)
                        .foregroundStyle(article.isRead ? .secondary : .primary)

                    if let summary = article.summary {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if let date = article.publishedDate {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) {
                    Color.secondary.opacity(0.1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .task {
            if let feed = feedManager.feed(forArticle: article) {
                favicon = await FaviconCache.shared.favicon(for: feed.domain)
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                feedManager.toggleBookmark(article)
            } label: {
                Image(systemName: article.isBookmarked ? "bookmark.slash" : "bookmark")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            Button {
                feedManager.markRead(article)
            } label: {
                Image(systemName: "checkmark.circle")
            }
            .tint(.blue)
        }
    }
}
