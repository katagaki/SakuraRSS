import AVKit
import SwiftUI

/// Hosts an `AVPlayerLayer` for the experimental YouTube player. The
/// underlying `AVPlayer` is owned by `NewYouTubePlaybackController.shared`,
/// so it survives this view being torn down (sheet dismissal, navigation).
struct NewYouTubePlayerRepresentable: UIViewRepresentable {

    let controller: NewYouTubePlaybackController

    func makeUIView(context: Context) -> NewYouTubePlayerLayerView {
        let view = NewYouTubePlayerLayerView()
        view.playerLayer.videoGravity = .resizeAspect
        controller.attach(layer: view.playerLayer)
        return view
    }

    func updateUIView(_ view: NewYouTubePlayerLayerView, context: Context) {
        if view.playerLayer.player !== controller.player {
            controller.attach(layer: view.playerLayer)
        }
    }

    static func dismantleUIView(_ view: NewYouTubePlayerLayerView, coordinator: ()) {
        view.playerLayer.player = nil
    }
}

final class NewYouTubePlayerLayerView: UIView {

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        // swiftlint:disable:next force_cast
        layer as! AVPlayerLayer
    }
}
