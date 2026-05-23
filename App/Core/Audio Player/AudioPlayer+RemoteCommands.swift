import MediaPlayer
import Hanami

extension AudioPlayer {

    // MARK: - Remote Commands

    func configureRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        configurePlayCommand(commandCenter)
        configurePauseCommand(commandCenter)
        configureTogglePlayPauseCommand(commandCenter)
        configureSkipForwardCommand(commandCenter)
        configureSkipBackwardCommand(commandCenter)
        configureChangePlaybackPositionCommand(commandCenter)
        configureChangePlaybackRateCommand(commandCenter)
    }

    private func configurePlayCommand(_ commandCenter: MPRemoteCommandCenter) {
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if YouTubePlayerSession.shared.isActive {
                    YouTubePlayerSession.shared.play()
                } else {
                    self?.player?.play()
                    self?.isPlaying = true
                    self?.postNowPlayingUpdate()
                }
            }
            return .success
        }
    }

    private func configurePauseCommand(_ commandCenter: MPRemoteCommandCenter) {
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if YouTubePlayerSession.shared.isActive {
                    YouTubePlayerSession.shared.pause()
                } else {
                    self?.player?.pause()
                    self?.isPlaying = false
                    self?.postNowPlayingUpdate()
                }
            }
            return .success
        }
    }

    private func configureTogglePlayPauseCommand(_ commandCenter: MPRemoteCommandCenter) {
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if YouTubePlayerSession.shared.isActive {
                    YouTubePlayerSession.shared.togglePlayPause()
                } else {
                    self?.togglePlayPause()
                }
            }
            return .success
        }
    }

    private func configureSkipForwardCommand(_ commandCenter: MPRemoteCommandCenter) {
        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            let interval = event.interval
            Task { @MainActor in
                self?.skipForward(interval)
            }
            return .success
        }
    }

    private func configureSkipBackwardCommand(_ commandCenter: MPRemoteCommandCenter) {
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            let interval = event.interval
            Task { @MainActor in
                self?.skipBackward(interval)
            }
            return .success
        }
    }

    private func configureChangePlaybackPositionCommand(_ commandCenter: MPRemoteCommandCenter) {
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let position = event.positionTime
            Task { @MainActor in
                self?.seek(to: position)
            }
            return .success
        }
    }

    private func configureChangePlaybackRateCommand(_ commandCenter: MPRemoteCommandCenter) {
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [
            0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0
        ]
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackRateCommandEvent else {
                return .commandFailed
            }
            let rate = event.playbackRate
            Task { @MainActor in
                self?.setPlaybackRate(rate)
            }
            return .success
        }
    }
}
