import SwiftUI
import FoundationModels
@preconcurrency import Translation

struct ArticleDetailView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    let article: Article
    @State var favicon: UIImage?
    @State var feedName: String?
    @State var acronymIcon: UIImage?
    @State var skipFaviconInset = false
    @State var isVideoFeed = false
    @State var extractedText: String?
    @State var isExtracting = false
    @State var translatedText: String?
    @State var translatedTitle: String?
    @State var translatedSummary: String?
    @State var isTranslating = false
    @State var translationConfig: TranslationSession.Configuration?
    @State var showingTranslation = false
    @State var hasCachedTranslation = false
    @State var summarizedText: String?
    @State var isSummarizing = false
    @State var hasCachedSummary = false
    @State var showingSummary = false
    @State var isBookmarked = false
    @State var summarizationError: String?

    var isAppleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var hasTranslationForCurrentMode: Bool {
        if showingSummary {
            return translatedSummary != nil
        }
        return translatedText != nil || hasCachedTranslation
    }

    var displayText: String? {
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SelectableText(
                    (showingTranslation ? translatedTitle : nil) ?? article.title,
                    font: .preferredFont(forTextStyle: .title2).bold(),
                    textColor: .label
                )
                .id(showingTranslation ? translatedTitle : nil)
                .transition(.blurReplace)

                HStack(spacing: 12) {
                    if let favicon = favicon {
                        FaviconImage(favicon, size: 18, cornerRadius: 3,
                                     circle: isVideoFeed, skipInset: skipFaviconInset)
                    } else if let acronymIcon {
                        FaviconImage(acronymIcon, size: 18, cornerRadius: 3,
                                     circle: isVideoFeed, skipInset: true)
                    } else if let feedName {
                        InitialsAvatarView(feedName, size: 18, circle: isVideoFeed, cornerRadius: 3)
                    }

                    if let feed = feedManager.feed(forArticle: article) {
                        Text(feed.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let author = article.author {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let date = article.publishedDate {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        RelativeTimeText(date: date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)

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
            .animation(.smooth.speed(2.0), value: translatedTitle)
            .padding(.horizontal)
            .padding(.top)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if !isExtracting && displayText != nil {
                        if hasTranslationForCurrentMode && !isTranslating {
                            Button {
                                withAnimation(.smooth.speed(2.0)) {
                                    showingTranslation.toggle()
                                }
                            } label: {
                                Label(
                                    String(localized: showingTranslation
                                           ? "Article.ShowOriginal"
                                           : "Article.ShowTranslation"),
                                    systemImage: showingTranslation
                                        ? "doc.plaintext" : "translate"
                                )
                                .padding(.horizontal, 2)
                                .padding(.vertical, 2)
                            }
                        } else {
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
                        }

                        if isAppleIntelligenceAvailable {
                            if (summarizedText != nil || hasCachedSummary) && !isSummarizing {
                                Button {
                                    if summarizedText == nil {
                                        Task {
                                            await summarizeArticle()
                                            if summarizedText != nil {
                                                withAnimation(.smooth.speed(2.0)) {
                                                    showingSummary = true
                                                }
                                            }
                                        }
                                    } else {
                                        withAnimation(.smooth.speed(2.0)) {
                                            showingSummary.toggle()
                                        }
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
                                    Task {
                                        await summarizeArticle()
                                        if summarizedText != nil {
                                            withAnimation(.smooth.speed(2.0)) {
                                                showingSummary = true
                                            }
                                        }
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
                    let blocks = ContentBlock.parse(text)
                    ForEach(blocks) { block in
                        switch block {
                        case .text(let content):
                            SelectableText(content)
                        case .image(let url):
                            CachedAsyncImage(url: url) {
                                Rectangle()
                                    .fill(.secondary.opacity(0.1))
                                    .frame(height: 200)
                            }
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .id("\(showingSummary)-\(showingTranslation)")
                    .transition(.blurReplace)
                }
            }
            .animation(.smooth.speed(2.0), value: showingSummary)
            .animation(.smooth.speed(2.0), value: showingTranslation)
            .animation(.smooth.speed(2.0), value: translatedText)
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
                    isBookmarked.toggle()
                    feedManager.toggleBookmark(article)
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
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
            isBookmarked = article.isBookmarked
            feedManager.markRead(article)
            if let feed = feedManager.feed(forArticle: article) {
                feedName = feed.title
                if let data = feed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                isVideoFeed = feed.isVideoFeed
                skipFaviconInset = feed.isVideoFeed
                    || FullFaviconDomains.shouldUseFullImage(feedDomain: feed.domain)
                favicon = await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL)
            }
            await extractArticleContent()
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
        .alert(String(localized: "Article.Summarize.Error"), isPresented: Binding(
            get: { summarizationError != nil },
            set: { if !$0 { summarizationError = nil } }
        )) {
        } message: {
            if let summarizationError {
                Text(summarizationError)
            }
        }
        .translationTask(translationConfig) { session in
            isTranslating = true
            defer { isTranslating = false }

            if showingSummary, let summarizedText {
                // Translate the summary
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
                // Translate the original article
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
    }
}
