import SwiftUI
import AVKit
import Hanami

struct VideoBlockView: View {

    let url: URL
    var aspectRatio: CGFloat = 16 / 9

    var body: some View {
        VideoPlayerRepresentable(url: url)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: 12))
            .articleMediaWidthCap()
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

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) {
        controller.player?.pause()
        controller.player = nil
    }
}
