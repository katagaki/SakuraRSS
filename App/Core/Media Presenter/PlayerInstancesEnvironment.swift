import SwiftUI

private struct YouTubePlayerSessionKey: EnvironmentKey {
    static let defaultValue: YouTubePlayerSession? = nil
}

private struct AudioPlayerKey: EnvironmentKey {
    static let defaultValue: AudioPlayer? = nil
}

extension EnvironmentValues {
    @MainActor
    var youTubePlayerSession: YouTubePlayerSession {
        get { self[YouTubePlayerSessionKey.self] ?? .shared }
        set { self[YouTubePlayerSessionKey.self] = newValue }
    }

    @MainActor
    var podcastAudioPlayer: AudioPlayer {
        get { self[AudioPlayerKey.self] ?? .shared }
        set { self[AudioPlayerKey.self] = newValue }
    }
}
