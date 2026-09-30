import Foundation

extension YouTubePlayerScripts {
    static let mediaSessionUserActionBridge = """
    (function() {
        if (!('mediaSession' in navigator)) return;
        var mediaSession = navigator.mediaSession;
        var origSet = mediaSession.setActionHandler.bind(mediaSession);
        var pageHandlers = { play: null, pause: null };
        var pipHandler = null;
        window.__yt.setPiPActionHandler = function(handler) {
            pipHandler = handler;
            try { origSet('enterpictureinpicture', handler); } catch (error) {}
        };

        function wrapper(action) {
            return function(details) {
                var pipVideo = window.__yt.getPiPVideo();
                var video = pipVideo || document.querySelector('video');
                window.__yt.logState('mediaSession ' + action + ' received', video);
                if (action === 'pause') {
                    window.__yt.userPaused = true;
                } else {
                    window.__yt.userPaused = false;
                    window.__yt.autoplayBlocked = false;
                    window.__yt.exitedPiPRecently = false;
                }
                var handler = pageHandlers[action];
                if (typeof handler === 'function') {
                    window.__yt.logState('mediaSession ' + action + ' page handler', video);
                    try { handler(details); return; } catch (e) {
                        window.__yt.logState('mediaSession page handler failed', video);
                    }
                }
                video = window.__yt.getPiPVideo() || document.querySelector('video');
                if (!video) {
                    window.__yt.logState('mediaSession fallback video missing', null);
                    return;
                }
                window.__yt.logState('mediaSession ' + action + ' video fallback', video);
                if (action === 'pause') {
                    video.pause();
                } else {
                    var playback = video.play();
                    if (playback && typeof playback.catch === 'function') playback.catch(function(){});
                }
            };
        }

        function install(action) {
            try { origSet(action, wrapper(action)); } catch (e) {}
        }

        mediaSession.setActionHandler = function(action, handler) {
            if (action === 'play' || action === 'pause') {
                pageHandlers[action] = handler || null;
                install(action);
                return;
            }
            if (action === 'enterpictureinpicture' && pipHandler) {
                return origSet(action, pipHandler);
            }
            return origSet(action, handler);
        };

        install('play');
        install('pause');
    })();
    """

}
