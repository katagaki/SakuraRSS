import SwiftUI

struct ScrollArticlePage: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.zoomNamespace) private var zoomNamespace
    @Environment(\.navigateToFeed) private var navigateToFeed
    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer

    let article: Article
    let pageSize: CGSize
    let contextInsets: EdgeInsets
    let isExpanded: Bool
    let onTapContent: () -> Void
    let onAdvance: () -> Void

    @State private var feed: Feed?
    @State private var icon: UIImage?
    @State private var acronymIcon: UIImage?
    @State private var feedName: String?
    @State private var isVideoFeed = false
    @State private var isSocialFeed = false
    @State private var backgroundImage: UIImage?
    @State private var showSafari = false

    @Namespace private var headerNamespace

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundLayer
                .frame(width: pageSize.width, height: pageSize.height)
                .clipped()

            ScrollStyleProgressiveBlurView()
                .frame(width: pageSize.width, height: pageSize.height * (isExpanded ? 1.0 : 0.5))
                .opacity(isExpanded ? 1.0 : 0.6)
                .allowsHitTesting(false)

            if isExpanded {
                Color.black
                    .opacity(0.55)
                    .frame(width: pageSize.width, height: pageSize.height)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            Group {
                if isExpanded {
                    ScrollExpandedArticleView(
                        article: feedManager.article(byID: article.id) ?? article,
                        feedName: feedName,
                        icon: icon,
                        acronymIcon: acronymIcon,
                        isVideoFeed: isVideoFeed,
                        contextInsets: contextInsets,
                        headerNamespace: headerNamespace,
                        onTapToCollapse: onTapContent,
                        onAdvance: onAdvance
                    )
                } else {
                    compactContentLayer
                }
            }
        }
        .zoomSource(id: article.id, namespace: zoomNamespace)
        .sheet(isPresented: $showSafari) {
            if let url = URL(string: article.url) {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .task {
            if let loadedFeed = feedManager.feed(forArticle: article) {
                feed = loadedFeed
                feedName = loadedFeed.title
                isVideoFeed = loadedFeed.isVideoFeed || loadedFeed.isXFeed || loadedFeed.isInstagramFeed
                isSocialFeed = loadedFeed.isSocialFeed
                if let data = loadedFeed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                icon = await IconCache.shared.icon(for: loadedFeed)
            }
        }
        .task(id: article.imageURL) {
            guard let urlString = article.imageURL, let url = URL(string: urlString) else { return }
            let image = await CachedAsyncImage<EmptyView>.loadImage(from: url)
            guard !Task.isCancelled, let image else { return }
            let pixelWidth = image.size.width * image.scale
            let pixelHeight = image.size.height * image.scale
            guard pixelWidth > 100 || pixelHeight > 100 else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                backgroundImage = image
            }
        }
    }

    // MARK: Background

    @ViewBuilder
    private var backgroundLayer: some View {
        ZStack {
            iconBackground
                .feedMatchedGeometry("Icon.\(article.id)")
            if let backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
                    .debugLayout()
                    .feedMatchedGeometry("Thumb.\(article.id)")
            }
        }
    }

    private var iconBackground: some View {
        let isDark = colorScheme == .dark
        let bgColor = icon?.cardBackgroundColor(isDarkMode: isDark)
            ?? (isDark ? Color(white: 0.15) : Color(white: 0.9))
        return ZStack {
            Rectangle()
                .fill(bgColor)
            if let icon {
                let iconImage = Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: isSocialFeed ? .fill : .fit)
                    .frame(width: pageSize.width * 0.5, height: pageSize.width * 0.5)
                Group {
                    if isSocialFeed {
                        iconImage.clipShape(Circle())
                    } else {
                        iconImage
                    }
                }
                .opacity(isDark ? 0.6 : 0.4)
                .offset(y: -pageSize.height * 0.1)
            }
            LinearGradient(
                colors: [bgColor.opacity(0), bgColor],
                startPoint: .center,
                endPoint: .bottom
            )
        }
    }

    // MARK: Compact overlay

    private var compactContentLayer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            compactTextBlock
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .onTapGesture { onTapContent() }

            ScrollActionButtonsColumn(
                article: article,
                icon: icon,
                acronymIcon: acronymIcon,
                feedName: feedName,
                isVideoFeed: isVideoFeed,
                onOpenFeed: {
                    if let feed, let navigateToFeed {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        navigateToFeed(feed)
                    }
                },
                onOpen: { openArticleURL() },
                onCopy: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    UIPasteboard.general.string = article.url
                },
                onToggleBookmark: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    feedManager.toggleBookmark(article)
                },
                shareURL: URL(string: article.url)
            )
        }
        .padding(.leading, 20)
        .padding(.trailing, 12)
        .padding(.bottom, 16 + contextInsets.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var compactTextBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(article.title)
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.6), radius: 4, y: 1)
                .matchedGeometryEffect(id: "headerTitle", in: headerNamespace)
                .feedMatchedGeometry("Title.\(article.id)")

            if let summary = article.summary, !summary.isEmpty {
                SummaryText(summary: summary)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 1)
                    .feedMatchedGeometry("Subtitle.\(article.id)")
            }
        }
    }

    private func openArticleURL() {
        feedManager.markReadOnScroll(article)
        if article.isYouTubeURL {
            switch youTubeOpenMode {
            case .inAppPlayer, .youTubeApp:
                YouTubeHelper.openInApp(url: article.url)
                return
            case .browser:
                showSafari = true
                return
            }
        }
        if let url = URL(string: article.url) {
            openURL(url)
        }
    }
}
