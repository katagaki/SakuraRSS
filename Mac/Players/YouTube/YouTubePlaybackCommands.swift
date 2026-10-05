import Hanami
import WebKit

/// The page-side commands the Mac player sends, alongside the session's own
/// play and pause.
enum YouTubePlaybackCommands {

    static func seek(_ webView: WKWebView?, to time: TimeInterval) {
        webView?.evaluateJavaScript(
            "(function(){var video=document.querySelector('video');if(video){video.currentTime=\(time);}})();",
            completionHandler: nil
        )
    }

    static func skipAd(_ webView: WKWebView?) {
        webView?.evaluateJavaScript(YouTubePlayerScripts.skipAd, completionHandler: nil)
    }

    /// Hands the video element to the system's Picture in Picture window,
    /// going through `window.__yt` since the page's own calls are blocked.
    static func togglePictureInPicture(_ webView: WKWebView?) {
        let script = """
        (function() {
            var video = window.__yt && window.__yt.getPlaybackVideo();
            if (!video) { return 'missing'; }
            if (window.__yt.isInPiP()) {
                window.__yt.expectingPiPExit = true;
                window.__yt.exitPiP(window.__yt.getPiPVideo());
                return 'exit';
            }
            if (video.webkitSupportsPresentationMode
                && !video.webkitSupportsPresentationMode('picture-in-picture')) {
                return 'unsupported';
            }
            window.__yt.enterPiP(video);
            return 'enter';
        })();
        """
        webView?.evaluateJavaScript(script) { result, error in
            // swiftlint:disable:next line_length
            log("YT Mac", "togglePictureInPicture result=\(String(describing: result)) error=\(String(describing: error))")
        }
    }

    /// Takes the video element itself fullscreen, so WebKit shows its native
    /// controls and Esc returns it inline.
    static func enterFullscreen(_ webView: WKWebView?) {
        let script = """
        (function() {
            var video = window.__yt ? window.__yt.getPlaybackVideo() : document.querySelector('video');
            if (!video) { return 'missing'; }
            if (window.__yt && window.__yt.isInPiP()) {
                window.__yt.expectingPiPExit = true;
                window.__yt.exitPiP(window.__yt.getPiPVideo());
            }
            if (video.webkitEnterFullscreen) {
                video.webkitEnterFullscreen();
                return 'webkitEnterFullscreen';
            }
            if (video.requestFullscreen) {
                video.requestFullscreen().catch(function() {});
                return 'requestFullscreen';
            }
            return 'unsupported';
        })();
        """
        webView?.evaluateJavaScript(script) { result, error in
            log("YT Mac", "enterFullscreen result=\(String(describing: result)) error=\(String(describing: error))")
        }
    }
}
