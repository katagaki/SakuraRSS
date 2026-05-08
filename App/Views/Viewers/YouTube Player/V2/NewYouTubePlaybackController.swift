import AVFoundation
import AVKit
import Foundation
import SwiftUI

/// Controls and observes an `AVPlayer` for the experimental YouTube player.
/// Implemented as a singleton so playback survives the player view being
/// dismissed (audio continues in the background, Picture in Picture continues
/// in the floating window).
@MainActor
@Observable
final class NewYouTubePlaybackController: NSObject {

    static let shared = NewYouTubePlaybackController()

    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var videoSize: CGSize = .zero
    var isPictureInPictureActive: Bool = false
    var isPictureInPicturePossible: Bool = false

    var audioOptions: [AVMediaSelectionOption] = []
    var subtitleOptions: [AVMediaSelectionOption] = []
    var currentAudioOption: AVMediaSelectionOption?
    var currentSubtitleOption: AVMediaSelectionOption?

    @ObservationIgnored var player: AVPlayer?
    @ObservationIgnored var currentVideoID: String?
    @ObservationIgnored private var pictureInPictureController: AVPictureInPictureController?

    @ObservationIgnored private var timeObserverToken: Any?
    @ObservationIgnored private var rateObservation: NSKeyValueObservation?
    @ObservationIgnored private var presentationSizeObservation: NSKeyValueObservation?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var pipPossibleObservation: NSKeyValueObservation?
    @ObservationIgnored private var audioGroup: AVMediaSelectionGroup?
    @ObservationIgnored private var subtitleGroup: AVMediaSelectionGroup?

    var aspectRatio: CGFloat {
        guard videoSize.width > 0, videoSize.height > 0 else { return 16.0 / 9.0 }
        return videoSize.width / videoSize.height
    }

    private override init() { super.init() }

    /// Loads a new HLS stream for the given video. If the same video is already
    /// loaded, this is a no-op and the existing player keeps playing.
    func load(url: URL, videoID: String) {
        if currentVideoID == videoID, player != nil { return }
        clear()
        YouTubeAudioSession.prepare()
        YouTubeAudioSession.activate()
        let newPlayer = AVPlayer(url: url)
        attach(player: newPlayer)
        currentVideoID = videoID
        newPlayer.play()
    }

    /// Stops playback, releases the player, and deactivates the audio session.
    func clear() {
        if let pictureInPictureController, pictureInPictureController.isPictureInPictureActive {
            pictureInPictureController.stopPictureInPicture()
        }
        detachObservers()
        player?.pause()
        pictureInPictureController = nil
        player = nil
        currentVideoID = nil
        YouTubeAudioSession.deactivate()
    }

    /// Connects a player layer (from the on-screen view) so we can drive
    /// programmatic Picture in Picture.
    func attach(layer: AVPlayerLayer) {
        layer.player = player
        let controller = AVPictureInPictureController(playerLayer: layer)
        controller?.delegate = self
        controller?.canStartPictureInPictureAutomaticallyFromInline = true
        pipPossibleObservation = controller?.observe(
            \.isPictureInPicturePossible, options: [.initial, .new]
        ) { [weak self] observed, _ in
            let possible = observed.isPictureInPicturePossible
            Task { @MainActor in
                self?.isPictureInPicturePossible = possible
            }
        }
        pictureInPictureController = controller
    }

    private func attach(player: AVPlayer) {
        detachObservers()
        self.player = player

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval, queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                let seconds = time.seconds
                if seconds.isFinite {
                    self.currentTime = seconds
                }
                if let item = player.currentItem {
                    let durationSeconds = item.duration.seconds
                    if durationSeconds.isFinite, durationSeconds > 0,
                       self.duration != durationSeconds {
                        self.duration = durationSeconds
                    }
                }
            }
        }

        rateObservation = player.observe(\.rate, options: [.initial, .new]) { [weak self] observed, _ in
            let rate = observed.rate
            Task { @MainActor in
                self?.isPlaying = rate > 0
            }
        }

        if let item = player.currentItem {
            attach(item: item)
        }
    }

    private func attach(item: AVPlayerItem) {
        presentationSizeObservation = item.observe(
            \.presentationSize, options: [.initial, .new]
        ) { [weak self] observed, _ in
            let size = observed.presentationSize
            Task { @MainActor in
                self?.videoSize = size
            }
        }

        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
            let status = observed.status
            guard status == .readyToPlay else { return }
            Task { @MainActor in
                await self?.loadMediaSelectionOptions(for: observed)
            }
        }
    }

    private func loadMediaSelectionOptions(for item: AVPlayerItem) async {
        let asset = item.asset
        let audible = try? await asset.loadMediaSelectionGroup(for: .audible)
        let legible = try? await asset.loadMediaSelectionGroup(for: .legible)

        audioGroup = audible
        subtitleGroup = legible
        audioOptions = audible?.options ?? []
        subtitleOptions = legible?.options ?? []

        if let audible {
            currentAudioOption = item.currentMediaSelection.selectedMediaOption(in: audible)
        }
        if let legible {
            currentSubtitleOption = item.currentMediaSelection.selectedMediaOption(in: legible)
        }
    }

    private func detachObservers() {
        if let timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
        }
        timeObserverToken = nil
        rateObservation?.invalidate()
        rateObservation = nil
        presentationSizeObservation?.invalidate()
        presentationSizeObservation = nil
        statusObservation?.invalidate()
        statusObservation = nil
        pipPossibleObservation?.invalidate()
        pipPossibleObservation = nil
        audioGroup = nil
        subtitleGroup = nil
        audioOptions = []
        subtitleOptions = []
        currentAudioOption = nil
        currentSubtitleOption = nil
        videoSize = .zero
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let target = CMTime(seconds: max(time, 0), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func rewind(by seconds: TimeInterval = 10) {
        seek(to: max(currentTime - seconds, 0))
    }

    func fastForward(by seconds: TimeInterval = 10) {
        let upperBound = duration > 0 ? duration : .greatestFiniteMagnitude
        seek(to: min(currentTime + seconds, upperBound))
    }

    func togglePictureInPicture() {
        guard let pictureInPictureController else { return }
        if pictureInPictureController.isPictureInPictureActive {
            pictureInPictureController.stopPictureInPicture()
        } else if pictureInPictureController.isPictureInPicturePossible {
            pictureInPictureController.startPictureInPicture()
        }
    }

    func selectAudioOption(_ option: AVMediaSelectionOption?) {
        guard let group = audioGroup, let item = player?.currentItem else { return }
        item.select(option, in: group)
        currentAudioOption = option
    }

    func selectSubtitleOption(_ option: AVMediaSelectionOption?) {
        guard let group = subtitleGroup, let item = player?.currentItem else { return }
        item.select(option, in: group)
        currentSubtitleOption = option
    }
}

extension NewYouTubePlaybackController: AVPictureInPictureControllerDelegate {

    nonisolated func pictureInPictureControllerWillStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor in
            self.isPictureInPictureActive = true
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor in
            self.isPictureInPictureActive = false
        }
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }
}
