import SwiftUI
import AVKit

/// Renders a video content block inline in the article detail view.
/// Wraps `AVPlayerViewController` so users get scrubbing, fullscreen, and
/// Picture-in-Picture controls for free. Works with any AVPlayer-compatible
/// URL (HLS, MP4, etc.), so it isn't tied to Reddit specifically.
struct VideoBlockView: View {

    let url: URL

    var body: some View {
        VideoPlayerRepresentable(url: url)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct VideoPlayerRepresentable: UIViewControllerRepresentable {

    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: url)
        controller.allowsPictureInPicturePlayback = true
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if (controller.player?.currentItem?.asset as? AVURLAsset)?.url != url {
            controller.player = AVPlayer(url: url)
        }
    }
}
