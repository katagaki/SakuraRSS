import Foundation

extension YouTubePlayerScripts {
    static let inactivitySuppressor = """
    (function() {
        var lastRefresh = 0;
        document.addEventListener('timeupdate', function(event) {
            var video = event.target;
            if (!(video instanceof HTMLVideoElement) || video.paused || video.ended) return;
            var now = Date.now();
            if (now - lastRefresh < 60000) return;
            lastRefresh = now;
            if (typeof window._lact === 'number') window._lact = now;
        }, true);
    })();
    """
}
