import SwiftUI

struct PhotosStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) private var openURL
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    @State private var youTubeArticle: Article?

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(articles) { article in
                    let articleFeed = feedManager.feed(forArticle: article)
                    if articleFeed?.isInstagramFeed == true || articleFeed?.isXFeed == true {
                        PhotosArticleCard(article: article, onPhotoTap: {
                            feedManager.markRead(article)
                            if let url = URL(string: article.url) {
                                openURL(url)
                            }
                        })
                        .buttonStyle(.plain)
                        .zoomSource(id: article.id, namespace: zoomNamespace)
                    } else {
                        ArticleLink(article: article, onShowYouTubePlayer: {
                            youTubeArticle = $0
                        }, label: {
                            PhotosArticleCard(article: article)
                                .zoomSource(id: article.id, namespace: zoomNamespace)
                        })
                        .buttonStyle(.plain)
                    }
                }
                if let onLoadMore {
                    LoadPreviousArticlesButton(action: onLoadMore)
                        .padding(.vertical, 20)
                }
            }
        }
        .navigationDestination(item: $youTubeArticle) { article in
            YouTubePlayerView(article: article)
                .zoomTransition(sourceID: article.id, in: zoomNamespace)
        }
    }
}

struct PhotosArticleCard: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    var onPhotoTap: (() -> Void)?
    @State private var favicon: UIImage?
    @State private var feedName: String?
    @State private var acronymIcon: UIImage?
    @State private var skipFaviconInset = false
    @State private var photoImage: UIImage?
    @State private var feed: Feed?

    @ViewBuilder
    private var feedAvatarView: some View {
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
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile photo and feed name header
            HStack(spacing: 10) {
                if let feed {
                    NavigationLink(value: feed) {
                        HStack(spacing: 10) {
                            feedAvatarView
                            if let feedName {
                                Text(feedName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    feedAvatarView
                    if let feedName {
                        Text(feedName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if !article.isRead {
                    UnreadDotView(isRead: article.isRead)
                }

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
                .aspectRatio(4/3, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay {
                    if let onPhotoTap {
                        Button(action: onPhotoTap) {
                            Color.clear.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .task {
                    photoImage = await CachedAsyncImage<EmptyView>.loadImage(from: url)
                }
                .padding(.bottom, 10)
            }

            // Action buttons below photo
            HStack(spacing: 16) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            if let loadedFeed = feedManager.feed(forArticle: article) {
                feed = loadedFeed
                feedName = loadedFeed.title
                if let data = loadedFeed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                skipFaviconInset = loadedFeed.isVideoFeed || loadedFeed.isXFeed || loadedFeed.isInstagramFeed
                    || FullFaviconDomains.shouldUseFullImage(feedDomain: loadedFeed.domain)
                favicon = await FaviconCache.shared.favicon(for: loadedFeed)
            }
        }
    }
}
