import SwiftUI
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

    var displayText: String? {
        translatedText ?? extractedText ?? article.summary
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

                HStack(spacing: 12) {
                    if !isExtracting && displayText != nil {
                        Button {
                            triggerTranslation()
                        } label: {
                            if isTranslating {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Label(
                                String(localized: "Article.Translate"),
                                systemImage: "translate"
                            )
                        }
                        .disabled(isTranslating)
                    }

                    Button {
                        openArticleURL()
                    } label: {
                        Label(String(localized: "Article.OpenInBrowser"),
                              systemImage: article.isYouTubeURL ? "play.rectangle.fill" : "safari")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.primary)

                if isExtracting {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else if let text = displayText {
                    SelectableText(text)
                }
            }
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
        }
        .translationTask(translationConfig) { session in
            isTranslating = true
            defer { isTranslating = false }

            let source = extractedText ?? article.summary ?? ""
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
        translatedText = nil
        translatedTitle = nil
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

    private func triggerTranslation() {
        if translationConfig == nil {
            translationConfig = .init()
        } else {
            translationConfig?.invalidate()
        }
    }
}
