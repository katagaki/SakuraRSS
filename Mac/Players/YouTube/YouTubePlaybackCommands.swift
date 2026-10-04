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
    /// video presentation shows only black on the Mac.
    static func enterFullscreen(_ webView: WKWebView?) {
        guard let webView else { return }
        YouTubeFullscreenFitter.track(webView)
        let script = """
        (function() {
            \(installVideoFillStyle)
            var video = window.__yt ? window.__yt.getPlaybackVideo() : document.querySelector('video');
            if (!video) { return; }
            if (video.requestFullscreen) {
                video.requestFullscreen().catch(function() {});
            } else if (video.webkitRequestFullscreen) {
                video.webkitRequestFullscreen();
            }
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    /// Lays the page out as just the video while it plays in the floating
    /// window, leaving fullscreen first so WebKit's own controls don't stack
    /// on the window's.
    static func setPictureInPictureLayout(_ webView: WKWebView?, isActive: Bool) {
        let script = """
        (function() {
            \(installVideoFillStyle)
            if (\(isActive) && document.fullscreenElement) { document.exitFullscreen().catch(function() {}); }
            document.documentElement.classList.toggle('sakura-pip', \(isActive));
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    /// YouTube sizes the video with inline styles for the inline player, and
    /// may fullscreen its player rather than the video, so these fill the
    /// screen or window with the video whatever the page set.
    private static let installVideoFillStyle = """
    if (!document.getElementById('sakura-video-fill-style')) {
        var fill = 'position: fixed !important; inset: 0 !important;'
            + ' width: 100vw !important; height: 100vh !important;'
            + ' max-width: none !important; max-height: none !important;'
            + ' margin: 0 !important; transform: none !important;'
            + ' object-fit: contain !important; background: black !important;'
            + ' z-index: 2147483646 !important;';
        var style = document.createElement('style');
        style.id = 'sakura-video-fill-style';
        style.textContent = 'video:fullscreen, video:-webkit-full-screen,'
            + ' :fullscreen video, :-webkit-full-screen video, html.sakura-pip video {' + fill + '}'
            + ' html.sakura-pip, html.sakura-pip body { background: black !important; overflow: hidden !important; }';
        document.head.appendChild(style);
    }
    """
}
