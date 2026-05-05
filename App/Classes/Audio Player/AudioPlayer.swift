import AVFoundation
import Combine
import MediaPlayer
import SwiftUI

@Observable
final class AudioPlayer {

    static let shared = AudioPlayer()

    // MARK: - State

    var isPlaying = false
    var duration: TimeInterval = 0
    var isLoading = false

    var currentArticleID: Int64?
    var currentFeedID: Int64?
    var currentEpisodeTitle: String?
    var currentFeedTitle: String?
    var currentArtworkURL: String?
    var cachedArtwork: MPMediaItemArtwork?

    var playbackRate: Float = 1.0

    // MARK: - Internal

    var player: AVPlayer?
    var cancellables: Set<AnyCancellable> = []

    /// Live read of playback position. Views drive their refresh cadence via
    /// `TimelineView` so updates only happen while the seek bar is visible.
    func currentTime() -> TimeInterval {
        guard let player else { return 0 }
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    private init() {
        let storedRate = UserDefaults.standard.float(forKey: "Podcast.PlaybackSpeed")
        playbackRate = storedRate > 0 ? storedRate : 1.0
        configureRemoteCommands()
    }

    // MARK: - Audio Session

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
    }

    // MARK: - Playback

    // swiftlint:disable function_parameter_count
    func play(
        url: URL,
        articleID: Int64,
        feedID: Int64,
        episodeTitle: String,
        feedTitle: String,
        artworkURL: String?,
        feedIconURL: String? = nil,
        episodeDuration: Int?
    ) {
        stop()
        Task { @MainActor in
            YouTubePlayerSession.shared.clear()
        }

        activateAudioSession()
        isLoading = true
        currentArticleID = articleID
        currentFeedID = feedID
        currentEpisodeTitle = episodeTitle
        currentFeedTitle = feedTitle
        currentArtworkURL = artworkURL
        loadArtwork(from: artworkURL ?? feedIconURL)

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        playerItem.publisher(for: \.status)
            .filter { $0 == .readyToPlay }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.isLoading = false
                let itemDuration = playerItem.duration.seconds
                self.duration = itemDuration.isFinite ? itemDuration : Double(episodeDuration ?? 0)
                self.player?.play()
                self.player?.rate = self.playbackRate
                self.isPlaying = true
                self.postNowPlayingUpdate()
            }
            .store(in: &cancellables)
    }
    // swiftlint:enable function_parameter_count

    func togglePlayPause() {
        guard player != nil else { return }
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
            player?.rate = playbackRate
        }
        isPlaying.toggle()
        postNowPlayingUpdate()
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        UserDefaults.standard.set(rate, forKey: "Podcast.PlaybackSpeed")
        if isPlaying {
            player?.rate = rate
        }
        postNowPlayingUpdate()
    }

    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        updateNowPlayingElapsedTime(time)
    }

    func skipForward(_ seconds: TimeInterval = 30) {
        seek(to: min(currentTime() + seconds, duration))
    }

    func skipBackward(_ seconds: TimeInterval = 15) {
        seek(to: max(currentTime() - seconds, 0))
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        duration = 0
        isLoading = false
        currentArticleID = nil
        currentFeedID = nil
        currentEpisodeTitle = nil
        currentFeedTitle = nil
        currentArtworkURL = nil
        cachedArtwork = nil
        cancellables.removeAll()
        clearNowPlayingInfo()
    }
}
