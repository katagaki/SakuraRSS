import SwiftUI
import FoundationModels
@preconcurrency import Translation

struct PodcastEpisodeView: View {

    @Environment(FeedManager.self) var feedManager
    let article: Article
    private let audioPlayer = AudioPlayer.shared

    @State private var favicon: UIImage?
    @State private var feedName: String?
    @State private var acronymIcon: UIImage?

    @AppStorage("Podcast.PlaybackSpeed") private var playbackSpeed: Double = 1.0

    private let playbackSpeedPresets: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    // Downloads
    private let downloadManager = PodcastDownloadManager.shared
    private let networkMonitor = NetworkMonitor.shared
    @State var isDownloaded: Bool = false
    // Transcript
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

    // Translation state
    @State var translatedText: String?
    @State var translatedSummary: String?
    @State var isTranslating = false
    @State var translationConfig: TranslationSession.Configuration?
    @State var showingTranslation = false

    // Summarization state
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

    private var isThisEpisode: Bool {
        audioPlayer.currentArticleID == article.id
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
        ScrollView {
            VStack(spacing: 24) {
                // Artwork
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
                }

                // Title and metadata
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

                // Playback controls
                if isThisEpisode {
                    VStack(spacing: 12) {
                        // Seek bar
                        SeekBarView(
                            currentTime: Binding(
                                get: { audioPlayer.currentTime },
                                set: { audioPlayer.currentTime = $0 }
                            ),
                            duration: audioPlayer.duration,
                            onSeek: { audioPlayer.seek(to: $0) }
                        )

                        // Transport controls with transcript toggle and speed
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
                    // Not currently playing - show play button with download
                    HStack(spacing: 12) {
                        Button {
                            startPlayback()
                        } label: {
                            Label(
                                isOffline && !isDownloaded ? "Podcast.Offline" : "Podcast.Play",
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

                // Action buttons
                actionButtons

                // Transcript / Episode description
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
                                Text("AppleIntelligence.VerifyImportantInformation")
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
            // When the user starts interacting with the scroll view while the
            // transcript is showing, disable auto-follow so the transcript
            // doesn't snap back to the active segment while they're reading.
            if showingTranscript,
               isTranscriptAutoScrolling,
               newPhase == .interacting || newPhase == .tracking {
                isTranscriptAutoScrolling = false
            }
        }
        .overlay(alignment: .bottom) {
            followAlongOverlay(scrollProxy: scrollProxy)
        }
        } // ScrollViewReader
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
                        Label("Article.Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            feedManager.markRead(article)
            if let feed = feedManager.feed(forArticle: article) {
                feedName = feed.title
                if let data = feed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                favicon = await FaviconCache.shared.favicon(for: feed.domain, siteURL: feed.siteURL)
            }
            // Load cached summary/translation
            if let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
               !cached.isEmpty {
                hasCachedSummary = true
            }
            if let cached = try? DatabaseManager.shared.cachedArticleTranslation(for: article.id),
               let text = cached.text, !text.isEmpty {
                translatedText = text
            }
            // Load download/transcript state
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
        .alert("Article.Summarize.Error", isPresented: Binding(
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

    private var transcriptToggle: some View {
        Button {
            withAnimation(.smooth.speed(2.0)) {
                showingTranscript.toggle()
            }
        } label: {
            Image(systemName: "quote.bubble")
                .font(.title3)
                .foregroundStyle(showingTranscript ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        }
        .buttonStyle(.plain)
        .disabled(transcript == nil)
    }

    private var playbackSpeedMenu: some View {
        Menu {
            Picker("Podcast.PlaybackSpeed", selection: $playbackSpeed) {
                ForEach(playbackSpeedPresets, id: \.self) { preset in
                    Text(formatSpeed(preset))
                        .tag(preset)
                }
            }
        } label: {
            Image(systemName: gaugeIcon(for: playbackSpeed))
                .font(.title3)
                .foregroundStyle(.primary)
        }
        .onChange(of: playbackSpeed) { _, newValue in
            audioPlayer.setPlaybackRate(Float(newValue))
        }
    }

    private func gaugeIcon(for speed: Double) -> String {
        switch speed {
        case ...0.75:
            return "gauge.with.dots.needle.0percent"
        case 0.76...1.0:
            return "gauge.with.dots.needle.33percent"
        case 1.01...1.5:
            return "gauge.with.dots.needle.50percent"
        case 1.51...2.0:
            return "gauge.with.dots.needle.67percent"
        default:
            return "gauge.with.dots.needle.100percent"
        }
    }

    private func formatSpeed(_ speed: Double) -> String {
        if speed == floor(speed) {
            return "\(Int(speed))×"
        }
        let formatted = String(format: "%g", speed)
        return "\(formatted)×"
    }

    func startPlayback() {
        let playbackURL: URL
        if let localURL = downloadManager.localFileURL(for: article.id) {
            playbackURL = localURL
        } else if let audioURLString = article.audioURL,
                  let audioURL = URL(string: audioURLString) {
            playbackURL = audioURL
        } else {
            return
        }
        let feed = feedManager.feed(forArticle: article)
        audioPlayer.play(
            url: playbackURL,
            articleID: article.id,
            feedID: article.feedID,
            episodeTitle: article.title,
            feedTitle: feed?.title ?? "",
            artworkURL: article.imageURL,
            feedIconURL: feed?.faviconURL,
            episodeDuration: article.duration
        )
    }

}
