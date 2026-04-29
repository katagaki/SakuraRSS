import AVFoundation

/// Lifecycle helper for the YouTube player's audio session. Setting the category
/// is separated from claiming the audio route so we don't interrupt other apps
/// until the player actually starts playing, and we release the route on dismiss
/// so other apps can resume.
enum YouTubeAudioSession {

    static func prepare() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
    }

    static func activate() {
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
    }
}
