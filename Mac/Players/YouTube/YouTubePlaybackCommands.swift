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

    static func seek(_ webView: WKWebView?, by offset: TimeInterval) {
        let script = """
        (function() {
            var video = window.__yt ? window.__yt.getPlaybackVideo() : document.querySelector('video');
            if (!video) { return; }
            var end = isFinite(video.duration) ? video.duration : video.currentTime + \(offset);
            video.currentTime = Math.min(Math.max(video.currentTime + \(offset), 0), end);
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    static func skipAd(_ webView: WKWebView?) {
        webView?.evaluateJavaScript(YouTubePlayerScripts.skipAd, completionHandler: nil)
    }

    /// Takes the video element itself fullscreen, so WebKit shows its native
    /// controls and Esc returns it inline.
    static func enterFullscreen(_ webView: WKWebView?) {
        let script = """
        (function() {
            var video = window.__yt ? window.__yt.getPlaybackVideo() : document.querySelector('video');
            if (!video) { return 'missing'; }
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

    /// Lays the page out as just the video, filling the Picture in Picture
    /// panel, with the media controls hidden so the panel's own show instead.
    static func setPictureInPictureLayout(_ webView: WKWebView?, isEnabled: Bool) {
        let script = """
        (function() {
            \(installPictureInPictureStyle)
            document.documentElement.classList.toggle('sakura-pip', \(isEnabled));
            document.querySelectorAll('video').forEach(function(video) { video.controls = false; });
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    /// Transforms and filters on the video's ancestors would make it fixed to
    /// them rather than the viewport, so they're dropped too.
    private static let installPictureInPictureStyle = """
    if (!document.getElementById('sakura-pip-style')) {
        var style = document.createElement('style');
        style.id = 'sakura-pip-style';
        style.textContent = 'html.sakura-pip video {'
            + ' position: fixed !important; left: 0 !important; top: 0 !important;'
            + ' right: auto !important; bottom: auto !important;'
            + ' width: 100vw !important; height: 100vh !important;'
            + ' max-width: none !important; max-height: none !important;'
            + ' margin: 0 !important; transform: none !important;'
            + ' object-fit: contain !important; background: black !important;'
            + ' z-index: 2147483646 !important; }'
            + ' html.sakura-pip video::-webkit-media-controls { display: none !important; }'
            + ' html.sakura-pip *:has(video) { transform: none !important; filter: none !important;'
            + ' contain: none !important; perspective: none !important; will-change: auto !important; }'
            + ' html.sakura-pip, html.sakura-pip body {'
            + ' background: black !important; overflow: hidden !important; }';
        document.head.appendChild(style);
    }
    """
}
