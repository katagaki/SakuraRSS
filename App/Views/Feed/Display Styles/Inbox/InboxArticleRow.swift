import SwiftUI

struct InboxArticleRow: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var icon: UIImage?
    @State private var acronymIcon: UIImage?
    @State private var feedName: String?
    @State private var isSocialFeed = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            UnreadDotView(isRead: feedManager.isRead(article))
                .padding(.leading, -4)
                .padding(.top, 6)

            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) {
                    FeedIconPlaceholder(
                        icon: icon,
                        acronymIcon: acronymIcon,
                        feedName: feedName,
                        isSocialFeed: isSocialFeed,
                        iconSize: 30,
                        cornerRadius: 8
                    )
                }
                .frame(width: 48, height: 48)
                .clipShape(.rect(cornerRadius: 8))
            } else {
                FeedIconPlaceholder(
                    icon: icon,
                    acronymIcon: acronymIcon,
                    feedName: feedName,
                    isSocialFeed: isSocialFeed,
                    iconSize: 30,
                    cornerRadius: 8
                )
                .frame(width: 48, height: 48)
            }

            VStack(alignment: .leading, spacing: 4) {
                if isSocialFeed, let feedName {
                    Text(feedName)
                        .font(.body)
                        .fontWeight(feedManager.isRead(article) ? .regular : .semibold)
                        .lineLimit(1)
                        .foregroundStyle(feedManager.isRead(article) ? .secondary : .primary)

                    Text(article.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text(article.title)
                        .font(.body)
                        .fontWeight(feedManager.isRead(article) ? .regular : .semibold)
                        .lineLimit(1)
                        .foregroundStyle(feedManager.isRead(article) ? .secondary : .primary)

                    if article.hasMeaningfulSummary, let summary = article.summary {
                        SummaryText(summary: summary)
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
                icon = await IconCache.shared.icon(for: feed)
            }
        }
    }
}
