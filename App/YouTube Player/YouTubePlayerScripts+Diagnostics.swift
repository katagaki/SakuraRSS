import Foundation
import Hanami

extension YouTubePlayerScripts {
    static let playbackDiagnostics = """
    (function() {
        if (!window.__yt) return;
        var sequence = 0;
        var loggedPolicies = new WeakSet();
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
            if (player && !loggedPolicies.has(player) && typeof player.getWebPlayerContextConfig === 'function') {
                try {
                    var config = player.getWebPlayerContextConfig();
                    if (config && typeof config.serializedExperimentFlags === 'string') {
                        var flags = new URLSearchParams(config.serializedExperimentFlags);
                        state.log('player policy background=' + flags.get('mweb_allow_background_playback')
                            + ' blockPiP=' + flags.get('uniplayer_block_pip')
                            + ' blockPiPProgress=' + flags.get('html5_picture_in_picture_blocking_ontimeupdate'));
                        loggedPolicies.add(player);
                    }
                } catch (error) {}
            }
            var bufferedAhead = 0;
            try {
                for (var index = 0; video && index < video.buffered.length; index++) {
                    if (video.buffered.start(index) <= video.currentTime
                        && video.currentTime <= video.buffered.end(index)) {
                        bufferedAhead = video.buffered.end(index) - video.currentTime;
                        break;
                    }
                }
            } catch (error) {}
            var mediaSessionState = 'unavailable';
            try { mediaSessionState = navigator.mediaSession.playbackState; }
            catch (error) {}
            var visibility = 'unknown';
            try { visibility = state.realVisibilityState(); } catch (error) {}
            state.log('action#' + (++sequence) + ' ' + action
                + ' videoPaused=' + (video ? video.paused : 'missing')
                + ' readyState=' + (video ? video.readyState : 'missing')
                + ' networkState=' + (video ? video.networkState : 'missing')
                + ' mediaError=' + (video && video.error
                    ? video.error.code + ':' + video.error.message : 'none')
                + ' bufferedAhead=' + bufferedAhead.toFixed(2)
                + ' sourcePresent=' + (video ? !!(video.currentSrc || video.srcObject) : 'missing')
                + ' mode=' + (video ? state.realPresentationMode(video) : 'missing')
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
        ['playing', 'waiting', 'stalled', 'emptied', 'error'].forEach(function(type) {
            window.addEventListener(type, function(event) {
                if (event.target !== window.__yt.getPlaybackVideo()) return;
                window.__yt.logState('media ' + type, event.target);
            }, true);
        });
    })();
    """
}
