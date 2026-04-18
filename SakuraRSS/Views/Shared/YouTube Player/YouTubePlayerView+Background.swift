import AVFoundation
import SwiftUI
import WebKit

extension YouTubePlayerView {

    func activateBackgroundAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }

    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background, .inactive:
            wantsPlaybackInBackground = isPlaying
            activateBackgroundAudioSession()
            if isPlaying {
                resumePlaybackIfNeeded()
            }
        case .active:
            activateBackgroundAudioSession()
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
            if (v && v.paused) { v.play().catch(function(){}); }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }
}
