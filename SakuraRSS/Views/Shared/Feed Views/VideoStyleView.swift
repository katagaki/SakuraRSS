import SwiftUI

struct VideoStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("Labs.YouTubePlayer") private var youTubePlayerEnabled: Bool = false
    let articles: [Article]
    var onLoadMore: (() -> Void)?

    @State private var youTubePlayerArticle: Article?
    @State private var showYouTubePlayer = false

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 24) {
                ForEach(articles) { article in
                    Button {
                        feedManager.markRead(article)
                        if article.isYouTubeURL && youTubePlayerEnabled {
                            youTubePlayerArticle = article
                            showYouTubePlayer = true
                        } else {
                            YouTubeHelper.openInApp(url: article.url)
                        }
                    } label: {
                        VideoArticleCard(article: article)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            feedManager.toggleRead(article)
                        } label: {
                            Label(
                                article.isRead
                                    ? String(localized: "Article.MarkUnplayed")
                                    : String(localized: "Article.MarkPlayed"),
                                systemImage: article.isRead ? "arrow.uturn.backward" : "checkmark"
                            )
                        }
                        Divider()
                        Button {
                            feedManager.toggleBookmark(article)
                        } label: {
                            Label(
                                article.isBookmarked
                                    ? String(localized: "Article.RemoveBookmark")
                                    : String(localized: "Article.Bookmark"),
                                systemImage: article.isBookmarked ? "bookmark.fill" : "bookmark"
                            )
                        }
                        Button {
                            UIPasteboard.general.string = article.url
                        } label: {
                            Label(String(localized: "Article.CopyLink"), systemImage: "link")
                        }
                        if let shareURL = URL(string: article.url) {
                            ShareLink(item: shareURL) {
                                Label(String(localized: "Article.Share"), systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
            .padding(.bottom)
            if let onLoadMore {
                LoadPreviousArticlesButton(action: onLoadMore)
                    .padding(.horizontal, 16)
                    .padding(.bottom)
            }
        }
        .navigationDestination(isPresented: $showYouTubePlayer) {
            if let article = youTubePlayerArticle {
                YouTubePlayerView(article: article)
            }
        }
    }
}

struct VideoArticleCard: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.navigateToFeed) var navigateToFeed
    let article: Article
    @State private var favicon: UIImage?
    @State private var feedName: String?
    @State private var acronymIcon: UIImage?
    @State private var feed: Feed?

    @ViewBuilder
    private var feedAvatarView: some View {
        if let favicon = favicon {
            FaviconImage(favicon, size: 36, circle: true, skipInset: true)
        } else if let acronymIcon {
            FaviconImage(acronymIcon, size: 36, circle: true, skipInset: true)
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
            // Thumbnail
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

            // Channel avatar + title + metadata
            HStack(alignment: .top, spacing: 12) {
                if let feed, let navigateToFeed {
                    Button { navigateToFeed(feed) } label: { feedAvatarView }
                        .buttonStyle(.plain)
                } else {
                    feedAvatarView
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(article.isRead ? .secondary : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

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
                            article.isRead
                                ? String(localized: "Article.MarkUnplayed")
                                : String(localized: "Article.MarkPlayed"),
                            systemImage: article.isRead ? "arrow.uturn.backward" : "checkmark"
                        )
                    }
                    Divider()
                    Button {
                        feedManager.toggleBookmark(article)
                    } label: {
                        Label(
                            article.isBookmarked
                                ? String(localized: "Article.RemoveBookmark")
                                : String(localized: "Article.Bookmark"),
                            systemImage: article.isBookmarked ? "bookmark.fill" : "bookmark"
                        )
                    }
                    Button {
                        UIPasteboard.general.string = article.url
                    } label: {
                        Label(String(localized: "Article.CopyLink"), systemImage: "link")
                    }
                    if let shareURL = URL(string: article.url) {
                        ShareLink(item: shareURL) {
                            Label(String(localized: "Article.Share"), systemImage: "square.and.arrow.up")
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
                favicon = await FaviconCache.shared.favicon(for: loadedFeed)
            }
        }
    }
}
