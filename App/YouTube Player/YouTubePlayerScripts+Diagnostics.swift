import Foundation
import Hanami

extension YouTubePlayerScripts {
    static let playbackDiagnostics = """
    (function() {
        if (!window.__yt) return;
        var sequence = 0;
        window.__yt.logState = function(action, video) {
            if (!window.webkit || !window.webkit.messageHandlers
                || !window.webkit.messageHandlers.ytDebug) return;
            var player = document.getElementById('movie_player');
            var playerState = 'missing';
            try {
                if (player && typeof player.getPlayerState === 'function') {
                    playerState = player.getPlayerState();
                }
            } catch (error) { playerState = 'error'; }
            var state = window.__yt;
            var mediaSessionState = 'unavailable';
            try { mediaSessionState = navigator.mediaSession.playbackState; }
            catch (error) {}
            var visibility = 'unknown';
            try { visibility = state.realVisibilityState(); } catch (error) {}
            state.log('action#' + (++sequence) + ' ' + action
                + ' videoPaused=' + (video ? video.paused : 'missing')
                + ' readyState=' + (video ? video.readyState : 'missing')
                + ' sourcePresent=' + (video ? !!(video.currentSrc || video.srcObject) : 'missing')
                + ' mode=' + (video ? video.webkitPresentationMode : 'missing')
                + ' nativePiP=' + state.isInPiP()
                + ' playerState=' + playerState
                + ' mediaSessionState=' + mediaSessionState
                + ' userPaused=' + state.userPaused
                + ' autoplayBlocked=' + state.autoplayBlocked
                + ' exitedPiP=' + state.exitedPiPRecently
                + ' visibility=' + visibility
                + ' time=' + (video && isFinite(video.currentTime)
                    ? video.currentTime.toFixed(2) : 'unknown'));
        };
    })();
    """
}
