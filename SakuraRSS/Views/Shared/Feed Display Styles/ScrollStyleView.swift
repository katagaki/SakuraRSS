import SwiftUI

// MARK: - Scroll Style View

/// A TikTok/Reels-inspired full-screen vertical pager where each article
/// takes up the entire screen. Tapping the image or content preview expands
/// the article to reveal the full extracted text; tapping again collapses it.
/// When expanded, overscrolling past the top or bottom advances to the
/// previous or next article respectively.
struct ScrollStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?

    @State private var currentID: ScrollPageID?
    @State private var expandedArticleID: Int64?
    @State private var youTubeArticle: Article?
    @State private var podcastArticle: Article?

    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer

    var body: some View {
        GeometryReader { geometry in
            let pageSize = geometry.size

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(articles) { article in
                        ScrollArticlePage(
                            article: article,
                            pageSize: pageSize,
                            isExpanded: expandedArticleID == article.id,
                            onTapContent: { handleTap(on: article) },
                            onAdvance: { advance(from: article) },
                            onRetreat: { retreat(from: article) }
                        )
                        .frame(width: pageSize.width, height: pageSize.height)
                        .id(ScrollPageID.article(article.id))
                    }
                    if onLoadMore != nil {
                        ScrollEndOfFeedPage(
                            pageSize: pageSize,
                            onLoadMore: { onLoadMore?() }
                        )
                        .frame(width: pageSize.width, height: pageSize.height)
                        .id(ScrollPageID.endOfFeed)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentID, anchor: .center)
            .scrollDisabled(expandedArticleID != nil)
        }
        .ignoresSafeArea()
        .background(Color.black.ignoresSafeArea())
        .navigationDestination(item: $youTubeArticle) { article in
            YouTubePlayerView(article: article)
                .zoomTransition(sourceID: article.id, in: zoomNamespace)
        }
        .navigationDestination(item: $podcastArticle) { article in
            PodcastEpisodeView(article: article)
                .zoomTransition(sourceID: article.id, in: zoomNamespace)
        }
    }

    private func handleTap(on article: Article) {
        // YouTube videos always open in player (never expand inline)
        if article.isYouTubeURL && youTubeOpenMode == .inAppPlayer {
            feedManager.markRead(article)
            youTubeArticle = article
            return
        }
        // Podcast episodes always open in podcast player (never expand inline)
        if article.isPodcastEpisode {
            feedManager.markRead(article)
            podcastArticle = article
            return
        }
        withAnimation(.smooth.speed(1.5)) {
            if expandedArticleID == article.id {
                expandedArticleID = nil
            } else {
                feedManager.markRead(article)
                expandedArticleID = article.id
            }
        }
    }

    private func advance(from article: Article) {
        guard let idx = articles.firstIndex(where: { $0.id == article.id }) else { return }
        withAnimation(.smooth.speed(1.5)) {
            expandedArticleID = nil
            if idx + 1 < articles.count {
                currentID = .article(articles[idx + 1].id)
            } else if onLoadMore != nil {
                currentID = .endOfFeed
            }
        }
    }

    private func retreat(from article: Article) {
        guard let idx = articles.firstIndex(where: { $0.id == article.id }),
              idx > 0 else { return }
        withAnimation(.smooth.speed(1.5)) {
            expandedArticleID = nil
            currentID = .article(articles[idx - 1].id)
        }
    }
}

// MARK: - Page identifier

private enum ScrollPageID: Hashable {
    case article(Int64)
    case endOfFeed
}

// MARK: - Individual page

