import AVKit
import SwiftUI
#if !os(visionOS)
@preconcurrency import Translation
#endif

/// Experimental YouTube player that uses `AVPlayer` to stream the HLS manifest
/// fetched through `NewYouTubeClient`.
struct NewYouTubePlayerView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismissSheet
    let article: Article
    let showsDismissButton: Bool

    @State var loadState: LoadState = .loading
    let playback = NewYouTubePlaybackController.shared
    @State var feed: Feed?
    @State var icon: UIImage?
    @State var acronymIcon: UIImage?
    @State var isBookmarked = false

    @AppStorage("YouTube.SponsorBlock.Enabled") var sponsorBlockEnabled = false
    @AppStorage("YouTube.SponsorBlock.Categories") var sponsorBlockCategories = "sponsor,selfpromo,interaction"
    @State var sponsorSegments: [SponsorSegment] = []
    @State var skippedSegmentIDs: Set<String> = []
    @State var skippedSegmentMessage: String?

    @State var translatedText: String?
    @State var translatedSummary: String?
    @State var isTranslating = false
    #if !os(visionOS)
    @State var translationConfig: TranslationSession.Configuration?
    #endif
    @State var showingTranslation = false
    @State var hasCachedTranslation = false
    @State var summarizedText: String?
    @State var isSummarizing = false
    @State var hasCachedSummary = false
    @State var showingSummary = false
    @State var summarizationError: String?
    @State var imageViewerURL: URL?
    @State var isFullscreenPresented = false
    @Namespace var imageViewerNamespace
    @Namespace var fullscreenNamespace

    init(article: Article, showsDismissButton: Bool = false) {
        self.article = article
        self.showsDismissButton = showsDismissButton
    }

    enum LoadState {
        case loading
        case ready
        case failed
    }

    var body: some View {
        VStack(spacing: 0) {
            playerContainer
                .aspectRatio(playback.aspectRatio, contentMode: .fit)
                .clipped()
                .overlay {
                    if case .ready = loadState {
                        NewYouTubePlayerOverlayControls(
                            playback: playback,
                            trailingAction: .enterFullscreen { isFullscreenPresented = true },
                            sponsorSegments: sponsorSegments
                        )
                    }
                }
                .overlay(alignment: .top) {
                    if let skippedSegmentMessage {
                        Text(skippedSegmentMessage)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.smooth.speed(2.0), value: skippedSegmentMessage)
                .matchedTransitionSource(id: "youtube-player", in: fullscreenNamespace)

            ScrollView(.vertical) {
                descriptionContent
                    .padding()
            }
            .ignoresSafeArea(.all, edges: [.top])
        }
        .sakuraBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { playerToolbar }
        .onChange(of: playback.currentTime) { _, newTime in
            checkSponsorSegments(at: newTime)
        }
        .task { await loadStream() }
        #if !os(visionOS)
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            handleOrientationChange()
        }
        #endif
        .alert(String(localized: "Article.Summarize.Error", table: "Articles"), isPresented: Binding(
            get: { summarizationError != nil },
            set: { if !$0 { summarizationError = nil } }
        )) {
        } message: {
            if let summarizationError {
                Text(summarizationError)
            }
        }
        #if !os(visionOS)
        .translationTask(translationConfig) { session in
            await handleTranslation(session: session)
        }
        #endif
        .navigationDestination(item: $imageViewerURL) { url in
            ImageViewerView(url: url)
                .navigationTransition(.zoom(sourceID: url, in: imageViewerNamespace))
        }
        .fullScreenCover(isPresented: $isFullscreenPresented) {
            NewYouTubeFullscreenView(
                playback: playback,
                sponsorSegments: sponsorSegments
            ) {
                isFullscreenPresented = false
            }
            .navigationTransition(.zoom(sourceID: "youtube-player", in: fullscreenNamespace))
        }
    }

    @ViewBuilder
    private var playerContainer: some View {
        switch loadState {
        case .loading:
            Color.black.overlay {
                ProgressView()
                    .tint(.white)
            }
        case .ready:
            NewYouTubePlayerRepresentable(controller: playback)
        case .failed:
            Color.black.overlay {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                    Text(String(localized: "YouTube.NewPlayer.LoadFailed", table: "Integrations"))
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var descriptionContent: some View {
        VStack(spacing: 16) {
            WordWrappingText(
                article.title,
                font: .preferredFont(forTextStyle: .title2, weight: .bold)
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            if let feed {
                HStack(alignment: .center, spacing: 12) {
                    feedAvatarView
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feed.title)
                            .font(.subheadline.bold())
                        if let date = article.publishedDate {
                            RelativeTimeText(date: date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                Divider()
            }

            if let text = displayDescription, !text.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    if showingSummary && summarizedText != nil {
                        Text(
                            String(
                                localized: "AppleIntelligence.VerifyImportantInformation",
                                table: "Settings"
                            )
                        )
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
                .animation(.smooth.speed(2.0), value: showingSummary)
                .animation(.smooth.speed(2.0), value: showingTranslation)
                .animation(.smooth.speed(2.0), value: translatedText)
            }

            Spacer().frame(height: 32)
        }
    }

    #if !os(visionOS)
    private func handleOrientationChange() {
        let orientation = UIDevice.current.orientation
        if orientation.isLandscape {
            if !isFullscreenPresented {
                isFullscreenPresented = true
            }
        } else if orientation.isPortrait {
            if isFullscreenPresented {
                isFullscreenPresented = false
            }
        }
    }
    #endif

    private func loadStream() async {
        isBookmarked = feedManager.isBookmarked(article)
        if let loadedFeed = feedManager.feed(forArticle: article) {
            feed = loadedFeed
            if let data = loadedFeed.acronymIcon {
                acronymIcon = UIImage(data: data)
            }
            icon = await IconCache.shared.icon(for: loadedFeed)
        }

        if sponsorBlockEnabled,
           let videoID = SponsorBlockClient.extractVideoID(from: article.url) {
            let categories = sponsorBlockCategories
                .split(separator: ",")
                .map(String.init)
            sponsorSegments = await SponsorBlockClient.fetchSegments(
                for: videoID, categories: categories
            )
        }

        if !article.isEphemeral,
           let cached = try? DatabaseManager.shared.cachedArticleTranslation(for: article.id) {
            if cached.text != nil { hasCachedTranslation = true }
            translatedText = cached.text
        }
        if !article.isEphemeral,
           let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
           !cached.isEmpty {
            hasCachedSummary = true
        }

        guard let videoId = NewYouTubeClient.parseVideoIdentifier(article.url) else {
            loadState = .failed
            return
        }

        if playback.currentVideoID == videoId, playback.player != nil {
            loadState = .ready
            return
        }

        do {
            let client = try await NewYouTubeClient.bootstrap()
            let masterURL = try await client.hlsMasterURL(videoId: videoId)
            playback.load(url: masterURL, videoID: videoId)
            loadState = .ready
        } catch {
            log("YT NewPlayer", "Failed to resolve stream: \(error)")
            loadState = .failed
        }
    }
}
