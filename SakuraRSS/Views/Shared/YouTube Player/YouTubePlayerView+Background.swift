import AVFoundation
import SwiftUI
import WebKit

/// Applies the playback audio session exactly once per app launch. Re-running
/// `setCategory`/`setActive` during scene transitions causes a brief audio drop.
enum YouTubeAudioSession {

    private static var isConfigured = false

    static func configureForPlaybackIfNeeded() {
        guard !isConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
        isConfigured = true
    }
}

extension YouTubePlayerView {

    func activateBackgroundAudioSession() {
        YouTubeAudioSession.configureForPlaybackIfNeeded()
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
