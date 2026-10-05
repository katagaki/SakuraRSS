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
                VStack(alignment: .leading, spacing: 24) {
                    header
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
                .frame(maxWidth: 820)
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

    /// The artwork beside the episode's details and controls, as a Mac
    /// player lays out, rather than stacked as on a phone.
    private var header: some View {
        HStack(alignment: .center, spacing: 28) {
            TodayThumbnail(urlString: article.imageURL ?? feed?.iconURL)
                .frame(width: 200, height: 200)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(radius: 12, y: 6)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.displayTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(3)
                        .textSelection(.enabled)
                    if let feed {
                        Text(feed.title)
                            .foregroundStyle(.secondary)
                    }
                }
                if isCurrentEpisode {
                    PodcastScrubber(player: player)
                }
                PodcastPlaybackControls(player: player, isCurrentEpisode: isCurrentEpisode) {
                    PodcastPlayback.start(article, feedManager: feedManager)
                }
                HStack(spacing: 8) {
                    PodcastDownloadControl(article: article)
                    transcriptToggle
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var transcriptToggle: some View {
        Toggle(isOn: $showingTranscript.animation(.smooth.speed(2.0))) {
            Label(String(localized: "Transcripts.Title", table: "Podcast"), systemImage: "quote.bubble")
        }
        .toggleStyle(.button)
        .disabled(transcript?.isEmpty ?? true)
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
