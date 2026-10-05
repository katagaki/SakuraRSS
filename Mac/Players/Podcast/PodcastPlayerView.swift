import Hanami
import SwiftUI

/// What the reader shows for a podcast episode: the shared player's controls
/// above the episode's notes, or its transcript once one has been made.
struct PodcastPlayerView: View {

    let article: Article
    let feed: Feed?
    let feedManager: FeedManager
    private let player = AudioPlayer.shared
    private let downloadManager = PodcastDownloadManager.shared
    @State private var transcript: [TranscriptSegment]?
    @State private var showingTranscript = false
    @State private var isTranscriptAutoScrolling = true

    private var isCurrentEpisode: Bool {
        player.currentArticleID == article.id
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 20) {
                    header
                    if isCurrentEpisode {
                        PodcastScrubber(player: player)
                    }
                    HStack(spacing: 20) {
                        PodcastPlaybackControls(player: player, isCurrentEpisode: isCurrentEpisode) {
                            PodcastPlayback.start(article, feedManager: feedManager)
                        }
                        PodcastDownloadButton(article: article, size: 26, lineWidth: 3)
                        transcriptToggle
                    }
                    if showingTranscript, let transcript, !transcript.isEmpty {
                        TranscriptView(
                            segments: transcript,
                            currentTime: isCurrentEpisode ? player.currentTime() : 0,
                            isPlaying: isCurrentEpisode && player.isPlaying,
                            onSeek: seek,
                            scrollProxy: scrollProxy,
                            isAutoScrolling: $isTranscriptAutoScrolling
                        )
                    } else {
                        PodcastEpisodeNotes(article: article)
                    }
                }
                .padding(32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .task(id: article.id) { loadTranscript() }
        .onChange(of: downloadManager.activeDownloads[article.id]?.state) { _, state in
            if state == .completed || state == nil {
                loadTranscript()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 20) {
            TodayThumbnail(urlString: article.imageURL ?? feed?.iconURL)
                .frame(width: 220, height: 220)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(radius: 12, y: 6)
            VStack(spacing: 4) {
                Text(article.displayTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                if let feed {
                    Text(feed.title)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var transcriptToggle: some View {
        Button {
            withAnimation(.smooth.speed(2.0)) {
                showingTranscript.toggle()
            }
        } label: {
            Image(systemName: "quote.bubble")
                .font(.system(size: 20))
                .foregroundStyle(showingTranscript ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.plain)
        .disabled(transcript?.isEmpty ?? true)
        .help(String(localized: "Transcripts.Title", table: "Podcast"))
    }

    private func loadTranscript() {
        let cached = try? DatabaseManager.shared.cachedTranscript(for: article.id)
        transcript = (cached?.isEmpty ?? true) ? nil : cached
    }

    /// Starts the episode first when the transcript is read before it plays.
    private func seek(to time: TimeInterval) {
        if !isCurrentEpisode {
            PodcastPlayback.start(article, feedManager: feedManager)
        }
        player.seek(to: time)
    }
}
