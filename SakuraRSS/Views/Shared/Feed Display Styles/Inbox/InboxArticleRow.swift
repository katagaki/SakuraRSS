import SwiftUI

struct InboxArticleRow: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.colorScheme) private var colorScheme
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
            } else {
                feedIconFallback
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

    @ViewBuilder
    private var feedIconFallback: some View {
        let isDark = colorScheme == .dark
        let bgColor = favicon?.cardBackgroundColor(isDarkMode: isDark)
            ?? (isDark ? Color(white: 0.15) : Color(white: 0.9))
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(bgColor)
            if let favicon {
                Image(uiImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
            } else if let acronymIcon {
                Image(uiImage: acronymIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
            } else if let feedName {
                Text(feedName.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 48, height: 48)
    }
}
