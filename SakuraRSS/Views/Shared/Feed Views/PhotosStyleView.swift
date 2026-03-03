import SwiftUI

struct PhotosStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]
    var onLoadMore: (() -> Void)?

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(articles) { article in
                    ArticleLink(article: article) {
                        PhotosArticleCard(article: article)
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
    @State private var isYouTube = false
    @State private var photoImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile photo and feed name header
            HStack(spacing: 10) {
                if let favicon = favicon {
                    FaviconImage(favicon, size: 32, circle: true, skipInset: isYouTube)
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
            .font(.system(size: 18.0, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

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
                favicon = await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL)
                feedName = feed.title
                isYouTube = feed.isVideoFeed
            }
        }
    }
}