private struct ScrollArticlePage: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.zoomNamespace) private var zoomNamespace
    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer

    let article: Article
    let pageSize: CGSize
    let isExpanded: Bool
    let onTapContent: () -> Void
    let onAdvance: () -> Void
    let onRetreat: () -> Void

    @State private var favicon: UIImage?
    @State private var acronymIcon: UIImage?
    @State private var feedName: String?
    @State private var isVideoFeed = false
    @State private var hideImage = false
    @State private var showSafari = false

    @Namespace private var headerNamespace

    private var hasArticleImage: Bool {
        article.imageURL != nil && !hideImage
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundLayer
                .frame(width: pageSize.width, height: pageSize.height)
                .clipped()

            ScrollStyleProgressiveBlurView()
                .frame(width: pageSize.width, height: pageSize.height * (isExpanded ? 1.0 : 0.55))
                .allowsHitTesting(false)

            Group {
                if isExpanded {
                    ScrollExpandedArticleView(
                        article: article,
                        feedName: feedName,
                        favicon: favicon,
                        acronymIcon: acronymIcon,
                        isVideoFeed: isVideoFeed,
                        headerNamespace: headerNamespace,
                        onTapToCollapse: onTapContent,
                        onAdvance: onAdvance,
                        onRetreat: onRetreat
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
            if let feed = feedManager.feed(forArticle: article) {
                feedName = feed.title
                isVideoFeed = feed.isVideoFeed || feed.isXFeed || feed.isInstagramFeed
                if let data = feed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                favicon = await FaviconCache.shared.favicon(for: feed)
            }
        }
    }

    // MARK: Background

    @ViewBuilder
    private var backgroundLayer: some View {
        if hasArticleImage, let urlString = article.imageURL, let url = URL(string: urlString) {
            CachedAsyncImage(url: url, alignment: .center, onImageLoaded: { image in
                let pixelWidth = image.size.width * image.scale
                let pixelHeight = image.size.height * image.scale
                if pixelWidth <= 100 && pixelHeight <= 100 {
                    hideImage = true
                }
            }) {
                faviconBackground
            }
            .scaledToFill()
        } else {
            faviconBackground
        }
    }

    private var faviconBackground: some View {
        let isDark = colorScheme == .dark
        let bgColor = favicon?.cardBackgroundColor(isDarkMode: isDark)
            ?? (isDark ? Color(white: 0.15) : Color(white: 0.9))
        return ZStack {
            Rectangle()
                .fill(bgColor)
            if let favicon {
                Image(uiImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: pageSize.width * 0.5, height: pageSize.width * 0.5)
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
                .contentShape(Rectangle())
                .onTapGesture { onTapContent() }

            ScrollActionButtonsColumn(
                article: article,
                onOpen: { openArticleURL() },
                onToggleRead: {
                    withAnimation(.smooth.speed(2.0)) {
                        feedManager.toggleRead(article)
                    }
                },
                onCopy: { UIPasteboard.general.string = article.url },
                shareURL: URL(string: article.url)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var compactTextBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Group {
                    if let favicon {
                        FaviconImage(favicon, size: 24, cornerRadius: 4, circle: isVideoFeed)
                    } else if let acronymIcon {
                        FaviconImage(acronymIcon, size: 24, cornerRadius: 4,
                                     circle: isVideoFeed, skipInset: true)
                    } else if let feedName {
                        InitialsAvatarView(feedName, size: 24, circle: isVideoFeed, cornerRadius: 4)
                    }
                }
                .matchedGeometryEffect(id: "headerIcon", in: headerNamespace)
                if let feedName {
                    Text(feedName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .matchedGeometryEffect(id: "headerFeedName", in: headerNamespace)
                }
            }

            Text(article.title)
                .font(.system(.title2, weight: .bold))
                .fontWidth(.condensed)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                .matchedGeometryEffect(id: "headerTitle", in: headerNamespace)

            if let summary = article.summary, !summary.isEmpty {
                Text(ContentBlock.stripMarkdown(summary))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            }
        }
    }

    private func openArticleURL() {
        feedManager.markRead(article)
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

// MARK: - Action buttons column

private struct ScrollActionButtonsColumn: View {

    let article: Article
    let onOpen: () -> Void
    let onToggleRead: () -> Void
    let onCopy: () -> Void
    let shareURL: URL?

    var body: some View {
        VStack(spacing: 18) {
            actionButton(
                systemImage: article.isYouTubeURL ? "play.rectangle" : "safari",
                label: Text("Article.OpenInBrowser"),
                action: onOpen
            )
            actionButton(
                systemImage: article.isRead ? "envelope.badge" : "envelope.open",
                label: Text(article.isRead
                            ? "Article.MarkUnread"
                            : "Article.MarkRead"),
                action: onToggleRead
            )
            actionButton(
                systemImage: "doc.on.doc",
                label: Text("Article.CopyLink"),
                action: onCopy
            )
            if let shareURL {
                ShareLink(item: shareURL) {
                    buttonContent(systemImage: "square.and.arrow.up")
                }
                .accessibilityLabel(Text("Article.Share"))
            }
        }
    }

    @ViewBuilder
    private func actionButton(systemImage: String,
                              label: Text,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            buttonContent(systemImage: systemImage)
        }
        .accessibilityLabel(label)
    }

    private func buttonContent(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            .frame(width: 48, height: 48)
            .glassEffect(.regular.interactive(), in: .circle)
    }
}

// MARK: - Expanded article content

private struct ScrollExpandedArticleView: View {

    @Environment(FeedManager.self) var feedManager

    let article: Article
    let feedName: String?
    let favicon: UIImage?
    let acronymIcon: UIImage?
    let isVideoFeed: Bool
    let headerNamespace: Namespace.ID
    let onTapToCollapse: () -> Void
    let onAdvance: () -> Void
    let onRetreat: () -> Void

    @State private var extractedText: String?
    @State private var isExtracting = true
    @State private var didStartExtraction = false

    @State private var scrollOffset: CGFloat = 0
    @State private var maxScrollOffset: CGFloat = 0

    private static let overscrollThreshold: CGFloat = 80

    private var displayText: String? {
        extractedText ?? article.summary
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                headerSection

                if isExtracting && extractedText == nil {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else if let text = displayText {
                    let blocks = ContentBlock.parse(text)
                    ForEach(blocks) { block in
                        switch block {
                        case .text(let content):
                            SelectableText(content, textColor: .white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        case .code(let content):
                            CodeBlockView(code: content)
                        case .image(let url, _):
                            CachedAsyncImage(url: url) {
                                Rectangle()
                                    .fill(.white.opacity(0.1))
                                    .frame(height: 180)
                            }
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: 12))
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 80)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded { onTapToCollapse() }
            )
        }
        .onScrollGeometryChange(for: ScrollMetrics.self) { geo in
            ScrollMetrics(
                offset: geo.contentOffset.y,
                maxOffset: max(0, geo.contentSize.height - geo.containerSize.height)
            )
        } action: { _, new in
            scrollOffset = new.offset
            maxScrollOffset = new.maxOffset
        }
        .onScrollPhaseChange { _, newPhase in
            guard newPhase == .decelerating || newPhase == .idle else { return }
            if scrollOffset < -Self.overscrollThreshold {
                onRetreat()
            } else if scrollOffset > maxScrollOffset + Self.overscrollThreshold {
                onAdvance()
            }
        }
        .task {
            guard !didStartExtraction else { return }
            didStartExtraction = true
            await loadArticleText()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Group {
                    if let favicon {
                        FaviconImage(favicon, size: 24, cornerRadius: 4, circle: isVideoFeed)
                    } else if let acronymIcon {
                        FaviconImage(acronymIcon, size: 24, cornerRadius: 4,
                                     circle: isVideoFeed, skipInset: true)
                    } else if let feedName {
                        InitialsAvatarView(feedName, size: 24, circle: isVideoFeed, cornerRadius: 4)
                    }
                }
                .matchedGeometryEffect(id: "headerIcon", in: headerNamespace)
                if let feedName {
                    Text(feedName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .matchedGeometryEffect(id: "headerFeedName", in: headerNamespace)
                }
            }

            Text(article.title)
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(.white)
                .matchedGeometryEffect(id: "headerTitle", in: headerNamespace)

            HStack(spacing: 8) {
                if let author = article.author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                if article.author != nil, article.publishedDate != nil {
                    Text("·")
                        .foregroundStyle(.white.opacity(0.55))
                }
                if let date = article.publishedDate {
                    RelativeTimeText(date: date)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            Divider()
                .overlay(.white.opacity(0.2))
        }
    }

    // MARK: - Extraction

    private func loadArticleText() async {
        // Check cache first
        if let cached = try? DatabaseManager.shared.cachedArticleContent(for: article.id),
           !cached.isEmpty {
            extractedText = cached
            isExtracting = false
            return
        }

        let title = article.title
        var result: String?

        if let content = article.content, !content.isEmpty {
            let baseURL = URL(string: article.url)
            if let text = ArticleExtractor.extractText(fromHTML: content,
                                                       baseURL: baseURL,
                                                       excludeTitle: title),
               !text.isEmpty {
                let paragraphCount = text.components(separatedBy: "\n\n").count
                if paragraphCount > 1 || text.count < 500 {
                    result = text
                }
            }
        }

        if result == nil, let url = URL(string: article.url) {
            result = await ArticleExtractor.extractText(fromURL: url, excludeTitle: title)
        }

        if let result, !result.isEmpty {
            extractedText = result
            try? DatabaseManager.shared.cacheArticleContent(result, for: article.id)
        }
        isExtracting = false
    }
}

private struct ScrollMetrics: Equatable {
    let offset: CGFloat
    let maxOffset: CGFloat
}

// MARK: - End of feed page

private struct ScrollEndOfFeedPage: View {

    let pageSize: CGSize
    let onLoadMore: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)

            ContentUnavailableView {
                Label("Scroll.EndOfFeed.Title", systemImage: "clock.arrow.circlepath")
                    .foregroundStyle(.white)
            } description: {
                Text("Scroll.EndOfFeed.Description")
                    .foregroundStyle(.white.opacity(0.75))
            } actions: {
                Button {
                    onLoadMore()
                } label: {
                    Label("Articles.LoadPrevious", systemImage: "clock.arrow.circlepath")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.2))
                .foregroundStyle(.white)
            }
        }
        .frame(width: pageSize.width, height: pageSize.height)
    }
}

// MARK: - Progressive Blur

/// A progressive blur that fades from transparent at the top to a stronger
/// blur at the bottom of the frame, matching the style used in the Cards view.
private struct ScrollStyleProgressiveBlurView: UIViewRepresentable {

    @Environment(\.colorScheme) private var colorScheme

    func makeUIView(context _: Context) -> ScrollStyleProgressiveBlurUIView {
        ScrollStyleProgressiveBlurUIView(blurStyle: blurStyle)
    }

    func updateUIView(_ view: ScrollStyleProgressiveBlurUIView, context _: Context) {
        view.update(blurStyle: blurStyle)
    }

    private var blurStyle: UIBlurEffect.Style {
        colorScheme == .dark ? .dark : .light
    }
}

private final class ScrollStyleProgressiveBlurUIView: UIView {

    static let steps = 6
    private var blurStyle: UIBlurEffect.Style
    private let tintOverlay = UIView()

    init(blurStyle: UIBlurEffect.Style) {
        self.blurStyle = blurStyle
        super.init(frame: .zero)
        clipsToBounds = true

        for _ in 0..<Self.steps {
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(blur)
        }

        tintOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(tintOverlay)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    func update(blurStyle style: UIBlurEffect.Style) {
        blurStyle = style
        for case let blur as UIVisualEffectView in subviews {
            blur.effect = UIBlurEffect(style: style)
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let blurViews = subviews.compactMap { $0 as? UIVisualEffectView }
        guard blurViews.count == Self.steps else { return }

        for (index, blur) in blurViews.enumerated() {
            blur.frame = bounds

            let mask = CAGradientLayer()
            mask.frame = bounds
            mask.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor,
                           UIColor.black.cgColor, UIColor.black.cgColor]

            let start = CGFloat(index) / CGFloat(Self.steps)
            let end = CGFloat(index + 1) / CGFloat(Self.steps)
            mask.locations = [0, NSNumber(value: start), NSNumber(value: end), 1]
            mask.startPoint = CGPoint(x: 0.5, y: 0)
            mask.endPoint = CGPoint(x: 0.5, y: 1)
            blur.layer.mask = mask

            blur.alpha = CGFloat(index + 1) / CGFloat(Self.steps)
        }

        tintOverlay.frame = bounds
        tintOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.35)

        let tintMask = CAGradientLayer()
        tintMask.frame = bounds
        tintMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        tintMask.startPoint = CGPoint(x: 0.5, y: 0)
        tintMask.endPoint = CGPoint(x: 0.5, y: 1)
        tintOverlay.layer.mask = tintMask
    }
}
