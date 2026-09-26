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
            var visibility = 'unknown';
            try { visibility = state.realVisibilityState(); } catch (error) {}
            state.log('action#' + (++sequence) + ' ' + action
                + ' videoPaused=' + (video ? video.paused : 'missing')
                + ' pagePaused=' + (video ? !!video.__ytPagePaused : 'missing')
                + ' mode=' + (video ? video.webkitPresentationMode : 'missing')
                + ' playerState=' + playerState
                + ' userPaused=' + state.userPaused
                + ' autoplayBlocked=' + state.autoplayBlocked
                + ' exitedPiP=' + state.exitedPiPRecently
                + ' recoveringPiP=' + (video ? !!video.__ytRecoveringPiPPause : false)
                + ' retryMs=' + Math.max(0, state.pipResumeDeadline - Date.now())
                + ' visibility=' + visibility
                + ' time=' + (video && isFinite(video.currentTime)
                    ? video.currentTime.toFixed(2) : 'unknown'));
        };
    })();
    """
}
