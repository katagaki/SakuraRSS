import SwiftUI

struct VideoArticleCard: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.navigateToFeed) var navigateToFeed
    let article: Article
    @State private var icon: UIImage?
    @State private var feedName: String?
    @State private var acronymIcon: UIImage?
    @State private var feed: Feed?

    @ViewBuilder
    private var feedAvatarView: some View {
        if let icon = icon {
            IconImage(icon, size: 36, circle: true, skipInset: true)
        } else if let acronymIcon {
            IconImage(acronymIcon, size: 36, circle: true, skipInset: true)
        } else if let feedName {
            InitialsAvatarView(feedName, size: 36, circle: true)
        } else {
            Circle()
                .fill(.secondary.opacity(0.2))
                .frame(width: 36, height: 36)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
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
            }
            .feedMatchedGeometry("Thumb.\(article.id)")

            HStack(alignment: .top, spacing: 12) {
                Group {
                    if let feed, let navigateToFeed {
                        Button { navigateToFeed(feed) } label: { feedAvatarView }
                            .buttonStyle(.plain)
                    } else {
                        feedAvatarView
                    }
                }
                .feedMatchedGeometry("Icon.\(article.id)")

                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(feedManager.isRead(article) ? .secondary : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .feedMatchedGeometry("Title.\(article.id)")

                    HStack(spacing: 4) {
                        if let feed, let feedName, let navigateToFeed {
                            Button { navigateToFeed(feed) } label: {
                                Text(feedName)
                            }
                            .buttonStyle(.plain)
                        } else if let feedName {
                            Text(feedName)
                        }
                        if let date = article.publishedDate {
                            Text("·")
                            RelativeTimeText(date: date)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 0)

                Menu {
                    Button {
                        feedManager.toggleRead(article)
                    } label: {
                        Label(
                            feedManager.isRead(article)
                                ? String(localized: "Article.MarkUnplayed", table: "Articles")
                                : String(localized: "Article.MarkPlayed", table: "Articles"),
                            systemImage: feedManager.isRead(article) ? "arrow.uturn.backward" : "checkmark"
                        )
                    }
                    Divider()
                    Button {
                        feedManager.toggleBookmark(article)
                    } label: {
                        Label(
                            article.isBookmarked
                                ? String(localized: "Article.RemoveBookmark", table: "Articles")
                                : String(localized: "Article.Bookmark", table: "Articles"),
                            systemImage: article.isBookmarked ? "bookmark.fill" : "bookmark"
                        )
                    }
                    Button {
                        UIPasteboard.general.string = article.url
                    } label: {
                        Label(
                            String(localized: "Article.CopyLink", table: "Articles"),
                            systemImage: "link"
                        )
                    }
                    if let shareURL = URL(string: article.url) {
                        ShareLink(item: shareURL) {
                            Label(
                                String(localized: "Article.Share", table: "Articles"),
                                systemImage: "square.and.arrow.up"
                            )
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 28, height: 28)
                        .contentShape(.rect)
                }
            }
            .padding(.horizontal, 16)
        }
        .task {
            if let loadedFeed = feedManager.feed(forArticle: article) {
                feed = loadedFeed
                feedName = loadedFeed.title
                if let data = loadedFeed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                icon = await IconCache.shared.icon(for: loadedFeed)
            }
        }
    }
}
