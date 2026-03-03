import SwiftUI
import FoundationModels
@preconcurrency import Translation

struct ArticleDetailView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    let article: Article
    @State private var favicon: UIImage?
    @State private var feedName: String?
    @State private var skipFaviconInset = false
    @State private var isVideoFeed = false
    @State private var extractedText: String?
    @State private var isExtracting = false
    @State private var translatedText: String?
    @State private var translatedTitle: String?
    @State private var isTranslating = false
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var summarizedText: String?
    @State private var isSummarizing = false
    @State private var hasCachedSummary = false
    @State private var showingSummary = false

    private var isAppleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var displayText: String? {
        if showingSummary, let summarizedText {
            return translatedText ?? summarizedText
        }
        return translatedText ?? extractedText ?? article.summary
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SelectableText(
                    translatedTitle ?? article.title,
                    font: .preferredFont(forTextStyle: .title2).bold(),
                    textColor: .label
                )

                HStack(spacing: 12) {
                    if let favicon = favicon {
                        FaviconImage(favicon, size: 18, cornerRadius: 3,
                                     circle: isVideoFeed, skipInset: skipFaviconInset)
                    } else if let feedName {
                        InitialsAvatarView(feedName, size: 18, circle: isVideoFeed, cornerRadius: 3)
                    }

                    if let feed = feedManager.feed(forArticle: article) {
                        Text(feed.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let author = article.author {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let date = article.publishedDate {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        RelativeTimeText(date: date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) {
                        Rectangle()
                            .fill(.secondary.opacity(0.1))
                            .frame(height: 200)
                    }
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

            }
            .padding(.horizontal)
            .padding(.top)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if !isExtracting && displayText != nil {
                        Button {
                            triggerTranslation()
                        } label: {
                            Label(
                                String(localized: "Article.Translate"),
                                systemImage: "translate"
                            )
                            .opacity(isTranslating ? 0 : 1)
                            .overlay {
                                if isTranslating {
                                    ProgressView()
                                }
                            }
                            .padding(.horizontal, 2)
                            .padding(.vertical, 2)
                        }
                        .disabled(isTranslating)
                        .animation(.smooth.speed(2.0), value: isTranslating)

                        if isAppleIntelligenceAvailable {
                            if (summarizedText != nil || hasCachedSummary) && !isSummarizing {
                                Button {
                                    translatedText = nil
                                    translatedTitle = nil
                                    if summarizedText == nil {
                                        Task {
                                            await summarizeArticle()
                                            showingSummary = true
                                        }
                                    } else {
                                        showingSummary.toggle()
                                    }
                                } label: {
                                    Label(
                                        String(localized: showingSummary
                                               ? "Article.ShowOriginal"
                                               : "Article.ShowSummary"),
                                        systemImage: showingSummary
                                            ? "doc.plaintext" : "apple.intelligence"
                                    )
                                    .padding(.horizontal, 2)
                                    .padding(.vertical, 2)
                                }
                            } else {
                                Button {
                                    translatedText = nil
                                    translatedTitle = nil
                                    Task {
                                        await summarizeArticle()
                                        showingSummary = true
                                    }
                                } label: {
                                    Label(
                                        String(localized: "Article.Summarize"),
                                        systemImage: "apple.intelligence"
                                    )
                                    .opacity(isSummarizing ? 0 : 1)
                                    .overlay {
                                        if isSummarizing {
                                            ProgressView()
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                    .padding(.vertical, 2)
                                }
                                .disabled(isSummarizing)
                                .animation(.smooth.speed(2.0), value: isSummarizing)
                            }
                        }
                    }

                    Button {
                        openArticleURL()
                    } label: {
                        Label(
                            String(localized: "Article.OpenInBrowser"),
                            systemImage: (
                                article.isYouTubeURL && YouTubeHelper.isAppInstalled ? "play.rectangle" : "safari"
                            )
                        )
                        .padding(.horizontal, 2)
                        .padding(.vertical, 2)
                    }
                }
                .buttonStyle(.bordered)
                .tint(.primary)
                .padding(.horizontal)
            }
            .padding(.top)

            VStack(alignment: .leading, spacing: 16) {

                if isExtracting {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else if let text = displayText {
                    if showingSummary && summarizedText != nil {
                        Text("AppleIntelligence.VerifyImportantInformation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    SelectableText(text)
                        .id(showingSummary)
                        .transition(.blurReplace)
                }
            }
            .animation(.smooth, value: showingSummary)
            .padding()
        }
        .refreshable {
            await refreshArticleContent()
        }
        .sakuraBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    feedManager.toggleBookmark(article)
                } label: {
                    Image(systemName: article.isBookmarked ? "bookmark.fill" : "bookmark")
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let shareURL = URL(string: article.url) {
                    ShareLink(item: shareURL) {
                        Label(String(localized: "Article.Share"), systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            feedManager.markRead(article)
            if let feed = feedManager.feed(forArticle: article) {
                feedName = feed.title
                favicon = await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL)
                isVideoFeed = feed.isVideoFeed
                skipFaviconInset = feed.isVideoFeed
                    || FullFaviconDomains.shouldUseFullImage(feedDomain: feed.domain)
            }
            await extractArticleContent()
            if let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
               !cached.isEmpty {
                hasCachedSummary = true
            }
        }
        .translationTask(translationConfig) { session in
            isTranslating = true
            defer { isTranslating = false }

            let source: String
            if showingSummary, let summarizedText {
                source = summarizedText
            } else {
                source = extractedText ?? article.summary ?? ""
            }
            guard !source.isEmpty else { return }

            do {
                var requests = [
                    TranslationSession.Request(sourceText: source)
                ]
                if !showingSummary {
                    requests.insert(
                        TranslationSession.Request(sourceText: article.title),
                        at: 0
                    )
                }
                let responses = try await session.translations(from: requests)
                if showingSummary {
                    translatedText = responses[0].targetText
                } else if responses.count >= 2 {
                    translatedTitle = responses[0].targetText
                    translatedText = responses[1].targetText
                }
            } catch {
                // Translation failed; user can retry
            }
        }
    }

    private func extractArticleContent() async {
        isExtracting = true
        defer { isExtracting = false }

        #if DEBUG
                debugPrint("Extracting article content: \(article.url)")
        #endif

        if let cached = try? DatabaseManager.shared.cachedArticleContent(for: article.id),
           !cached.isEmpty {
            extractedText = cached
            #if DEBUG
            debugPrint("Using cached content: \(article.url)")
            #endif
            return
        }

        // For whitelisted domains, always fetch the full article via WKWebView
        if let url = URL(string: article.url), WebViewExtractor.requiresWebView(for: url) {
            let text = await ArticleExtractor.extractText(fromURL: url)
            extractedText = text
            if let text, !text.isEmpty {
                try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
            }
            return
        }

        if let content = article.content, !content.isEmpty {
            let text = ArticleExtractor.extractText(fromHTML: content)
            if let text, !text.isEmpty {
                extractedText = text
                try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
                return
            }
        }

        if let url = URL(string: article.url) {
            let text = await ArticleExtractor.extractText(fromURL: url)
            extractedText = text
            if let text, !text.isEmpty {
                try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
            }
        }
    }

    private func refreshArticleContent() async {
        try? DatabaseManager.shared.clearCachedArticleContent(for: article.id)
        try? DatabaseManager.shared.clearCachedArticleSummary(for: article.id)
        translatedText = nil
        translatedTitle = nil
        summarizedText = nil
        hasCachedSummary = false
        showingSummary = false
        extractedText = nil
        await extractArticleContent()
    }

    private func openArticleURL() {
        if article.isYouTubeURL {
            YouTubeHelper.openInApp(url: article.url)
        } else if let url = URL(string: article.url) {
            openURL(url)
        }
    }

    private func summarizeArticle() async {
        let source = extractedText ?? article.summary ?? ""
        guard !source.isEmpty else { return }

        if let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
           !cached.isEmpty {
            summarizedText = cached
            return
        }

        isSummarizing = true
        defer { isSummarizing = false }

        let instructions = String(localized: "Article.Summarize.Prompt")
        let prompt = "\(instructions)\n\n\(source)"

        #if DEBUG
        debugPrint(prompt)
        #endif

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            summarizedText = response.content
            try? DatabaseManager.shared.cacheArticleSummary(response.content, for: article.id)
        } catch {
            // Summarization failed; user can retry
        }
    }

    private func triggerTranslation() {
        if translationConfig == nil {
            translationConfig = .init()
        } else {
            translationConfig?.invalidate()
        }
    }
}
