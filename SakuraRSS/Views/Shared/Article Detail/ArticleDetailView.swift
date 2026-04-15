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
    @State var showYouTubePlayer = false
    @State var showYouTubeSafari = false
    @State var arXivPDFReference: ArXivPDFReference?
    @State var imageViewerURL: URL?
    @State var heroImageAspectRatio: CGFloat?
    @Namespace private var imageViewerNamespace
    @AppStorage("YouTube.OpenMode") var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @AppStorage("Intelligence.ContentInsights.Enabled") var contentInsightsEnabled: Bool = false
    @State var similarArticles: [SimilarArticleItem] = []
    @State var articleTopics: [String] = []
    @State var articlePeople: [String] = []
    @State var isLoadingInsights: Bool = false

    var isAppleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var hasTranslationForCurrentMode: Bool {
        if showingSummary {
            return translatedSummary != nil
        }
        return translatedText != nil || hasCachedTranslation
    }

    var fullTextHasImages: Bool {
        extractedText?.contains("{{IMG}}") == true
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

            }
            .animation(.smooth.speed(2.0), value: translatedTitle)
            .padding(.horizontal)
            .padding(.top)

            actionButtons

            if !fullTextHasImages,
               let imageURL = article.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url, onImageLoaded: { image in
                    heroImageAspectRatio = image.size.width / image.size.height
                }, placeholder: {
                    Rectangle()
                        .fill(.secondary.opacity(0.1))
                        .frame(height: 200)
                })
                .aspectRatio(heroImageAspectRatio, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .matchedTransitionSource(id: url, in: imageViewerNamespace)
                .onTapGesture { imageViewerURL = url }
                .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 16) {

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
                    let blocks = ContentBlock.parse(text)
                    ForEach(blocks) { block in
                        switch block {
                        case .text(let content):
                            SelectableText(content)
                        case .code(let content):
                            CodeBlockView(code: content)
                        case .image(let url, let link):
                            FitWidthImage(url: url, link: link, namespace: imageViewerNamespace) {
                                imageViewerURL = url
                            }
                        case .video(let url):
                            VideoBlockView(url: url)
                        }
                    }
                    .id("\(showingSummary)-\(showingTranslation)")
                    .transition(.blurReplace)
                }
            }
            .animation(.smooth.speed(2.0), value: isExtracting)
            .animation(.smooth.speed(2.0), value: showingSummary)
            .animation(.smooth.speed(2.0), value: showingTranslation)
            .animation(.smooth.speed(2.0), value: translatedText)
            .padding()

            insightsSection
                .animation(.smooth.speed(2.0), value: similarArticles.count)
                .animation(.smooth.speed(2.0), value: articleTopics.count)
                .animation(.smooth.speed(2.0), value: articlePeople.count)
                .animation(.smooth.speed(2.0), value: isLoadingInsights)
        }
        .refreshable {
            await refreshArticleContent()
        }
        .sakuraBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            articleToolbar
        }
        .task {
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
        .navigationDestination(isPresented: $showYouTubePlayer) {
            YouTubePlayerView(article: article)
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

struct FitWidthImage: View {

    let url: URL
    var link: URL?
    let namespace: Namespace.ID
    var onTap: (() -> Void)?
    @State private var aspectRatio: CGFloat?
    @State private var imageSize: CGSize?
    @Environment(\.openURL) private var openURL

    var body: some View {
        GeometryReader { geo in
            let maxWidth = geo.size.width
            let naturalWidth = imageSize?.width ?? maxWidth
            let displayWidth = min(naturalWidth, maxWidth)

            CachedAsyncImage(url: url, onImageLoaded: { image in
                aspectRatio = image.size.width / image.size.height
                imageSize = image.size
            }, placeholder: {
                Rectangle()
                    .fill(.secondary.opacity(0.1))
                    .frame(height: 200)
            })
            .aspectRatio(aspectRatio, contentMode: .fill)
            .frame(width: displayWidth)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .bottomTrailing) {
                if let link, displayWidth >= 120 {
                    Button {
                        openURL(link)
                    } label: {
                        Label("Shared.Link", systemImage: "link")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }
            .matchedTransitionSource(id: url, in: namespace)
            .onTapGesture { onTap?() }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: imageSize?.width)
    }
}
