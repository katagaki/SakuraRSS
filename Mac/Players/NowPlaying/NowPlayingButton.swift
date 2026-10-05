import Hanami
import SwiftUI

/// The toolbar's mini player, for whichever of the podcast or YouTube player
/// is active, so playback stays reachable after leaving its page.
struct NowPlayingButton: View {

    let player: AudioPlayer
    let session: YouTubePlayerSession
    let onShowContent: (Int64) -> Void
    @State private var isShowingControls = false

    static func hasContent(player: AudioPlayer, session: YouTubePlayerSession) -> Bool {
        player.currentArticleID != nil || (session.isActive && session.currentArticle != nil)
    }

    var body: some View {
        if let articleID = player.currentArticleID {
            button(
                artworkURL: player.currentArtworkURL,
                isPlaying: player.isPlaying,
                aspectRatio: 1,
                elapsedFraction: { [player] in
                    player.duration > 0 ? player.currentTime() / player.duration : 0
                },
                popover: {
                    NowPlayingPopover(player: player) {
                        isShowingControls = false
                        onShowContent(articleID)
                    }
                }
            )
        } else if session.isActive, let article = session.currentArticle {
            button(
                artworkURL: session.artworkURL?.absoluteString,
                isPlaying: session.isPlaying,
                aspectRatio: 16 / 9,
                elapsedFraction: { [session] in
                    session.duration > 0 ? session.currentTime / session.duration : 0
                },
                popover: {
                    YouTubeNowPlayingPopover(session: session) {
                        isShowingControls = false
                        onShowContent(article.id)
                    }
                }
            )
        }
    }

    private func button<Popover: View>(
        artworkURL: String?,
        isPlaying: Bool,
        aspectRatio: CGFloat,
        elapsedFraction: @escaping () -> Double,
        @ViewBuilder popover: @escaping () -> Popover
    ) -> some View {
        Button {
            isShowingControls.toggle()
        } label: {
            HStack(spacing: 6) {
                TodayThumbnail(urlString: artworkURL)
                    .frame(width: 22 * aspectRatio, height: 22)
                    .clipShape(.rect(cornerRadius: 5))
                PlaybackProgressDonut(isPlaying: isPlaying, elapsedFraction: elapsedFraction)
                    .frame(width: 16, height: 16)
            }
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .help(String(localized: "Player.NowPlaying", table: "Mac"))
        .popover(isPresented: $isShowingControls, arrowEdge: .bottom, content: popover)
    }
}
