import SwiftUI
import FoundationModels
@preconcurrency import Translation

// MARK: - Scroll Style View

/// A TikTok/Reels-inspired full-screen vertical pager where each article
/// takes up the entire screen. Tapping the image or content preview expands
/// the article to reveal the full extracted text; tapping again collapses it.
/// When expanded, overscrolling past the top collapses back to the compact
/// overlay and overscrolling past the bottom advances to the next article.
struct ScrollStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?

    @State private var currentID: ScrollPageID?
    @State private var expandedArticleID: Int64?
    @State private var youTubeArticle: Article?
    @State private var podcastArticle: Article?
    @State private var contextInsets: EdgeInsets = EdgeInsets()

    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer

    var body: some View {
        Color.clear
            .overlay {
                GeometryReader { geometry in
                    let pageSize = geometry.size

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(articles) { article in
                                ScrollArticlePage(
                                    article: article,
                                    pageSize: pageSize,
                                    contextInsets: contextInsets,
                                    isExpanded: expandedArticleID == article.id,
                                    onTapContent: { handleTap(on: article) },
                                    onAdvance: { advance(from: article) }
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
                    .onChange(of: currentID) { oldValue, _ in
                        if case .article(let id) = oldValue,
                           let prev = articles.first(where: { $0.id == id }) {
                            feedManager.markRead(prev)
                        }
                    }
                    .onChange(of: articles.count) { oldValue, newValue in
                        guard newValue > oldValue,
                              currentID == .endOfFeed,
                              oldValue < articles.count else { return }
                        let firstNew = articles[oldValue]
                        withAnimation(.smooth.speed(1.5)) {
                            currentID = .article(firstNew.id)
                        }
                    }
                }
                .ignoresSafeArea(.container, edges: .vertical)
            }
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { contextInsets = proxy.safeAreaInsets }
                        .onChange(of: proxy.safeAreaInsets) { _, new in contextInsets = new }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .scrollEdgeEffectHidden(true, for: .all)
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
    @Environment(\.navigateToFeed) private var navigateToFeed
    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer

    let article: Article
    let pageSize: CGSize
    let contextInsets: EdgeInsets
    let isExpanded: Bool
    let onTapContent: () -> Void
    let onAdvance: () -> Void

    @State private var feed: Feed?
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
                        article: article,
                        feedName: feedName,
                        favicon: favicon,
                        acronymIcon: acronymIcon,
                        isVideoFeed: isVideoFeed,
                        contextInsets: contextInsets,
                        headerNamespace: headerNamespace,
                        onTapToCollapse: onTapContent,
                        onAdvance: onAdvance,
                        onOpenArticleURL: { openArticleURL() }
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
                if let data = loadedFeed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                favicon = await FaviconCache.shared.favicon(for: loadedFeed)
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
                favicon: favicon,
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
        .padding(.horizontal, 20)
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

            if let summary = article.summary, !summary.isEmpty {
                Text(ContentBlock.stripMarkdown(summary))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 1)
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
    let favicon: UIImage?
    let acronymIcon: UIImage?
    let feedName: String?
    let isVideoFeed: Bool
    let onOpenFeed: () -> Void
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onToggleBookmark: () -> Void
    let shareURL: URL?

    var body: some View {
        VStack(spacing: 20) {
            Button(action: onOpenFeed) {
                Group {
                    if let favicon {
                        FaviconImage(favicon, size: 48, cornerRadius: 8, circle: isVideoFeed)
                    } else if let acronymIcon {
                        FaviconImage(acronymIcon, size: 48, cornerRadius: 8,
                                     circle: isVideoFeed, skipInset: true)
                    } else if let feedName {
                        InitialsAvatarView(feedName, size: 48, circle: isVideoFeed, cornerRadius: 8)
                    } else {
                        Circle().fill(.white.opacity(0.2)).frame(width: 48, height: 48)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(feedName ?? ""))

            Button(action: onOpen) {
                labeledIcon(
                    systemName: article.isYouTubeURL ? "play.rectangle.fill" : "safari.fill",
                    label: Text("Article.OpenInBrowser")
                )
            }
            .accessibilityLabel(Text("Article.OpenInBrowser"))

            Button(action: onCopy) {
                labeledIcon(
                    systemName: "square.on.square.fill",
                    label: Text("Article.CopyLink")
                )
            }
            .accessibilityLabel(Text("Article.CopyLink"))

            Button(action: onToggleBookmark) {
                labeledIcon(
                    systemName: article.isBookmarked ? "bookmark.fill" : "bookmark",
                    label: Text(article.isBookmarked
                                ? "Article.RemoveBookmark"
                                : "Article.Bookmark")
                )
            }
            .accessibilityLabel(Text(article.isBookmarked
                                     ? "Article.RemoveBookmark"
                                     : "Article.Bookmark"))

            if let shareURL {
                ShareLink(item: shareURL) {
                    labeledIcon(
                        systemName: "square.and.arrow.up",
                        label: Text("Article.Share"),
                        iconOffsetY: -1
                    )
                }
                .accessibilityLabel(Text("Article.Share"))
            }
        }
        .font(.title)
        .fontWeight(.semibold)
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
        .buttonStyle(.plain)
    }

    private func labeledIcon(
        systemName: String,
        label: Text,
        iconOffsetY: CGFloat = 0
    ) -> some View {
        VStack(spacing: 2) {
            Image(systemName: systemName)
                .offset(y: iconOffsetY)
            label
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
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
    let contextInsets: EdgeInsets
    let headerNamespace: Namespace.ID
    let onTapToCollapse: () -> Void
    let onAdvance: () -> Void
    let onOpenArticleURL: () -> Void

    @State private var extractedText: String?
    @State private var isExtracting = true
    @State private var didStartExtraction = false

    @State private var translatedText: String?
    @State private var translatedTitle: String?
    @State private var translatedSummary: String?
    @State private var isTranslating = false
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var showingTranslation = false
    @State private var hasCachedTranslation = false

    @State private var summarizedText: String?
    @State private var isSummarizing = false
    @State private var hasCachedSummary = false
    @State private var showingSummary = false
    @State private var summarizationError: String?

    @State private var scrollOffset: CGFloat = 0
    @State private var maxScrollOffset: CGFloat = 0

    private static let overscrollThreshold: CGFloat = 80

    private var isAppleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    private var hasTranslationForCurrentMode: Bool {
        if showingSummary {
            return translatedSummary != nil
        }
        return translatedText != nil || hasCachedTranslation
    }

    private var displayText: String? {
        if showingSummary, let summarizedText {
            if showingTranslation, let translatedSummary {
                return translatedSummary
            }
            return summarizedText
        }
        if showingTranslation, let translatedText {
            return translatedText
        }
        return extractedText ?? article.summary
    }

    private var displayTitle: String {
        if showingTranslation, let translatedTitle {
            return translatedTitle
        }
        return article.title
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                headerSection

                actionButtons

                if isExtracting && extractedText == nil {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else if let text = displayText {
                    if showingSummary && summarizedText != nil {
                        Text("AppleIntelligence.VerifyImportantInformation")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
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
                    .id("\(showingSummary)-\(showingTranslation)")
                    .transition(.blurReplace)
                }

                Spacer(minLength: 40)
            }
            .animation(.smooth.speed(2.0), value: showingSummary)
            .animation(.smooth.speed(2.0), value: showingTranslation)
            .animation(.smooth.speed(2.0), value: translatedText)
            .padding(.horizontal, 20)
            .padding(.top, 20 + contextInsets.top)
            .padding(.bottom, 40 + contextInsets.bottom)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .leading) {
            Color.clear
                .frame(width: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onEnded { value in
                            if value.translation.width > 40 &&
                                abs(value.translation.height) < 60 {
                                onTapToCollapse()
                            }
                        }
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
                onTapToCollapse()
            } else if scrollOffset > maxScrollOffset + Self.overscrollThreshold {
                onAdvance()
            }
        }
        .task {
            guard !didStartExtraction else { return }
            didStartExtraction = true
            await loadArticleText()
            loadCachedAIContent()
        }
        .translationTask(translationConfig) { session in
            await handleTranslation(session: session)
        }
        .alert("Article.Summarize.Error", isPresented: Binding(
            get: { summarizationError != nil },
            set: { if !$0 { summarizationError = nil } }
        )) {
        } message: {
            if let summarizationError {
                Text(summarizationError)
            }
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

            Text(displayTitle)
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

    // MARK: - Action buttons

    private var actionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !isExtracting && displayText != nil {
                    TranslateButton(
                        hasTranslation: hasTranslationForCurrentMode,
                        isTranslating: isTranslating,
                        showingTranslation: $showingTranslation,
                        onTranslate: { triggerTranslation() }
                    )
                    if isAppleIntelligenceAvailable {
                        SummarizeButton(
                            summarizedText: summarizedText,
                            hasCachedSummary: hasCachedSummary,
                            isSummarizing: isSummarizing,
                            showingSummary: $showingSummary,
                            onSummarize: {
                                await summarizeArticle()
                                return summarizedText != nil
                            }
                        )
                    }
                }

                OpenLinkButton(
                    title: "Article.OpenInBrowser",
                    systemImage: article.isYouTubeURL && YouTubeHelper.isAppInstalled
                        ? "play.rectangle" : "safari",
                    action: { onOpenArticleURL() }
                )
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.2))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
        .scrollClipDisabled()
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

    private func loadCachedAIContent() {
        if let cached = try? DatabaseManager.shared.cachedArticleTranslation(for: article.id) {
            translatedTitle = cached.title
            translatedText = cached.text
            translatedSummary = cached.summary
            hasCachedTranslation = cached.title != nil || cached.text != nil
            showingTranslation = hasCachedTranslation
        }
        if let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
           !cached.isEmpty {
            hasCachedSummary = true
        }
    }

    // MARK: - Translation

    private func triggerTranslation() {
        if translationConfig == nil {
            translationConfig = .init()
        } else {
            translationConfig?.invalidate()
        }
    }

    private func handleTranslation(session: TranslationSession) async {
        isTranslating = true
        defer { isTranslating = false }

        if showingSummary, let summarizedText {
            guard !summarizedText.isEmpty else { return }
            do {
                let response = try await session.translate(summarizedText)
                translatedSummary = response.targetText
                showingTranslation = true
                try? DatabaseManager.shared.cacheTranslatedSummary(
                    response.targetText, for: article.id
                )
            } catch {
                // Translation failed; user can retry
            }
        } else {
            let source = ContentBlock.plainText(from: extractedText ?? article.summary ?? "")
            guard !source.isEmpty else { return }
            do {
                let requests = [
                    TranslationSession.Request(sourceText: article.title),
                    TranslationSession.Request(sourceText: source)
                ]
                let responses = try await session.translations(from: requests)
                if responses.count >= 2 {
                    translatedTitle = responses[0].targetText
                    translatedText = responses[1].targetText
                    hasCachedTranslation = true
                    showingTranslation = true
                    try? DatabaseManager.shared.cacheArticleTranslation(
                        title: responses[0].targetText,
                        text: responses[1].targetText,
                        for: article.id
                    )
                }
            } catch {
                // Translation failed; user can retry
            }
        }
    }

    // MARK: - Summarization

    private func summarizeArticle() async {
        if let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
           !cached.isEmpty {
            summarizedText = cached
            return
        }

        let source = ContentBlock.plainText(from: extractedText ?? article.summary ?? "")
        guard !source.isEmpty else { return }

        isSummarizing = true
        defer { isSummarizing = false }

        let instructions = String(localized: "Article.Summarize.Prompt")

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: source)
            summarizedText = response.content
            try? DatabaseManager.shared.cacheArticleSummary(response.content, for: article.id)
        } catch {
            summarizationError = error.localizedDescription
        }
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

    func makeUIView(context _: Context) -> ScrollStyleProgressiveBlurUIView {
        ScrollStyleProgressiveBlurUIView(blurStyle: .dark)
    }

    func updateUIView(_ view: ScrollStyleProgressiveBlurUIView, context _: Context) {
        view.update(blurStyle: .dark)
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
