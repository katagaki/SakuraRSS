import SwiftUI

struct InboxStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]

    var body: some View {
        List(articles) { article in
            if article.isYouTubeURL {
                Button {
                    feedManager.markRead(article)
                    YouTubeHelper.openInApp(url: article.url)
                } label: {
                    InboxArticleRow(article: article)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 16))
            } else {
                NavigationLink {
                    ArticleDetailView(article: article)
                } label: {
                    InboxArticleRow(article: article)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
    }
}

struct InboxArticleRow: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var favicon: UIImage?
    @State private var feedName: String?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(article.isRead ? .clear : .blue)
                .frame(width: 8, height: 8)
                .padding(.leading, -4)
                .padding(.top, 6)

            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) {
                    Color.secondary.opacity(0.1)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.body)
                    .fontWeight(article.isRead ? .regular : .semibold)
                    .lineLimit(1)
                    .foregroundStyle(article.isRead ? .secondary : .primary)

                if let summary = article.summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let author = article.author {
                        Text(author)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if let date = article.publishedDate {
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            if let feed = feedManager.feed(forArticle: article) {
                feedName = feed.title
                favicon = await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL)
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                feedManager.toggleRead(article)
            } label: {
                Image(systemName: article.isRead ? "envelope.badge" : "checkmark.circle")
            }
            .tint(.blue)
        }
    }
}
