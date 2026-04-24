import SwiftUI
import WebKit

extension Notification.Name {
    static let youTubePlayerDidStartPlaying = Notification.Name("youTubePlayerDidStartPlaying")
}

extension YouTubePlayerView {

    func togglePlayPause() {
        #if DEBUG
        print("[YT Native] togglePlayPause tapped, webView=\(webView != nil)")
        #endif
        let script = """
        (function() {
            var videos = document.querySelectorAll('video');
            try { window.webkit.messageHandlers.ytDebug.postMessage('toggle: videos=' + videos.length); } catch(e) {}
            var video = videos[0];
            if (video) {
                try { window.webkit.messageHandlers.ytDebug.postMessage('toggle: paused=' + video.paused); } catch(e) {}
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
        webView?.evaluateJavaScript(script) { result, error in
            #if DEBUG
            print("[YT Native] toggle result=\(String(describing: result)) error=\(String(describing: error))")
            #endif
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

    func skipAd() {
        #if DEBUG
        print("[YT Native] skipAd invoked isAd=\(isAd) isAdSkippable=\(isAdSkippable) "
            + "webView=\(webView != nil)")
        #endif
        webView?.evaluateJavaScript(YouTubePlayerScripts.skipAd) { result, error in
            #if DEBUG
            print("[YT Native] skipAd result=\(String(describing: result)) "
                + "error=\(String(describing: error))")
            #endif
        }
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
