import SwiftUI
import FoundationModels
@preconcurrency import Translation

struct ScrollExpandedArticleView: View { // swiftlint:disable:this type_body_length
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
                        Text(String(localized: "AppleIntelligence.VerifyImportantInformation", table: "Settings"))
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
                        case .video(let url):
                            VideoBlockView(url: url)
                        case .youtube(let videoID):
                            YouTubeEmbedBlockView(videoID: videoID)
                        case .xPost(let url):
                            XEmbedBlockView(url: url)
                        case .embed(let provider, let url):
                            EmbedBlockView(provider: provider, url: url)
                        case .table(let header, let rows):
                            TableBlockView(header: header, rows: rows)
                        case .math(let latex):
                            MathBlockView(latex: latex)
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
        .alert(String(localized: "Article.Summarize.Error", table: "Articles"), isPresented: Binding(
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
                    title: String(localized: "Article.OpenInBrowser", table: "Articles"),
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
            } catch { }
        } else {
            let source = extractedText ?? article.summary ?? ""
            guard !ContentBlock.plainText(from: source).isEmpty else { return }
            do {
                let result = try await ContentBlock.translateArticleContent(
                    title: article.title, markerText: source, session: session
                )
                translatedTitle = result.title
                translatedText = result.text
                hasCachedTranslation = true
                showingTranslation = true
                try? DatabaseManager.shared.cacheArticleTranslation(
                    title: result.title, text: result.text, for: article.id
                )
            } catch { }
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

        let instructions = String(localized: "Article.Summarize.Prompt", table: "Articles")

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

struct ScrollMetrics: Equatable {
    let offset: CGFloat
    let maxOffset: CGFloat
}
