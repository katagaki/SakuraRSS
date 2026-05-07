import SwiftUI
import WebKit
import FoundationModels
#if !os(visionOS)
@preconcurrency import Translation
#endif

struct YouTubePlayerView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) var dismissSheet
    let article: Article
    let showsDismissButton: Bool
    let session = YouTubePlayerSession.shared

    @State var isBookmarked = false
    @State var isPlaying = false
    @State private var isPiPEligible = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State var webView: WKWebView?
    @State var isAd = false
    @State var isAdSkippable = false
    @State private var advertiserURL: URL?
    @State private var hasStartedPlaying = false
    @State var isPiP = false
    @State private var videoAspectRatio: CGFloat
    @State var feed: Feed?
    @State var icon: UIImage?
    @State var acronymIcon: UIImage?
    @State var fetchedTitle: String?
    @State var fetchedAuthor: String?
    @State var chapters: [YouTubeChapter] = []
    @State var wantsPlaybackInBackground = false
    @State var playerID = UUID()

    @AppStorage("YouTube.SponsorBlock.Enabled") var sponsorBlockEnabled = false
    @AppStorage("YouTube.SponsorBlock.Categories") private var sponsorBlockCategories = "sponsor,selfpromo,interaction"
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
    @State private var imageViewerURL: URL?
    @Namespace private var imageViewerNamespace

    init(article: Article, showsDismissButton: Bool = false) {
        self.article = article
        self.showsDismissButton = showsDismissButton
        _videoAspectRatio = State(initialValue: YouTubePlayerSession.shared.videoAspectRatio)
    }

    var body: some View {
        VStack(spacing: 0) {
            YouTubePlayerWebView(
                urlString: article.url,
                isPlaying: $isPlaying,
                currentTime: $currentTime,
                duration: $duration,
                webView: $webView,
                isAd: $isAd,
                isAdSkippable: $isAdSkippable,
                advertiserURL: $advertiserURL,
                videoAspectRatio: $videoAspectRatio,
                isPiP: $isPiP,
                chapters: $chapters
            )
            .aspectRatio(videoAspectRatio, contentMode: .fit)
            .clipped()
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
            .animation(.smooth.speed(2.0), value: isAd && isAdSkippable && !isPiP)
            .overlay {
                if isPiP {
                    Color.black
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "pip")
                                    .font(.largeTitle)
                                Text(String(localized: "YouTube.PiP.Active", table: "Integrations"))
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.secondary)
                        }
                } else if !hasStartedPlaying {
                    Color.black
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }
            }
            .overlay(alignment: .bottomLeading) {
                if isAd && !isPiP && hasStartedPlaying {
                    Text(String(localized: "YouTube.Ad.Label", table: "Integrations"))
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .compatibleGlassEffect(in: .capsule)
                        .padding(8)
                        .transition(.opacity)
                }
            }
            .animation(.smooth.speed(2.0), value: isAd && !isPiP && hasStartedPlaying)

            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    WordWrappingText(
                        (article.isEphemeral ? fetchedTitle : nil) ?? article.title,
                        font: .preferredFont(forTextStyle: .title2, weight: .bold)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    SeekBarView(
                        currentTime: currentTime,
                        duration: duration,
                        isDisabled: isAd,
                        segments: sponsorSegments.map { (start: $0.startTime, end: $0.endTime) },
                        onSeek: { seek(to: $0) }
                    )

                    YouTubePlayerControls(
                        isPlaying: isPlaying,
                        isAd: isAd,
                        isAdSkippable: isAdSkippable,
                        onTogglePiP: togglePiP,
                        onRewind: rewind,
                        onTogglePlayPause: togglePlayPause,
                        onSkipAd: skipAd,
                        onFastForward: fastForward,
                        onEnterFullscreen: enterFullscreen
                    )

                    if isAd, let advertiserURL {
                        Button {
                            openURL(advertiserURL)
                        } label: {
                            Text(String(localized: "YouTube.VisitAdvertiser", table: "Integrations"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Divider()

                    Group {
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
                        } else if article.isEphemeral, let fetchedAuthor {
                            HStack(alignment: .center, spacing: 12) {
                                Text(fetchedAuthor)
                                    .font(.subheadline.bold())
                                Spacer(minLength: 0)
                            }
                        }
                    }

                    Divider()

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

                    Spacer()
                        .frame(height: 32)
                }
                .padding()
            }
            .ignoresSafeArea(.all, edges: [.top])
        }
        .sakuraBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { playerToolbar }
        #if !os(visionOS)
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            let orientation = UIDevice.current.orientation
            if orientation.isLandscape {
                enterFullscreen()
            }
        }
        #endif
        .onChange(of: isPlaying) { _, newValue in
            session.isPlaying = newValue
            if newValue && !hasStartedPlaying {
                withAnimation(.smooth.speed(2.0)) {
                    hasStartedPlaying = true
                }
                NotificationCenter.default.post(
                    name: .youTubePlayerDidStartPlaying,
                    object: playerID
                )
            }
        }
        .onChange(of: isAd) { _, newValue in
            webView?.isUserInteractionEnabled = newValue
        }
        .onChange(of: currentTime) { _, newTime in
            session.currentTime = newTime
            checkSponsorSegments(at: newTime)
        }
        .onChange(of: duration) { _, newDuration in
            session.duration = newDuration
        }
        .onChange(of: videoAspectRatio) { _, newRatio in
            session.videoAspectRatio = newRatio
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onReceive(NotificationCenter.default.publisher(for: .youTubePlayerDidStartPlaying)) { notification in
            guard let otherID = notification.object as? UUID, otherID != playerID else { return }
            pauseForOtherPlayer()
            wantsPlaybackInBackground = false
        }
        .onDisappear {
            // On iPhone, keep the session alive so audio continues in the
            // background and the tab bar bottom accessory acts as a stand-in.
            // On iPad there's no accessory, so tear the session down (unless
            // the player is in PiP).
            if UIDevice.current.userInterfaceIdiom == .pad, !isPiP {
                pauseForOtherPlayer()
                YouTubeAudioSession.deactivate()
                session.clear()
            }
        }
        .task {
            activateBackgroundAudioSession()
            isBookmarked = article.isBookmarked
            session.adopt(article: article)
            isPlaying = session.isPlaying
            currentTime = session.currentTime
            duration = session.duration
            if session.isPlaying || session.duration > 0 {
                hasStartedPlaying = true
            }
            let signedIn = await YouTubePlayerView.hasYouTubeSession()
            let premium = signedIn ? await YouTubePlayerView.hasYouTubePremium() : false
            isPiPEligible = signedIn && premium

            if let loadedFeed = feedManager.feed(forArticle: article) {
                feed = loadedFeed
                session.channelTitle = loadedFeed.title
                if let data = loadedFeed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                icon = await IconCache.shared.icon(for: loadedFeed)
            }
            session.videoTitle = article.title
            if let imageURL = article.imageURL.flatMap(URL.init(string:)) {
                session.artworkURL = imageURL
            }

            if article.isEphemeral {
                await fetchYouTubeOEmbed()
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
        #if !os(visionOS)
        .translationTask(translationConfig) { session in
            await handleTranslation(session: session)
        }
        #endif
        .navigationDestination(item: $imageViewerURL) { url in
            ImageViewerView(url: url)
                .navigationTransition(.zoom(sourceID: url, in: imageViewerNamespace))
        }
    }

}
