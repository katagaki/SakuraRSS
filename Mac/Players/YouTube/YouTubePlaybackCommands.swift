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

    /// Element fullscreen rather than iOS's `webkitEnterFullscreen`, whose
    /// video presentation shows only black on the Mac. YouTube sizes the video
    /// with inline styles, which would keep it small without the override.
    static func enterFullscreen(_ webView: WKWebView?) {
        let script = """
        (function() {
            var video = window.__yt ? window.__yt.getPlaybackVideo() : document.querySelector('video');
            if (!video) { return; }
            if (!document.getElementById('sakura-fullscreen-style')) {
                var style = document.createElement('style');
                style.id = 'sakura-fullscreen-style';
                style.textContent = 'video:fullscreen, video:-webkit-full-screen {'
                    + ' position: fixed !important; inset: 0 !important;'
                    + ' width: 100vw !important; height: 100vh !important;'
                    + ' max-width: none !important; max-height: none !important;'
                    + ' margin: 0 !important; transform: none !important;'
                    + ' object-fit: contain !important; background: black !important; }';
                document.head.appendChild(style);
            }
            if (video.requestFullscreen) {
                video.requestFullscreen().catch(function() {});
            } else if (video.webkitRequestFullscreen) {
                video.webkitRequestFullscreen();
            } else if (video.webkitEnterFullscreen) {
                video.webkitEnterFullscreen();
            }
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
