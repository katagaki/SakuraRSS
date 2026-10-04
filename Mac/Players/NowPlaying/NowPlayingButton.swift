import Hanami
import SwiftUI

/// The toolbar's mini player, for whichever of the podcast or YouTube player
/// is active, so playback stays reachable after leaving its page.
struct NowPlayingButton: View {

    let player: AudioPlayer
    let session: YouTubePlayerSession
    let onShowContent: (Int64) -> Void
    @State private var isShowingControls = false

    var body: some View {
        if let articleID = player.currentArticleID {
            button(artworkURL: player.currentArtworkURL, isPlaying: player.isPlaying, aspectRatio: 1) {
                NowPlayingPopover(player: player) {
                    isShowingControls = false
                    onShowContent(articleID)
                }
            }
        } else if session.isActive, let article = session.currentArticle {
            button(artworkURL: session.artworkURL?.absoluteString, isPlaying: session.isPlaying, aspectRatio: 16 / 9) {
                YouTubeNowPlayingPopover(session: session) {
                    isShowingControls = false
                    onShowContent(article.id)
                }
            }
        }
    }

    private func button<Popover: View>(
        artworkURL: String?,
        isPlaying: Bool,
        aspectRatio: CGFloat,
        @ViewBuilder popover: @escaping () -> Popover
    ) -> some View {
        Button {
            isShowingControls.toggle()
        } label: {
            HStack(spacing: 6) {
                TodayThumbnail(urlString: artworkURL)
                    .frame(width: 22 * aspectRatio, height: 22)
                    .clipShape(.rect(cornerRadius: 5))
                Image(systemName: isPlaying ? "waveform" : "pause.fill")
                    .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16)
            }
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .help(String(localized: "Player.NowPlaying", table: "Mac"))
        .popover(isPresented: $isShowingControls, arrowEdge: .bottom, content: popover)
    }
}
