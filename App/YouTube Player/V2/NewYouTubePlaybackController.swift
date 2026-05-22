import AVFoundation
import AVKit
import Foundation
import MediaPlayer
import SwiftUI
import Hanami

/// Controls and observes an `AVPlayer` for the experimental YouTube player.
@MainActor
@Observable
final class NewYouTubePlaybackController: NSObject {

    static let shared = NewYouTubePlaybackController(isPrimary: true)

    /// Whether this is the app-wide shared controller. Detached-window
    /// instances are not primary and skip global Now Playing updates.
    @ObservationIgnored
    let isPrimary: Bool

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
    @ObservationIgnored var nowPlayingTitle: String?
    @ObservationIgnored var nowPlayingArtist: String?
    @ObservationIgnored var nowPlayingArtworkURL: String?
    @ObservationIgnored var cachedArtwork: MPMediaItemArtwork?
    @ObservationIgnored private var pictureInPictureController: AVPictureInPictureController?
    @ObservationIgnored private var lastPostedElapsedTime: TimeInterval = -1
    @ObservationIgnored private var resourceLoader: LocalHLSResourceLoader?

    @ObservationIgnored private var timeObserverToken: Any?
    @ObservationIgnored private var rateObservation: NSKeyValueObservation?
    @ObservationIgnored private var presentationSizeObservation: NSKeyValueObservation?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var pipPossibleObservation: NSKeyValueObservation?
    @ObservationIgnored var audioGroup: AVMediaSelectionGroup?
    @ObservationIgnored var subtitleGroup: AVMediaSelectionGroup?

    var aspectRatio: CGFloat {
        guard videoSize.width > 0, videoSize.height > 0 else { return 16.0 / 9.0 }
        return videoSize.width / videoSize.height
    }

    init(isPrimary: Bool = false) {
        self.isPrimary = isPrimary
        super.init()
    }

    /// Loads a new stream for the given video. If the same video is already
    /// loaded, this is a no-op and the existing player keeps playing.
    func load(
        source: YouTubePlaybackSource,
        videoID: String,
        title: String? = nil,
        artist: String? = nil,
        artworkURLString: String? = nil
    ) {
        if currentVideoID == videoID, player != nil {
            applyMetadata(title: title, artist: artist, artworkURLString: artworkURLString)
            return
        }
        clear()
        YouTubeAudioSession.prepare()
        YouTubeAudioSession.activate()
        let newPlayer = AVPlayer(playerItem: makePlayerItem(for: source))
        newPlayer.appliesMediaSelectionCriteriaAutomatically = false
        let originalCriteria = AVPlayerMediaSelectionCriteria(
            preferredLanguages: nil,
            preferredMediaCharacteristics: [.isOriginalContent]
        )
        newPlayer.setMediaSelectionCriteria(originalCriteria, forMediaCharacteristic: .audible)
        attach(player: newPlayer)
        currentVideoID = videoID
        applyMetadata(title: title, artist: artist, artworkURLString: artworkURLString)
        newPlayer.play()
    }

    private func makePlayerItem(for source: YouTubePlaybackSource) -> AVPlayerItem {
        switch source {
        case .remoteHLS(let url):
            return AVPlayerItem(asset: AVURLAsset(url: url))
        case .localHLS(let stream):
            let loader = LocalHLSResourceLoader(stream: stream)
            resourceLoader = loader
            let asset = AVURLAsset(url: LocalHLSResourceLoader.masterURL)
            asset.resourceLoader.setDelegate(loader, queue: loader.queue)
            return AVPlayerItem(asset: asset)
        }
    }

    func updateMetadata(title: String?, artist: String?, artworkURLString: String?) {
        applyMetadata(title: title, artist: artist, artworkURLString: artworkURLString)
    }

    private func applyMetadata(title: String?, artist: String?, artworkURLString: String?) {
        nowPlayingTitle = title
        nowPlayingArtist = artist
        if nowPlayingArtworkURL != artworkURLString {
            cachedArtwork = nil
            nowPlayingArtworkURL = artworkURLString
            loadArtwork(from: artworkURLString)
        }
        postNowPlayingUpdate()
    }

    /// Stops playback, releases the player, and deactivates the audio session.
    func clear() {
        if let pictureInPictureController, pictureInPictureController.isPictureInPictureActive {
            pictureInPictureController.stopPictureInPicture()
        }
        detachObservers()
        player?.pause()
        pictureInPictureController = nil
        resourceLoader = nil
        player = nil
        currentVideoID = nil
        nowPlayingTitle = nil
        nowPlayingArtist = nil
        nowPlayingArtworkURL = nil
        cachedArtwork = nil
        lastPostedElapsedTime = -1
        clearNowPlayingInfo()
        if isPrimary {
            YouTubeAudioSession.deactivate()
        }
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
                    if abs(seconds - self.lastPostedElapsedTime) >= 1.0 {
                        self.lastPostedElapsedTime = seconds
                        self.updateNowPlayingElapsedTime(seconds)
                    }
                }
                if let item = player.currentItem {
                    let durationSeconds = item.duration.seconds
                    if durationSeconds.isFinite, durationSeconds > 0,
                       self.duration != durationSeconds {
                        self.duration = durationSeconds
                        self.postNowPlayingUpdate()
                    }
                }
            }
        }

        rateObservation = player.observe(\.rate, options: [.initial, .new]) { [weak self] observed, _ in
            let rate = observed.rate
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = rate > 0
                self.postNowPlayingUpdate()
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
        let wasPlaying = player.timeControlStatus != .paused
        updateNowPlayingElapsedTime(max(time, 0))
        player.seek(
            to: target, toleranceBefore: .positiveInfinity, toleranceAfter: .positiveInfinity
        ) { [weak self] finished in
            guard finished, wasPlaying else { return }
            Task { @MainActor in self?.player?.play() }
        }
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
