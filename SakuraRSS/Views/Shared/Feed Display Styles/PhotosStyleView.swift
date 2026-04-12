import SwiftUI

struct PhotosStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    @State private var youTubeArticle: Article?

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(articles) { article in
                    PhotosArticleCard(article: article, youTubeArticle: $youTubeArticle)
                        .zoomSource(id: article.id, namespace: zoomNamespace)
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
    @Binding var youTubeArticle: Article?
    @State private var favicon: UIImage?
    @State private var feedName: String?
    @State private var acronymIcon: UIImage?
    @State private var skipFaviconInset = false
    @State private var photoImage: UIImage?
    @State private var imageAspectRatio: CGFloat?
    @State private var feed: Feed?
    @State private var currentPage: Int = 0
    @State private var hideImage = false

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
                        #if DEBUG
                        print("[PhotosCard] Menu: toggle read for article \(article.id)")
                        #endif
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
                        .tint(.primary)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(.rect)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Edge-to-edge photo or carousel
            if article.carouselImageURLs.count > 1 {
                let urls = article.carouselImageURLs.compactMap { URL(string: $0) }
                if !urls.isEmpty {
                    let effectiveRatio = max(imageAspectRatio ?? 4.0/5.0, 4.0/5.0)
                    TabView(selection: $currentPage) {
                        ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                            CachedAsyncImage(url: url) {
                                Rectangle()
                                    .fill(.secondary.opacity(0.1))
                            }
                            .allowsHitTesting(false)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .aspectRatio(effectiveRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        PageDotsView(count: urls.count, current: currentPage)
                            .padding(.bottom, 8)
                    }
                    .task {
                        let loaded = await CachedAsyncImage<EmptyView>.loadImage(from: urls[0])
                        photoImage = loaded
                        if let loaded, loaded.size.height > 0 {
                            imageAspectRatio = loaded.size.width / loaded.size.height
                        }
                    }
                    .padding(.bottom, 10)
                }
            } else if !hideImage, let imageURL = article.imageURL, let url = URL(string: imageURL) {
                let effectiveRatio = max(imageAspectRatio ?? 4.0/5.0, 4.0/5.0)
                CachedAsyncImage(url: url) {
                    Rectangle()
                        .fill(.secondary.opacity(0.1))
                        .aspectRatio(4.0/5.0, contentMode: .fit)
                }
                .aspectRatio(effectiveRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()
                .allowsHitTesting(false)
                .overlay {
                    if article.url.contains("/reel/") {
                        ArticleLink(article: article, onShowYouTubePlayer: {
                            youTubeArticle = $0
                        }, label: {
                            Image(systemName: "play.fill")
                                .font(.title)
                                .foregroundStyle(.primary)
                                .padding(16)
                                .background(.ultraThinMaterial, in: .circle)
                                .glassEffect(.regular.interactive(), in: .circle)
                        })
                        .buttonStyle(.plain)
                    }
                }
                .task {
                    let loaded = await CachedAsyncImage<EmptyView>.loadImage(from: url)
                    photoImage = loaded
                    if let loaded, loaded.size.height > 0 {
                        imageAspectRatio = loaded.size.width / loaded.size.height
                        let pixelWidth = loaded.size.width * loaded.scale
                        let pixelHeight = loaded.size.height * loaded.scale
                        if pixelWidth <= 100 && pixelHeight <= 100 {
                            hideImage = true
                        }
                    }
                }
                .padding(.bottom, 10)
            }

            // Article caption / title (tapping opens the article)
            ArticleLink(article: article, onShowYouTubePlayer: {
                youTubeArticle = $0
            }, label: {
                let isPhotoFeed = feed?.isInstagramFeed == true || feed?.isPhotoViewDomain == true
                let captionText = isPhotoFeed ? (article.summary ?? article.title) : article.title
                Text(captionText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(isPhotoFeed ? nil : 3)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            })
            .buttonStyle(.plain)

            if let date = article.publishedDate {
                RelativeTimeText(date: date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }

            // Action buttons below photo
            HStack(spacing: 16) {
                Button {
                    #if DEBUG
                    print("[PhotosCard] Copy tapped for article \(article.id), photoImage=\(photoImage != nil)")
                    #endif
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if let photoImage {
                        UIPasteboard.general.image = photoImage
                    }
                } label: {
                    Label("Article.CopyPhoto",
                          systemImage: "square.on.square")
                }

                ShareLink(item: URL(string: article.url) ?? URL(string: "https://")!) {
                    Label("Article.Share",
                          systemImage: "square.and.arrow.up")
                }
                .padding(.bottom, 1)
                .disabled(URL(string: article.url) == nil)

                Spacer()

                Button {
                    #if DEBUG
                    print("[PhotosCard] Bookmark tapped for article \(article.id)")
                    #endif
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
                    || FaviconNoInsetDomains.shouldUseFullImage(feedDomain: loadedFeed.domain)
                favicon = await FaviconCache.shared.favicon(for: loadedFeed)
            }
        }
    }
}

// MARK: - Page Dots

private struct PageDotsView: View {

    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.white : Color.white.opacity(0.5))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.3), in: .capsule)
        .animation(.easeInOut(duration: 0.2), value: current)
    }
}
