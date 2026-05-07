import AVKit
import SwiftUI

/// Hosts an `AVPlayerViewController` for the experimental YouTube player.
struct NewYouTubePlayerRepresentable: UIViewControllerRepresentable {

    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        YouTubeAudioSession.prepare()
        YouTubeAudioSession.activate()

        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: url)
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.videoGravity = .resizeAspect
        controller.player?.play()
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        let currentURL = (controller.player?.currentItem?.asset as? AVURLAsset)?.url
        if currentURL != url {
            controller.player = AVPlayer(url: url)
            controller.player?.play()
        }
    }

    static func dismantleUIViewController(
        _ controller: AVPlayerViewController,
        coordinator: Coordinator
    ) {
        controller.player?.pause()
        controller.player = nil
        YouTubeAudioSession.deactivate()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {}
}
