import SwiftUI

struct PhotosStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(articles) { article in
                    ArticleLink(article: article) {
                        PhotosArticleCard(article: article)
                            .zoomSource(id: article.id, namespace: zoomNamespace)
                    }
                    .buttonStyle(.plain)
                }
                if let onLoadMore {
                    LoadPreviousArticlesButton(action: onLoadMore)
                        .padding(.vertical, 20)
                }
            }
        }
    }
}

struct PhotosArticleCard: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    @State private var favicon: UIImage?
    @State private var feedName: String?
    @State private var acronymIcon: UIImage?
    @State private var skipFaviconInset = false
    @State private var photoImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile photo and feed name header
            HStack(spacing: 10) {
                if let favicon = favicon {
                    FaviconImage(favicon, size: 32, circle: true, skipInset: skipFaviconInset)
                } else if let acronymIcon {
                    FaviconImage(acronymIcon, size: 32, circle: true, skipInset: true)
                } else if let feedName {
                    InitialsAvatarView(feedName, size: 32, circle: true)
                } else {
                    Circle()
                        .fill(.secondary.opacity(0.2))
                        .frame(width: 32, height: 32)
                }

                if let feedName {
                    Text(feedName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer()

                Menu {
                    Button {
                        feedManager.toggleRead(article)
                    } label: {
                        Label(
                            article.isRead
                                ? String(localized: "Article.MarkUnread")
                                : String(localized: "Article.MarkRead"),
                            systemImage: article.isRead
                                ? "envelope" : "envelope.open"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(.rect)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Edge-to-edge photo
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) {
                    Rectangle()
                        .fill(.secondary.opacity(0.1))
                        .aspectRatio(1, contentMode: .fit)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(contentMode: .fit)
                .task {
                    photoImage = await CachedAsyncImage<EmptyView>.loadImage(from: url)
                }
                .padding(.bottom, 10)
            }

            // Action buttons below photo
            HStack(spacing: 16) {
                Button {
                    if let photoImage {
                        UIPasteboard.general.image = photoImage
                    }
                } label: {
                    Label(String(localized: "Article.CopyPhoto"),
                          systemImage: "square.on.square")
                }
                .disabled(photoImage == nil)

                if let shareURL = URL(string: article.url) {
                    ShareLink(item: shareURL) {
                        Label(String(localized: "Article.Share"),
                              systemImage: "square.and.arrow.up")
                    }
                    .padding(.bottom, 1)
                }

                Spacer()

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
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            // Article title below photo
            Text(article.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            if let date = article.publishedDate {
                RelativeTimeText(date: date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }

            Divider()
                .padding(.top, 4)
        }
        .task {
            if let feed = feedManager.feed(forArticle: article) {
                feedName = feed.title
                if let data = feed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                skipFaviconInset = feed.isVideoFeed || feed.isXFeed
                    || FullFaviconDomains.shouldUseFullImage(feedDomain: feed.domain)
                favicon = await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL)
            }
        }
    }
}
