import SwiftUI
import FoundationModels
@preconcurrency import Translation

struct ArticleDetailView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    let article: Article
    /// When non-nil, forces a specific text-extraction mode for ephemeral
    /// articles (those opened via `sakura://open`).
    let ephemeralTextMode: OpenArticleRequest.TextMode?
    @State var favicon: UIImage?
    @State var feedName: String?
    @State var acronymIcon: UIImage?
    @State var skipFaviconInset = false
    @State var isVideoFeed = false
    @State var extractedText: String?
    @State var isExtracting = false
    @State var extractedAuthor: String?
    @State var extractedPublishedDate: Date?
    @State var extractedLeadImageURL: String?
    @State var extractedPageTitle: String?
    @State var isPaywalled = false
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
    @State var showYouTubeSafari = false
    @State var linkedArticleURL: URL?
    @State var arXivPDFReference: ArXivPDFReference?
    @State var imageViewerURL: URL?
    @Namespace private var imageViewerNamespace
    @AppStorage("YouTube.OpenMode") var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @AppStorage("Intelligence.ContentInsights.Enabled") var contentInsightsEnabled: Bool = false
    @State var similarArticles: [SimilarArticleItem] = []
    @State var articleTopics: [String] = []
    @State var articlePeople: [String] = []
    @State var isLoadingInsights: Bool = false

    init(
        article: Article,
        ephemeralTextMode: OpenArticleRequest.TextMode? = nil
    ) {
        self.article = article
        self.ephemeralTextMode = ephemeralTextMode
    }

    var isAppleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var hasTranslationForCurrentMode: Bool {
        if showingSummary {
            return translatedSummary != nil
        }
        return translatedText != nil || hasCachedTranslation
    }

    var hasTranslatedFullText: Bool {
        translatedText != nil || hasCachedTranslation
    }

    var fullTextHasImages: Bool {
        extractedText?.contains("{{IMG}}") == true
    }

    var isInsecureArticle: Bool {
        URL(string: article.url)?.scheme?.lowercased() == "http"
    }

    var displayText: String? {
        if isInsecureArticle {
            return String(localized: "Article.Insecure.Content", table: "Articles")
        }
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
                    isInsecureArticle
                        ? String(localized: "Article.Insecure.Title", table: "Articles")
                        : ((showingTranslation ? translatedTitle : nil)
                            ?? (article.isEphemeral ? extractedPageTitle : nil)
                            ?? article.title),
                    font: .preferredFont(forTextStyle: .title2).bold(),
                    textColor: .label
                )
                .id(showingTranslation ? translatedTitle : nil)
                .transition(.blurReplace)

                if !article.isEphemeral {
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

                        if let author = article.author ?? extractedAuthor {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(author)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if let date = article.publishedDate ?? extractedPublishedDate {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            RelativeTimeText(date: date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .lineLimit(1)
                }

            }
            .animation(.smooth.speed(2.0), value: translatedTitle)
            .padding([.horizontal, .top])

            Divider()
                .padding(.horizontal)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 16) {
                if !fullTextHasImages,
                   let imageURL = article.imageURL ?? extractedLeadImageURL,
                   let url = URL(string: imageURL) {
                    ImageBlockView(url: url, namespace: imageViewerNamespace) {
                        imageViewerURL = url
                    }
                }

                if isExtracting {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .transition(.blurReplace)
                } else if let text = displayText {
                    if showingSummary && summarizedText != nil {
                        Text(String(localized: "AppleIntelligence.VerifyImportantInformation", table: "Settings"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ContentBlockStack(
                        text: text,
                        imageNamespace: imageViewerNamespace,
                        onImageTap: { url in imageViewerURL = url }
                    )
                    .id("\(showingSummary)-\(showingTranslation)")
                    .transition(.blurReplace)
                }
            }
            .animation(.smooth.speed(2.0), value: isExtracting)
            .animation(.smooth.speed(2.0), value: showingSummary)
            .animation(.smooth.speed(2.0), value: showingTranslation)
            .animation(.smooth.speed(2.0), value: translatedText)
            .padding([.horizontal, .bottom])

            insightsSection
                .animation(.smooth.speed(2.0), value: similarArticles.count)
                .animation(.smooth.speed(2.0), value: articleTopics.count)
                .animation(.smooth.speed(2.0), value: articlePeople.count)
                .animation(.smooth.speed(2.0), value: isLoadingInsights)
        }
        .refreshable {
            await refreshArticleContent()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isInsecureArticle {
                InsecureBannerView(articleURL: article.url)
                    .padding()
            } else if isPaywalled {
                PaywallBannerView(articleURL: article.url)
                    .padding()
                    .animation(.smooth.speed(2.0), value: isPaywalled)
            }
        }
        .sakuraBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            articleToolbar
        }
        .task {
            guard !isInsecureArticle else { return }
            await loadArticleMetadata()
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
        .navigationDestination(item: $arXivPDFReference) { reference in
            ArXivPDFViewerView(url: reference.url, title: reference.title)
        }
        .sheet(isPresented: $showYouTubeSafari) {
            if let url = URL(string: article.url) {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .navigationDestination(item: $imageViewerURL) { url in
            ImageViewerView(url: url)
                .navigationTransition(.zoom(sourceID: url, in: imageViewerNamespace))
        }
        .translationTask(translationConfig) { session in
            await handleTranslation(session: session)
        }
    }
}
