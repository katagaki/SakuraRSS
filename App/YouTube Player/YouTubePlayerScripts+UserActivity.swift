import Foundation
import Hanami

extension YouTubePlayerScripts {

    // Adapted from Brave's `brave-video-bg-play-update.js`.
    static let inactivitySuppressor = """
    (function() {
        var LACT_REFRESH_MS = 5 * 60 * 1000;
        var INTERACTION_INTERVAL_MS = 10 * 60 * 1000;
        var PLAYER_STATE_INTERVAL_MS = 60 * 1000;

        function findVideo() {
            return document.querySelector(
                'ytd-player video, #movie_player video, video'
            );
        }

        function refreshLact() {
            try {
                if (window._lact !== undefined) {
                    window._lact = Date.now();
                }
            } catch (error) {}
        }

        function waitForLact(callback, interval, delay) {
            var nextDelay = delay || 1000;
            var maxDelay = 60 * 1000;
            if (Object.prototype.hasOwnProperty.call(window, '_lact')) {
                setInterval(callback, interval);
            } else {
                setTimeout(function() {
                    waitForLact(callback, interval,
                        Math.min(nextDelay * 2, maxDelay));
                }, nextDelay);
            }
        }
        waitForLact(refreshLact, LACT_REFRESH_MS);

        setInterval(function() {
            var player = document.querySelector('#movie_player');
            if (player) {
                try {
                    player.dispatchEvent(new MouseEvent('mousemove',
                        { bubbles: true }));
                } catch (error) {}
            }
            refreshLact();
        }, INTERACTION_INTERVAL_MS);

        setInterval(function() {
            var video = findVideo();
            if (video && !video.paused) {
                try {
                    video.dispatchEvent(new Event('timeupdate'));
                } catch (error) {}
            }
        }, PLAYER_STATE_INTERVAL_MS);
    })();
    """
}
