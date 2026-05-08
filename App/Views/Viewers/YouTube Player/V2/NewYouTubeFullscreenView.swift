import AVKit
import SwiftUI

/// Fullscreen presentation for the experimental YouTube player. Renders the
/// shared `AVPlayer` in a new layer so the inline player keeps its Picture
/// in Picture wiring intact.
struct NewYouTubeFullscreenView: View {

    let playback: NewYouTubePlaybackController
    let sponsorSegments: [SponsorSegment]
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black

            NewYouTubePlayerLayerOnlyRepresentable(controller: playback)
                .aspectRatio(playback.aspectRatio, contentMode: .fit)
        }
        .overlay {
            NewYouTubePlayerOverlayControls(
                playback: playback,
                trailingAction: .exitFullscreen(onDismiss),
                sponsorSegments: sponsorSegments
            )
        }
        .ignoresSafeArea()
        .statusBarHidden()
    }
}

private struct NewYouTubePlayerLayerOnlyRepresentable: UIViewRepresentable {

    let controller: NewYouTubePlaybackController

    func makeUIView(context: Context) -> NewYouTubePlayerLayerView {
        let view = NewYouTubePlayerLayerView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = controller.player
        return view
    }

    func updateUIView(_ view: NewYouTubePlayerLayerView, context: Context) {
        if view.playerLayer.player !== controller.player {
            view.playerLayer.player = controller.player
        }
    }

    static func dismantleUIView(_ view: NewYouTubePlayerLayerView, coordinator: ()) {
        view.playerLayer.player = nil
    }
}
