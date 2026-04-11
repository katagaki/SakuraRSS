import SwiftUI

// MARK: - Feed Navigation Environment

private struct FeedNavigationActionKey: EnvironmentKey {
    static let defaultValue: ((Feed) -> Void)? = nil
}

extension EnvironmentValues {
    var navigateToFeed: ((Feed) -> Void)? {
        get { self[FeedNavigationActionKey.self] }
        set { self[FeedNavigationActionKey.self] = newValue }
    }
}

struct FeedStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    @State private var youTubeArticle: Article?

    var body: some View {
        List {
            ForEach(articles) { article in
                ZStack {
                    ArticleLink(article: article, onShowYouTubePlayer: {
                        youTubeArticle = $0
                    }, label: {
                        EmptyView()
                    })
                    .opacity(0)

                    FeedArticleRow(article: article, onShowYouTubePlayer: {
                        youTubeArticle = article
                    })
                        .zoomSource(id: article.id, namespace: zoomNamespace)
                }
                .padding(.horizontal, 12)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                .listRowSeparator(.hidden, edges: .top)
                .listRowSeparator(.visible, edges: .bottom)
                .alignmentGuide(.listRowSeparatorLeading) { _ in
                    return 0
                }
                .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
                    return dimensions.width
                }
            }
            if let onLoadMore {
                LoadPreviousArticlesButton(action: onLoadMore)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationDestination(item: $youTubeArticle) { article in
            YouTubePlayerView(article: article)
                .zoomTransition(sourceID: article.id, in: zoomNamespace)
        }
    }
}

struct FeedArticleRow: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    @Environment(\.navigateToFeed) var navigateToFeed
    let article: Article
    var onShowYouTubePlayer: (() -> Void)?
    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @State private var favicon: UIImage?
    @State private var feedName: String?
    @State private var acronymIcon: UIImage?
    @State private var skipFaviconInset = false
    @State private var preferTitle = false
    @State private var feed: Feed?
    @State private var showSafari = false
    @State private var imageAspectRatio: CGFloat?
    @State private var hideImage = false

    private var imageHeight: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 200
        }
        guard let imageAspectRatio else { return 180 }
        let estimatedWidth = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.width ?? 375) - 86
        let naturalHeight = estimatedWidth * imageAspectRatio
        return min(max(naturalHeight, 180), 420)
    }

    @ViewBuilder
    private var feedAvatarView: some View {
        if let favicon = favicon {
            FaviconImage(favicon, size: 40, circle: true, skipInset: skipFaviconInset)
        } else if let acronymIcon {
            FaviconImage(acronymIcon, size: 40, circle: true, skipInset: true)
        } else if let feedName {
            InitialsAvatarView(feedName, size: 40, circle: true)
        } else {
            Circle()
                .fill(.secondary.opacity(0.2))
                .frame(width: 40, height: 40)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let feed, let navigateToFeed {
                Button { navigateToFeed(feed) } label: { feedAvatarView }
                    .buttonStyle(.plain)
            } else {
                feedAvatarView
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    if let feed, let feedName, let navigateToFeed {
                        Button { navigateToFeed(feed) } label: {
                            Text(feedName)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    } else if let feedName {
                        Text(feedName)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    if let date = article.publishedDate {
                        Text("·")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        RelativeTimeText(date: date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !article.isRead {
                        UnreadDotView(isRead: article.isRead)
                    }
                }

                Group {
                    if !preferTitle, article.hasMeaningfulSummary, let summary = article.summary {
                        Text(ContentBlock.stripMarkdown(summary)
                            .trimmingCharacters(in: .whitespacesAndNewlines))
                    } else {
                        Text(article.title
                            .trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(feed?.isXFeed == true || feed?.isInstagramFeed == true ? nil : 3)
                .truncationMode(.tail)

                if article.carouselImageURLs.count > 1 {
                    // Multiple images — horizontal scroll at fixed height
                    let urls = article.carouselImageURLs.compactMap { URL(string: $0) }
                    if !urls.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(urls.enumerated()), id: \.offset) { _, url in
                                    CarouselImageView(url: url, height: 300)
                                }
                            }
                        }
                        .scrollClipDisabled()
                        .contentMargins(.horizontal, 0)
                        .padding(.top, 4)
                    }
                } else if !hideImage, let imageURL = article.imageURL, let url = URL(string: imageURL) {
                    let shouldCenter = feed.map { CenteredImageDomains.shouldCenterImage(feedDomain: $0.domain) } ?? false
                    CachedAsyncImage(url: url, alignment: shouldCenter ? .center : (imageAspectRatio ?? 0 > 1 ? .leading : .top),
                                     onImageLoaded: { image in
                        imageAspectRatio = image.size.height / image.size.width
                        let pixelWidth = image.size.width * image.scale
                        let pixelHeight = image.size.height * image.scale
                        if pixelWidth <= 100 && pixelHeight <= 100 {
                            hideImage = true
                        }
                    }, placeholder: {
                        Color.secondary.opacity(0.1)
                            .frame(height: imageHeight)
                    })
                    .frame(maxWidth: imageAspectRatio ?? 0 > 1 ? nil : .infinity)
                    .frame(height: imageHeight)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.quaternary, lineWidth: 0.5)
                    }
                    .overlay {
                        if feed?.isVideoFeed == true || feed?.isPodcast == true {
                            Image(systemName: "play.fill")
                                .font(.title)
                                .foregroundStyle(.primary)
                                .padding(16)
                                .background(.ultraThinMaterial, in: .circle)
                                .glassEffect(.regular.interactive(), in: .circle)
                        }
                    }
                    .padding(.top, 4)
                }

                HStack {
                    Button {
                        if article.isYouTubeURL && youTubeOpenMode == .inAppPlayer {
                            onShowYouTubePlayer?()
                        } else if article.isYouTubeURL && youTubeOpenMode == .youTubeApp {
                            YouTubeHelper.openInApp(url: article.url)
                        } else if article.isYouTubeURL && youTubeOpenMode == .browser {
                            showSafari = true
                        } else if let url = URL(string: article.url) {
                            openURL(url)
                        }
                    } label: {
                        Image(
                            systemName: (
                                article.isYouTubeURL && YouTubeHelper.isAppInstalled ? "play.rectangle" : "safari"
                            )
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        UIPasteboard.general.string = article.url
                    } label: {
                        Image(systemName: "square.on.square")
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        feedManager.toggleRead(article)
                    } label: {
                        Image(
                            systemName: article.isRead
                                ? "envelope" : "envelope.open"
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        feedManager.toggleBookmark(article)
                    } label: {
                        Image(systemName: article.isBookmarked ? "bookmark.fill" : "bookmark")
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if let shareURL = URL(string: article.url) {
                        ShareLink(item: shareURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            }
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
                preferTitle = TitleOnlyDomains.shouldPreferTitle(feedDomain: loadedFeed.domain)
                favicon = await FaviconCache.shared.favicon(for: loadedFeed)
            }
        }
        .sheet(isPresented: $showSafari) {
            if let url = URL(string: article.url) {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Carousel Image

/// Loads and displays an image fitted to a fixed height, letting
/// its natural aspect ratio determine the width.
private struct CarouselImageView: View {

    let url: URL
    let height: CGFloat
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: height)
            } else {
                Color.secondary.opacity(0.1)
                    .frame(width: 200, height: height)
            }
        }
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 0.5)
        }
        .task {
            image = await CachedAsyncImage<EmptyView>.loadImage(from: url)
        }
    }
}
