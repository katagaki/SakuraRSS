import AVFoundation
import SwiftUI
import WebKit
import Hanami

extension YouTubePlayerView {

    func prepareBackgroundAudioSession() {
        YouTubeAudioSession.prepare()
    }

    /// Claiming the route interrupts other apps, so it waits until playback
    /// actually starts instead of happening when the player appears.
    func activateAudioSessionForPlayback() {
        YouTubeAudioSession.activate()
    }

    func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        log("YT Native", "scene \(oldPhase) -> \(newPhase) isPlaying=\(isPlaying) isPiP=\(isPiP)")
        switch newPhase {
        case .background, .inactive:
            // Coming back passes through `.inactive` too, after the video may
            // have been paused in the background; only leaving `.active` says
            // whether it was playing. PiP carries playback on its own, and
            // closing it in the background is a deliberate stop.
            if oldPhase == .active {
                wantsPlaybackInBackground = isPlaying && !isPiP
            }
            session.rememberPlaybackPosition()
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
            log("YT Native", "PiP resync result=\(actuallyInPiP) wasPiP=\(isPiP)")
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
            if (window.__yt && window.__yt.exitedPiPRecently === true) return;
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
