import SwiftUI
import WebKit
import Hanami

extension Notification.Name {
    static let youTubePlayerDidStartPlaying = Notification.Name("youTubePlayerDidStartPlaying")
}

extension YouTubePlayerView {

    func togglePlayPause() {
        log("YT Native", "togglePlayPause tapped, webView=\(webView != nil)")
        let script = """
        var video = document.querySelectorAll('video')[0];
        if (!video) { return null; }
        if (video.paused) {
            if (window.__yt) {
                window.__yt.autoplayBlocked = false;
                window.__yt.userPaused = false;
                window.__yt.exitedPiPRecently = false;
            }
            var player = document.getElementById('movie_player');
            if (player && typeof player.playVideo === 'function') {
                player.playVideo();
            }
            // The play promise can reject under the autoplay policy, so the
            // resulting state is only known once it settles.
            try { await video.play(); } catch (error) { return false; }
            return !video.paused;
        }
        if (window.__yt) { window.__yt.userPaused = true; }
        video.pause();
        return !video.paused;
        """
        let startingID = playerID
        webView?.callAsyncJavaScript(script, in: nil, in: .page) { result in
            switch result {
            case .success(let value):
                log("YT Native", "toggle result=\(String(describing: value))")
                guard let playing = value as? Bool else { return }
                isPlaying = playing
                if playing {
                    NotificationCenter.default.post(
                        name: .youTubePlayerDidStartPlaying,
                        object: startingID
                    )
                }
            case .failure(let error):
                log("YT Native", "toggle error=\(error)")
            }
        }
    }

    func pauseForOtherPlayer() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video && !video.paused) {
                if (window.__yt) { window.__yt.userPaused = true; }
                video.pause();
            }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func seek(to time: TimeInterval) {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) { video.currentTime = \(time); }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func rewind() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) { video.currentTime = Math.max(0, video.currentTime - 10); }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func fastForward() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) { video.currentTime += 10; }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func enterFullscreen() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video && video.webkitEnterFullscreen) {
                video.webkitEnterFullscreen();
            }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func skipAd() {
        log("YT Native", "skipAd invoked isAd=\(isAd) isAdSkippable=\(isAdSkippable) webView=\(webView != nil)")
        webView?.evaluateJavaScript(YouTubePlayerScripts.skipAd) { result, error in
            log("YT Native", "skipAd result=\(String(describing: result)) error=\(String(describing: error))")
        }
    }

    func togglePiP() {
        // Goes through `__yt.enterPiP` / `__yt.exitPiP` which call the
        // *saved-original* PiP methods.
        // `expectingPiPExit` tells the PiP bridge that this exit is
        // user-initiated, so it doesn't mistake it for a system teardown
        // and suppress the pause guard.
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (!video) { return; }
            if (window.__yt.isInPiP()) {
                window.__yt.expectingPiPExit = true;
                window.__yt.exitPiP(video);
            } else {
                window.__yt.enterPiP(video);
            }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }
}
