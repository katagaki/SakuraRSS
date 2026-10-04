import Hanami
import SwiftUI

struct YouTubeNowPlayingPopover: View {

    let session: YouTubePlayerSession
    let onShowVideo: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                TodayThumbnail(urlString: session.artworkURL?.absoluteString)
                    .frame(width: 96, height: 54)
                    .clipShape(.rect(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.videoTitle ?? "")
                        .font(.headline)
                        .lineLimit(2)
                    Text(session.channelTitle ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 28) {
                Button { session.togglePlayPause() } label: {
                    Image(systemName: session.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .symbolRenderingMode(.hierarchical)
                }
                Button { session.stop() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18))
                }
            }
            .buttonStyle(.plain)
            Button(String(localized: "Player.ShowVideo", table: "Mac"), action: onShowVideo)
                .buttonStyle(.link)
        }
        .padding(18)
        .frame(width: 340)
    }
}
