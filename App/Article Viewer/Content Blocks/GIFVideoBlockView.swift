import SwiftUI
import AVKit
import Hanami

/// Plays X-style GIFs (short MP4s) the way X does: autoplaying, looping,
/// muted, and without playback controls.
struct GIFVideoBlockView: View {

    let url: URL
    var aspectRatio: CGFloat = 16 / 9

    var body: some View {
        LoopingVideoPlayerRepresentable(url: url)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: 12))
            .articleMediaWidthCap()
    }
}

private struct LoopingVideoPlayerRepresentable: UIViewRepresentable {

    let url: URL

    func makeUIView(context: Context) -> LoopingVideoPlayerUIView {
        LoopingVideoPlayerUIView(url: url)
    }

    func updateUIView(_ view: LoopingVideoPlayerUIView, context: Context) {
        view.replaceVideo(url: url)
    }

    static func dismantleUIView(_ view: LoopingVideoPlayerUIView, coordinator: ()) {
        view.stop()
    }
}

final class LoopingVideoPlayerUIView: UIView {

    private var currentURL: URL
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?

    override static var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer {
        // swiftlint:disable:next force_cast
        layer as! AVPlayerLayer
    }

    init(url: URL) {
        self.currentURL = url
        super.init(frame: .zero)
        playerLayer.videoGravity = .resizeAspect
        startPlayback(url: url)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func replaceVideo(url: URL) {
        guard url != currentURL else { return }
        currentURL = url
        startPlayback(url: url)
    }

    func stop() {
        queuePlayer?.pause()
        queuePlayer = nil
        playerLooper = nil
        playerLayer.player = nil
    }

    private func startPlayback(url: URL) {
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        playerLayer.player = player
        queuePlayer = player
        player.play()
    }
}
