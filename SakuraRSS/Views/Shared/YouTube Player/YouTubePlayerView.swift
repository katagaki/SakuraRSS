import SwiftUI
import WebKit
import FoundationModels
@preconcurrency import Translation

struct YouTubePlayerView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    @Environment(\.scenePhase) private var scenePhase
    let article: Article

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
    @State private var isPiP = false
    @State private var videoAspectRatio: CGFloat = 16 / 9
    @State var feed: Feed?
    @State var favicon: UIImage?
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
    @State var translationConfig: TranslationSession.Configuration?
    @State var showingTranslation = false
    @State var hasCachedTranslation = false
    @State var summarizedText: String?
    @State var isSummarizing = false
    @State var hasCachedSummary = false
    @State var showingSummary = false
    @State var summarizationError: String?
    @State private var imageViewerURL: URL?
    @Namespace private var imageViewerNamespace

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

            ScrollView(.vertical) {
                VStack(spacing: 8) {
                    WordWrappingText(
                        (article.isEphemeral ? fetchedTitle : nil) ?? article.title,
                        font: .preferredFont(forTextStyle: .title2, weight: .bold)
                    )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 12)

                    SeekBarView(
                        currentTime: Binding(
                            get: { currentTime },
                            set: { currentTime = $0 }
                        ),
                        duration: duration,
                        isDisabled: isAd,
                        segments: sponsorSegments.map { (start: $0.startTime, end: $0.endTime) },
                        onSeek: { seek(to: $0) }
                    )
                    .padding(.horizontal)
                    .padding(.top, 16)

                    HStack(spacing: 32) {
                        Button {
                            togglePiP()
                        } label: {
                            Image(systemName: "pip.enter")
                                .font(.title2)
                        }
                        .disabled(isAd)
                        .opacity(isAd ? 0.5 : 1.0)

                        Button {
                            rewind()
                        } label: {
                            Image(systemName: "gobackward.10")
                                .font(.title2)
                        }
                        .disabled(isAd)
                        .opacity(isAd ? 0.5 : 1.0)

                        Button {
                            togglePlayPause()
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 56))
                        }

                        Button {
                            if isAd && isAdSkippable {
                                skipAd()
                            } else {
                                fastForward()
                            }
                        } label: {
                            Image(systemName: isAd
                                ? "forward.end.fill"
                                : "goforward.10")
                                .font(.title2)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .disabled(isAd && !isAdSkippable)
                        .opacity((isAd && !isAdSkippable) ? 0.5 : 1.0)

                        Button {
                            enterFullscreen()
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.title2)
                        }
                        .disabled(isAd)
                        .opacity(isAd ? 0.5 : 1.0)
                    }
                    .foregroundStyle(.primary)
                    .padding(.top, 16)

                    if isAd, let advertiserURL {
                        Button {
                            openURL(advertiserURL)
                        } label: {
                            Text(String(localized: "YouTube.VisitAdvertiser", table: "Integrations"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }

                    if let feed {
                        HStack(alignment: .top, spacing: 12) {
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
                        .padding(.horizontal)
                        .padding(.top, 20)
                    } else if article.isEphemeral, let fetchedAuthor {
                        HStack(alignment: .top, spacing: 12) {
                            Text(fetchedAuthor)
                                .font(.subheadline.bold())
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }

                    descriptionActionButtons

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
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }

                    Spacer()
                        .frame(height: 32)
                }
            }
            .ignoresSafeArea(.all, edges: [.top])
        }
        .sakuraBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { playerToolbar }
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            let orientation = UIDevice.current.orientation
            if orientation.isLandscape {
                enterFullscreen()
            }
        }
        .onChange(of: isPlaying) { _, newValue in
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
            checkSponsorSegments(at: newTime)
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
            if !isPiP {
                pauseForOtherPlayer()
                YouTubeAudioSession.deactivate()
            }
        }
        .task {
            activateBackgroundAudioSession()
            isBookmarked = article.isBookmarked
            let signedIn = await YouTubePlayerView.hasYouTubeSession()
            let premium = signedIn ? await YouTubePlayerView.hasYouTubePremium() : false
            isPiPEligible = signedIn && premium

            if let loadedFeed = feedManager.feed(forArticle: article) {
                feed = loadedFeed
                if let data = loadedFeed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                favicon = await FaviconCache.shared.favicon(for: loadedFeed)
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
        .translationTask(translationConfig) { session in
            await handleTranslation(session: session)
        }
        .navigationDestination(item: $imageViewerURL) { url in
            ImageViewerView(url: url)
                .navigationTransition(.zoom(sourceID: url, in: imageViewerNamespace))
        }
    }

}
