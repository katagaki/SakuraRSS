import AVFoundation
import SwiftUI
import WebKit

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

extension YouTubePlayerView {

    func activateBackgroundAudioSession() {
        YouTubeAudioSession.prepare()
        YouTubeAudioSession.activate()
    }

    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background, .inactive:
            wantsPlaybackInBackground = isPlaying
        case .active:
            if wantsPlaybackInBackground {
                resumePlaybackIfNeeded()
                wantsPlaybackInBackground = false
            }
        @unknown default:
            break
        }
    }

    func resumePlaybackIfNeeded() {
        let script = """
        (function() {
            var v = document.querySelector('video');
            if (v && v.paused && !v.ended && window.__ytUserPaused !== true) {
                var p = v.play();
                if (p && typeof p.catch === 'function') { p.catch(function(){}); }
            }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }
}
