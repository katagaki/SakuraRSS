import SwiftUI

struct FeedArticleRow: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    @Environment(\.navigateToFeed) var navigateToFeed
    let article: Article
    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @State private var icon: UIImage?
    @State private var feedName: String?
    @State private var acronymIcon: UIImage?
    @State private var skipIconInset = false
    @State private var feed: Feed?
    @State private var showSafari = false
    @State private var imageAspectRatio: CGFloat?
    @State private var loadedImage: UIImage?

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
        if let icon = icon {
            IconImage(icon, size: 40, circle: true, skipInset: skipIconInset)
        } else if let acronymIcon {
            IconImage(acronymIcon, size: 40, circle: true, skipInset: true)
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

                    if !feedManager.isRead(article) {
                        UnreadDotView(isRead: feedManager.isRead(article))
                    }
                }

                Group {
                    if article.hasMeaningfulSummary, let summary = article.summary {
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
                } else if let loadedImage {
                    let shouldCenter = feed.map {
                        CenteredImageDomains.shouldCenterImage(feedDomain: $0.domain)
                    } ?? false
                    Color.clear
                        .frame(maxWidth: imageAspectRatio ?? 0 > 1 ? nil : .infinity)
                        .frame(height: imageHeight)
                        .overlay(alignment: shouldCenter ? .center : (imageAspectRatio ?? 0 > 1 ? .leading : .top)) {
                            Image(uiImage: loadedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .debugLayout()
                        }
                        .clipped()
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
                        .transition(.opacity)
                }

                HStack {
                    Button {
                        if article.isYouTubeURL && youTubeOpenMode == .inAppPlayer {
                            feedManager.markRead(article)
                            MediaPresenter.shared.presentYouTube(article)
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
                            systemName: feedManager.isRead(article)
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
                skipIconInset = loadedFeed.isVideoFeed || loadedFeed.isXFeed || loadedFeed.isInstagramFeed
                icon = await IconCache.shared.icon(for: loadedFeed)
            }
        }
        .task(id: article.imageURL) {
            guard let imageURL = article.imageURL, let url = URL(string: imageURL) else {
                loadedImage = nil
                imageAspectRatio = nil
                return
            }
            let image = await CachedAsyncImage<EmptyView>.loadImage(from: url)
            guard !Task.isCancelled, let image else { return }
            let pixelWidth = image.size.width * image.scale
            let pixelHeight = image.size.height * image.scale
            guard pixelWidth > 100 || pixelHeight > 100 else { return }
            let aspect = image.size.height / image.size.width
            imageAspectRatio = aspect
            loadedImage = image
        }
        .sheet(isPresented: $showSafari) {
            if let url = URL(string: article.url) {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}
