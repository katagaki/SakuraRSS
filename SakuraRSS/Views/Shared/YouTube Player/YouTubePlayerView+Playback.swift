import SwiftUI
import WebKit

extension Notification.Name {
    static let youTubePlayerDidStartPlaying = Notification.Name("youTubePlayerDidStartPlaying")
}

extension YouTubePlayerView {

    func togglePlayPause() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) {
                if (video.paused) {
                    window.__ytUserPaused = false;
                    video.play();
                } else {
                    window.__ytUserPaused = true;
                    video.pause();
                }
                return !video.paused;
            }
            return null;
        })();
        """
        let startingID = playerID
        webView?.evaluateJavaScript(script) { result, _ in
            if let playing = result as? Bool {
                isPlaying = playing
                if playing {
                    NotificationCenter.default.post(
                        name: .youTubePlayerDidStartPlaying,
                        object: startingID
                    )
                }
            }
        }
    }

    func pauseForOtherPlayer() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video && !video.paused) {
                window.__ytUserPaused = true;
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

    func togglePiP() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) {
                if (document.pictureInPictureElement) {
                    document.exitPictureInPicture();
                } else if (video.requestPictureInPicture) {
                    video.requestPictureInPicture();
                }
            }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }
}
