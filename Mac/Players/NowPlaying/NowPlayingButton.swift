import Hanami
import SwiftUI

/// The toolbar's mini player: the playing episode's artwork, with its
/// controls in a popover, so playback stays reachable after leaving its page.
struct NowPlayingButton: View {

    let player: AudioPlayer
    let onShowEpisode: (Int64) -> Void
    @State private var isShowingControls = false

    var body: some View {
        if let articleID = player.currentArticleID {
            Button {
                isShowingControls.toggle()
            } label: {
                HStack(spacing: 6) {
                    TodayThumbnail(urlString: player.currentArtworkURL)
                        .frame(width: 22, height: 22)
                        .clipShape(.rect(cornerRadius: 5))
                    Image(systemName: player.isPlaying ? "waveform" : "pause.fill")
                        .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 16)
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)
            .help(String(localized: "Player.NowPlaying", table: "Mac"))
            .popover(isPresented: $isShowingControls, arrowEdge: .bottom) {
                NowPlayingPopover(player: player) {
                    isShowingControls = false
                    onShowEpisode(articleID)
                }
            }
        }
    }
}
