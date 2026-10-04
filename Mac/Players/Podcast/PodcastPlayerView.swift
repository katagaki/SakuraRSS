import Hanami
import SwiftUI

/// What the reader shows for a podcast episode: the shared player's controls
/// above the episode's notes.
struct PodcastPlayerView: View {

    let article: Article
    let feed: Feed?
    let feedManager: FeedManager
    private let player = AudioPlayer.shared

    private var isCurrentEpisode: Bool {
        player.currentArticleID == article.id
    }

    var body: some View {
        ScrollView {
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
                if isCurrentEpisode {
                    PodcastScrubber(player: player)
                }
                PodcastPlaybackControls(player: player, isCurrentEpisode: isCurrentEpisode) {
                    PodcastPlayback.start(article, feedManager: feedManager)
                }
                PodcastEpisodeNotes(article: article)
            }
            .padding(32)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }
}
