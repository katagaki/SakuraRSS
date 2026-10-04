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

    static func enterFullscreen(_ webView: WKWebView?) {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video && video.webkitEnterFullscreen) { video.webkitEnterFullscreen(); }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    static func togglePictureInPicture(_ webView: WKWebView?) {
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
