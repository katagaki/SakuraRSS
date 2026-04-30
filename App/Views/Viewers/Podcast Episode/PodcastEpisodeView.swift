import SwiftUI
import FoundationModels
@preconcurrency import Translation

struct PodcastEpisodeView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) private var dismiss
    let article: Article
    var showsDismissButton: Bool = false
    let audioPlayer = AudioPlayer.shared

    @State var favicon: UIImage?
    @State var feedName: String?
    @State var acronymIcon: UIImage?

    @AppStorage("Podcast.PlaybackSpeed") var playbackSpeed: Double = 1.0

    let playbackSpeedPresets: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    let downloadManager = PodcastDownloadManager.shared
    let networkMonitor = NetworkMonitor.shared
    @State var isDownloaded: Bool = false
    @State var transcript: [TranscriptSegment]?
    @State var showingTranscript: Bool = false
    @State var isTranscriptAutoScrolling: Bool = true

    var isOffline: Bool {
        !networkMonitor.isOnline
    }

    var downloadProgress: DownloadProgress? {
        downloadManager.activeDownloads[article.id]
    }

    var canPlay: Bool {
        isDownloaded || !isOffline
    }

    var canDownload: Bool {
        !isDownloaded && !isOffline && downloadProgress == nil
    }

    @State var translatedText: String?
    @State var translatedSummary: String?
    @State var isTranslating = false
    @State var translationConfig: TranslationSession.Configuration?
    @State var showingTranslation = false

    @State var summarizedText: String?
    @State var isSummarizing = false
    @State var hasCachedSummary = false
    @State var showingSummary = false
    @State var summarizationError: String?

    var isAppleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var hasTranslationForCurrentMode: Bool {
        if showingSummary {
            return translatedSummary != nil
        }
        return translatedText != nil
    }

    var displayText: String? {
        guard let summary = article.summary, !summary.isEmpty else { return nil }
        if showingSummary, let summarizedText {
            if showingTranslation, let translatedSummary {
                return translatedSummary
            }
            return summarizedText
        }
        if showingTranslation, let translatedText {
            return translatedText
        }
        return summary
    }

    var isThisEpisode: Bool {
        audioPlayer.currentArticleID == article.id
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 24) {
                    if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                        CachedAsyncImage(url: url) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.secondary.opacity(0.15))
                                .aspectRatio(1, contentMode: .fit)
                        }
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 300, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.quaternary, lineWidth: 0.5)
                        )
                        .shadow(radius: 8, y: 4)
                        .padding(.horizontal, 40)
                    } else if let feedIcon = favicon ?? acronymIcon {
                        Image(uiImage: feedIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 300, maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.quaternary, lineWidth: 0.5)
                            )
                            .shadow(radius: 8, y: 4)
                            .padding(.horizontal, 40)
                    }

                    VStack(spacing: 8) {
                        Text(article.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 8) {
                            if let favicon {
                                FaviconImage(favicon, size: 18, cornerRadius: 4, skipInset: true)
                            } else if let acronymIcon {
                                FaviconImage(acronymIcon, size: 18, cornerRadius: 4, skipInset: true)
                            } else if let feedName {
                                InitialsAvatarView(feedName, size: 18, cornerRadius: 4)
                            }

                            if let feedName {
                                Text(feedName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let date = article.publishedDate {
                                Text("·")
                                    .foregroundStyle(.tertiary)
                                RelativeTimeText(date: date)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)

                    if isThisEpisode {
                        VStack(spacing: 12) {
                            SeekBarView(
                                currentTime: Binding(
                                    get: { audioPlayer.currentTime },
                                    set: { audioPlayer.currentTime = $0 }
                                ),
                                duration: audioPlayer.duration,
                                onSeek: { audioPlayer.seek(to: $0) }
                            )

                            HStack {
                                transcriptToggle
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                HStack(spacing: 40) {
                                    Button { audioPlayer.skipBackward() } label: {
                                        Image(systemName: "gobackward.15")
                                            .font(.title2)
                                    }

                                    Button { audioPlayer.togglePlayPause() } label: {
                                        Image(systemName: audioPlayer.isPlaying
                                              ? "pause.circle.fill"
                                              : "play.circle.fill")
                                            .font(.system(size: 72))
                                    }

                                    Button { audioPlayer.skipForward() } label: {
                                        Image(systemName: "goforward.30")
                                            .font(.title2)
                                    }
                                }

                                playbackSpeedMenu
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .foregroundStyle(.primary)
                        }
                        .padding(.horizontal)
                    } else {
                        HStack(spacing: 12) {
                            Button {
                                startPlayback()
                            } label: {
                                Label(
                                    isOffline && !isDownloaded ? String(
                                        localized: "Offline",
                                        table: "Podcast"
                                    ) : String(
                                        localized: "Play",
                                        table: "Podcast"
                                    ),
                                    systemImage: "play.fill"
                                )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canPlay)

                            PodcastDownloadButton(article: article, size: 50, lineWidth: 3.5)
                        }
                        .padding(.horizontal)

                        if audioPlayer.isLoading && audioPlayer.currentArticleID == article.id {
                            ProgressView()
                        }
                    }

                    Group {
                        if showingTranscript, let transcript, !transcript.isEmpty {
                            TranscriptView(
                                segments: transcript,
                                currentTime: audioPlayer.currentTime,
                                isPlaying: audioPlayer.isPlaying,
                                onSeek: { audioPlayer.seek(to: $0) },
                                scrollProxy: scrollProxy,
                                isAutoScrolling: $isTranscriptAutoScrolling
                            )
                            .transition(.blurReplace)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
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
                                if let text = displayText {
                                    SelectableText(text)
                                        .id("\(showingSummary)-\(showingTranslation)")
                                        .transition(.blurReplace)
                                }
                            }
                        }
                    }
                    .animation(.smooth.speed(2.0), value: showingSummary)
                    .animation(.smooth.speed(2.0), value: showingTranslation)
                    .animation(.smooth.speed(2.0), value: showingTranscript)
                    .animation(.smooth.speed(2.0), value: translatedText)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .onScrollPhaseChange { _, newPhase in
                if showingTranscript, isTranscriptAutoScrolling,
                   newPhase == .interacting || newPhase == .tracking {
                    isTranscriptAutoScrolling = false
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
            .overlay(alignment: .bottom) {
                followAlongOverlay(scrollProxy: scrollProxy)
            }
        }
        .sakuraBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityLabel(String(localized: "Article.Dismiss", table: "Articles"))
                }
            }
            if let activityLabel = toolbarActivityLabel {
                ToolbarItem(placement: .principal) {
                    ToolbarActivityIndicator(label: activityLabel)
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    feedManager.toggleBookmark(article)
                } label: {
                    Image(systemName: article.isBookmarked ? "bookmark.fill" : "bookmark")
                }
                overflowMenu
            }
        }
        .task {
            feedManager.markRead(article)
            if let feed = feedManager.feed(forArticle: article) {
                feedName = feed.title
                if let data = feed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                favicon = await FaviconCache.shared.favicon(for: feed)
            }
            if let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
               !cached.isEmpty {
                hasCachedSummary = true
            }
            if let cached = try? DatabaseManager.shared.cachedArticleTranslation(for: article.id),
               let text = cached.text, !text.isEmpty {
                translatedText = text
            }
            isDownloaded = downloadManager.isDownloaded(articleID: article.id)
            if let cached = try? DatabaseManager.shared.cachedTranscript(for: article.id),
               !cached.isEmpty {
                transcript = cached
            }
        }
        .onChange(of: downloadProgress?.state) { _, newState in
            if newState == .completed || newState == nil {
                isDownloaded = downloadManager.isDownloaded(articleID: article.id)
                if let cached = try? DatabaseManager.shared.cachedTranscript(for: article.id),
                   !cached.isEmpty {
                    transcript = cached
                }
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
    }
}
