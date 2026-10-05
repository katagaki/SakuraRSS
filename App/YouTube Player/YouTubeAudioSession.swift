import AVFoundation
import Hanami

/// Lifecycle helper for the YouTube player's audio session. Setting the category
/// is separated from claiming the audio route so we don't interrupt other apps
/// until the player actually starts playing, and we release the route on dismiss
/// so other apps can resume.
/// macOS has no audio session, so these do nothing there.
enum YouTubeAudioSession {

    static func prepare() {
        #if !os(macOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        #endif
    }

    static func activate() {
        #if !os(macOS)
        log("YT Native", "audio session activation requested")
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            log("YT Native", "audio session activation completed")
        } catch {
            log("YT Native", "audio session activation failed: \(error)")
        }
        #endif
    }

    static func deactivate() {
        #if !os(macOS)
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
        #endif
    }
}
