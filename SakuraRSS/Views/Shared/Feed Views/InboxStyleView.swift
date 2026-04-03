import SwiftUI

struct InboxStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?

    var body: some View {
        List {
            ForEach(articles) { article in
                ArticleLink(article: article) {
                    InboxArticleRow(article: article)
                        .zoomSource(id: article.id, namespace: zoomNamespace)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        withAnimation(.smooth.speed(2.0)) {
                            feedManager.toggleRead(article)
                        }
                    } label: {
                        Image(systemName: article.isRead ? "envelope" : "envelope.open")
                    }
                    .tint(.blue)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden, edges: .top)
                .listRowSeparator(.visible, edges: .bottom)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }
            if let onLoadMore {
                LoadPreviousArticlesButton(action: onLoadMore)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationLinkIndicatorVisibility(.hidden)
    }
}

struct InboxArticleRow: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var favicon: UIImage?
    @State private var acronymIcon: UIImage?
    @State private var feedName: String?
    @State private var isSocialFeed = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            UnreadDotView(isRead: article.isRead)
                .padding(.leading, -4)
                .padding(.top, 6)

            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) {
                    Color.secondary.opacity(0.1)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let favicon {
                FaviconImage(favicon, size: 48, cornerRadius: 8)
            } else if let acronymIcon {
                FaviconImage(acronymIcon, size: 48, cornerRadius: 8, skipInset: true)
            } else if let feedName {
                InitialsAvatarView(feedName, size: 48, cornerRadius: 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                if isSocialFeed, let feedName {
                    Text(feedName)
                        .font(.body)
                        .fontWeight(article.isRead ? .regular : .semibold)
                        .lineLimit(1)
                        .foregroundStyle(article.isRead ? .secondary : .primary)

                    Text(article.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text(article.title)
                        .font(.body)
                        .fontWeight(article.isRead ? .regular : .semibold)
                        .lineLimit(1)
                        .foregroundStyle(article.isRead ? .secondary : .primary)

                    if article.hasMeaningfulSummary, let summary = article.summary {
                        Text(ContentBlock.stripMarkdown(summary))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                HStack(spacing: 8) {
                    if !isSocialFeed, let author = article.author {
                        Text(author)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if let date = article.publishedDate {
                        RelativeTimeText(date: date)
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
                isSocialFeed = feed.isSocialFeed
                if let data = feed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                favicon = await FaviconCache.shared.favicon(for: feed)
            }
        }
    }
}
