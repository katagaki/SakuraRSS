import AVFoundation
import SwiftUI
import WebKit

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
