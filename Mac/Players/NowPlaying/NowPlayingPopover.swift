import Hanami
import SwiftUI

struct NowPlayingPopover: View {

    let player: AudioPlayer
    let onShowEpisode: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                TodayThumbnail(urlString: player.currentArtworkURL)
                    .frame(width: 56, height: 56)
                    .clipShape(.rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentEpisodeTitle ?? "")
                        .font(.headline)
                        .lineLimit(2)
                    Text(player.currentFeedTitle ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            PodcastScrubber(player: player)
            PodcastPlaybackControls(player: player, isCurrentEpisode: true) {}
            Button(String(localized: "Player.ShowEpisode", table: "Mac"), action: onShowEpisode)
                .buttonStyle(.link)
        }
        .padding(18)
        .frame(width: 340)
    }
}
