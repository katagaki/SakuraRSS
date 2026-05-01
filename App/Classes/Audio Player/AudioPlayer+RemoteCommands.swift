import MediaPlayer

// swiftlint:disable function_body_length
extension AudioPlayer {

    // MARK: - Remote Commands

    func configureRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

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

        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            let interval = event.interval
            Task { @MainActor in
                self?.skipForward(interval)
            }
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            let interval = event.interval
            Task { @MainActor in
                self?.skipBackward(interval)
            }
            return .success
        }

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
// swiftlint:enable function_body_length
