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
    @State var isTranslating = false
    @State var translationConfig: TranslationSession.Configuration?
    @State var summarizedText: String?
    @State var isSummarizing = false
    @State var hasCachedSummary = false
    @State var showingSummary = false
    @State var isBookmarked = false
    @State var summarizationError: String?

    var isAppleIntelligenceAvailable: Bool {
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
                .id(translatedTitle)
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
            .animation(.smooth.speed(2.0), value: translatedTitle)
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
                                    translatedText = nil
                                    translatedTitle = nil
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
                    SelectableText(text)
                        .id("\(showingSummary)-\(translatedText ?? "")")
                        .transition(.blurReplace)
                }
            }
            .animation(.smooth.speed(2.0), value: showingSummary)
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
}
