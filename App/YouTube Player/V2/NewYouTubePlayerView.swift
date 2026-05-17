import AVKit
import SwiftUI
import Hanami
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
    let playback: NewYouTubePlaybackController
    @State var feed: Feed?
    @State var icon: UIImage?
    @State var acronymIcon: UIImage?
    @State var isBookmarked = false
    @State var fetchedMetadata: YouTubeVideoMetadata?

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

    init(
        article: Article,
        playback: NewYouTubePlaybackController = .shared,
        showsDismissButton: Bool = false
    ) {
        self.article = article
        self.playback = playback
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
        .background {
            YouTubeTimeObserver(
                currentTime: { playback.currentTime },
                onTimeChange: { newTime in checkSponsorSegments(at: newTime) }
            )
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
                VStack(spacing: 12) {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                        Text(String(localized: "YouTube.NewPlayer.LoadFailed", table: "Integrations"))
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                    Button {
                        Task {
                            loadState = .loading
                            await loadStream()
                        }
                    } label: {
                        Text(String(localized: "YouTube.NewPlayer.Retry", table: "Integrations"))
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
            }
        }
    }

    @ViewBuilder
    private var descriptionContent: some View {
        VStack(spacing: 16) {
            WordWrappingText(
                displayTitle,
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
            } else if article.isEphemeral, let metadata = fetchedMetadata,
                      !metadata.uploader.isEmpty {
                ephemeralUploaderRow(metadata: metadata)
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

}
