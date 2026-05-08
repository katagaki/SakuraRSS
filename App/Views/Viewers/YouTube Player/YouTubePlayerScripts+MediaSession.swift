import Foundation

extension YouTubePlayerScripts {

    /// Prevents YouTube from forcing PiP to close during ads by neutralizing
    /// any `disablePictureInPicture` writes on `<video>` elements.
    static let pipDisableOverride = """
    (function() {
        try {
            var proto = HTMLVideoElement.prototype;
            if (!proto.__ytPiPDisableOverridden) {
                proto.__ytPiPDisableOverridden = true;
                Object.defineProperty(proto, 'disablePictureInPicture', {
                    configurable: true,
                    get: function() { return false; },
                    set: function() {}
                });
            }
        } catch (e) {}
        function strip(video) {
            if (!video) return;
            try { video.removeAttribute('disablepictureinpicture'); } catch (e) {}
            try { video.removeAttribute('disablePictureInPicture'); } catch (e) {}
        }
        function scan() { document.querySelectorAll('video').forEach(strip); }
        scan();
        var observer = new MutationObserver(scan);
        if (document.documentElement) {
            observer.observe(document.documentElement, {
                childList: true, subtree: true,
                attributes: true,
                attributeFilter: ['disablepictureinpicture', 'disablePictureInPicture']
            });
        }
    })();
    """

    /// Bridges system Now Playing play/pause taps (Lock Screen, Control Center,
    /// PiP overlay, headset clicker) to the `__yt.userPaused` flag so the pause
    /// guard knows the pause was user-initiated and shouldn't be auto-resumed.
    static let mediaSessionUserActionBridge = """
    (function() {
        if (!('mediaSession' in navigator)) return;
        var ms = navigator.mediaSession;
        var origSet = ms.setActionHandler.bind(ms);
        var pageHandlers = { play: null, pause: null };

        function wrapper(action) {
            return function() {
                if (action === 'pause') {
                    window.__yt.userPaused = true;
                } else {
                    window.__yt.userPaused = false;
                    window.__yt.autoplayBlocked = false;
                    window.__yt.exitedPiPRecently = false;
                }
                var h = pageHandlers[action];
                if (typeof h === 'function') {
                    try { h(); return; } catch (e) {}
                }
                var v = document.querySelector('video');
                if (!v) return;
                if (action === 'pause') {
                    v.pause();
                } else {
                    var p = v.play();
                    if (p && typeof p.catch === 'function') p.catch(function(){});
                }
            };
        }

        function install(action) {
            try { origSet(action, wrapper(action)); } catch (e) {}
        }

        ms.setActionHandler = function(action, handler) {
            if (action === 'play' || action === 'pause') {
                pageHandlers[action] = handler || null;
                install(action);
                return;
            }
            return origSet(action, handler);
        };

        install('play');
        install('pause');
    })();
    """

}
