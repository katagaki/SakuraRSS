import Foundation

extension YouTubePlayerScripts {
    static let mediaSessionUserActionBridge = """
    (function() {
        if (!('mediaSession' in navigator)) return;
        var mediaSession = navigator.mediaSession;
        var originalSet = mediaSession.setActionHandler.bind(mediaSession);
        var pipHandler = null;
        window.__yt.setPiPActionHandler = function(handler) {
            pipHandler = handler;
            try { originalSet('enterpictureinpicture', handler); } catch (error) {}
        };
        var handlers = {};
        ['play', 'pause', 'stop'].forEach(function(action) {
            handlers[action] = function() {
                var video = window.__yt.getPlaybackVideo();
                if (!video) return;
                window.__yt.logState('native mediaSession ' + action, video);
                if (action === 'play') {
                    window.__yt.userPaused = false;
                    window.__yt.autoplayBlocked = false;
                    window.__yt.exitedPiPRecently = false;
                    var playback = window.__yt.resumeVideo(video);
                    if (playback && typeof playback.catch === 'function') {
                        playback.catch(function() {
                            window.__yt.logState('mediaSession play rejected', video);
                        });
                    }
                } else {
                    window.__yt.userPaused = true;
                    window.__yt.pauseVideo(video);
                }
            };
        });
        mediaSession.setActionHandler = function(action, handler) {
            if (Object.prototype.hasOwnProperty.call(handlers, action)) {
                return originalSet(action, handlers[action]);
            }
            if (action === 'enterpictureinpicture' && pipHandler) {
                return originalSet(action, pipHandler);
            }
            return originalSet(action, handler);
        };
        Object.keys(handlers).forEach(function(action) {
            try { originalSet(action, handlers[action]); } catch (error) {}
        });
    })();
    """
}
