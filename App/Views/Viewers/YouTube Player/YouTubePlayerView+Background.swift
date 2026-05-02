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
            if wantsPlaybackInBackground && !isPlaying {
                resumePlaybackIfNeeded()
            }
            wantsPlaybackInBackground = false
            // iOS may tear down PiP during background without firing a
            // `webkitpresentationmodechanged` event the page can observe.
            // Force-resync from the canonical iOS-side property so the
            // overlay matches reality on return.
            resyncPiPState()
        @unknown default:
            break
        }
    }

    func resyncPiPState() {
        let script = """
        (function() {
            var v = document.querySelector('video');
            if (!v) { return false; }
            return v.webkitPresentationMode === 'picture-in-picture';
        })();
        """
        webView?.evaluateJavaScript(script) { result, _ in
            let actuallyInPiP = (result as? Bool) ?? false
            if isPiP != actuallyInPiP {
                isPiP = actuallyInPiP
            }
        }
    }

    /// Safety net for the rare case the audio session lost the route while we
    /// were backgrounded. With detection isolation in place YouTube no longer
    /// pauses on visibility changes, so this is normally a no-op. Bails when
    /// the user explicitly paused (e.g. via the Lock Screen Now Playing
    /// control) so returning to the app doesn't override their intent.
    func resumePlaybackIfNeeded() {
        let script = """
        (function() {
            if (window.__yt && window.__yt.userPaused === true) return;
            var v = document.querySelector('video');
            if (v && v.paused && !v.ended) {
                var p = v.play();
                if (p && typeof p.catch === 'function') { p.catch(function(){}); }
            }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }
}
