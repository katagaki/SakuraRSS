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

    /// Lays the page out as just the video, filling the floating or fullscreen
    /// window it has moved into; `nil` puts the page back. The size comes from
    /// the window since YouTube's own layout, sized for the inline player,
    /// can't be trusted to follow it.
    static func setVideoOnlyLayout(_ webView: WKWebView?, size: CGSize?) {
        let script = """
        (function() {
            \(installVideoOnlyStyle)
            var root = document.documentElement;
            root.style.setProperty('--sakura-video-width', '\(Int(size?.width ?? 0))px');
            root.style.setProperty('--sakura-video-height', '\(Int(size?.height ?? 0))px');
            root.classList.toggle('sakura-video-only', \(size != nil));
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    /// Transforms and filters on the video's ancestors would make it fixed to
    /// them rather than the window, so they're dropped too.
    private static let installVideoOnlyStyle = """
    if (!document.getElementById('sakura-video-only-style')) {
        var style = document.createElement('style');
        style.id = 'sakura-video-only-style';
        style.textContent = 'html.sakura-video-only video {'
            + ' position: fixed !important; left: 0 !important; top: 0 !important;'
            + ' right: auto !important; bottom: auto !important;'
            + ' width: var(--sakura-video-width) !important; height: var(--sakura-video-height) !important;'
            + ' max-width: none !important; max-height: none !important;'
            + ' margin: 0 !important; transform: none !important;'
            + ' object-fit: contain !important; background: black !important;'
            + ' z-index: 2147483646 !important; }'
            + ' html.sakura-video-only *:has(video) { transform: none !important; filter: none !important;'
            + ' contain: none !important; perspective: none !important; will-change: auto !important; }'
            + ' html.sakura-video-only, html.sakura-video-only body {'
            + ' background: black !important; overflow: hidden !important; }';
        document.head.appendChild(style);
    }
    """
}
